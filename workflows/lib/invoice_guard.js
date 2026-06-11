// =============================================================================
// invoice_guard.js — deterministic validation gate for the Invoice Processor.
//
// Governing principle: "LLM advises, deterministic code decides."
// Claude extracts invoice fields (advice). This gate:
//   1. Validates the extraction against a strict schema + match_result allowlist.
//      On violation -> { ok:false } -> route to a dispute ticket (human), no money.
//   2. DERIVES the PO this invoice attaches to (po_id) deterministically — never
//      from the model's matched_po_id:
//        a. parse a PO number (PO-XXX / the supplier's open PO numbers) from the
//           invoice subject/body/attachment text;
//        b. bind ONLY to a PO the supplier actually has open (supplierOpenPOs).
//      If no PO number resolves to an open supplier PO -> po_id = null. A null
//      po_id makes match_invoice return 'no_po' server-side (dispute, no payment).
//   3. Does NOT trust the model's match_result to gate money. The downstream
//      match_invoice RPC re-derives the match from po_id + amount tolerance.
//      The guard's safeFields.match_result is forced to 'pending' so the n8n
//      Route switch CANNOT take the payment branch on the model's say-so; the
//      authoritative result comes back from the RPC.
//
// Single source of truth; the n8n Code node "Validate Invoice Extraction" copies
// validateInvoiceExtraction()'s body (asserted by scripts/sync-workflow-guards.js).
// =============================================================================

'use strict'

const MATCH_RESULTS = new Set(['matched', 'amount_mismatch', 'no_po', 'no_delivery'])
// PO numbers in this system look like PO-<BRANCH>-<YEAR>-<seq>, e.g. PO-DACH-2026-0042.
const PO_NUM_RE = /\bPO-[A-Z]{2,5}-\d{4}-\d{2,6}\b/g

function isNum(v) { return typeof v === 'number' && Number.isFinite(v) }
function toNum(v)  { const n = parseFloat(v); return Number.isFinite(n) ? n : NaN }

function coerce(o) {
  const c = { ...o }
  c.amount     = toNum(c.amount)
  c.amount_eur = toNum(c.amount_eur)
  if (c.matched_po_id === 'null' || c.matched_po_id === '') c.matched_po_id = null
  if (c.matched_po_number === 'null' || c.matched_po_number === '') c.matched_po_number = null
  if (c.invoice_number === 'null' || c.invoice_number === '') c.invoice_number = null
  return c
}

// Deterministic PO binding — independent of model output.
function derivePoId({ inbound, supplierOpenPOs }) {
  const byNum = new Map((supplierOpenPOs || []).map(p => [p.po_number, p.id]))
  const hay = `${inbound.subject || ''}\n${inbound.body_text || ''}\n${inbound.attachment_content || ''}`
  const nums = hay.match(PO_NUM_RE) || []
  for (const n of nums) {
    if (byNum.has(n)) return { id: byNum.get(n), basis: `PO number ${n}` }
  }
  return { id: null, basis: 'no PO number resolved to an open supplier PO' }
}

function validateInvoiceExtraction({ modelOutput, inbound, supplierOpenPOs }) {
  const o = coerce(modelOutput)
  const errs = []

  if (o.invoice_number == null || typeof o.invoice_number !== 'string')
    errs.push('invoice_number missing')
  if (!isNum(o.amount) || o.amount <= 0)        errs.push(`amount invalid: ${o.amount}`)
  if (!isNum(o.amount_eur) || o.amount_eur <= 0) errs.push(`amount_eur invalid: ${o.amount_eur}`)
  if (o.match_result != null && !MATCH_RESULTS.has(o.match_result))
    errs.push(`match_result not in allowlist: ${o.match_result}`)

  if (errs.length) {
    return { ok: false, reason: errs.join('; '), routeToHuman: true }
  }

  const bind = derivePoId({ inbound, supplierOpenPOs })

  return {
    ok: true,
    routeToHuman: false,
    safeFields: {
      // po_id is deterministic. null -> match_invoice returns 'no_po' (dispute).
      matched_po_id: bind.id,
      po_bind_basis: bind.basis,
      // Force the n8n Route switch off the money branch. The AUTHORITATIVE match
      // comes from the match_invoice RPC after the invoice row is written.
      match_result: 'pending',
      // keep extracted numerics for the invoice row (server re-validates amounts):
      amount: o.amount,
      amount_eur: o.amount_eur,
      invoice_number: o.invoice_number,
    },
  }
}

module.exports = { validateInvoiceExtraction, derivePoId, MATCH_RESULTS }
