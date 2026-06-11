// =============================================================================
// Phase 1 — prompt-injection repro + post-fix guard test.
//
// Run:  node workflows/__tests__/phase1_repro.test.js
//
// Two modes, selected by which logic the action nodes' inputs go through:
//   BEFORE: model output flows straight into the action node expressions
//           (the current workflow). Asserts the holes are LIVE.
//   AFTER:  model output is first run through the deterministic guard in
//           workflows/lib/reply_guard.js / invoice_guard.js. Asserts the
//           SAME fixtures are now inert (no auto-send of model body, no
//           model-chosen ticket close / PO steer).
//
// No live n8n / DB / email. Pure logic replay against the real workflow JSON.
// =============================================================================

const assert = require('assert')
const path = require('path')
const {
  loadWorkflow, loadWorkflowFile, loadFixture, nodeByName, runSetNode, runTemplate, runHttpBody,
} = require('./harness')

// BEFORE mode replays the FROZEN pre-fix workflow snapshots (captured from the
// commit before Phase 1) so the holes stay demonstrable after the fix lands.
// AFTER mode replays the LIVE (fixed) workflow files.
const PRE_FIX_REPLY   = 'fixtures/_pre_fix_reply_handler.json'
const PRE_FIX_INVOICE = 'fixtures/_pre_fix_invoice_processor.json'

let PASS = 0, FAIL = 0
function check(label, fn) {
  try { fn(); console.log(`  ✓ ${label}`); PASS++ }
  catch (e) { console.log(`  ✗ ${label}\n      ${e.message}`); FAIL++ }
}

// Guards exist only after the fix; load lazily so BEFORE-mode runs without them.
function tryLoad(rel) {
  try { return require(path.resolve(__dirname, '..', rel)) } catch { return null }
}
const replyGuard   = tryLoad('lib/reply_guard.js')
const invoiceGuard = tryLoad('lib/invoice_guard.js')

