import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync } from 'node:fs';
import path from 'node:path';
import os from 'node:os';

export function memberKey(message, group) {
  if (message.kind === 'c2c' || message.senderId === group.senderId) return 'owner';
  return createHash('sha256').update(JSON.stringify([message.groupOpenid, message.senderId])).digest('hex');
}

function save(file, value) {
  writeFileSync(file + '.tmp', JSON.stringify(value), { mode: 0o600 });
  renameSync(file + '.tmp', file);
}

export class Sessions {
  constructor(rpc, runtime, workspace, ownerThread) {
    this.rpc = rpc;
    this.workspace = workspace;
    this.ownerThread = ownerThread;
    this.file = path.join(runtime, 'member-threads.json');
    this.threads = existsSync(this.file) ? JSON.parse(readFileSync(this.file, 'utf8')) : {};
    this.persisted = { ...this.threads };
  }
  lookup(key) { return key === 'owner' ? this.ownerThread : this.threads[key]; }
  threadIds() { return [...new Set([this.ownerThread, ...Object.values(this.threads)])]; }
  options(key) {
    if (key === 'owner') return {};
    const cwd = path.join(this.workspace, '.qq-workspaces', key);
    return {
      cwd,
      approvalPolicy: 'never',
      permissions: `qq_member_${key}`,
    };
  }
  config(key) {
    if (key === 'owner') return {};
    const { cwd, permissions } = this.options(key);
    const filesystem = { ':root': 'deny', ':minimal': 'read',
      [cwd]: 'write', [path.join(this.workspace, '01_Skill')]: 'read' };
    for (const name of ['00_Doc', '02_Prototype', '03_Build']) filesystem[path.join(this.workspace, name)] = 'write';
    return {
      default_permissions: permissions,
      'windows.sandbox': 'elevated',
      'features.prefer_mxc': true,
      project_doc_max_bytes: 0,
      'features.skip_host_skill_discovery': true,
      'plugins.codex-app-tools@openai-bundled.mcp_servers.codex_app.enabled': false,
      [`permissions.${permissions}`]: { filesystem, network: { enabled: false } },
    };
  }
  async resolve(key) {
    if (this.lookup(key)) return this.lookup(key);
    const { cwd, permissions } = this.options(key);
    mkdirSync(cwd, { recursive: true });
    // Feed trusted policy text explicitly: this Windows build's sandboxed AGENTS loader
    // fails to supply SYSTEMROOT. Member commands still use the restricted profile.
    const policyFiles = [
      path.join(os.homedir(), '.codex', 'AGENTS.md'), path.join(this.workspace, 'AGENTS.md'),
      path.join(os.homedir(), '.codex', 'skills', 'stop-that-shit', 'SKILL.md'),
      path.join(os.homedir(), '.codex', 'skills', 'ponytail', 'SKILL.md'),
    ];
    const policies = policyFiles.filter(file => existsSync(file)).map(file => `\nLoaded policy: ${file}\n${readFileSync(file, 'utf8')}`).join('\n');
    const result = await this.rpc.request('thread/start', {
      cwd, permissions, approvalPolicy: 'never', config: this.config(key),
      developerInstructions: `You are handling one QQ group member's independent conversation. Do not read other members' conversations or bridge runtime credentials. Shared project content directories: ${['00_Doc', '02_Prototype', '03_Build'].map(name => path.join(this.workspace, name)).join(', ')}. Modify project content only there. Your personal scratch directory is ${cwd}; record each task in its memory/YYYY-MM-DD.md, never credentials. Reply in Chinese unless requested otherwise and include three brief follow-up prompts. Do not start detached/background file-writing jobs: all writes must finish before the turn completes. Do not send messages to other people or chats without explicit authorization. Manually read applicable AGENTS.md files in shared directories you work on. If the filesystem helper fails, use sandboxed shell execution for file operations. The following policy files were loaded for you; apply Ponytail only to coding tasks.\n${policies}`,
    });
    if (result.activePermissionProfile?.id !== permissions) throw new Error('Member permission profile was not applied');
    const { thread } = result;
    if (!thread?.id || this.threadIds().includes(thread.id)) throw new Error('A distinct member thread was not returned');
    this.threads[key] = thread.id;
    return thread.id;
  }
  markStarted(key) {
    if (key === 'owner') return;
    this.persisted[key] = this.lookup(key);
    save(this.file, this.persisted);
  }
  async resume(key) {
    const existing = this.lookup(key);
    const id = await this.resolve(key);
    // A newly started thread is already loaded; its rollout is not persisted until
    // the first turn. Resuming it now fails with "no rollout found".
    if (!existing) return id;
    const { thread } = await this.rpc.request('thread/read', { threadId: id, includeTurns: false });
    if (thread.status.type !== 'notLoaded') return id;
    const options = this.options(key);
    const result = await this.rpc.request('thread/resume', {
      threadId: id, excludeTurns: true,
      ...(key === 'owner' ? {} : { cwd: options.cwd, permissions: options.permissions, approvalPolicy: 'never', config: this.config(key) }),
    });
    if (key !== 'owner' && result.activePermissionProfile?.id !== options.permissions) throw new Error('Member permission profile was not applied');
    return id;
  }
}

// One shared project: serialize all bridge-dispatched project turns, including questions.
// File-level parallelism requires a declared write set; natural-language guesses are insufficient.
export async function completedLockedTurn(rpc, lock) {
  if (!lock?.threadId || !lock.turnId) return null;
  const result = await rpc.request('thread/turns/list', {
    threadId: lock.threadId, limit: 50, itemsView: 'summary',
  });
  const turn = result.data.find(turn => turn.id === lock.turnId);
  return turn && ['completed', 'failed', 'interrupted'].includes(turn.status) ? turn : null;
}

export async function projectCanStop(rpc, lock, threadIds) {
  if (lock && !(await completedLockedTurn(rpc, lock))) return false;
  for (const threadId of new Set(threadIds)) {
    const { thread } = await rpc.request('thread/read', { threadId, includeTurns: false });
    if (!['idle', 'notLoaded'].includes(thread.status.type)) return false;
  }
  return true;
}

export class ProjectLock {
  constructor(file) {
    this.file = file;
    this.current = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : null;
  }
  persist() { save(this.file, this.current); }
  reserve(member) {
    if (this.current) return false;
    this.current = { member, threadId: null, turnId: null, phase: 'reserved' };
    this.persist();
    return true;
  }
  beforeStart(threadId) {
    this.current = { ...this.current, threadId, phase: 'starting' };
    this.persist();
  }
  started(threadId, turnId) {
    if (this.current?.threadId !== threadId) return;
    this.current = { ...this.current, turnId, phase: 'running' };
    this.persist();
  }
  complete(threadId, turnId) {
    if (this.current?.threadId !== threadId || !turnId || this.current?.turnId !== turnId) return false;
    this.clear();
    return true;
  }
  releaseReservation() {
    if (this.current?.phase !== 'reserved') return false;
    this.clear();
    return true;
  }
  clear() { this.current = null; this.persist(); }
}
