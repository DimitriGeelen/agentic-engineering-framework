#!/usr/bin/env python3
# T-2265 (arc-010 Slice 2): framework MCP server.
#
# Reads policy/capability-overlay/tool-set.yaml at startup, emits the
# manifest at agents/mcp/framework-mcp-manifest.json, and registers an
# MCP tool for every read_only: (16) + agent_authority: (6) entry.
# sovereignty_bound_excluded: (5) is NEVER registered (foreclosed today).
#
# Transport: stdio (Claude Code default).
# Backend: shell out to `bin/fw <fw_command>` to preserve existing gates.
"""Framework MCP server — stdio transport, shells to bin/fw."""

from __future__ import annotations

import asyncio
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any

# Allow direct invocation: python3 agents/mcp/framework_mcp_server.py
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from manifest import (  # noqa: E402
    emit_manifest,
    framework_root,
    load_catalogue,
    load_tool_set,
    project_root,
    tool_set_path,
)

from mcp.server.lowlevel import Server  # noqa: E402
from mcp.server.stdio import stdio_server  # noqa: E402
from mcp.types import TextContent, Tool  # noqa: E402

SERVER_NAME = "framework-mcp"
SERVER_VERSION = "0.1.0"


def _fw_bin(root: Path) -> Path:
    return root / "bin" / "fw"


def _read_only_schema(_entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "args": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Extra arguments forwarded verbatim to `fw <verb>`.",
            }
        },
        "additionalProperties": False,
    }


def _agent_authority_schema(_entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "task_id": {
                "type": "string",
                "description": (
                    "T-XXX task id under which this call runs. Required: focus "
                    "is set to this task before the underlying `fw` verb runs, "
                    "preserving framework gate behaviour."
                ),
                "pattern": "^T-\\d+$",
            },
            "args": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Extra arguments forwarded verbatim to `fw <verb>`.",
            },
        },
        "required": ["task_id"],
        "additionalProperties": False,
    }


def _build_tools(tool_set: dict[str, Any]) -> list[Tool]:
    tools: list[Tool] = []
    for entry in tool_set.get("read_only", []):
        tools.append(
            Tool(
                name=entry["name"],
                description=f"[read-only] {entry.get('description', '').strip()}",
                inputSchema=_read_only_schema(entry),
            )
        )
    for entry in tool_set.get("agent_authority", []):
        tools.append(
            Tool(
                name=entry["name"],
                description=(
                    f"[agent-authority] {entry.get('description', '').strip()} "
                    f"Requires task_id (sets focus before invocation)."
                ),
                inputSchema=_agent_authority_schema(entry),
            )
        )
    return tools


def _index_by_name(tool_set: dict[str, Any]) -> dict[str, tuple[str, dict[str, Any]]]:
    out: dict[str, tuple[str, dict[str, Any]]] = {}
    for entry in tool_set.get("read_only", []):
        out[entry["name"]] = ("read_only", entry)
    for entry in tool_set.get("agent_authority", []):
        out[entry["name"]] = ("agent_authority", entry)
    return out


def _run_fw(
    fw_root: Path, proj_root: Path, fw_command: str, extra_args: list[str]
) -> tuple[int, str, str]:
    # T-2459: bin/fw resolves against framework_root (the assets live with the
    # framework — in a consumer that's .agentic-framework/bin/fw), but cwd is
    # project_root (the consumer checkout) so `fw` operates on the right project.
    # In the framework repo the two roots coincide (no behaviour change).
    cmd = [str(_fw_bin(fw_root))]
    cmd.extend(shlex.split(fw_command))
    cmd.extend(extra_args)
    proc = subprocess.run(
        cmd,
        cwd=proj_root,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


def _set_focus(fw_root: Path, proj_root: Path, task_id: str) -> tuple[int, str, str]:
    return _run_fw(fw_root, proj_root, "context focus", [task_id])


def _format_result(rc: int, stdout: str, stderr: str) -> str:
    parts: list[str] = []
    if stdout:
        parts.append(stdout.rstrip("\n"))
    if stderr:
        parts.append("--- stderr ---\n" + stderr.rstrip("\n"))
    parts.append(f"--- exit: {rc} ---")
    return "\n".join(parts)


def build_server(tool_set: dict[str, Any] | None = None) -> Server:
    ts = tool_set if tool_set is not None else load_catalogue()
    fw_root = framework_root()
    proj_root = project_root()
    index = _index_by_name(ts)
    tools = _build_tools(ts)

    server: Server = Server(SERVER_NAME, version=SERVER_VERSION)

    @server.list_tools()
    async def _list_tools() -> list[Tool]:
        return tools

    @server.call_tool()
    async def _call_tool(
        name: str,
        arguments: dict[str, Any] | None,
    ) -> list[TextContent]:
        if name not in index:
            return [TextContent(type="text", text=f"ERROR: unknown tool: {name}")]
        klass, entry = index[name]
        args = arguments or {}
        extra: list[str] = list(args.get("args") or [])
        if klass == "agent_authority":
            task_id = args.get("task_id")
            if not task_id:
                return [
                    TextContent(
                        type="text",
                        text=f"ERROR: tool {name!r} requires task_id (agent-authority class)",
                    )
                ]
            rc_f, out_f, err_f = _set_focus(fw_root, proj_root, task_id)
            if rc_f != 0:
                return [
                    TextContent(
                        type="text",
                        text=(
                            f"ERROR: focus set on {task_id} failed (rc={rc_f})\n"
                            f"{err_f or out_f}"
                        ),
                    )
                ]
        rc, out, err = _run_fw(fw_root, proj_root, entry["fw_command"], extra)
        return [TextContent(type="text", text=_format_result(rc, out, err))]

    return server


async def _serve() -> None:
    # T-2459: only re-emit the manifest when the source (tool-set.yaml) is
    # present — i.e. the framework repo / dev checkout. In a consumer the source
    # is not vendored, so we serve from the vendored manifest and must NOT crash
    # trying to emit from a file that isn't there.
    if tool_set_path().is_file():
        try:
            emit_manifest(tool_set=load_tool_set())
        except (FileNotFoundError, ValueError) as exc:
            sys.stderr.write(f"WARN: manifest emit skipped ({exc})\n")
    cat = load_catalogue()
    server = build_server(cat)
    init_opts = server.create_initialization_options()
    async with stdio_server() as (read, write):
        await server.run(read, write, init_opts)


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help", "help"):
        sys.stdout.write(
            "Usage: framework-mcp-server\n"
            "  Runs the framework MCP server on stdio transport.\n"
            "  Emits agents/mcp/framework-mcp-manifest.json on startup.\n"
        )
        return 0
    try:
        asyncio.run(_serve())
        return 0
    except KeyboardInterrupt:
        return 130
    except (FileNotFoundError, ValueError) as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
