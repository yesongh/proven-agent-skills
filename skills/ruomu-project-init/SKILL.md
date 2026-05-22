---
name: ruomu-project-init
description: Scaffold a new project with AGENTS.md, CLAUDE.md, and GEMINI.md already wired for Claude Code, Codex, and Gemini CLI. Use this whenever the user wants to start a new project, init a repo, bootstrap a package, scaffold a skeleton, or says "ruomu init", "new cli", "new agent project", or "new website" — even if they don't explicitly say "scaffold".
---

Scaffold a new project with your standard conventions baked in.

## Step 1: Project type

Ask the user: "What type of project?" with these choices:

- **npm** — Node.js CLI published to npm (full template)
- **agent** — Cloudflare Workers-based agent: D1, R2, Queue, AI Gateway, Workflow, Worker (placeholder template — Cloudflare details TBD)
- **website** — Website project (placeholder template — framework TBD)

## Step 2: Collect params

Ask for **name** (package name, no scope) and **description** in one question. Confirm these defaults inline:

| Param | Default |
|-------|---------|
| npm_scope | `@yesongh` |
| github_owner | `yesongh` |
| target dir | `./<name>` |

Present the defaults and let the user override any of them. Don't ask for each separately unless they say they want to change the defaults.

## Step 3: Run the scaffolder

```bash
node ~/.claude/skills/ruomu-project-init/scripts/scaffold.mjs \
  <type> ./<name> \
  --name "<name>" \
  --description "<description>" \
  --npm-scope "<scope>" \
  --github-owner "<owner>"
```

The script walks `~/.claude/skills/ruomu-project-init/assets/templates/<type>/`, substitutes `{{var}}` in file names and content, strips `.tmpl` from output file names, then runs `git init`.

## Step 4: After scaffold

**For npm projects:**
1. `cd <name> && npm install` — also auto-creates `.claude/skills → .agents/skills` junction
2. `npm test` — three smoke tests should pass immediately
3. `gh repo create <owner>/<name> --public --source=. --push`
4. First publish: follow `docs/npm-publish-sop.md` in the new project

**For agent / website projects:**
1. `cd <name> && npm install` — also auto-creates `.claude/skills → .agents/skills` junction
2. Open `AGENTS.md` and work through the `## TODO` section.

## Notes

- To add a file to a template, drop it into `~/.claude/skills/ruomu-project-init/assets/templates/<type>/`. Files with `{{var}}` placeholders should end in `.tmpl` (extension is stripped on output).
- agent and website templates are placeholders in v0.1 — they'll be enriched in a later version.
- Conventions reference: `~/.claude/skills/ruomu-project-init/references/conventions.md`.
- **Shared skills convention:** project-specific skills go in `.agents/skills/<name>/SKILL.md`. The `postinstall` hook links `.claude/skills → .agents/skills` automatically (Windows: Junction, macOS/Linux: symlink), so Claude Code, Codex CLI, and Gemini CLI all discover the same skills from one source. `.claude/skills` is gitignored; `.agents/skills/` is committed.
