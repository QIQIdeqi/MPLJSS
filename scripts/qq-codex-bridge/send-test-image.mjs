// This app rejected proactive image posting (40034105). Use a fresh QQ @ reply.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkedImage, imageRoots, testImage } from './images.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const workspace = path.resolve(directory, '../..'), runtime = path.join(directory, '.runtime');
const group = JSON.parse(fs.readFileSync(path.join(runtime, 'group.json')));
if (!group?.groupOpenid) throw new Error('No selected QQ group is bound');
checkedImage(path.join(workspace, testImage), imageRoots(workspace, 'owner'));
console.log('PASS: selected group and test image verified. No network message was sent.');
if (!process.argv.includes('--check')) {
  const readyFile = path.join(runtime, 'ready.json');
  const ready = fs.existsSync(readyFile) ? JSON.parse(fs.readFileSync(readyFile)) : null;
  if (ready?.imageReplyVersion !== 'local-images-v1') {
    console.log('The running bridge does not have image replies. Fully quit Codex, then run Start-Bridge.cmd -Restart.');
  }
  console.log('In the bound QQ group, use QQ to @ the bot and send: /image-test');
  console.log('This uses the new incoming message ID to reply with the image. No extra AppSecret entry is needed by this helper.');
}
