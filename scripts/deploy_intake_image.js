#!/usr/bin/env node
/**
 * Deploys intake as a Railway image-based service.
 * Uses node:20-alpine + inline Node.js HTTP server that fetches static files from GitHub raw CDN.
 * Bypasses Railway's broken Metal builder entirely.
 */

const https = require('https');
const fs = require('fs');

const env = fs.readFileSync('.env', 'utf8');
const TOKEN = env.match(/RAILWAY_TOKEN=(.+)/)[1].trim();
const SERVICE_ID = '65cdbfea-b0d1-4b90-9e9d-aacff0b1ca86';
const ENV_ID = '5d530fe4-480e-4096-9a36-fc700ecd6f03';

// The tiny Node.js HTTP server that serves our pre-built files from GitHub raw
// Files are cached in-memory after first fetch
const SERVER_CODE = `
const http=require('http');
const https=require('https');
const FILES={
  '/':['https://raw.githubusercontent.com/eugnmueller-87/TrueSpend/main/intake/dist/index.html','text/html'],
  '/index.html':['https://raw.githubusercontent.com/eugnmueller-87/TrueSpend/main/intake/dist/index.html','text/html'],
  '/assets/index-Dvr4nzXS.css':['https://raw.githubusercontent.com/eugnmueller-87/TrueSpend/main/intake/dist/assets/index-Dvr4nzXS.css','text/css'],
  '/assets/index-B6bQ1y2i.js':['https://raw.githubusercontent.com/eugnmueller-87/TrueSpend/main/intake/dist/assets/index-B6bQ1y2i.js','application/javascript'],
};
const cache={};
function get(url){return new Promise((ok,fail)=>{https.get(url,r=>{if(r.statusCode>=300&&r.statusCode<400)return get(r.headers.location).then(ok).catch(fail);const b=[];r.on('data',c=>b.push(c));r.on('end',()=>ok(Buffer.concat(b)));}).on('error',fail);});}
const PORT=process.env.PORT||3000;
http.createServer(async(req,res)=>{
  const e=FILES[req.url]||FILES['/'];
  try{
    if(!cache[e[0]])cache[e[0]]=await get(e[0]);
    res.writeHead(200,{'Content-Type':e[1],'Cache-Control':'public,max-age=3600'});
    res.end(cache[e[0]]);
  }catch(err){res.writeHead(500);res.end(''+err);}
}).listen(PORT,()=>console.log('TrueSpend Ops Board on port '+PORT));
`;

// Encode as base64 to avoid quoting issues
const b64 = Buffer.from(SERVER_CODE).toString('base64');
const startCmd = `node -e "require('child_process').execSync('echo ' + '${b64}' + ' | base64 -d > /app.js'); require('/app.js');"`;

// Simpler: just write the b64 to a file then run it
const cmd = `echo "${b64}" | base64 -d > /srv.js && node /srv.js`;

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
  console.log('Start command length:', cmd.length);
  console.log('Start command preview:', cmd.slice(0, 120) + '...');

  const update = await gql(`mutation serviceInstanceUpdate($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) {
    serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input)
  }`, {
    serviceId: SERVICE_ID,
    environmentId: ENV_ID,
    input: {
      source: { image: 'node:20-alpine' },
      startCommand: cmd,
      healthcheckPath: '/',
      healthcheckTimeout: 60,
    }
  });

  console.log('Update result:', JSON.stringify(update));
  if (update.errors) { console.error('Update failed'); return; }

  const deploy = await gql(`mutation { serviceInstanceDeployV2(serviceId: "${SERVICE_ID}", environmentId: "${ENV_ID}") }`);
  const depId = deploy.data?.serviceInstanceDeployV2;
  console.log('Deployment ID:', depId);

  if (!depId) { console.error('Deploy failed:', deploy); return; }

  // Poll
  for (let i = 0; i < 25; i++) {
    await new Promise(r => setTimeout(r, 8000));
    const r = await gql(`{ deployment(id: "${depId}") { id status } }`);
    const dep = r.data?.deployment;
    const t = new Date().toISOString().slice(11, 19);
    console.log(t, dep?.status);

    if (dep?.status === 'SUCCESS') {
      console.log('✅ DEPLOYED! https://intake-production-84a0.up.railway.app');
      process.exit(0);
    }
    if (dep?.status === 'FAILED' || dep?.status === 'CRASHED' || dep?.status === 'REMOVED') {
      const logs = await gql(`{ deploymentLogs(deploymentId: "${depId}") { message timestamp } }`);
      const msgs = logs.data?.deploymentLogs || [];
      console.log('Runtime logs (' + msgs.length + '):');
      msgs.forEach(l => console.log(l.timestamp?.slice(11, 19) || '', l.message));
      break;
    }
  }
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
