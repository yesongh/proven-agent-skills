#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def usage() -> None:
    print(
        "Usage:\n"
        "  project_json_patch.py add <claude|gemini> <config_path> <server_name> <http|npx> <target> [extra_args...]\n"
        "  project_json_patch.py remove <claude|gemini> <config_path> <server_name>\n"
        "  project_json_patch.py status <claude|gemini> <config_path> <server_name>",
        file=sys.stderr,
    )


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def windows_npx_command(package: str, extra_args: list[str]) -> tuple[str, list[str]]:
    if os.name == "nt":
        return "cmd", ["/c", "npx", "-y", package, *extra_args]
    return "npx", ["-y", package, *extra_args]


def build_claude_server(transport: str, target: str, extra_args: list[str]) -> dict:
    if transport == "http":
        return {"type": "http", "url": target}
    command, args = windows_npx_command(target, extra_args)
    return {"type": "stdio", "command": command, "args": args, "env": {}}


def build_gemini_server(transport: str, target: str, extra_args: list[str]) -> dict:
    if transport == "http":
        return {"httpUrl": target}
    command, args = windows_npx_command(target, extra_args)
    return {"command": command, "args": args}


def add_server(kind: str, path: Path, server_name: str, transport: str, target: str, extra_args: list[str]) -> None:
    payload = read_json(path)
    servers = payload.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        raise ValueError("mcpServers exists but is not an object")

    if kind == "claude":
        servers[server_name] = build_claude_server(transport, target, extra_args)
    elif kind == "gemini":
        servers[server_name] = build_gemini_server(transport, target, extra_args)
    else:
        raise ValueError(f"unsupported kind: {kind}")

    write_json(path, payload)


def remove_server(path: Path, server_name: str) -> bool:
    if not path.exists():
        return False
    payload = read_json(path)
    servers = payload.get("mcpServers")
    if not isinstance(servers, dict) or server_name not in servers:
        return False

    del servers[server_name]
    if not servers:
        payload.pop("mcpServers", None)
    write_json(path, payload)
    return True


def has_server(path: Path, server_name: str) -> bool:
    if not path.exists():
        return False
    payload = read_json(path)
    servers = payload.get("mcpServers")
    return isinstance(servers, dict) and server_name in servers


def main() -> int:
    if len(sys.argv) < 5:
        usage()
        return 1

    action = sys.argv[1]
    kind = sys.argv[2]
    path = Path(sys.argv[3])
    server_name = sys.argv[4]

    if kind not in {"claude", "gemini"}:
        usage()
        return 1

    if action == "add":
        if len(sys.argv) < 7:
            usage()
            return 1
        transport = sys.argv[5]
        target = sys.argv[6]
        extra_args = sys.argv[7:]
        if transport not in {"http", "npx"}:
            usage()
            return 1
        add_server(kind, path, server_name, transport, target, extra_args)
        print(f"Added project-scoped {kind} MCP server: {server_name}")
        return 0

    if action == "remove":
        removed = remove_server(path, server_name)
        if removed:
            print(f"Removed project-scoped {kind} MCP server: {server_name}")
        else:
            print(f"Server not found in project config: {server_name}")
        return 0

    if action == "status":
        if has_server(path, server_name):
            print(f"present: {server_name}")
            return 0
        print(f"missing: {server_name}")
        return 2

    usage()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