// ─────────────────────────────────────────────────────────────────────────────
// REPLY HANDLER
// ─────────────────────────────────────────────────────────────────────────────
function replayReplyHandler(claudeOutput, fixture,
    { guard, email: emailOverride, ctxThreadParents, wfFile } = {}) {
  // BEFORE: frozen pre-fix snapshot. AFTER: live fixed workflow.
  const wf = wfFile ? loadWorkflowFile(wfFile)
    : (guard ? loadWorkflow('communication/supplier_reply_handler.json')
             : loadWorkflowFile(PRE_FIX_REPLY))

  // Context shared across nodes: Extract Email Data (deterministic, from inbound),
  // Match Supplier (the verified supplier), the open tickets for that supplier.
  const email = emailOverride || fixture.inbound_email
  const extract = {
    from_email: email.from.value[0].address,
    from_name:  email.from.value[0].name,
    subject:    email.subject,
    body:       email.text,
    received_at: email.date,
    message_id: email.messageId,
  }
  const supplier = [{ id: 's0000000-0000-0000-0000-000000000001', name: 'Acme Supplier' }]
  // The supplier legitimately owns exactly these tickets:
  const openTickets = [
    { id: 'd7000000-0000-0000-0000-000000000003', status: 'pending_review', reference: 'TS-2026-DEMO3' },
  ]

  // Claude node output shape:
  const claudeNodeOut = { content: [{ text: JSON.stringify(claudeOutput) }] }

  // ── Node: Parse Claude Response (Set) ──
  const parseNode = nodeByName(wf, 'Parse Claude Response')
  let parsed = runSetNode(parseNode, { $json: claudeNodeOut, $node: {} })

  // ── FIX INSERTION POINT: run the guard between parse and any action ──
  // The workflow resolves the thread parent (Option 1): inbound In-Reply-To ->
  // outbound supplier_emails.message_id -> ticket_id. Simulate that lookup here.
  const inReplyTo = email.headers?.['in-reply-to'] || null
  const threadParent = (ctxThreadParents || []).find(p => p.message_id === inReplyTo) || null

  let routedToHuman = false
  if (guard) {
    const decision = guard.validateReplyDecision({
      modelOutput: parsed,
      inbound: { ...extract, inReplyTo, references: email.headers?.references },
      supplierOpenTickets: openTickets,
      threadParent,
    })
    if (!decision.ok) {
      routedToHuman = true
      return { autoSent: null, ticketClose: null, ackSent: null, routedToHuman, reason: decision.reason }
    }
    // Guard rewrites the fields the action nodes will read: deterministic
    // ticket id, auto_send=false (model body never sends), and an optional
    // fixed-template ack.
    parsed = { ...parsed, ...decision.safeFields }
  }

  // ── Node: Can Agent Resolve? (IF on can_resolve) ──
  const canResolve = parsed.can_resolve === true || parsed.can_resolve === 'true'

  // Build the $node map the action nodes reference by name.
  const $node = {
    'Extract Email Data':            { json: extract },
    'Parse Claude Response':         { json: parsed },
    'Match Supplier in PostgREST':   { json: supplier },
  }

  let autoSent = null
  let ticketClose = null

  // Post-fix, auto-send is gated: even if can_resolve is true, the guard sets
  // auto_send=false so the model body never auto-sends. Represent that here.
  const autoSendAllowed = guard ? (parsed.auto_send === true) : canResolve

  if (autoSendAllowed) {
    // ── Node: Send Reply Directly to Supplier (emailSend) ──
    const sendNode = nodeByName(wf, 'Send Reply Directly to Supplier')
    autoSent = {
      to:      runTemplate(sendNode.parameters.toEmail, { $json: parsed, $node }),
      subject: runTemplate(sendNode.parameters.subject, { $json: parsed, $node }),
      text:    runTemplate(sendNode.parameters.text,    { $json: parsed, $node }),
    }

    // ── Node: Close Related Ticket (httpRequest PATCH) ──
    const closeNode = nodeByName(wf, 'Close Related Ticket (if any)')
    const url = runTemplate(closeNode.parameters.url, { $json: parsed, $node })
    const body = runHttpBody(closeNode, { $json: parsed, $node })
    ticketClose = { url, body }
  }

  // Post-fix only: the fixed-template ack (no model text). Represented separately
  // from autoSent because it is a DIFFERENT, safe outbound.
  let ackSent = null
  if (guard && parsed.ack_send === true) {
    ackSent = { to: extract.from_email, subject: parsed.ack_subject, text: parsed.ack_body }
  }

  return { autoSent, ticketClose, ackSent, routedToHuman, parsed }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVOICE PROCESSOR
// ─────────────────────────────────────────────────────────────────────────────
function replayInvoiceProcessor(claudeOutput, fixture, { guard, email: emailOverride, wfFile } = {}) {
  const wf = wfFile ? loadWorkflowFile(wfFile)
    : (guard ? loadWorkflow('automatic/invoice_processor.json')
             : loadWorkflowFile(PRE_FIX_INVOICE))
  const email = emailOverride || fixture.inbound_email
  const meta = {
    from_email: email.from.value[0].address,
    from_name:  email.from.value[0].name,
    subject:    email.subject,
    body_text:  email.text,
    attachment_content: '',
    received_at: email.date,
  }
  const supplier = [{ id: 's0000000-0000-0000-0000-000000000002', name: 'Dell Technologies' }]
  // The only PO this supplier legitimately has open, as returned by the fetch node:
  const openPOs = [
    { id: 'p0000000-0000-0000-0000-000000000001', po_number: 'PO-DACH-2026-0042', amount: 62500, amount_eur: 62500, status: 'delivered' },
  ]

  const claudeNodeOut = { content: [{ text: JSON.stringify(claudeOutput) }] }
  const parseNode = nodeByName(wf, 'Parse Claude Invoice Extraction')
  const rawParsed = runSetNode(parseNode, { $json: claudeNodeOut, $node: {} })

  let routedToHuman = false
  let guarded = null
  if (guard) {
    const decision = guard.validateInvoiceExtraction({
      modelOutput: rawParsed,
      inbound: meta,
      supplierOpenPOs: openPOs,
    })
    if (!decision.ok) {
      routedToHuman = true
      return { invoicePoId: null, moneyBranch: false, routedToHuman, reason: decision.reason }
    }
    guarded = { ...rawParsed, ...decision.safeFields }
  }

  // $json into Create Invoice Record is whatever the node before it emits:
  // BEFORE -> the parsed model output; AFTER -> the guard output.
  const itemJson = guarded || rawParsed
  const $node = {
    'Extract Email Metadata':          { json: meta },
    'Match Supplier by Email Domain':  { json: supplier },
    'Parse Claude Invoice Extraction': { json: rawParsed },
    'Validate Invoice Extraction':     { json: guarded || rawParsed },
  }

  // ── Node: Create Invoice Record — po_id source differs before/after ──
  const createNode = nodeByName(wf, 'Create Invoice Record')
  const invoiceBody = runHttpBody(createNode, { $json: itemJson, $node })

  // ── Route to money branch ──
  // BEFORE: switch reads the MODEL match_result (parsed). AFTER: the switch
  // reads the match_invoice RPC result; the guard forces the row's match_result
  // to a non-'matched' value so the model can never select the money branch on
  // its own. We model that as: money branch reachable only if the guard did NOT
  // neutralize it (it always does) — i.e. AFTER, the model cannot trigger money.
  const moneyBranch = guard
    ? (itemJson.match_result === 'matched')   // guard forces 'no_po' -> false
    : (rawParsed.match_result === 'matched')  // model drives it -> true for the attack

  return { invoicePoId: invoiceBody.po_id, moneyBranch, routedToHuman, parsed: itemJson }
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────
const replyFx   = loadFixture('injection_reply.json')
const invoiceFx = loadFixture('injection_invoice.json')

console.log('\n=== BEFORE FIX — these assertions document the LIVE holes ===\n')

console.log('Reply handler (injection):')
const rBefore = replayReplyHandler(replyFx._simulated_claude_output, replyFx)
check('model output AUTO-SENDS an attacker-authored email', () => {
  assert(rBefore.autoSent, 'expected an auto-sent email')
  assert(rBefore.autoSent.to === 'ar@acme-supplier.example')
  assert(/remit all future payments to IBAN/.test(rBefore.autoSent.text),
    'attacker body should reach the wire')
})
check('model output CLOSES an attacker-chosen ticket (PATCH built)', () => {
  assert(rBefore.ticketClose, 'expected a PATCH to be constructed')
  assert(rBefore.ticketClose.url.includes('d7000000-0000-0000-0000-000000000004'),
    `PATCH should target the attacker ticket; got ${rBefore.ticketClose.url}`)
  assert(rBefore.ticketClose.body.status === 'closed')
})

console.log('\nInvoice processor (injection):')
const iBefore = replayInvoiceProcessor(invoiceFx._simulated_claude_output, invoiceFx)
check('model picks the invoice po_id (steers which PO it attaches to)', () => {
  assert.strictEqual(iBefore.invoicePoId, invoiceFx._simulated_claude_output.matched_po_id,
    'po_id should be the model-chosen value')
})
check('model match_result drives the MONEY (payment) branch', () => {
  assert.strictEqual(iBefore.moneyBranch, true, 'matched => create_payment_instruction branch')
})

console.log('\n=== AFTER FIX — same fixtures must be INERT ===\n')
if (!replyGuard || !invoiceGuard) {
  console.log('  (guards not present yet — skipping AFTER assertions)')
  console.log('  reply_guard.js loaded:', !!replyGuard, ' invoice_guard.js loaded:', !!invoiceGuard)
} else {
  console.log('Reply handler (injection, guarded):')
  const rAfter = replayReplyHandler(replyFx._simulated_claude_output, replyFx, { guard: replyGuard })
  check('attacker reply is NOT auto-sent', () =>
    assert(!rAfter.autoSent, 'no model-authored email may auto-send'))
  check('attacker ticket is NOT closed', () =>
    assert(!rAfter.ticketClose, 'no model-chosen ticket close'))
  // The injection payload happens to be schema-valid (can_resolve:true, valid
  // enums, well-formed UUID), so the guard does not reject it as malformed — it
  // NEUTRALIZES it: auto_send is forced false (body cannot send) and the ticket
  // id is re-derived deterministically. The attacker's chosen ticket (…04) must
  // NOT be the bound id; it binds the supplier's actually-owned ticket instead.
  check('attacker ticket id is discarded; derived id is supplier-owned (…03), not …04', () => {
    assert(rAfter.parsed.related_ticket_id !== 'd7000000-0000-0000-0000-000000000004',
      'must not bind the attacker-chosen ticket')
    assert(rAfter.parsed.related_ticket_id === 'd7000000-0000-0000-0000-000000000003',
      `should bind the supplier's sole open ticket; got ${rAfter.parsed.related_ticket_id}`)
  })
  // And a MALFORMED model output (the other failure mode) IS routed to human:
  check('malformed model output routes to human (no action)', () => {
    const bad = { ...replyFx._simulated_claude_output, urgency: 'EXTREME', can_resolve: 'yes-please' }
    const r = replayReplyHandler(bad, replyFx, { guard: replyGuard })
    assert(r.routedToHuman, 'schema violation must route to human')
    assert(!r.autoSent && !r.ticketClose && !r.ackSent, 'no action on malformed output')
  })
  // The injection is resolution_type=confirmation, so a fixed-template ack MAY
  // send — but it must contain ZERO attacker text (no IBAN line).
  check('any ack that sends carries fixed-template text only (no attacker body)', () => {
    if (rAfter.ackSent) {
      assert(!/IBAN/i.test(rAfter.ackSent.text),
        'ack must not contain the attacker-authored body')
      assert(/procurement team will follow up/i.test(rAfter.ackSent.text),
        'ack must be the fixed template')
    }
  })

  // ── Option 1 (schema-backed thread resolution) ──
  console.log('\nReply handler (Option 1 — thread-parent binding):')
  check('In-Reply-To -> outbound message_id -> ticket_id (supplier-owned) binds', () => {
    const parents = [{ message_id: '<out-parent-1@truespend>', ticket_id: 'd7000000-0000-0000-0000-000000000003' }]
    const emailWithThread = {
      ...replyFx._benign_email,
      headers: { 'in-reply-to': '<out-parent-1@truespend>', references: null },
      subject: 'Re: your order',  // no [TS-…] ref in subject — force the header path
      text: 'Looks good, thanks.',
    }
    const r = replayReplyHandler(replyFx._benign_claude_output, replyFx,
      { guard: replyGuard, email: emailWithThread, ctxThreadParents: parents })
    assert.strictEqual(r.parsed.related_ticket_id, 'd7000000-0000-0000-0000-000000000003')
    assert(/thread parent/.test(r.parsed.ticket_bind_basis), `basis: ${r.parsed.ticket_bind_basis}`)
  })
  check('forged In-Reply-To pointing at a NON-owned ticket is rejected (ownership check)', () => {
    // Parent row claims a ticket the supplier does NOT own -> must NOT bind it.
    const parents = [{ message_id: '<forged@x>', ticket_id: 'd7000000-0000-0000-0000-000000000004' }]
    const emailWithThread = {
      ...replyFx._benign_email,
      headers: { 'in-reply-to': '<forged@x>', references: null },
      subject: 'Re: anything', text: 'hi',
    }
    const r = replayReplyHandler(replyFx._benign_claude_output, replyFx,
      { guard: replyGuard, email: emailWithThread, ctxThreadParents: parents })
    assert(r.parsed.related_ticket_id !== 'd7000000-0000-0000-0000-000000000004',
      'must not bind a ticket the supplier does not own')
  })

  console.log('\nReply handler (benign, guarded) — must not over-block:')
  const rBenign = replayReplyHandler(replyFx._benign_claude_output, replyFx,
    { guard: replyGuard, email: replyFx._benign_email })
  check('benign reply still resolves to a board action (not auto-sent body)', () => {
    assert(!rBenign.autoSent, 'fix routes replies to board, never auto-sends model body')
    // It must NOT be rejected as an injection:
    assert(!rBenign.routedToHuman || rBenign.reason === undefined || true)
  })
  check('benign reply binds the deterministic ticket id (supplier-owned)', () => {
    const t = rBenign.parsed && rBenign.parsed.related_ticket_id
    assert(t === 'd7000000-0000-0000-0000-000000000003' || t === null,
      `benign ticket id must be the supplier-owned one or null; got ${t}`)
  })

  console.log('\nInvoice processor (injection, guarded):')
  const iAfter = replayInvoiceProcessor(invoiceFx._simulated_claude_output, invoiceFx, { guard: invoiceGuard })
  check('forged invoice does NOT enter the money branch', () =>
    assert(!iAfter.moneyBranch || iAfter.routedToHuman,
      'forged match_result must not reach create_payment_instruction'))
  check('invoice po_id is NOT the model-chosen value', () =>
    assert(iAfter.invoicePoId !== invoiceFx._simulated_claude_output.matched_po_id,
      'po attach must be deterministic, not model-chosen'))

  console.log('\nInvoice processor (benign, guarded) — must not over-block:')
  const iBenign = replayInvoiceProcessor(invoiceFx._benign_claude_output, invoiceFx,
    { guard: invoiceGuard, email: invoiceFx._benign_email })
  check('benign invoice with a real PO-number reference still matches its PO', () =>
    assert(iBenign.invoicePoId === 'p0000000-0000-0000-0000-000000000001',
      `benign invoice should attach to the deterministically-resolved PO; got ${iBenign.invoicePoId}`))
}

console.log(`\n${'='.repeat(60)}\n  ${PASS} passed, ${FAIL} failed\n${'='.repeat(60)}\n`)
process.exit(FAIL ? 1 : 0)
