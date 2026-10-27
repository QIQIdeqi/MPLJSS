import { existsSync, readFileSync, writeFileSync, renameSync } from 'node:fs';

export class Results {
  constructor(file) {
    this.file = file;
    this.records = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {};
  }
  save() {
    writeFileSync(this.file + '.tmp', JSON.stringify(this.records), { mode: 0o600 });
    renameSync(this.file + '.tmp', this.file);
  }
  started(key, threadId, turnId) {
    if (this.records[key]?.turnId === turnId) return;
    this.records[key] = { threadId, turnId, status: 'inProgress', text: '' };
    this.save();
  }
  completed(key, threadId, turn, text) {
    const record = this.records[key];
    if (record?.threadId !== threadId || record?.turnId !== turn.id) return;
    this.records[key] = { threadId, turnId: turn.id, status: turn.status,
      text: text || `任务状态：${turn.status}。本次没有可显示的最终回答。` };
    this.save();
  }
  async query(rpc, key, threadId) {
    const record = this.records[key];
    if (!threadId) return null;
    if (record?.threadId === threadId && record.status !== 'inProgress') return record;
    // Recover the exact task from server history after restart or a missed event.
    // For pre-upgrade chats only, use that member's latest turn as a fallback.
    let cursor;
    do {
      const page = await rpc.request('thread/turns/list', {
        threadId, limit: record?.threadId === threadId ? 50 : 1,
        itemsView: 'full', ...(cursor ? { cursor } : {}),
      });
      const turn = record?.threadId === threadId
        ? page.data.find(turn => turn.id === record.turnId) : page.data[0];
      if (turn) {
        this.started(key, threadId, turn.id);
        if (['completed', 'failed', 'interrupted'].includes(turn.status)) {
          const answer = turn.items?.filter(i => i.type === 'agentMessage' && i.phase !== 'commentary').at(-1);
          this.completed(key, threadId, turn, answer?.text);
        }
        return this.records[key];
      }
      if (!record || !page.nextCursor || page.nextCursor === cursor) break;
      cursor = page.nextCursor;
    } while (cursor);
    return record?.threadId === threadId ? record : null;
  }
}

export function resultPage(record, page = 1) {
  if (!record) return '你还没有可查询的任务结果。';
  if (record.status === 'inProgress') return '你的任务仍在运行。完成后发送 /result 查询；无需重复提交任务。';
  const points = Array.from(record.text);
  const pages = Math.max(1, Math.ceil(points.length / 3000));
  if (!Number.isSafeInteger(page) || page < 1 || page > pages) return `页码无效，请发送 /result 1 至 /result ${pages}。`;
  return `任务状态：${record.status}｜第${page}/${pages}页\n` + points.slice((page - 1) * 3000, page * 3000).join('')
    + (page < pages ? `\n下一页：/result ${page + 1}` : '');
}
