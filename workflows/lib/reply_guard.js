// =============================================================================
// reply_guard.js — deterministic validation gate for the Supplier Reply Handler.
//
// Governing principle: "LLM advises, deterministic code decides."
// Claude's JSON is ADVICE. This module is the deterministic gate that sits
// between the model and any action. It:
//   1. Validates the model output against a strict schema + enum allowlist.
//      On ANY violation -> { ok:false } -> the workflow routes to a human and
//      takes NO action.
//   2. DERIVES related_ticket_id deterministically (never from the model):
//        a. PRIMARY (Option 1, schema-backed): match the inbound In-Reply-To /
//           References Message-ID to the parent outbound supplier_emails row and
//           take its ticket_id (resolved by the workflow, handed in as
//           `threadParent`);
//        b. else parse a [TS-YYYY-...] reference from the inbound subject/body,
//           accept it ONLY if it matches a ticket the supplier actually owns;
//        c. else, if the supplier has exactly ONE open ticket, bind that;
//        d. else bind null (no ticket touched).
//   3. NEVER auto-sends a model-authored body. A SUBSTANTIVE reply (the model's
//      draft) is queued to the Operations Board as pending_confirm for a human.
//      A zero-touch acknowledgment is allowed ONLY as a FIXED TEMPLATE with no
//      model-authored text (ack_template below) — gated to safe resolution_types.
//
// This file is the single source of truth. The n8n Code node "Validate Reply
// Decision" contains a copy of validateReplyDecision()'s body (see
// scripts/sync-workflow-guards.js, which asserts they have not drifted).
// =============================================================================

'use strict'

const RESOLUTION_TYPES = new Set([
  'confirmation', 'query_answer', 'invoice_clarification', 'delivery_update',
  'negotiation', 'dispute', 'escalation_request', 'other',
])
const URGENCIES = new Set(['low', 'medium', 'high', 'critical'])

// A TrueSpend ticket reference looks like TS-2026-DEMO3 / TS-2026-INV-4821 etc.
const TICKET_REF_RE = /\bTS-\d{4}-[A-Z0-9-]{1,20}\b/g
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function isBool(v) { return v === true || v === false }
function isStr(v)  { return typeof v === 'string' }

// Normalize the Set-node string fields back to real types (the Set node stores
// everything as strings via n8n expressions).
function coerce(modelOutput) {
  const o = { ...modelOutput }
  if (o.can_resolve === 'true')  o.can_resolve = true
  if (o.can_resolve === 'false') o.can_resolve = false
  if (o.route_to_human === 'true')  o.route_to_human = true
  if (o.route_to_human === 'false') o.route_to_human = false
  if (o.route_reason === 'null' || o.route_reason === '') o.route_reason = null
  if (o.related_ticket_id === 'null' || o.related_ticket_id === '') o.related_ticket_id = null
  return o
}

// Deterministic ticket binding — independent of model output.
// `threadParent` is the outbound supplier_emails row the inbound reply answers,
// resolved by the workflow via In-Reply-To/References -> message_id (Option 1).
function deriveTicketId({ inbound, supplierOpenTickets, threadParent }) {
  const byRef = new Map((supplierOpenTickets || []).map(t => [t.reference, t.id]))

  // (a) PRIMARY: thread parent (matched by Message-ID) carries the ticket_id.
  // Trust it only if that ticket is still one this supplier owns (defense in
  // depth against a stale/forged parent row).
  if (threadParent && threadParent.ticket_id) {
    const ownedIds = new Set((supplierOpenTickets || []).map(t => t.id))
    if (ownedIds.has(threadParent.ticket_id)) {
      return { id: threadParent.ticket_id, basis: `thread parent (message_id ${threadParent.message_id || '?'})` }
    }
  }

  // (b) reference parsed from the inbound subject/body, validated against owned set
  const hay = `${inbound.subject || ''}\n${inbound.body || ''}`
  const refs = hay.match(TICKET_REF_RE) || []
  for (const ref of refs) {
    if (byRef.has(ref)) return { id: byRef.get(ref), basis: `reference ${ref}` }
  }

  // (c) exactly one open ticket for this supplier -> safe to bind
  if ((supplierOpenTickets || []).length === 1) {
    return { id: supplierOpenTickets[0].id, basis: 'sole open ticket for supplier' }
  }

  // (d) ambiguous / none -> bind nothing
  return { id: null, basis: 'no deterministic match' }
}

