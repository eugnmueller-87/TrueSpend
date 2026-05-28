#!/usr/bin/env node
/**
 * TrueSpend n8n Workflow Importer
 * Imports all 7 workflows with credentials pre-wired.
 */

const fs   = require('fs');
const path = require('path');
const https = require('https');

const N8N_URL = 'https://n8n-n3xl.eugenmueller.tech';
const API_KEY = process.env.N8N_API_KEY;

// Credential ID map (all confirmed in n8n)
const CRED_MAP = {
  httpHeaderAuth:       { id: 'diPB8BwY8mvOiQb3', name: 'Authorization-TrueSpend' },
  anthropicApi:         { id: 'xyPPCH287jdXoc7x', name: 'Anthropic-Truespend' },
  imap:                 { id: 'exBmmkmgHSx799Np', name: 'IMAP-Procurement' },
  smtp:                 { id: '4nJqszHi2HtSAqVx', name: 'SMTP-TrueSpend' },
  jiraSoftwareCloudApi: { id: 'MYydmb8FjLgo9CxM', name: 'Jira TrueSpend' },
};

// invoice_processor uses the invoices IMAP
const INVOICE_CRED_MAP = {
  ...CRED_MAP,
  imap: { id: 'IVh1LNAvDdK3xYMJ', name: 'IMAP-Invoices' },
};

const WORKFLOWS = [
  { file: 'stakeholder/intake_receiver.json',        credMap: CRED_MAP },
  { file: 'communication/supplier_reply_handler.json', credMap: CRED_MAP },
  { file: 'automatic/contract_watcher.json',         credMap: CRED_MAP },
  { file: 'automatic/reorder_trigger.json',          credMap: CRED_MAP },
  { file: 'automatic/hyperscaler_monitor.json',      credMap: CRED_MAP },
  { file: 'automatic/supplier_onboarding.json',      credMap: CRED_MAP },
  { file: 'automatic/invoice_processor.json',        credMap: INVOICE_CRED_MAP },
];

const WF_DIR = path.join(__dirname, '..', 'workflows');

function request(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const url   = new URL(N8N_URL + urlPath);
    const data  = body ? JSON.stringify(body) : null;
    const opts  = {
      hostname: url.hostname,
      port:     443,
      path:     url.pathname + url.search,
      method,
      headers: {
        'X-N8N-API-KEY':  API_KEY,
        'Content-Type':   'application/json',
        'Content-Length': data ? Buffer.byteLength(data) : 0,
      },
    };
    const req = https.request(opts, (res) => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(buf) }); }
        catch { resolve({ status: res.statusCode, body: buf }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// Fields n8n API rejects at node level (moved into parameters/onError in v2)
const DISALLOWED_NODE_PROPS = new Set([
  'retryOnFail', 'maxTries', 'waitBetweenTries',
  'alwaysOutputData', 'executeOnce', 'notesInFlow', 'notes',
  'continueOnFail', 'options',
]);

function cleanNodes(nodes) {
  return nodes.map(node => {
    const clean = {};
    for (const [k, v] of Object.entries(node)) {
      if (!DISALLOWED_NODE_PROPS.has(k)) clean[k] = v;
    }
    return clean;
  });
}

function wireCredentials(nodes, credMap) {
  for (const node of nodes) {
    if (!node.credentials) continue;
    for (const [type, val] of Object.entries(node.credentials)) {
      if (credMap[type]) {
        node.credentials[type] = {
          ...val,
          id:   credMap[type].id,
          name: credMap[type].name,
        };
      }
    }
  }
}

async function main() {
  // First delete any existing TrueSpend workflows to avoid duplicates
  console.log('Fetching existing workflows...');
  const existing = await request('GET', '/api/v1/workflows?limit=100');
  const tsWorkflows = existing.body.data?.filter(w =>
    ['intake_receiver','supplier_reply_handler','contract_watcher',
     'reorder_trigger','hyperscaler_monitor','supplier_onboarding','invoice_processor']
     .some(name => w.name?.toLowerCase().includes(name.replace('_',' ').split('_')[0]))
  ) || [];

  console.log(`Found ${tsWorkflows.length} existing TrueSpend workflows to skip/replace\n`);

  for (const { file, credMap } of WORKFLOWS) {
    const fullPath = path.join(WF_DIR, file);
    const wfName   = path.basename(file, '.json');

    if (!fs.existsSync(fullPath)) {
      console.log(`SKIP ${wfName} â€” file not found`);
      continue;
    }

    let wf;
    try {
      let raw = fs.readFileSync(fullPath, 'utf8');
      // Strip BOM if present
      if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
      wf = JSON.parse(raw);
    } catch (e) {
      console.log(`ERR  ${wfName} â€” parse error: ${e.message}`);
      continue;
    }

    // Build clean payload â€” only fields n8n API accepts
    const cleanedNodes = cleanNodes(wf.nodes || []);
    const payload = {
      name:        wf.name,
      nodes:       cleanedNodes,
      connections: wf.connections || {},
      settings:    wf.settings    || {},
    };
    if (wf.staticData) payload.staticData = wf.staticData;

    // Wire credentials
    wireCredentials(payload.nodes, credMap);

    wf = payload;

    const res = await request('POST', '/api/v1/workflows', wf);
    if (res.status === 200 || res.status === 201) {
      console.log(`OK   ${wfName} â†’ id ${res.body.id}`);
    } else {
      const err = typeof res.body === 'object'
        ? JSON.stringify(res.body).substring(0, 300)
        : String(res.body).substring(0, 300);
      console.log(`ERR  ${wfName} [${res.status}]: ${err}`);
    }
  }

  console.log('\nDone.');
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
