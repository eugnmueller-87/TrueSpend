#!/usr/bin/env node
/**
 * Deploys intake as nginx:1.27-alpine image.
 * Startup: wget pre-built files from GitHub raw, then nginx -g 'daemon off;'
 */
const https = require('https');
const fs = require('fs');

const env = fs.readFileSync('.env', 'utf8');
const TOKEN = env.match(/RAILWAY_TOKEN=(.+)/)[1].trim();
const SERVICE_ID = '65cdbfea-b0d1-4b90-9e9d-aacff0b1ca86';
const ENV_ID = '5d530fe4-480e-4096-9a36-fc700ecd6f03';

const RAW = 'https://raw.githubusercontent.com/eugnmueller-87/TrueSpend/main/intake/dist';
const START_CMD = [
  'mkdir -p /usr/share/nginx/html/assets',
  'wget -qO /usr/share/nginx/html/index.html ' + RAW + '/index.html',
  'wget -qO /usr/share/nginx/html/assets/index-BpVPuwL6.css ' + RAW + '/assets/index-BpVPuwL6.css',
  'wget -qO /usr/share/nginx/html/assets/index-DLhzsQob.js ' + RAW + '/assets/index-DLhzsQob.js',
  "echo 'Files ready'",
  "nginx -g 'daemon off;'"
].join(' && ');

function gql(query, variables) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ query, variables });
    const req = https.request({
      hostname: 'backboard.railway.app',
      path: '/graphql/v2',
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + TOKEN,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      }
    }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => resolve(JSON.parse(buf)));
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  console.log('Updating service to nginx:1.27-alpine with wget startup...');

  const update = await gql(
    `mutation SvcUpdate($sid: String!, $eid: String!, $input: ServiceInstanceUpdateInput!) {
      serviceInstanceUpdate(serviceId: $sid, environmentId: $eid, input: $input)
    }`,
    {
      sid: SERVICE_ID,
      eid: ENV_ID,
      input: {
        source: { image: 'nginx:1.27-alpine' },
        startCommand: START_CMD,
        healthcheckPath: '/',
        healthcheckTimeout: 60,
      }
    }
  );

  if (update.errors) {
    console.error('Update failed:', JSON.stringify(update.errors));
    return;
  }
  console.log('✓ Service updated');

  const deploy = await gql(
    `mutation Deploy($sid: String!, $eid: String!) {
      serviceInstanceDeployV2(serviceId: $sid, environmentId: $eid)
    }`,
    { sid: SERVICE_ID, eid: ENV_ID }
  );

  const depId = deploy.data?.serviceInstanceDeployV2;
  if (!depId) { console.error('Deploy failed:', deploy); return; }
  console.log('Deployment ID:', depId);

  for (let i = 0; i < 25; i++) {
    await new Promise(r => setTimeout(r, 8000));
    const r = await gql(`{ deployment(id: "${depId}") { id status } }`);
    const dep = r.data?.deployment;
    console.log(new Date().toISOString().slice(11, 19), dep?.status);

    if (dep?.status === 'SUCCESS') {
      console.log('✅ https://intake-production-84a0.up.railway.app is LIVE!');
      process.exit(0);
    }
    if (dep?.status === 'FAILED' || dep?.status === 'CRASHED' || dep?.status === 'REMOVED') {
      const logs = await gql(`{ deploymentLogs(deploymentId: "${depId}") { message timestamp } }`);
      const msgs = logs.data?.deploymentLogs || [];
      console.log('Runtime logs (' + msgs.length + '):');
      msgs.forEach(l => console.log(l.timestamp?.slice(11, 19), l.message));
      break;
    }
  }
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
