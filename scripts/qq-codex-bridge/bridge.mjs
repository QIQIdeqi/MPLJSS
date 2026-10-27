import http from 'node:http';
import net from 'node:net';
import { spawn } from 'node:child_process';
import { once, EventEmitter } from 'node:events';
import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
import WebSocket, { WebSocketServer } from 'ws';
import { QQBot } from '@tencent-connect/qqbot-nodejs';
import { same, permitted, messageText, groupMention, groupMessage, bindGroup } from './access.mjs';
import { memberKey, Sessions, ProjectLock, completedLockedTurn } from './sessions.mjs';
import { Results, resultPage } from './results.mjs';
import { GroupContext } from './group-context.mjs';
import { imageRoots, replyImages, sendImages, testImage } from './images.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const runtime = path.join(directory, '.runtime');
const threadId = '01a17d13-31ba-7eb2-9587-05e4f55ec7df';
const workspace = path.resolve(directory, '../..');
// Owner chose mention-only mode. Keep passive discussion intake disabled.
const useGroupContext = false;
let desktopConnections = 0;
mkdirSync(runtime, { recursive: true });
const log = (event, details = {}) => {
  const line = JSON.stringify({ time: new Date().toISOString(), event, ...details });
  console.log(line);
  writeFileSync(path.join(runtime, 'events.jsonl'), line + '\n', { flag: 'a' });
};