// Fixed-template acknowledgment — the ONLY zero-touch outbound allowed.
// No model-authored text; the only interpolated value is the deterministic
// ticket reference (or a generic phrase if none bound). Enabled only for
// low-risk resolution types where a "received, we'll respond" ack is correct.
const ACK_TYPES = new Set(['confirmation', 'query_answer', 'delivery_update', 'other'])
function buildAck({ ticketRef }) {
  const ref = ticketRef ? ` (ref ${ticketRef})` : ''
  return {
    subject: `Re: your message${ref} — received`,
    body:
      `Thank you for your message${ref}. We have received it and a member of the ` +
      `procurement team will follow up shortly.\n\nTrueSpend Procurement`,
  }
}

function validateReplyDecision({ modelOutput, inbound, supplierOpenTickets, threadParent }) {
  const o = coerce(modelOutput)
  const errs = []

  // ── strict schema ──
  if (!isBool(o.can_resolve))           errs.push('can_resolve must be boolean')
  if (!isBool(o.route_to_human))        errs.push('route_to_human must be boolean')
  if (!isStr(o.resolution_type) || !RESOLUTION_TYPES.has(o.resolution_type))
    errs.push(`resolution_type not in allowlist: ${o.resolution_type}`)
  if (!isStr(o.urgency) || !URGENCIES.has(o.urgency))
    errs.push(`urgency not in allowlist: ${o.urgency}`)
  if (!isStr(o.reply_subject)) errs.push('reply_subject must be a string')
  if (!isStr(o.reply_body))    errs.push('reply_body must be a string')

  // The model may NOT supply a ticket id at all. If it tries to, we ignore it,
  // but a malformed value is a signal of tampering -> note it (non-fatal; we
  // derive deterministically regardless).
  if (o.related_ticket_id != null && !(isStr(o.related_ticket_id) && UUID_RE.test(o.related_ticket_id))) {
    errs.push('related_ticket_id (model) is malformed (ignored; derived instead)')
  }

  if (errs.length) {
    return { ok: false, reason: errs.join('; '), routeToHuman: true }
  }

  // ── deterministic ticket binding (model value discarded) ──
  const bind = deriveTicketId({ inbound, supplierOpenTickets, threadParent })
  const ticketRef = (supplierOpenTickets || []).find(t => t.id === bind.id)?.reference || null

  // ── action policy ──
  // NEVER auto-send a model-authored body. The model's draft (subject/body) is
  // carried to the Operations Board as a pending_confirm ticket; a human confirms.
  // A zero-touch FIXED-TEMPLATE ack is allowed for low-risk types only — no model
  // text on the wire. Whether to actually send the ack is the workflow's call;
  // the guard just provides it and marks it safe.
  const ackAllowed = o.can_resolve === true && o.route_to_human === false
    && ACK_TYPES.has(o.resolution_type)
  const ack = ackAllowed ? buildAck({ ticketRef }) : null

  return {
    ok: true,
    routeToHuman: false,
    safeFields: {
      // The model body NEVER auto-sends. This stays false unconditionally.
      auto_send: false,
      // A fixed-template ack MAY auto-send (no model text). Off unless ackAllowed.
      ack_send: ackAllowed,
      ack_subject: ack ? ack.subject : null,
      ack_body: ack ? ack.body : null,
      related_ticket_id: bind.id,       // <- deterministic, supplier-owned or null
      ticket_reference: ticketRef,
      ticket_bind_basis: bind.basis,
      // draft fields preserved for the human, clearly marked as draft:
      draft_reply_subject: o.reply_subject,
      draft_reply_body: o.reply_body,
      resolution_type: o.resolution_type,
      urgency: o.urgency,
      reasoning: o.reasoning,
      // carried through for the audit-log PATCH (non-action fields):
      commitments_extracted: o.commitments_extracted,
      route_to_human: o.route_to_human,
      route_reason: o.route_reason,
    },
  }
}

module.exports = { validateReplyDecision, deriveTicketId, RESOLUTION_TYPES, URGENCIES }
