import path from 'node:path';
import os from 'node:os';
import { realpathSync, statSync, openSync, readSync, closeSync } from 'node:fs';

export const testImage = '00_Doc/测试素材/2026-10-27/alchemy-cottage-test.png';
export function imageRoots(workspace, key, threadId) {
  const roots = ['00_Doc', '02_Prototype', '03_Build'].map(name => path.join(workspace, name));
  if (key !== 'owner') roots.push(path.join(workspace, '.qq-workspaces', key));
  if (threadId) roots.push(path.join(os.homedir(), '.codex', 'generated_images', threadId));
  return roots;
}
export function checkedImage(file, roots) {
  if (!path.isAbsolute(file)) throw new Error('Image must be a local absolute path');
  const real = realpathSync(file);
  if (!roots.some(root => {
    try {
      const relative = path.relative(realpathSync(root), real);
      return relative && !relative.startsWith('..' + path.sep) && relative !== '..' && !path.isAbsolute(relative);
    } catch { return false; }
  })) throw new Error('Image is outside this member allowed directories');
  const info = statSync(real);
  if (!info.isFile() || info.size > 20 * 1024 * 1024) throw new Error('Image exceeds bridge limit or is not a file');
  const header = Buffer.alloc(12), descriptor = openSync(real, 'r');
  try { readSync(descriptor, header, 0, 12, 0); } finally { closeSync(descriptor); }
  const ext = path.extname(real).toLowerCase();
  const valid = (ext === '.png' && header.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])))
    || (['.jpg', '.jpeg'].includes(ext) && header[0] === 255 && header[1] === 216 && header[2] === 255)
    || (ext === '.gif' && /^GIF8[79]a/.test(header.toString('ascii')))
    || (ext === '.webp' && header.toString('ascii', 0, 4) === 'RIFF' && header.toString('ascii', 8, 12) === 'WEBP');
  if (!valid) throw new Error('Unsupported image format');
  return real;
}
export function replyImages(text, roots) {
  const files = [];
  const cleaned = text.replace(/!\[[^\]]*\]\((?:<([^>]+)>|([^\s)]+))\)/g, (markup, angle, plain) => {
    try {
      const file = checkedImage(angle || plain, roots);
      if (files.length < 4 && !files.includes(file)) files.push(file);
      return '〔图片〕';
    } catch { return '〔图片无法发送：路径或格式不在允许范围〕'; }
  });
  return { files, text: cleaned };
}
export async function sendImages(bot, target, files, caption) {
  const receipts = [];
  for (const file of files) {
    const sent = await bot.sendImage(target, { localPath: file }, { content: caption });
    if (!sent.message?.id) throw new Error('Image upload returned no sent-message receipt');
    receipts.push(sent.message.id);
  }
  return receipts;
}