class Rpc extends EventEmitter {
  sequence = 0;
  pending = new Map();
  constructor(socket) {
    super();
    this.socket = socket;
    socket.on('message', data => {
      const message = JSON.parse(data);
      if (message.id != null && !message.method) {
        const waiting = this.pending.get(message.id);
        if (!waiting) return;
        clearTimeout(waiting.timer);
        this.pending.delete(message.id);
        if (message.error) {
          const error = new Error(message.error.message);
          error.rpcRejected = true;
          waiting.reject(error);
        } else waiting.resolve(message.result);
      } else if (message.id != null) {
        // Approval or input requests remain a desktop interaction; never grant access from QQ.
        socket.send(JSON.stringify({ id: message.id, error: { code: -32601, message: 'Use desktop for approvals and interactive input.' } }));
        this.emit('approvalRequired');
      } else this.emit('notification', message);
    });
    socket.on('close', () => {
      for (const item of this.pending.values()) {
        clearTimeout(item.timer);
        item.reject(new Error('Codex connection closed'));
      }
      this.pending.clear();
      this.emit('disconnected');
    });
  }
  request(method, params = {}) {
    const id = ++this.sequence;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Codex request timed out: ${method}`));
      }, 30000);
      this.pending.set(id, { resolve, reject, timer });
      this.socket.send(JSON.stringify({ id, method, params }), error => {
        if (!error) return;
        clearTimeout(timer);
        this.pending.delete(id);
        reject(error);
      });
    });
  }
}

async function connect(url, token) {
  const socket = new WebSocket(url, { headers: { Authorization: `Bearer ${token}` }, handshakeTimeout: 10000 });
  await once(socket, 'open');
  const rpc = new Rpc(socket);
  await rpc.request('initialize', {
    clientInfo: { name: 'alchemy_qq_bridge', version: '0.1.0' },
    capabilities: { experimentalApi: true },
  });
  socket.send(JSON.stringify({ method: 'initialized' }));
  return rpc;
}

async function startSharedServer() {
  // Windows can retain an inherited listening socket after its original PID exits.
  // Pick a fresh loopback port rather than reusing a stale fixed endpoint.
  const reservation = net.createServer();
  reservation.listen(0, '127.0.0.1');
  await once(reservation, 'listening');
  const backendPort = reservation.address().port;
  await new Promise((resolve, reject) => reservation.close(error => error ? reject(error) : resolve()));
  const backendUrl = `ws://127.0.0.1:${backendPort}`;
  const token = randomBytes(32).toString('hex');
  const tokenPath = path.join(runtime, `control-${process.pid}.key`);
  writeFileSync(tokenPath, token, { mode: 0o600 });
  const child = spawn(process.env.CODEX_BRIDGE_CLI || 'codex', [
    '-c', 'features.code_mode_host=true',
    '-c', 'plugins.codex-app-tools@openai-bundled.mcp_servers.codex_app.enabled=true',
    'app-server', '--listen', backendUrl,
    '--ws-auth', 'capability-token', '--ws-token-file', tokenPath,
  ], { cwd: workspace, windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  let childError;
  child.on('error', error => { childError = error; });
  // Keep diagnostics private: app-server logs may contain conversation content.
  child.stderr.on('data', () => {});
  const cleanup = () => { child.kill(); };
  process.on('exit', cleanup);
  for (let attempt = 0; attempt < 100; attempt++) {
    if (childError) throw childError;
    if (child.exitCode != null) throw new Error(`Codex exited: ${child.exitCode}`);
    try {
      const result = await fetch(`http://127.0.0.1:${backendPort}/readyz`, { signal: AbortSignal.timeout(1000) });
      if (result.ok) return { child, token, backendPort, backendUrl };
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  child.kill();
  throw new Error('Codex did not become ready');
}

async function startDesktopProxy(token, backendUrl) {
  const server = http.createServer((request, response) => {
    response.writeHead(404).end();
  });
  const wss = new WebSocketServer({ noServer: true, maxPayload: 16 * 1024 * 1024 });
  server.on('upgrade', (request, socket, head) => {
    const expected = 'Basic ' + Buffer.from(`codex:${token}`).toString('base64');
    if (request.headers.origin || !same(request.headers.authorization, expected)) {
      socket.end('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
      return;
    }
    wss.handleUpgrade(request, socket, head, frontend => {
      desktopConnections++;
      log('desktop_transport_connected');
      const backend = new WebSocket(backendUrl, { headers: { Authorization: `Bearer ${token}` } });
      const queue = [];
      frontend.on('message', data => {
        if (backend.readyState === WebSocket.OPEN) backend.send(data.toString());
        else if (queue.length < 100) queue.push(data.toString());
        else frontend.close(1013, 'Backend is starting');
      });
      backend.on('open', () => { for (const message of queue) backend.send(message); });
      backend.on('message', data => { if (frontend.readyState === WebSocket.OPEN) frontend.send(data.toString()); });
      frontend.on('close', () => { desktopConnections--; backend.close(); });
      backend.on('close', () => { frontend.close(); });
      frontend.on('error', () => { backend.terminate(); });
      backend.on('error', () => { frontend.close(1011, 'Codex unavailable'); });
    });
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return server;
}

async function runBot(rpc) {
  const secret = process.env.QQ_BOT_SECRET;
  delete process.env.QQ_BOT_SECRET;
  if (!secret) throw new Error('QQ_BOT_SECRET is required; use Start-Bridge.ps1');
  const bot = new QQBot({ appId: '1906033435', appSecret: secret, intents: 1 << 25, reconnect: { maxAttempts: 10 } });
  const ownerFile = path.join(runtime, 'owner.json');
  let owner = existsSync(ownerFile) ? JSON.parse(readFileSync(ownerFile, 'utf8')).senderId : null;
  const groupFile = path.join(runtime, 'group.json');
  let group = existsSync(groupFile) ? JSON.parse(readFileSync(groupFile, 'utf8')) : null;
  // The owner authorized all members of the already selected group in this update.
  if (group && group.allowMembers !== true) {
    group = { ...group, allowMembers: true };
    writeFileSync(groupFile, JSON.stringify(group), { mode: 0o600 });
  }
  let groupTicket = null;
  const pairingCode = randomBytes(12).toString('hex');
  if (!owner) writeFileSync(path.join(runtime, 'pairing.txt'), `/bind ${pairingCode}`, { mode: 0o600 });
  const seen = new Set();
  const pending = new Map();
  const sessions = new Sessions(rpc, runtime, workspace, threadId);
  const results = new Results(path.join(runtime, 'results.json'));
  const context = new GroupContext(path.join(runtime, 'group-context.json'));
  let fullGroupMessageObserved = false;
  const project = new ProjectLock(path.join(runtime, 'project-lock.json'));
  if (project.current) {
    if (project.current.phase === 'reserved') project.clear();
    else {
      const result = await rpc.request('thread/read', { threadId: project.current.threadId });
      if (result.thread.status.type !== 'active') project.clear();
    }
  }
  log('member_routing_ready', { groupEnabled: !!group, projectLocked: !!project.current });
  const reply = async (target, text) => {
    const images = replyImages(text, imageRoots(workspace, target.memberKey || 'owner', target.threadId));
    text = images.text;
    if (target.memberLabel) text = `【${target.memberLabel}】\n${text}`;
    const points = Array.from(text);
    await bot.sendText(target, points.length <= 3800 ? text : points.slice(0, 3700).join('') + '\n完整回答可发送 /result 分页查询。');
    if (images.files.length) {
      await sendImages(bot, target, images.files, target.memberLabel ? `【${target.memberLabel}】` : undefined);
      log('qq_images_delivered', { count: images.files.length, threadId: target.threadId ?? null });
    }
  };
  rpc.on('notification', message => {
    const p = message.params;
    const item = pending.get(p?.threadId);
    if (!item) return;
    if (message.method === 'turn/started' && !item.turnId) {
      item.turnId = p.turn.id;
      results.started(item.key, p.threadId, item.turnId);
      project.started(p.threadId, item.turnId);
    }
    if (message.method === 'item/completed' && p.turnId === item.turnId && p.item?.type === 'agentMessage') {
      if (p.item.phase !== 'commentary') item.text = p.item.text;
    }
    if (message.method === 'turn/completed' && p.turn?.id === item.turnId) {
      results.completed(item.key, p.threadId, p.turn, item.text);
      pending.delete(p.threadId);
      project.complete(p.threadId, p.turn.id);
      clearTimeout(item.timer);
      log('project_released', { threadId: p.threadId, turnId: p.turn.id });
      if (item.expired) return;
      const text = item.text || `任务状态：${p.turn.status}。请在桌面查看详情。`;
      reply(item.target, text)
        .then(() => log('qq_reply_delivered', { turnId: p.turn.id }))
        .catch(() => log('qq_reply_failed', { turnId: p.turn.id }));
    }
  });
  rpc.on('approvalRequired', () => log('desktop_approval_required'));
  let reconciling = null;
  const reconcileProject = () => {
    if (reconciling) return reconciling;
    reconciling = (async () => {
      const lock = project.current;
      const turn = await completedLockedTurn(rpc, lock);
      if (!turn || project.current !== lock) return;
      const item = pending.get(lock.threadId);
      if (item?.turnId === turn.id) {
        const answer = turn.items?.filter(i => i.type === 'agentMessage' && i.phase !== 'commentary').at(-1);
        if (answer) item.text = answer.text;
        rpc.emit('notification', { method: 'turn/completed', params: { threadId: lock.threadId, turn } });
      } else project.complete(lock.threadId, turn.id);
      log('project_completion_reconciled', { threadId: lock.threadId, turnId: turn.id });
    })().catch(() => log('project_reconcile_failed'))
      .finally(() => { reconciling = null; });
    return reconciling;
  };
  const reconcileTimer = setInterval(reconcileProject, 15000);
  reconcileTimer.unref();
  rpc.once('disconnected', () => clearInterval(reconcileTimer));
  bot.on('message', async (_context, message) => {
    if (seen.has(message.messageId)) return;
    if (useGroupContext && !fullGroupMessageObserved && group && message.groupOpenid === group.groupOpenid
        && groupMessage(message) && !groupMention(message)) {
      fullGroupMessageObserved = true;
      log('group_background_observed');
    }
    if (useGroupContext) context.record(message, group);
    const text = messageText(message);
    if (owner && groupMention(message) && text.startsWith('/bind-group ')) {
      const selected = bindGroup(groupTicket, message);
      if (!selected) return;
      selected.allowMembers = true;
      groupTicket = null;
      writeFileSync(groupFile, JSON.stringify(selected), { mode: 0o600 });
      group = selected;
      context.clear();
      fullGroupMessageObserved = false;
      seen.add(message.messageId);
      await reply(message.replyTarget, '本群已绑定。群成员可 @ 使用，各人有独立对话；项目任务会依次执行，文件占用时提示稍等。你的原聊天保留。请 @ 我发送 /status 验证。');
      log('group_bound', { threadId });
      return;
    }
    if (!permitted(owner, pairingCode, message, group)) return;
    seen.add(message.messageId);
    if (seen.size > 2000) seen.delete(seen.values().next().value);
    if (!owner) {
      owner = message.senderId;
      writeFileSync(ownerFile, JSON.stringify({ senderId: owner }), { mode: 0o600 });
      await reply(message.replyTarget, '已绑定。QQ 消息将发送到原来的 Codex 聊天。先发送 /status 检查连接。');
      log('owner_bound');
      return;
    }
    if (message.kind === 'c2c' && text === '/group-bind') {
      const ticket = { code: randomBytes(12).toString('hex'), expiresAt: Date.now() + 600000 };
      await reply(message.replyTarget, `请在10分钟内到目标群，先用 QQ 的 @ 功能选中机器人，再发送下面的命令：\n/bind-group ${ticket.code}\n本群成员将可 @ 使用独立对话；你的身份继续对应原聊天，请由你本人发送绑定命令。`);
      groupTicket = ticket;
      log('group_binding_issued');
      return;
    }
    if (message.kind === 'c2c' && text === '/group-unbind') {
      writeFileSync(groupFile, 'null');
      group = null;
      context.clear();
      fullGroupMessageObserved = false;
      groupTicket = null;
      await reply(message.replyTarget, '已关闭群聊接入，原来的私聊连接保留。');
      log('group_unbound');
      return;
    }
    if (!text) return;
    const key = memberKey(message, group);
    const target = { ...message.replyTarget, memberKey: key, threadId: sessions.lookup(key),
      ...(message.kind === 'group' ? { memberLabel: key === 'owner' ? '原会话' : `成员会话 ${key.slice(0, 8)}` } : {}) };
    await reconcileProject();
    if (text === '/image-test') {
      try { await reply(target, `炼金小屋测试图\n![炼金小屋](<${path.join(workspace, testImage)}>)`); }
      catch (error) {
        const code = typeof error.bizCode === 'number' ? error.bizCode : typeof error.code === 'number' ? error.code : 'network_or_permission';
        await bot.sendText(target, `图片未确认发送成功（错误码：${code}），请让管理员核查；不要把文字提示当成发图成功。`);
        log('qq_image_failed', { code });
      }
      return;
    }
    if (/^\/result(?:\s|$)/.test(text) || ['查询结果', '查询最终结果'].includes(text)) {
      const match = /^(?:\/result(?:\s+(\d+))?|查询结果|查询最终结果)$/.exec(text);
      if (!match) { await reply(target, '请发送 /result，或 /result 2 查询指定页。'); return; }
      try {
        const record = await results.query(rpc, key, sessions.lookup(key));
        await reply(target, resultPage(record, match[1] ? Number(match[1]) : 1));
        log('result_reply_delivered', { threadId: sessions.lookup(key) ?? null });
      } catch { await reply(target, '暂时无法读取你的任务结果，请稍后重试 /result。'); }
      return;
    }
    if (text === '/status') {
      const id = sessions.lookup(key);
      const result = id ? await rpc.request('thread/read', { threadId: id }) : null;
      await reply(target, `你的聊天：${id || '尚未创建，首次提问时自动创建'}\n状态：${result?.thread.status.type || '未开始'}\n桌面连接数：${desktopConnections}\n项目：${project.current ? '文件正在使用，请稍等' : '空闲'}\n群接入：${group ? '指定群全员 @，各人独立对话' : '未绑定'}\n群讨论背景：${useGroupContext ? (fullGroupMessageObserved ? '已收到普通群消息' : '等待普通群消息，需腾讯侧权限') : '关闭；仅处理 @ 消息'}`);
      log('status_reply_delivered', { threadId: id ?? null, scope: message.kind });
      return;
    }
    if (!desktopConnections) {
      await reply(target, '桌面共享连接尚未就绪，请稍后再试。');
      return;
    }
    const busy = '项目文件正在被使用，请稍等。上一人的任务结束后再发送即可；这条请求尚未执行，也不会打断正在进行的任务。';
    if (!project.reserve(key)) {
      await reply(target, busy);
      log('project_busy', { scope: message.kind });
      return;
    }
    let id;
    try {
      // Also respect desktop tasks in the owner/member threads already known to this bridge.
      for (const knownId of sessions.threadIds()) {
        const { thread } = await rpc.request('thread/read', { threadId: knownId });
        if (thread.status.type === 'active') {
          project.releaseReservation();
          await reply(target, busy);
          log('project_busy', { scope: message.kind });
          return;
        }
        if (knownId === threadId && thread.status.type === 'notLoaded') {
          project.releaseReservation();
          await reply(target, '请先在共享桌面端打开原来的项目聊天。');
          return;
        }
      }
      id = await sessions.resume(key);
      target.threadId = id;
      const item = { key, target, text: '', turnId: null, expired: false };
      pending.set(id, item);
      project.beforeStart(id);
      const { turn } = await rpc.request('turn/start', { threadId: id,
        input: [{ type: 'text', text: (useGroupContext && message.kind === 'group' ? context.prompt(group, message.messageId) : '') + text
          + '\n\n[QQ传输提示：若本次有需要发回QQ的图片，请在最终回答写入 ![图片](<本地绝对路径>)。只引用本次真实生成或用户指定的图片，优先保存到共享项目内容目录或自己的工作目录。]', text_elements: [] }], ...sessions.options(key) });
      sessions.markStarted(key);
      results.started(key, id, turn.id);
      if (pending.get(id) !== item) return;
      item.turnId = turn.id;
      project.started(id, turn.id);
      item.timer = setTimeout(() => {
        // A QQ reply deadline is not proof that file writes finished. Keep the project locked.
        item.expired = true;
        log('qq_reply_window_elapsed', { turnId: turn.id });
        reply(target, '任务仍在运行，项目文件继续保持占用。可用 /status 查看状态，完成后发送 /result 查询最终结果；不要重复提交修改。').catch(() => log('qq_reply_failed'));
      }, 240000);
      log('qq_message_forwarded', { threadId: id, turnId: turn.id, scope: message.kind });
    } catch (error) {
      if (project.current?.phase === 'reserved') project.releaseReservation();
      else if (error.rpcRejected && project.current?.phase === 'starting') {
        pending.delete(id);
        project.clear();
      }
      await reply(target, project.current
        ? '任务启动结果尚未确认，项目文件仍保持占用。请让管理员核查状态后再试，勿重复提交。'
        : '请求未能启动，请稍后重试。');
      log('qq_forward_failed', { projectStillLocked: !!project.current });
    }
  });
  bot.on('ready', () => {
    writeFileSync(path.join(runtime, 'qq-ready.json'), JSON.stringify({ pid: process.pid }));
    log('qq_gateway_ready');
  });
  bot.on('error', error => log('qq_error', { code: error.code ?? error.bizCode ?? 'network' }));
  rpc.on('disconnected', () => { bot.stop(); log('codex_disconnected'); });
  await bot.start();
}

async function main() {
  const shared = await startSharedServer();
  const proxy = await startDesktopProxy(shared.token, shared.backendUrl);
  const desktopPort = proxy.address().port;
  const rpc = await connect(shared.backendUrl, shared.token);
  const result = await rpc.request('thread/read', { threadId });
  assert.equal(result.thread.id, threadId);
  log('current_thread_read_verified', { threadId, status: result.thread.status.type });
  if (process.argv.includes('--test')) {
    assert.equal(permitted(null, 'abc', { kind: 'group', content: '/bind abc' }), false);
    assert.equal(permitted(null, 'abc', { kind: 'c2c', content: '/bind bad' }), false);
    assert.equal(permitted(null, 'abc', { kind: 'c2c', content: '/bind abc' }), true);
    assert.equal(permitted('owner', '', { kind: 'c2c', senderId: 'other' }), false);
    assert.equal(permitted('owner', '', { kind: 'c2c', senderId: 'owner' }), true);
    assert.ok(shared.backendPort > 0 && desktopPort > 0);
    assert.notEqual(shared.backendPort, desktopPort);
    await assert.rejects(connect(shared.backendUrl, 'wrong'));
    const refused = new WebSocket(`ws://127.0.0.1:${desktopPort}`);
    await assert.rejects(once(refused, 'open'));
    const desktop = new WebSocket(`ws://codex:${shared.token}@127.0.0.1:${desktopPort}`);
    await once(desktop, 'open');
    const desktopRpc = new Rpc(desktop);
    await desktopRpc.request('initialize', { clientInfo: { name: 'alchemy_desktop_probe', version: '0.1.0' } });
    const read = await desktopRpc.request('thread/read', { threadId });
    assert.equal(read.thread.id, threadId);
    log('tests_passed', { checks: ['dynamic_loopback_ports', 'pairing_policy', 'backend_auth', 'frontend_auth', 'desktop_transport', 'same_thread_metadata'], threadId });
    desktop.close(); rpc.socket.close(); proxy.close(); shared.child.kill();
    return;
  }
  writeFileSync(path.join(runtime, 'desktop-url.key'), `ws://codex:${shared.token}@127.0.0.1:${desktopPort}`, { mode: 0o600 });
  writeFileSync(path.join(runtime, 'ready.json'), JSON.stringify({ pid: process.pid, backendPid: shared.child.pid, backendPort: shared.backendPort, desktopPort, threadId, routingVersion: 'members-project-lock-v1', imageReplyVersion: 'local-images-v1' }));
  try { await runBot(rpc); }
  finally { rpc.socket.close(); proxy.close(); shared.child.kill(); }
}

main().catch(error => {
  log('bridge_stopped', { error: error.name, code: error.code ?? error.bizCode ?? 'startup_failed' });
  process.exit(1);
});
