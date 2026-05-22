#!/usr/bin/env node
import { readFileSync, writeFileSync, copyFileSync, mkdirSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const SKILL_DIR = dirname(dirname(fileURLToPath(import.meta.url)));
const TEMPLATES_DIR = join(SKILL_DIR, 'assets', 'templates');
const SUPPORTED_TYPES = ['npm', 'agent', 'website'];

function usage() {
  process.stderr.write(
    'Usage: scaffold.mjs <type> <target> --name <name> --description <desc> [--npm-scope <scope>] [--github-owner <owner>] [--force]\n' +
    `  type: ${SUPPORTED_TYPES.join(', ')}\n`
  );
  process.exit(1);
}

function parseArgs(argv) {
  const result = { 'npm-scope': '@yesongh', 'github-owner': 'yesongh', force: false };
  const pos = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--force') { result.force = true; continue; }
    if (argv[i].startsWith('--')) { result[argv[i].slice(2)] = argv[++i]; continue; }
    pos.push(argv[i]);
  }
  result.type = pos[0];
  result.target = pos[1];
  return result;
}

function sub(text, vars) {
  return text.replace(/\{\{(\w+)\}\}/g, (_, k) => String(vars[k] ?? `{{${k}}}`));
}

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    statSync(full).isDirectory() ? out.push(...walk(full)) : out.push(full);
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));

if (!args.type || !args.target || !args.name || !args.description) usage();
if (!SUPPORTED_TYPES.includes(args.type)) {
  process.stderr.write(`Unknown type "${args.type}". Supported: ${SUPPORTED_TYPES.join(', ')}\n`);
  process.exit(1);
}

const vars = {
  name: args.name,
  description: args.description,
  npm_scope: args['npm-scope'],
  github_owner: args['github-owner'],
  year: String(new Date().getFullYear()),
  bin: args.name,
};

const target = args.target;
const templateDir = join(TEMPLATES_DIR, args.type);

if (!existsSync(templateDir)) {
  process.stderr.write(`No template found for type "${args.type}".\n`);
  process.exit(1);
}

mkdirSync(target, { recursive: true });

if (!args.force) {
  const existing = readdirSync(target).filter(f => f !== '.git');
  if (existing.length > 0) {
    process.stderr.write(`"${target}" is not empty. Use --force to overwrite.\n`);
    process.exit(1);
  }
}

process.stdout.write(`\nScaffolding ${args.type} project "${args.name}" → ${target}\n\n`);

let count = 0;
for (const srcPath of walk(templateDir)) {
  const rel = relative(templateDir, srcPath);
  const outRel = sub(rel.endsWith('.tmpl') ? rel.slice(0, -5) : rel, vars);
  const destPath = join(target, outRel);

  if (!args.force && existsSync(destPath) && readFileSync(destPath, 'utf8').trim()) {
    process.stdout.write(`  skip: ${outRel}\n`);
    continue;
  }

  mkdirSync(dirname(destPath), { recursive: true });
  writeFileSync(destPath, sub(readFileSync(srcPath, 'utf8'), vars));
  process.stdout.write(`  create: ${outRel}\n`);
  count++;
}

// copy setup-skills.mjs (lives alongside this script, not in the template)
const setupSrc = join(SKILL_DIR, 'scripts', 'setup-skills.mjs');
const setupDest = join(target, 'scripts', 'setup-skills.mjs');
mkdirSync(dirname(setupDest), { recursive: true });
copyFileSync(setupSrc, setupDest);
process.stdout.write(`  create: scripts/setup-skills.mjs\n`);
count++;

try {
  execSync('git init -q', { cwd: target });
  process.stdout.write('\n  git init OK\n');
} catch {
  process.stdout.write('\n  (git init skipped)\n');
}

process.stdout.write(`
Done! ${count} files created.

Next steps:
  cd ${target}
  npm install
  npm test
  gh repo create ${vars.github_owner}/${vars.name} --public --source=. --push

For first npm publish → docs/npm-publish-sop.md
`);
