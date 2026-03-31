# Claude Code

项目级配置文件：
- `.mcp.json`

验证：
- 检查 `.mcp.json` 是否存在
- 检查 `mcpServers.<server_name>` 是否已写入

下一步：

```text
/mcp
```

排障命令：

```bash
claude mcp list
claude mcp get cloudflare-ai
claude mcp remove cloudflare-ai
claude mcp reset-project-choices
```

会话内：

```text
/mcp
```

写入约定：
- `http`：`type = http` + `url`
- `npx`：`type = stdio` + `command` + `args`
