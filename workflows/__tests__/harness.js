// =============================================================================
// Phase 1 repro/guard harness — shared helpers
//
// This does NOT call live n8n, the live DB, or send real email (those are gated).
// It loads the ACTUAL workflow JSON and replays the real node logic:
//   - the Set node that parses Claude's JSON ("Parse Claude Response" /
//     "Parse Claude Invoice Extraction")
//   - the IF / switch that gates the action branch
//   - the action nodes' parameter expressions (email send, PATCH /tickets,
//     POST /invoices, RPC calls)
//
// It then reports which ACTIONS would fire and with what parameters, given a
// supplied (worst-case) Claude output. That is the security boundary under test:
// "does model output alone reach an action?" — independent of how the model was
// coerced into producing it.
//
// The harness also imports the post-fix guard (validateReplyDecision /
// validateInvoiceExtraction) so the SAME fixtures can be proven inert after the
// fix.
// =============================================================================

const fs = require('fs')
const path = require('path')

const WF_DIR = path.resolve(__dirname, '..')

function loadWorkflow(relPath) {
  return JSON.parse(fs.readFileSync(path.join(WF_DIR, relPath), 'utf8'))
}

// Load a workflow JSON from an explicit path under __tests__ (used for the
// frozen pre-fix snapshots so the BEFORE proof survives the fix landing).
function loadWorkflowFile(absOrTestRelPath) {
  const p = path.isAbsolute(absOrTestRelPath)
    ? absOrTestRelPath
    : path.join(__dirname, absOrTestRelPath)
  return JSON.parse(fs.readFileSync(p, 'utf8'))
}

function loadFixture(name) {
  return JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8'))
}

function nodeByName(wf, name) {
  const n = wf.nodes.find(x => x.name === name)
  if (!n) throw new Error(`node not found: ${name}`)
  return n
}

// ── n8n expression evaluation (the subset the workflows use) ────────────────
// The workflows use `={{ ... }}` and `=...{{ ... }}` expressions. We replicate
// the two evaluators the real nodes use:
//   - Set node "string" values: each is a single `={{ expr }}`
//   - httpRequest URL/body: a template string with embedded `{{ expr }}`
// `$json` and `$node[...]` resolve against a provided context.

function evalExpr(expr, ctx) {
  // expr is the JS inside {{ }}. Provide $json / $node / JSON / encodeURIComponent / new Date.
  const $json = ctx.$json
  const $node = ctx.$node
  // eslint-disable-next-line no-new-func
  const fn = new Function('$json', '$node', 'JSON', 'encodeURIComponent', 'Date',
    `return (${expr});`)
  return fn($json, $node, JSON, encodeURIComponent, Date)
}

// Evaluate a Set node's string values into a plain object (this is what becomes
// $json for the next node).
function runSetNode(node, ctx) {
  const out = {}
  const vals = node.parameters.values.string || []
  for (const { name, value } of vals) {
    // value looks like "={{ EXPR }}"
    const m = value.match(/^=\{\{([\s\S]*)\}\}$/)
    out[name] = m ? evalExpr(m[1].trim(), ctx) : value
  }
  return out
}

// Evaluate a template string with embedded {{ }} (httpRequest url / a single body param).
function runTemplate(tpl, ctx) {
  // strip a leading "=" (n8n marks expressions with it)
  const s = tpl.startsWith('=') ? tpl.slice(1) : tpl
  return s.replace(/\{\{([\s\S]*?)\}\}/g, (_, e) => String(evalExpr(e.trim(), ctx)))
}

// Pull the single body param expression out of an httpRequest node and evaluate it.
// The workflows wrap bodies as `={{ JSON.stringify({...}) }}`, so the evaluated
// result is a JSON string. Parse it back to an object for inspection; if it was
// not stringified (rare), return it as-is.
function runHttpBody(node, ctx) {
  const p = node.parameters.bodyParameters.parameters.find(x => x.name === 'body')
  const m = p.value.match(/^=\{\{([\s\S]*)\}\}$/)
  const v = evalExpr(m[1].trim(), ctx)
  if (typeof v === 'string') {
    try { return JSON.parse(v) } catch { return v }
  }
  return v
}

module.exports = {
  loadWorkflow, loadWorkflowFile, loadFixture, nodeByName,
  evalExpr, runSetNode, runTemplate, runHttpBody,
}
