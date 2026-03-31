---
name: project-mcp
description: 在当前项目里为 Claude Code、Gemini CLI、Codex CLI 安装、卸载或排查项目级 MCP 配置。适用于请求明确提到项目级 MCP、只修改当前仓库、不改用户全局配置、Cloudflare AI MCP、`.mcp.json`、`.gemini/settings.json`、`.codex/config.toml`、`http` 安装或 `npx` 安装的场景。
---

# Project MCP Manager

把 MCP 安装到当前项目，或从当前项目卸载，不写入用户全局目录。

默认目标是 Cloudflare AI MCP：
- server_name: `cloudflare-ai`
- server_url: `https://mcp.cloudflare.com/mcp`

## 工作流

1. 先确认目标 CLI：`claude`、`gemini` 或 `codex`。
2. 再确认安装方式：`http` 或 `npx`。
3. 默认优先 `http`，默认服务是 `cloudflare-ai` + `https://mcp.cloudflare.com/mcp`。
4. 只修改项目内配置文件，不改用户全局配置。
5. 执行安装或卸载脚本后，检查对应项目配置文件是否已写入或删除。
6. 最后告诉用户下一步认证命令或排障命令。

## 按目标 CLI 继续读取

- Claude Code：读 `references/claude.md`
- Gemini CLI：读 `references/gemini.md`
- Codex CLI：读 `references/codex.md`

脚本入口：
- `scripts/install.sh`
- `scripts/uninstall.sh`

## 用法

在项目根目录执行。

### 安装

```bash
./scripts/install.sh <claude|gemini|codex> http [server_name] [server_url]
./scripts/install.sh <claude|gemini|codex> npx [server_name] <package> [package_args...]
```

默认会安装：
- 方式 = `http`
- name = `cloudflare-ai`
- url = `https://mcp.cloudflare.com/mcp`

### 卸载

```bash
./scripts/uninstall.sh <claude|gemini|codex> [server_name]
```

## 参数约定

- 第一个参数：CLI 类型，取值为 `claude` / `gemini` / `codex`
- 第二个参数：安装方式，必须是 `http` 或 `npx`
- `http`：远程 HTTP MCP
- `npx`：本地 stdio MCP，由 `npx` 启动
- 默认 `server_name` 是 `cloudflare-ai`
- 默认 `server_url` 是 `https://mcp.cloudflare.com/mcp`
- Codex 内部会把 `server_name` 规范成 `server_key`
- 例如 `cloudflare-ai` → `cloudflare_ai`

## 设计原则

1. 默认只改当前项目，不改用户全局。
2. 每次安装或卸载后都做基本验证。
3. 以项目内配置文件作为最终真实状态来源。
4. 命令失败时先读项目配置，再决定修复动作，不要盲目重试。

优先直接执行脚本，不要重复描述已知命令语法。
