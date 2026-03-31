# Gemini CLI

项目级配置文件：
- `.gemini/settings.json`

验证：
- 检查 `.gemini/settings.json` 是否存在
- 检查 `mcpServers.<server_name>` 是否已写入

下一步：

```text
/mcp auth
```

或：

```text
/mcp auth cloudflare-ai
```

排障命令：

```bash
gemini mcp list
gemini mcp remove -s project cloudflare-ai
```

会话内：

```text
/mcp list
/mcp auth
/mcp auth cloudflare-ai
```

写入约定：
- `http`：`httpUrl`
- `npx`：`command` + `args`
