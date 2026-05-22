#!/usr/bin/env node
// Creates .claude/skills → .agents/skills junction/symlink so Claude Code,
// Codex CLI, and Gemini CLI all share one skill source without duplication.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const link = path.join(root, '.claude', 'skills');
const target = path.join(root, '.agents', 'skills');

if (!fs.existsSync(target)) {
  process.exit(0); // no skills directory yet — nothing to link
}

if (fs.existsSync(link)) {
  const stat = fs.lstatSync(link);
  if (stat.isSymbolicLink() || stat.isDirectory()) process.exit(0);
  console.error(`setup-skills: ${link} exists but is not a link/directory. Remove it manually.`);
  process.exit(1);
}

const type = process.platform === 'win32' ? 'junction' : 'dir';
fs.symlinkSync(target, link, type);
console.log(`setup-skills: linked .claude/skills → .agents/skills`);
