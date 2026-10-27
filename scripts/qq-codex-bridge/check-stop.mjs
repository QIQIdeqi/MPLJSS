// Read-only stop preflight. Never clear a lock or interrupt a turn.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import WebSocket from 'ws';
import { projectCanStop } from './sessions.mjs';

const runtime = path.join(path.dirname(fileURLToPath(import.meta.url)), '.runtime');
const state = JSON.parse(fs.readFileSync(path.join(runtime, 'ready.json')));
const lock = JSON.parse(fs.readFileSync(path.join(runtime, 'project-lock.json')));
const membersFile = path.join(runtime, 'member-threads.json');
const members = fs.existsSync(membersFile) ? JSON.parse(fs.readFileSync(membersFile)) : {};
const tokenFile = path.join(runtime, `control-${state.pid}.key`);
const token = fs.readFileSync(tokenFile, 'utf8').trim();
const socket = new WebSocket(`ws://127.0.0.1:${state.backendPort || 43175}`, {
  headers: { Authorization: `Bearer ${token}` }, handshakeTimeout: 5000,
});
let sequence = 0;
const pending = new Map();
const deadline = setTimeout(() => { console.error('Task status check timed out; bridge retained.'); process.exit(2); }, 15000);
socket.on('message', bytes => {
  const message = JSON.parse(bytes), item = pending.get(message.id);
  if (!item) return;
  pending.delete(message.id);
  message.error ? item.reject(new Error('Task status query failed')) : item.resolve(message.result);
});
const rpc = { request(method, params) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
} };
try {
  await new Promise((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  socket.on('error', () => {});
  await rpc.request('initialize', { clientInfo: { name: 'qq_stop_preflight', version: '0.1' }, capabilities: { experimentalApi: true } });
  socket.send(JSON.stringify({ method: 'initialized' }));
  const ids = [state.threadId, ...Object.values(members), ...(lock?.threadId ? [lock.threadId] : [])];
  if (!(await projectCanStop(rpc, lock, ids))) throw new Error('A task is active or the locked task is not confirmed finished.');
  console.log('PASS: recorded task finished and known project chats are idle; restart is safe.');
} catch {
  console.error('Cannot confirm project is idle. Bridge retained; wait for active tasks or inspect their status.');
  process.exitCode = 2;
} finally {
  clearTimeout(deadline);
  socket.terminate();
}
