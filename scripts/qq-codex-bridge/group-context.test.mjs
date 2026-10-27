import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync } from 'node:fs';
import { GroupContext } from './group-context.mjs';
import { groupMention, permitted } from './access.mjs';

mkdirSync(new URL('./.runtime/', import.meta.url), { recursive: true });
const directory = mkdtempSync(new URL('./.runtime/group-context-test-', import.meta.url));
const file = `${directory}/context.json`;
const context = new GroupContext(file);
const group = { groupOpenid: 'selected', senderId: 'owner', allowMembers: true };
const message = { kind: 'group', rawEventType: 'GROUP_MESSAGE_CREATE', groupOpenid: 'selected',
  senderId: 'alice', messageId: '1', senderName: 'Alice', content: 'We should test the boss.' };
const now = 200000000;
assert.equal(context.record(message, group, now), true);
assert.equal(permitted('owner', 'ticket', message, group), false); // Passive intake never authorizes a reply/task.
assert.equal(context.record(message, group, now), false);
assert.equal(context.record({ ...message, messageId: 'bot', senderIsBot: true }, group, now), false);
assert.equal(context.record({ ...message, groupOpenid: 'other' }, group, now), false);
assert.equal(context.record({ ...message, kind: 'c2c' }, group, now), false);
assert.equal(context.record({ ...message, messageId: 'secret', content: '/bind-group secret' }, group, now), false);
assert.equal(groupMention({ ...message, content: '@Someone else' }), false);
assert.equal(groupMention({ ...message, mentions: [{ is_you: true }] }), true);
assert.equal(groupMention({ ...message, content: '<@1906033435> summarize' }), true);
assert.equal(groupMention({ ...message, content: '<@99999> summarize' }), false);
assert.equal(permitted('owner', 'ticket', { ...message, mentions: [{ is_you: true }] }, group), true);
let prompt = new GroupContext(file).prompt(group, 'new', now);
assert.match(prompt, /We should test the boss/);
assert.match(prompt, /当前被@的请求/);
assert.equal(context.prompt(group, '1', now), ''); // Current request is not duplicated as background.
for (let i = 0; i < 205; i++) context.record({ ...message, messageId: `m${i}`, content: `discussion${i}` }, group, now + i);
assert.equal(context.data.entries.length, 200);
prompt = context.prompt(group, 'new', now + 300);
assert.equal((prompt.match(/"time":/g) ?? []).length, 30);
assert.equal(context.prompt(group, 'new', now + 86401000), '');
assert.equal(context.prompt({ ...group, groupOpenid: 'different' }, 'new', now), '');
assert.equal(context.data.entries.length, 0);
context.clear();
assert.equal(new GroupContext(file).data.group, null);
console.log('PASS: passive non-mention intake cannot reply, explicit bot mentions, selected-group isolation, no private/bot/control data, dedup, restart, retention, context bound, and group reset.');
