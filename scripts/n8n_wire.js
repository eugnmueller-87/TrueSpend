#!/usr/bin/env node
/**
 * TrueSpend n8n Wiring Script
 *
 * Creates 5 credentials + imports 7 workflows via n8n REST API.
 *
 * Usage:
 *   node scripts/n8n_wire.js --api-key <YOUR_N8N_API_KEY>
 *
 * Get API key: n8n UI → top-right avatar → API → Create API key
 */

const fs   = require('fs');
const path = require('path');
const https = require('https');

// ─── Config ──────────────────────────────────────────────────────────────────

const N8N_URL = process.env.N8N_URL || 'https://n8n-n3xl.eugenmueller.tech';

// All secrets must be set as environment variables (see .env.example)
const ENV = {
  POSTGREST_JWT:    process.env.POSTGREST_JWT,
  ANTHROPIC_KEY:    process.env.ANTHROPIC_API_KEY,
  IMAP_HOST:        process.env.IMAP_HOST        || 'imap.gmx.net',
  IMAP_PORT:        parseInt(process.env.IMAP_PORT || '993'),
  IMAP_USER:        process.env.IMAP_USER,
  IMAP_PASSWORD:    process.env.IMAP_PASSWORD,
  SMTP_HOST:        process.env.SMTP_HOST        || 'mail.gmx.net',
  SMTP_PORT:        parseInt(process.env.SMTP_PORT || '587'),
  SMTP_USER:        process.env.SMTP_USER,
  SMTP_PASSWORD:    process.env.SMTP_PASSWORD,
  JIRA_URL:         process.env.JIRA_BASE_URL,
  JIRA_EMAIL:       process.env.JIRA_EMAIL,
  JIRA_TOKEN:       process.env.JIRA_API_TOKEN,
};

// ─── Credentials to create ────────────────────────────────────────────────────

const CREDENTIALS = [
  {
    name: 'Authorization-TrueSpend',
    type: 'httpHeaderAuth',
    data: {
      name:  'Authorization',
      value: `Bearer ${ENV.POSTGREST_JWT}`,
    },
  },
  {
    name: 'Anthropic-TrueSpend',
    type: 'anthropicApi',
    data: {
      apiKey: ENV.ANTHROPIC_KEY,
    },
  },
  {
    name: 'IMAP-Procurement',
    type: 'imap',
    data: {
      host:          ENV.IMAP_HOST,
      port:          ENV.IMAP_PORT,
      user:          ENV.IMAP_USER,
      password:      ENV.IMAP_PASSWORD,
      secure:        true,
      allowUnauthorizedCerts: false,
    },
  },
  {
    name: 'IMAP-Invoices',
    type: 'imap',
    data: {
      host:          ENV.IMAP_HOST,
      port:          ENV.IMAP_PORT,
      user:          ENV.IMAP_USER,
      password:      ENV.IMAP_PASSWORD,
      secure:        true,
      allowUnauthorizedCerts: false,
    },
  },
  {
    name: 'SMTP-TrueSpend',
    type: 'smtp',
    data: {
      host:          ENV.SMTP_HOST,
      port:          ENV.SMTP_PORT,
      user:          ENV.SMTP_USER,
      password:      ENV.SMTP_PASSWORD,
      secure:        false, // STARTTLS on port 587
      tls:           true,
      allowUnauthorizedCerts: false,
    },
  },
];

// ─── Workflow files ───────────────────────────────────────────────────────────

const WORKFLOW_DIR = path.join(__dirname, '..', 'workflows');
const WORKFLOWS = [
  'stakeholder/intake_receiver.json',
  'communication/supplier_reply_handler.json',
  'automatic/contract_watcher.json',
  'automatic/reorder_trigger.json',
  'automatic/hyperscaler_monitor.json',
  'automatic/supplier_onboarding.json',
  'automatic/invoice_processor.json',
];

// ─── API helpers ──────────────────────────────────────────────────────────────

function apiRequest(method, path, body, apiKey) {
  return new Promise((resolve, reject) => {
    const url = new URL(N8N_URL + '/api/v1' + path);
    const data = body ? JSON.stringify(body) : null;
    const options = {
      hostname: url.hostname,
      port:     url.port || 443,
      path:     url.pathname + url.search,
      method,
      headers: {
        'X-N8N-API-KEY':  apiKey,
        'Content-Type':   'application/json',
        'Content-Length': data ? Buffer.byteLength(data) : 0,
      },
    };
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: body ? JSON.parse(body) : null });
        } catch {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const args  = process.argv.slice(2);
  const keyIdx = args.indexOf('--api-key');
  const apiKey = keyIdx !== -1 ? args[keyIdx + 1] : process.env.N8N_API_KEY;

  if (!apiKey) {
    console.error('\n❌  No API key. Usage: node n8n_wire.js --api-key <key>');
    console.error('   Get it: n8n UI → avatar (top-right) → API → Create API key\n');
    process.exit(1);
  }

  console.log(`\n🔗  Connecting to ${N8N_URL}`);

  // ── 1. Create credentials ─────────────────────────────────────────────────
  console.log('\n📋  Creating credentials...');
  const credMap = {}; // name → id

  for (const cred of CREDENTIALS) {
    const res = await apiRequest('POST', '/credentials', cred, apiKey);
    if (res.status === 200 || res.status === 201) {
      credMap[cred.name] = res.data.id;
      console.log(`   ✅  ${cred.name} → id ${res.data.id}`);
    } else if (res.status === 409) {
      // Already exists — fetch and get id
      const list = await apiRequest('GET', `/credentials?name=${encodeURIComponent(cred.name)}`, null, apiKey);
      if (list.data?.data?.[0]) {
        credMap[cred.name] = list.data.data[0].id;
        console.log(`   ⏭️   ${cred.name} already exists → id ${list.data.data[0].id}`);
      }
    } else {
      console.error(`   ❌  ${cred.name} failed: ${res.status} ${JSON.stringify(res.data)}`);
    }
  }

  // ── 2. Import workflows ───────────────────────────────────────────────────
  console.log('\n📦  Importing workflows...');

  for (const wfPath of WORKFLOWS) {
    const fullPath = path.join(WORKFLOW_DIR, wfPath);
    if (!fs.existsSync(fullPath)) {
      console.error(`   ❌  Not found: ${fullPath}`);
      continue;
    }

    let wf;
    try {
      wf = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    } catch (e) {
      console.error(`   ❌  Parse error ${wfPath}: ${e.message}`);
      continue;
    }

    // Remove id so n8n creates a new one
    delete wf.id;
    wf.active = false; // import inactive, activate manually

    const res = await apiRequest('POST', '/workflows', wf, apiKey);
    if (res.status === 200 || res.status === 201) {
      console.log(`   ✅  ${path.basename(wfPath)} → id ${res.data.id}`);
    } else {
      console.error(`   ❌  ${path.basename(wfPath)}: ${res.status} ${JSON.stringify(res.data).substring(0, 200)}`);
    }
  }

  // ── 3. Summary ────────────────────────────────────────────────────────────
  console.log('\n✅  Wiring complete.\n');
  console.log('Next steps:');
  console.log('  1. Open n8n UI → Credentials — verify all 5 credentials show "Connection tested"');
  console.log('  2. Open each workflow → manually assign credentials to nodes');
  console.log('     (API import preserves node names but credential assignment needs UI match)');
  console.log('  3. Activate workflows in this order:');
  console.log('     contract_watcher → reorder_trigger → hyperscaler_monitor → supplier_reply_handler');
  console.log('     → supplier_onboarding → invoice_processor → intake_receiver (last)');
  console.log('');
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
