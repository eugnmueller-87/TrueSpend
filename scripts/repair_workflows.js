#!/usr/bin/env node
/**
 * Repairs workflow JSON files for n8n v2 API compatibility:
 * 1. Fix connection format: main:[{node,type,index}] → main:[[{node,type,index}]]
 * 2. Remove connections that reference non-existent nodes (deleted Slack nodes)
 * 3. Strip BOM, fix missing opening brace
 * 4. Write fixed files back
 */

const fs   = require('fs');
const path = require('path');

const WF_DIR = path.join(__dirname, '..', 'workflows');
const FILES  = [
  'communication/supplier_reply_handler.json',
  'automatic/contract_watcher.json',
  'automatic/reorder_trigger.json',
  'automatic/hyperscaler_monitor.json',
];

function fixConnections(connections, nodeNames) {
  const fixed = {};
  for (const [fromNode, outputs] of Object.entries(connections)) {
    if (!nodeNames.has(fromNode)) {
      console.log(`  DROP connection from missing node: "${fromNode}"`);
      continue;
    }
    fixed[fromNode] = {};
    for (const [outputType, ports] of Object.entries(outputs)) {
      // ports should be array of arrays; if it's array of objects, wrap each in array
      if (!Array.isArray(ports)) { fixed[fromNode][outputType] = ports; continue; }

      fixed[fromNode][outputType] = ports.map((port, i) => {
        // If port is already an array → correct format
        if (Array.isArray(port)) {
          // Filter out connections to non-existent nodes
          return port.filter(conn => {
            if (!nodeNames.has(conn.node)) {
              console.log(`  DROP dangling connection → "${conn.node}"`);
              return false;
            }
            return true;
          });
        }
        // If port is an object (old format: single connection) → wrap in array
        if (port && typeof port === 'object' && port.node) {
          if (!nodeNames.has(port.node)) {
            console.log(`  DROP dangling connection → "${port.node}"`);
            return [];
          }
          return [port];
        }
        return port;
      });
    }
  }
  return fixed;
}

for (const file of FILES) {
  const fullPath = path.join(WF_DIR, file);
  const name     = path.basename(file, '.json');
  console.log(`\nRepairing: ${name}`);

  let raw = fs.readFileSync(fullPath);
  // Strip BOM
  if (raw[0] === 0xEF && raw[1] === 0xBB && raw[2] === 0xBF) {
    raw = raw.slice(3);
    console.log('  Stripped BOM');
  }
  let text = raw.toString('utf8');

  // Add missing opening brace
  if (!text.trimStart().startsWith('{')) {
    text = '{\n' + text;
    console.log('  Added opening brace');
  }

  let wf;
  try {
    wf = JSON.parse(text);
  } catch (e) {
    console.log(`  PARSE ERROR: ${e.message}`);
    continue;
  }

  // Build set of all node names that actually exist
  const nodeNames = new Set((wf.nodes || []).map(n => n.name));
  console.log(`  Nodes: ${nodeNames.size}`);

  // Fix connections
  if (wf.connections) {
    wf.connections = fixConnections(wf.connections, nodeNames);
  }

  // Write back (no BOM, UTF-8)
  fs.writeFileSync(fullPath, JSON.stringify(wf, null, 2), 'utf8');
  console.log(`  Saved`);
}

console.log('\nDone.');
