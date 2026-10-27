import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { memberKey, Sessions, ProjectLock, completedLockedTurn, projectCanStop } from './sessions.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const runtime = path.join(directory, '.runtime');
mkdirSync(runtime, { recursive: true });
const testRoot = mkdtempSync(path.join(runtime, 'routing-test-'));
const group = { groupOpenid: 'group-1', senderId: 'group-owner', allowMembers: true };
const owner = { kind: 'group', groupOpenid: 'group-1', senderId: 'group-owner' };
const alice = { ...owner, senderId: 'alice' };
const bob = { ...owner, senderId: 'bob' };
const aliceKey = memberKey(alice, group), bobKey = memberKey(bob, group);
assert.equal(memberKey(owner, group), 'owner');
assert.equal(memberKey({ kind: 'c2c' }, group), 'owner');
assert.notEqual(aliceKey, bobKey);
assert.notEqual(aliceKey, memberKey({ ...alice, groupOpenid: 'another-group' }, group));

const starts = [];
const rpc = { async request(method, params) {
  assert.notEqual(method, 'thread/fork');
  if (method === 'thread/start') {
    starts.push(params);
    return { thread: { id: `thread-${starts.length}` }, activePermissionProfile: { id: params.permissions } };
  }
  if (method === 'thread/read') return { thread: { status: { type: 'idle' } } };
  assert.equal(method, 'thread/resume');
  return { activePermissionProfile: { id: params.permissions } };
} };
const workspace = path.join(testRoot, 'project');
const sessions = new Sessions(rpc, testRoot, workspace, 'original-thread');
assert.equal(await sessions.resolve('owner'), 'original-thread');
const aliceThread = await sessions.resume(aliceKey);
const bobThread = await sessions.resume(bobKey);
assert.notEqual(aliceThread, bobThread);
assert.equal(await sessions.resolve(aliceKey), aliceThread);
assert.equal(starts.length, 2);
assert.equal(await sessions.resume(aliceKey), aliceThread);
assert.notEqual(starts[0].cwd, starts[1].cwd);
const restored = new Sessions(rpc, testRoot, workspace, 'original-thread');
assert.equal(restored.lookup(aliceKey), undefined); // Unstarted threads have no rollout to restore.
sessions.markStarted(aliceKey);
sessions.markStarted(bobKey);
const persisted = new Sessions(rpc, testRoot, workspace, 'original-thread');
assert.equal(persisted.lookup(aliceKey), aliceThread);
assert.equal(persisted.lookup(bobKey), bobThread);
assert.equal(restored.lookup('owner'), 'original-thread');
const resumed = [];
persisted.rpc = { async request(method, params) {
  if (method === 'thread/read') return { thread: { status: { type: 'notLoaded' } } };
  assert.equal(method, 'thread/resume');
  resumed.push(params.threadId);
  return { activePermissionProfile: { id: params.permissions } };
} };
assert.equal(await persisted.resume(aliceKey), aliceThread);
assert.deepEqual(resumed, [aliceThread]);
const profileId = sessions.options(aliceKey).permissions;
const policy = sessions.config(aliceKey)[`permissions.${profileId}`];
assert.equal(policy.network.enabled, false);
assert.equal(policy.filesystem[':root'], 'deny');
assert(!policy.filesystem[workspace]);
assert(!policy.filesystem[runtime]);
assert.equal(sessions.config(aliceKey)['plugins.codex-app-tools@openai-bundled.mcp_servers.codex_app.enabled'], false);

const file = path.join(testRoot, 'project-lock.json');
const lockedTurn = { threadId: aliceThread, turnId: 'locked' };
for (const status of ['completed', 'failed', 'interrupted', 'inProgress']) {
  const result = await completedLockedTurn({ async request(method, params) {
    assert.equal(method, 'thread/turns/list');
    assert.equal(params.threadId, aliceThread);
    return { data: [{ id: 'another', status: 'completed' }, { id: 'locked', status }] };
  } }, lockedTurn);
  assert.equal(!!result, status !== 'inProgress');
}
assert.equal(await completedLockedTurn({ async request() { return { data: [{ id: 'another', status: 'completed' }] }; } }, lockedTurn), null);
assert.equal(await completedLockedTurn({}, { threadId: aliceThread, turnId: null }), null);
const project = new ProjectLock(file);
for (const [turnStatus, threadStatus, expected] of [
  ['completed', 'idle', true], ['completed', 'active', false],
  ['inProgress', 'idle', false], ['completed', 'systemError', false],
]) {
  assert.equal(await projectCanStop({ async request(method) {
    return method === 'thread/turns/list'
      ? { data: [{ id: 'locked', status: turnStatus }] }
      : { thread: { status: { type: threadStatus } } };
  } }, lockedTurn, [aliceThread]), expected);
}
assert.equal(project.reserve(aliceKey), true);
assert.equal(project.reserve(bobKey), false);
project.beforeStart(aliceThread);
assert.equal(project.releaseReservation(), false); // A start with an uncertain result must stay locked.
project.started(aliceThread, 'alice-turn');
assert.equal(project.complete(bobThread, 'alice-turn'), false);
assert.equal(project.complete(aliceThread, 'old-turn'), false);
assert.equal(project.reserve(bobKey), false); // A reply deadline never releases file ownership.
const recovered = new ProjectLock(file);
assert.equal(recovered.current.turnId, 'alice-turn');
assert.equal(recovered.reserve(bobKey), false);
assert.equal(project.complete(aliceThread, 'alice-turn'), true);
assert.equal(project.reserve(bobKey), true);
assert.equal(project.releaseReservation(), true);
assert.equal(project.current, null);
console.log('PASS: distinct/persistent member threads, original owner thread, scoped member policy, project contention, exact-turn completion, uncertain start, and persisted lock.');
