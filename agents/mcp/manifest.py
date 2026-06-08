#!/usr/bin/env python3
# T-2265 (arc-010 Slice 2): manifest emission for the framework MCP server.
#
# Single source of truth: policy/capability-overlay/tool-set.yaml.
# Output contract (T-2260 probe_framework_tools at agents/audit/orchestrator-mcp-scan.sh:100):
#   {"tools": [{"name": "<verb>", "gated": <bool>}, ...]}
#
# read_only entries  → gated: false
# agent_authority    → gated: true (task_id required at MCP schema layer)
# sovereignty_bound_excluded → NEVER emitted (foreclosed per tool-set.yaml §3)
"""Framework MCP manifest emission."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import yaml


def _project_root() -> Path:
    env_root = os.environ.get("FRAMEWORK_ROOT") or os.environ.get("PROJECT_ROOT")
    if env_root:
        return Path(env_root).resolve()
    here = Path(__file__).resolve()
    for parent in (here, *here.parents):
        if (parent / "bin" / "fw").exists() and (parent / "policy").is_dir():
            return parent
    return Path.cwd().resolve()


def tool_set_path(root: Path | None = None) -> Path:
    return (root or _project_root()) / "policy" / "capability-overlay" / "tool-set.yaml"


def manifest_path(root: Path | None = None) -> Path:
    return (root or _project_root()) / "agents" / "mcp" / "framework-mcp-manifest.json"


def load_tool_set(path: Path | None = None) -> dict[str, Any]:
    p = path or tool_set_path()
    if not p.is_file():
        raise FileNotFoundError(f"tool-set.yaml not found at {p}")
    with p.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"tool-set.yaml must be a mapping, got {type(data).__name__}")
    for key in ("read_only", "agent_authority"):
        if key not in data:
            raise ValueError(f"tool-set.yaml missing required key: {key}")
        if not isinstance(data[key], list):
            raise ValueError(f"tool-set.yaml key {key!r} must be a list")
    return data


def build_manifest(tool_set: dict[str, Any]) -> dict[str, Any]:
    tools: list[dict[str, Any]] = []
    for entry in tool_set.get("read_only", []):
        tools.append({"name": entry["name"], "gated": False})
    for entry in tool_set.get("agent_authority", []):
        tools.append({"name": entry["name"], "gated": True})
    return {
        "version": 1,
        "source": "policy/capability-overlay/tool-set.yaml",
        "source_version": tool_set.get("version"),
        "filed_by": tool_set.get("filed_by"),
        "arc_id": tool_set.get("arc_id"),
        "tools": tools,
    }


def emit_manifest(
    target: Path | None = None,
    *,
    tool_set: dict[str, Any] | None = None,
) -> Path:
    ts = tool_set if tool_set is not None else load_tool_set()
    manifest = build_manifest(ts)
    out = target or manifest_path()
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")
    return out


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help", "help"):
        sys.stdout.write(
            "Usage: framework-mcp-manifest [emit|show]\n"
            "  emit  Read policy/capability-overlay/tool-set.yaml, write\n"
            "        agents/mcp/framework-mcp-manifest.json.\n"
            "  show  Print manifest JSON to stdout (no file write).\n"
        )
        return 0
    cmd = argv[0] if argv else "emit"
    try:
        if cmd == "emit":
            out = emit_manifest()
            sys.stdout.write(f"Wrote {out}\n")
            return 0
        if cmd == "show":
            ts = load_tool_set()
            json.dump(build_manifest(ts), sys.stdout, indent=2)
            sys.stdout.write("\n")
            return 0
        sys.stderr.write(f"ERROR: unknown command: {cmd}\n")
        return 2
    except (FileNotFoundError, ValueError) as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
