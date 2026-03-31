#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


def usage() -> None:
    print(
        "Usage:\n"
        "  codex_toml_patch.py add <config_path> <server_key> <url>\n"
        "  codex_toml_patch.py add-http <config_path> <server_key> <url>\n"
        "  codex_toml_patch.py add-stdio <config_path> <server_key> <command> [args...]\n"
        "  codex_toml_patch.py remove <config_path> <server_key>\n"
        "  codex_toml_patch.py status <config_path> <server_key>",
        file=sys.stderr,
    )


def normalize_newlines(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return normalize_newlines(path.read_text(encoding="utf-8"))


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def toml_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def toml_array(values: list[str]) -> str:
    return "[" + ", ".join(toml_string(value) for value in values) + "]"


def make_http_block(server_key: str, url: str) -> str:
    return (
        f"[mcp_servers.{server_key}]\n"
        f"url = {toml_string(url)}\n"
        f"enabled = true\n"
    )


def make_stdio_block(server_key: str, command: str, args: list[str]) -> str:
    block = [
        f"[mcp_servers.{server_key}]",
        f"command = {toml_string(command)}",
        f"args = {toml_array(args)}",
        "enabled = true",
    ]
    return "\n".join(block) + "\n"


def remove_block(text: str, server_key: str) -> tuple[str, bool]:
    pattern = re.compile(
        rf"(?ms)^\[mcp_servers\.{re.escape(server_key)}\]\n.*?(?=^\[|\Z)"
    )
    new_text, count = pattern.subn("", text, count=1)
    new_text = re.sub(r"\n{3,}", "\n\n", new_text).lstrip("\n")
    return new_text, count > 0


def add_block(text: str, block: str, server_key: str) -> str:
    cleaned, _ = remove_block(text, server_key)
    if cleaned and not cleaned.endswith("\n"):
        cleaned += "\n"
    if cleaned:
        return cleaned + "\n" + block
    return block


def status(text: str, server_key: str) -> bool:
    pattern = re.compile(rf"(?m)^\[mcp_servers\.{re.escape(server_key)}\]$")
    return bool(pattern.search(text))


def main() -> int:
    if len(sys.argv) < 4:
        usage()
        return 1

    action = sys.argv[1]
    path = Path(sys.argv[2])
    server_key = sys.argv[3]
    text = read_text(path)

    if action in {"add", "add-http"}:
        if len(sys.argv) != 5:
            usage()
            return 1
        url = sys.argv[4]
        updated = add_block(text, make_http_block(server_key, url), server_key)
        write_text(path, updated)
        print(f"Added project-scoped Codex MCP server: {server_key}")
        return 0

    if action == "add-stdio":
        if len(sys.argv) < 5:
            usage()
            return 1
        command = sys.argv[4]
        args = sys.argv[5:]
        updated = add_block(text, make_stdio_block(server_key, command, args), server_key)
        write_text(path, updated)
        print(f"Added project-scoped Codex MCP server: {server_key}")
        return 0

    if action == "remove":
        updated, removed = remove_block(text, server_key)
        write_text(path, updated)
        if removed:
            print(f"Removed project-scoped Codex MCP server: {server_key}")
        else:
            print(f"Server not found in project config: {server_key}")
        return 0

    if action == "status":
        if status(text, server_key):
            print(f"present: {server_key}")
            return 0
        print(f"missing: {server_key}")
        return 2

    usage()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
