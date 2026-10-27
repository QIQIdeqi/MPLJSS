import { timingSafeEqual } from 'node:crypto';

export function same(a, b) {
  const x = Buffer.from(a ?? ''), y = Buffer.from(b ?? '');
  return x.length === y.length && timingSafeEqual(x, y);
}

export function messageText(message) {
  const text = message.content ?? '';
  return (message.kind === 'group' ? text.replace(/^(?:\s*<@!?[^>]+>\s*)+/, '') : text).trim();
}

export function groupMention(message) {
  return groupMessage(message) && (message.rawEventType === 'GROUP_AT_MESSAGE_CREATE'
    || (Array.isArray(message.mentions) && message.mentions.some(mention => mention?.is_you === true))
    || /<@!?1906033435>/.test(message.content ?? ''));
}

export function groupMessage(message) {
  return message.kind === 'group'
    && ['GROUP_MESSAGE_CREATE', 'GROUP_AT_MESSAGE_CREATE'].includes(message.rawEventType)
    && !!message.groupOpenid && !!message.senderId && message.senderIsBot !== true;
}

export function permitted(owner, pairingCode, message, group = null) {
  if (message.kind === 'c2c') {
    return owner ? message.senderId === owner : same(messageText(message), `/bind ${pairingCode}`);
  }
  return !!owner && !!group && groupMention(message)
    && message.groupOpenid === group.groupOpenid
    && (group.allowMembers === true || message.senderId === group.senderId);
}

export function bindGroup(ticket, message, now = Date.now()) {
  if (!ticket || now >= ticket.expiresAt || !groupMention(message)) return null;
  if (!same(messageText(message), `/bind-group ${ticket.code}`)) return null;
  return { groupOpenid: message.groupOpenid, senderId: message.senderId };
}
