#!/usr/bin/env node
/**
 * Patches credentials onto nodes in live n8n workflows.
 * Uses PATCH /api/v1/workflows/:id to inject credential IDs by node type.
 */
const https = require('https');

const API_KEY = process.env.N8N_API_KEY;
const BASE   = 'https://n8n-n3xl.eugenmueller.tech/api/v1';

// Map node type â†’ credential type + id + name
const TYPE_TO_CRED = {
  'n8n-nodes-base.httpRequest':     { type: 'httpHeaderAuth',         id: 'diPB8BwY8mvOiQb3', name: 'Authorization-TrueSpend' },
  'n8n-nodes-base.emailReadImap':   { type: 'imap',                   id: 'exBmmkmgHSx799Np', name: 'IMAP-Procurement' },
  'n8n-nodes-base.emailSend':       { type: 'smtp',                   id: '4nJqszHi2HtSAqVx', name: 'SMTP-TrueSpend' },
  'n8n-nodes-base.jira':            { type: 'jiraSoftwareCloudApi',   id: 'MYydmb8FjLgo9CxM', name: 'Jira TrueSpend' },
};

// For invoice_processor: IMAP-Invoices instead of IMAP-Procurement
const INVOICE_IMAP = { type: 'imap', id: 'IVh1LNAvDdK3xYMJ', name: 'IMAP-Invoices' };

// Workflows to patch: id â†’ use invoice imap?
const WORKFLOWS = [
  { id: 'Qo0kSA8k1QXn8aLs', name: 'Automatic Reorder Trigger',        invoiceImap: false },
  { id: 'ULwmYavPqMs5VfGW', name: 'Supplier Reply Handler',            invoiceImap: false },
  { id: 'YvRX2dz8YQllBDL9', name: 'Hyperscaler Daily Monitor',         invoiceImap: false },
  { id: 'gHjP1datJ7srrN6H', name: 'Invoice Processor',                 invoiceImap: true  },
  { id: 'ptQ0nc8RXIgMwi9t', name: 'Daily Contract Watcher',            invoiceImap: false },
  { id: 'vH3Q5qftisZkBR3M', name: 'Intake Receiver',                   invoiceImap: false },
  { id: 'oLsj4j8YVQSG5aeQ', name: 'Supplier Onboarding & Compliance',  invoiceImap: false },
];

// PostgREST nodes: only assign httpHeaderAuth if URL matches postgrest
const POSTGREST_URL = 'postgrest-production-7960.up.railway.app';

function req(method, path, body) {
  return new Promise((resolve, reject) => {
    const url  = new URL(BASE + path);
    const data = body ? JSON.stringify(body) : null;
    const opts = {
      hostname: url.hostname, port: 443,
      path: url.pathname + url.search, method,
      headers: {
        'X-N8N-API-KEY': API_KEY,
        'Content-Type': 'application/json',
        'Content-Length': data ? Buffer.byteLength(data) : 0,
      },
    };
    const r = https.request(opts, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(buf) }); }
        catch { resolve({ status: res.statusCode, body: buf }); }
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

function patchNodeCreds(node, useInvoiceImap) {
  const cred = TYPE_TO_CRED[node.type];
  if (!cred) return false;

  // For httpRequest nodes: only assign PostgREST auth if they call PostgREST URL
  if (node.type === 'n8n-nodes-base.httpRequest') {
    const url = node.parameters?.url || node.parameters?.options?.url || '';
    if (!String(url).includes(POSTGREST_URL) && !String(url).includes('postgrest')) {
      return false; // Not a PostgREST node (e.g. Anthropic httpRequest)
    }
  }

  // IMAP: use invoice mailbox for invoice_processor
  let c = cred;
  if (node.type === 'n8n-nodes-base.emailReadImap' && useInvoiceImap) {
    c = INVOICE_IMAP;
  }

  node.credentials = node.credentials || {};
  node.credentials[c.type] = { id: c.id, name: c.name };
  return true;
}

async function main() {
  for (const wf of WORKFLOWS) {
    console.log(`\nâ”€â”€ ${wf.name} (${wf.id})`);

    // GET current workflow
    const get = await req('GET', `/workflows/${wf.id}`);
    if (get.status !== 200) { console.log(`  GET failed: ${get.status}`); continue; }

    const workflow = get.body;
    let patched = 0;

    for (const node of workflow.nodes) {
      if (patchNodeCreds(node, wf.invoiceImap)) {
        console.log(`  patched: ${node.name} (${node.type})`);
        patched++;
      }
    }

    if (patched === 0) { console.log('  nothing to patch'); continue; }

    // PUT workflow with updated nodes
    const put = await req('PUT', `/workflows/${wf.id}`, {
      name:        workflow.name,
      nodes:       workflow.nodes,
      connections: workflow.connections,
      settings:    workflow.settings || {},
    });

    if (put.status === 200) {
      console.log(`  saved (${patched} nodes patched)`);
    } else {
      console.log(`  PUT failed ${put.status}: ${JSON.stringify(put.body).substring(0,300)}`);
    }
  }

  // Activate all
  console.log('\nâ”€â”€ Activating all 7 workflows...');
  for (const wf of WORKFLOWS) {
    const r = await req('POST', `/workflows/${wf.id}/activate`, {});
    const active = r.body?.active;
    if (active) {
      console.log(`  âœ…  ${wf.name}`);
    } else {
      const msg = typeof r.body === 'object' ? r.body.message : r.body;
      console.log(`  âŒ  ${wf.name}: ${String(msg).substring(0,150)}`);
    }
  }
  console.log('\nDone.');
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
