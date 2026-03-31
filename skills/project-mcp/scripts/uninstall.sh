#!/usr/bin/env bash
set -euo pipefail

CLI="${1:-}"
SERVER_NAME="cloudflare-ai"
SERVER_KEY="$(printf '%s' "$SERVER_NAME" | tr '-' '_')"
ROOT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_JSON="$SCRIPT_DIR/project_json_patch.py"
PATCH_CODEX="$SCRIPT_DIR/codex_toml_patch.py"

usage() {
  cat <<USAGE
Usage:
  ./scripts/uninstall.sh <claude|gemini|codex> [server_name]
  ./scripts/uninstall.sh <claude|gemini|codex> [http|npx] [server_name]

Examples:
  ./scripts/uninstall.sh claude
  ./scripts/uninstall.sh gemini cloudflare-ai
  ./scripts/uninstall.sh codex my-server
USAGE
}

need_python() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
    return
  fi
  if command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
    return
  fi
  echo "Error: python3 or python is required." >&2
  exit 1
}

print_footer() {
  local cli="$1"
  echo
  echo "Done."
  echo "CLI: $cli"
  echo "Scope: project"
  echo "Project: $ROOT_DIR"
  echo "Removed server: $SERVER_NAME"
  echo
}

uninstall_claude() {
  echo "Removing project-scoped MCP from Claude Code..."
  "$PYTHON_BIN" "$PATCH_JSON" remove claude ".mcp.json" "$SERVER_NAME"

  echo
  echo "Verifying Claude config..."
  if [[ -f .mcp.json ]]; then
    "$PYTHON_BIN" "$PATCH_JSON" status claude ".mcp.json" "$SERVER_NAME" >/dev/null 2>&1 || true
    grep -n "\"$SERVER_NAME\"" .mcp.json || true
  fi

  print_footer "claude"
  echo "If Claude still behaves oddly, try:"
  echo "  claude mcp reset-project-choices"
  echo "Then reopen Claude Code and run:"
  echo "  /mcp"
}

uninstall_gemini() {
  echo "Removing project-scoped MCP from Gemini CLI..."
  "$PYTHON_BIN" "$PATCH_JSON" remove gemini ".gemini/settings.json" "$SERVER_NAME"

  echo
  echo "Verifying Gemini config..."
  if [[ -f .gemini/settings.json ]]; then
    "$PYTHON_BIN" "$PATCH_JSON" status gemini ".gemini/settings.json" "$SERVER_NAME" >/dev/null 2>&1 || true
    grep -n "\"$SERVER_NAME\"" .gemini/settings.json || true
  fi

  print_footer "gemini"
  echo "If needed, reopen Gemini and run:"
  echo "  /mcp list"
}

uninstall_codex() {
  echo "Removing project-scoped MCP from Codex CLI..."
  if [[ ! -f .codex/config.toml ]]; then
    echo "No .codex/config.toml found in current project. Nothing to remove."
  else
    "$PYTHON_BIN" "$PATCH_CODEX" remove ".codex/config.toml" "$SERVER_KEY"
  fi

  echo
  echo "Verifying Codex project config..."
  if [[ -f .codex/config.toml ]]; then
    "$PYTHON_BIN" "$PATCH_CODEX" status ".codex/config.toml" "$SERVER_KEY" >/dev/null 2>&1 || true
    grep -n "mcp_servers\.$SERVER_KEY" .codex/config.toml || true
  fi

  print_footer "codex"
  echo "Optional cleanup if you want to clear OAuth state too:"
  echo "  codex mcp logout $SERVER_KEY"
}

if [[ -z "$CLI" ]]; then
  usage
  exit 1
fi

shift || true
if [[ "${1:-}" == "http" || "${1:-}" == "npx" ]]; then
  shift || true
fi
if [[ -n "${1:-}" ]]; then
  SERVER_NAME="$1"
fi
SERVER_KEY="$(printf '%s' "$SERVER_NAME" | tr '-' '_')"
need_python

case "$CLI" in
  claude)
    uninstall_claude
    ;;
  gemini)
    uninstall_gemini
    ;;
  codex)
    uninstall_codex
    ;;
  *)
    echo "Error: unsupported CLI: $CLI" >&2
    usage
    exit 1
    ;;
esac
