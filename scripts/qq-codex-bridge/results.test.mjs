import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync } from 'node:fs';
import { Results, resultPage } from './results.mjs';

mkdirSync(new URL('./.runtime/', import.meta.url), { recursive: true });
const directory = mkdtempSync(new URL('./.runtime/results-test-', import.meta.url));
const file = `${directory}/results.json`;
let results = new Results(file);
results.started('alice', 'alice-thread', 'alice-task');
results.started('bob', 'bob-thread', 'bob-task');
results.completed('alice', 'alice-thread', { id: 'alice-task', status: 'completed' }, 'Alice final result');
results.completed('bob', 'alice-thread', { id: 'alice-task', status: 'completed' }, 'Wrong recipient');
results.started('alice', 'alice-thread', 'alice-task'); // A late start acknowledgement cannot erase completion.
results = new Results(file); // Result survives service restart and expired QQ targets.
assert.equal(resultPage(await results.query({}, 'alice', 'alice-thread')).includes('Alice final result'), true);
assert.equal(results.records.bob.status, 'inProgress');
const queried = [];
const rpc = { async request(method, params) {
  assert.equal(method, 'thread/turns/list'); // Queries never dispatch a model turn.
  queried.push(params.threadId);
  assert.equal(params.threadId, 'bob-thread');
  if (!params.cursor) return { data: [{ id: 'unrelated', status: 'completed' }], nextCursor: 'older' };
  return { data: [{ id: 'bob-task', status: 'completed', items: [
    { type: 'agentMessage', phase: 'commentary', text: 'Working' },
    { type: 'agentMessage', phase: 'final_answer', text: 'Bob final result' },
  ] }] };
} };
assert.equal((await results.query(rpc, 'bob', 'bob-thread')).text, 'Bob final result');
assert.deepEqual(queried, ['bob-thread', 'bob-thread']);
assert.equal(results.records.alice.text, 'Alice final result');
assert.equal(await results.query({}, 'unknown', undefined), null);
const legacy = await results.query({ async request(method, params) {
  assert.equal(params.threadId, 'legacy-thread');
  return { data: [{ id: 'legacy-task', status: 'completed', items: [{ type: 'agentMessage', text: 'Previous result' }] }] };
} }, 'legacy', 'legacy-thread');
assert.equal(legacy.text, 'Previous result');
assert.match(resultPage({ status: 'inProgress' }), /\/result/);
const long = { status: 'completed', text: '😀'.repeat(3001) };
assert.equal(Array.from(resultPage(long, 1)).filter(c => c === '😀').length, 3000);
assert.equal(Array.from(resultPage(long, 2)).filter(c => c === '😀').length, 1);
assert.match(resultPage(long, 3), /\/result 2/);
results.started('alice', 'alice-thread', 'new-task');
results.completed('alice', 'alice-thread', { id: 'alice-task', status: 'completed' }, 'Late old result');
assert.equal(results.records.alice.turnId, 'new-task');
assert.equal(results.records.alice.status, 'inProgress');
console.log('PASS: member isolation, restart persistence, exact-task history recovery, no model dispatch, old-chat fallback, late events, and Unicode pagination.');
