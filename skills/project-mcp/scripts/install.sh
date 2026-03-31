#!/usr/bin/env bash
set -euo pipefail

CLI="${1:-}"
TRANSPORT="http"
SERVER_NAME="cloudflare-ai"
SERVER_URL="https://mcp.cloudflare.com/mcp"
SERVER_KEY="$(printf '%s' "$SERVER_NAME" | tr '-' '_')"
ROOT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_JSON="$SCRIPT_DIR/project_json_patch.py"
PATCH_CODEX="$SCRIPT_DIR/codex_toml_patch.py"
NPX_PACKAGE=""
NPX_ARGS=()

usage() {
  cat <<USAGE
Usage:
  ./scripts/install.sh <claude|gemini|codex> http [server_name] [server_url]
  ./scripts/install.sh <claude|gemini|codex> npx [server_name] <package> [package_args...]

Examples:
  ./scripts/install.sh claude http
  ./scripts/install.sh gemini http cloudflare-ai https://mcp.cloudflare.com/mcp
  ./scripts/install.sh codex npx filesystem @modelcontextprotocol/server-filesystem /tmp
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

is_url() {
  [[ "$1" == http://* || "$1" == https://* ]]
}

is_probable_package() {
  [[ "$1" == @* || "$1" == *"/"* || "$1" == *"\\"* ]]
}

print_footer() {
  local cli="$1"
  echo
  echo "Done."
  echo "CLI: $cli"
  echo "Scope: project"
  echo "Project: $ROOT_DIR"
  echo "Transport: $TRANSPORT"
  echo "Server name: $SERVER_NAME"
  if [[ "$TRANSPORT" == "http" ]]; then
    echo "Server url:  $SERVER_URL"
  else
    echo "npx package: $NPX_PACKAGE"
    if [[ "${#NPX_ARGS[@]}" -gt 0 ]]; then
      echo "npx args:    ${NPX_ARGS[*]}"
    fi
  fi
  echo
}

install_claude() {
  echo "Installing project-scoped MCP for Claude Code..."
  if [[ "$TRANSPORT" == "http" ]]; then
    "$PYTHON_BIN" "$PATCH_JSON" add claude ".mcp.json" "$SERVER_NAME" http "$SERVER_URL"
  else
    "$PYTHON_BIN" "$PATCH_JSON" add claude ".mcp.json" "$SERVER_NAME" npx "$NPX_PACKAGE" "${NPX_ARGS[@]}"
  fi

  echo
  echo "Verifying Claude config..."
  if [[ -f .mcp.json ]] && "$PYTHON_BIN" "$PATCH_JSON" status claude ".mcp.json" "$SERVER_NAME" >/dev/null 2>&1; then
    echo "Found project config: .mcp.json"
  else
    echo "Warning: .mcp.json not found in current project." >&2
  fi

  print_footer "claude"
  echo "Next step in Claude Code session:"
  echo "  /mcp"
}

install_gemini() {
  echo "Installing project-scoped MCP for Gemini CLI..."
  if [[ "$TRANSPORT" == "http" ]]; then
    "$PYTHON_BIN" "$PATCH_JSON" add gemini ".gemini/settings.json" "$SERVER_NAME" http "$SERVER_URL"
  else
    "$PYTHON_BIN" "$PATCH_JSON" add gemini ".gemini/settings.json" "$SERVER_NAME" npx "$NPX_PACKAGE" "${NPX_ARGS[@]}"
  fi

  echo
  echo "Verifying Gemini config..."
  if [[ -f .gemini/settings.json ]] && "$PYTHON_BIN" "$PATCH_JSON" status gemini ".gemini/settings.json" "$SERVER_NAME" >/dev/null 2>&1; then
    echo "Found project config: .gemini/settings.json"
    grep -n "\"$SERVER_NAME\"" .gemini/settings.json || true
  else
    echo "Warning: .gemini/settings.json not found in current project." >&2
  fi

  print_footer "gemini"
  echo "Next step in Gemini CLI session:"
  echo "  /mcp auth"
  echo "or"
  echo "  /mcp auth $SERVER_NAME"
}

install_codex() {
  echo "Installing project-scoped MCP for Codex CLI..."
  mkdir -p .codex
  if [[ "$TRANSPORT" == "http" ]]; then
    "$PYTHON_BIN" "$PATCH_CODEX" add-http ".codex/config.toml" "$SERVER_KEY" "$SERVER_URL"
  else
    if [[ "$(uname -s)" =~ ^(MINGW|MSYS|CYGWIN) ]]; then
      "$PYTHON_BIN" "$PATCH_CODEX" add-stdio ".codex/config.toml" "$SERVER_KEY" cmd /c npx -y "$NPX_PACKAGE" "${NPX_ARGS[@]}"
    else
      "$PYTHON_BIN" "$PATCH_CODEX" add-stdio ".codex/config.toml" "$SERVER_KEY" npx -y "$NPX_PACKAGE" "${NPX_ARGS[@]}"
    fi
  fi

  echo
  echo "Verifying Codex project config..."
  if [[ -f .codex/config.toml ]] && "$PYTHON_BIN" "$PATCH_CODEX" status ".codex/config.toml" "$SERVER_KEY" >/dev/null 2>&1; then
    echo "Found project config: .codex/config.toml"
    grep -n "mcp_servers\.$SERVER_KEY" .codex/config.toml || true
  else
    echo "Warning: .codex/config.toml not found in current project." >&2
  fi

  print_footer "codex"
  echo "Next steps:"
  echo "  codex mcp login $SERVER_KEY"
  echo "Then open codex TUI and run:"
  echo "  /mcp"
}

if [[ -z "$CLI" ]]; then
  usage
  exit 1
fi

shift || true
TRANSPORT="${1:-}"
if [[ "$TRANSPORT" != "http" && "$TRANSPORT" != "npx" ]]; then
  echo "Error: transport must be http or npx." >&2
  usage
  exit 1
fi
shift || true

if [[ "$TRANSPORT" == "http" ]]; then
  if [[ -n "${1:-}" ]]; then
    if is_url "$1"; then
      SERVER_URL="$1"
      shift || true
    else
      SERVER_NAME="$1"
      shift || true
      if [[ -n "${1:-}" ]]; then
        SERVER_URL="$1"
        shift || true
      fi
    fi
  fi
else
  if [[ -n "${1:-}" ]]; then
    if is_probable_package "$1"; then
      NPX_PACKAGE="$1"
      shift || true
    else
      SERVER_NAME="$1"
      shift || true
      NPX_PACKAGE="${1:-}"
      if [[ -n "$NPX_PACKAGE" ]]; then
        shift || true
      fi
    fi
  fi
  if [[ -z "$NPX_PACKAGE" ]]; then
    echo "Error: npx transport requires a package name." >&2
    usage
    exit 1
  fi
  NPX_ARGS=("$@")
fi

SERVER_KEY="$(printf '%s' "$SERVER_NAME" | tr '-' '_')"
need_python

case "$CLI" in
  claude)
    install_claude
    ;;
  gemini)
    install_gemini
    ;;
  codex)
    install_codex
    ;;
  *)
    echo "Error: unsupported CLI: $CLI" >&2
    usage
    exit 1
    ;;
esac
