# Project Conventions

## AGENTS.md as canonical source

CLAUDE.md and GEMINI.md both contain only `@./AGENTS.md`. All project context lives in AGENTS.md. This means all three CLIs (Claude Code, Codex, Gemini CLI) read from a single file.

## Template substitution variables

| Variable | Description |
|----------|-------------|
| `{{name}}` | Package name without scope (e.g. `my-cli`) |
| `{{description}}` | One-line package description |
| `{{npm_scope}}` | npm scope (default: `@yesongh`) |
| `{{github_owner}}` | GitHub owner/org (default: `yesongh`) |
| `{{year}}` | Current year (auto-set by scaffold.mjs) |
| `{{bin}}` | CLI binary name (defaults to `{{name}}`) |

## Template file naming

- Files with `{{var}}` placeholders in content → name ends in `.tmpl` (extension stripped on output)
- Files with `{{var}}` in the filename → substituted directly in the path
- Non-template files copied verbatim (but content substitution still runs — safe because no `{{}}` present)

## Defaults

- npm_scope default: `@yesongh`
- github_owner default: `yesongh`
- No `author` field in package.json (intentional)
- MIT license, year only, no name

## Zero dependencies

All project code should use Node built-ins only. No runtime deps unless there's a compelling reason.

## Semver

- `patch`: docs, metadata, tests, backward-compatible fixes
- `minor`: new user-visible features
- `major`: breaking CLI or runtime behavior changes

Never bump version for docs-only changes by default.

## CLI bin naming

Single bin name = package name (`{{name}}`). If you want a short alias, add a second entry to `package.json` `bin`.
