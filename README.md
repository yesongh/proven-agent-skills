# proven-agent-skills
A curated collection of reusable, battle-tested skills for AI agents.

Skills live under `skills/`. This layout is compatible with CC Switch custom skill repositories, which can recursively scan repositories for `SKILL.md` files.

Compatibility replacement files live under `patches/`.

`patches/claude-plugins-official/marketplace.json` is a patched copy of the official Claude plugins marketplace file with incompatible `git-subdir` entries removed for Claude Code `2.1.68`.

To use it, replace:

`~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json`
