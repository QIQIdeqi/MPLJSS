// Native permission enforcement check; no model invocation or real member conversation.
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { Sessions } from './sessions.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const runtime = path.join(directory, '.runtime'), workspace = path.resolve(directory, '../..');
const sessions = new Sessions({}, runtime, workspace, 'test-owner');
const options = sessions.options('sandbox-probe');
fs.mkdirSync(options.cwd, { recursive: true });
const profile = sessions.config('sandbox-probe')[`permissions.${options.permissions}`];
const toml = value => typeof value === 'object' && value !== null
  ? `{ ${Object.entries(value).map(([key, item]) => `${JSON.stringify(key)} = ${toml(item)}`).join(', ')} }`
  : JSON.stringify(value);
const cli = process.env.CODEX_BRIDGE_CLI;
assert(cli, 'Set CODEX_BRIDGE_CLI to the installed executable');
const child = spawn(cli, ['-c', `permissions.${options.permissions}=${toml(profile)}`, '-c', `default_permissions=${JSON.stringify(options.permissions)}`, '-c', 'windows.sandbox="elevated"', '-c', 'features.prefer_mxc=true', '-c', 'project_doc_max_bytes=0', '-c', 'features.skip_host_skill_discovery=true', 'app-server', '--stdio'],
  { cwd: workspace, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
let diagnostics = '';
child.stderr.on('data', bytes => { diagnostics = (diagnostics + bytes.toString()).slice(-3000); });
let seq = 0;
const waiting = new Map();
child.on('exit', code => {
  for (const item of waiting.values()) {
    clearTimeout(item.timer);
    item.reject(new Error(`Probe server exited ${code}: ${diagnostics.slice(-1800)}`));
  }
  waiting.clear();
});
createInterface({ input: child.stdout }).on('line', line => {
  const message = JSON.parse(line), item = waiting.get(message.id);
  if (!item) return;
  waiting.delete(message.id); clearTimeout(item.timer);
  message.error ? item.reject(new Error(message.error.message)) : item.resolve(message.result);
});
function call(method, params) {
  return new Promise((resolve, reject) => {
    const id = ++seq;
    const timer = setTimeout(() => { waiting.delete(id); reject(new Error(`Timed out: ${method}`)); }, 30000);
    waiting.set(id, { resolve, reject, timer });
    child.stdin.write(JSON.stringify({ id, method, params }) + '\n');
  });
}
try {
  await call('initialize', { clientInfo: { name: 'qq_member_sandbox_probe', version: '0.1.0' }, capabilities: { experimentalApi: true } });
  child.stdin.write(JSON.stringify({ method: 'initialized' }) + '\n');
  const base = { cwd: options.cwd, permissionProfile: options.permissions, timeoutMs: 10000 };
  const canary = path.join(runtime, 'member-access-canary.txt');
  fs.writeFileSync(canary, 'non-secret sandbox fixture');
  const allowed = await call('command/exec', { ...base,
    command: [process.execPath, '-e', "require('node:fs').writeFileSync('probe-write.txt','ok')"] });
  const script = `try{require('node:fs').readFileSync(${JSON.stringify(canary)});process.exit(2)}catch(e){if(['EACCES','EPERM','ENOENT'].includes(e.code))process.exit(0);throw e}`;
  const denied = await call('command/exec', { ...base, command: [process.execPath, '-e', script] });
  const writeDeniedScript = `try{require('node:fs').writeFileSync(${JSON.stringify(canary + '-write')},'x');process.exit(2)}catch(e){if(['EACCES','EPERM','ENOENT'].includes(e.code))process.exit(0);throw e}`;
  const writeDenied = await call('command/exec', { ...base, command: [process.execPath, '-e', writeDeniedScript] });
  const result = { allowedWriteExitCode: allowed.exitCode, protectedReadDenied: denied.exitCode === 0, protectedWriteDenied: writeDenied.exitCode === 0 };
  assert.equal(allowed.exitCode, 0, allowed.stderr);
  assert.equal(denied.exitCode, 0, denied.stderr);
  assert.equal(writeDenied.exitCode, 0, writeDenied.stderr);
  const created = await call('thread/start', { ephemeral: true, cwd: options.cwd, permissions: options.permissions, approvalPolicy: 'never' });
  assert.equal(created.activePermissionProfile?.id, options.permissions);
  result.threadProfileSelected = true;
  fs.writeFileSync(path.join(runtime, 'member-sandbox-test.json'), JSON.stringify(result));
  console.log(JSON.stringify(result));
  console.log('PASS: native permitted write, protected read/write denial, and thread permission selection.');
} finally {
  for (const item of waiting.values()) clearTimeout(item.timer);
  child.kill();
  child.stdout.destroy();
  child.stderr.destroy();
  child.stdin.destroy();
  child.unref();
}
