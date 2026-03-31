# Codex CLI

项目级配置文件：
- `.codex/config.toml`

验证：
- 检查 `.codex/config.toml` 是否存在
- 检查 `[mcp_servers.<server_key>]` 是否已写入

下一步：

```bash
codex mcp login cloudflare_ai
```

然后进入 `codex` TUI：

```text
/mcp
```

排障命令：

```bash
codex mcp list
codex mcp get cloudflare_ai
codex mcp login cloudflare_ai
codex mcp logout cloudflare_ai
```

手动检查：

```bash
cat .codex/config.toml
```

写入约定：
- `http`：`url = "..."`
- `npx`：`command = "..."` + `args = [...]`
- `server_name` 在 TOML 里会转换成 `server_key`，例如 `cloudflare-ai` → `cloudflare_ai`
