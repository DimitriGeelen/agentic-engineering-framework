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


def framework_root() -> Path:
    """Where the framework's own assets live (bin/fw, agents/, policy/).

    Deterministic from this file's location: manifest.py lives at
    ``<framework_root>/agents/mcp/manifest.py`` so the root is ``parents[2]``.
    In the framework repo that's /opt/999…; in a consumer it's the vendored
    ``.agentic-framework/`` dir. ``FRAMEWORK_ROOT`` env overrides (tests, CI).

    T-2459 (arc-010 slice 1C): split out from the old ``_project_root()`` which
    conflated asset-location with the project ``fw`` should operate on. Asset
    paths (manifest, tool-set) resolve against THIS root; the operating dir is
    ``project_root()`` below.
    """
    env_root = os.environ.get("FRAMEWORK_ROOT")
    if env_root:
        return Path(env_root).resolve()
    return Path(__file__).resolve().parents[2]


def project_root() -> Path:
    """The project ``fw`` should operate on (the subprocess cwd).

    Derived from :func:`framework_root`: when the framework is vendored into a
    consumer (root dir named ``.agentic-framework``), the project is its parent
    — the consumer checkout. In the framework repo the two coincide.
    ``PROJECT_ROOT`` env overrides.

    T-2459: this is the fix for the consumer-breakage class (T-1633) — the
    framework repo never exposed the conflation because project == framework ==
    cwd there, but in a consumer ``fw`` must run against the consumer checkout,
    not the vendored ``.agentic-framework/`` dir (else tasks/notes/focus land in
    the wrong place).
    """
    env_root = os.environ.get("PROJECT_ROOT")
    if env_root:
        return Path(env_root).resolve()
    fr = framework_root()
    if fr.name == ".agentic-framework":
        return fr.parent
    return fr


# Backward-compat alias. Historic callers used `_project_root()` for ASSET
# paths (manifest/tool-set), so it maps to framework_root(). Callers that need
# the operating dir (subprocess cwd) must use project_root() explicitly.
_project_root = framework_root


def tool_set_path(root: Path | None = None) -> Path:
    return (root or framework_root()) / "policy" / "capability-overlay" / "tool-set.yaml"


def manifest_path(root: Path | None = None) -> Path:
    return (root or framework_root()) / "agents" / "mcp" / "framework-mcp-manifest.json"


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


def _manifest_tool(entry: dict[str, Any], *, gated: bool) -> dict[str, Any]:
    # name + gated FIRST so the scanner contract (orchestrator-mcp-scan.sh
    # reads only t['name'] and t.get('gated')) is satisfied and the diff stays
    # minimal. fw_command + description are ADDITIVE (T-2459) — they make the
    # manifest a self-contained runtime catalogue so a consumer that never
    # vendored policy/tool-set.yaml can still drive the server.
    # .get (not []) for fw_command: a well-formed tool-set entry always carries
    # it, but build_manifest must not crash on a malformed/partial entry — e.g.
    # the drift-test (t2293:t2) appends {name, rationale} to force a diff. An
    # empty fw_command still changes the emitted manifest (→ drift detected) and
    # is caught loudly downstream by _catalogue_from_manifest at server build.
    return {
        "name": entry["name"],
        "gated": gated,
        "fw_command": entry.get("fw_command") or "",
        "description": (entry.get("description") or "").strip(),
    }


def build_manifest(tool_set: dict[str, Any]) -> dict[str, Any]:
    tools: list[dict[str, Any]] = []
    for entry in tool_set.get("read_only", []):
        tools.append(_manifest_tool(entry, gated=False))
    for entry in tool_set.get("agent_authority", []):
        tools.append(_manifest_tool(entry, gated=True))
    return {
        "version": 1,
        "source": "policy/capability-overlay/tool-set.yaml",
        "source_version": tool_set.get("version"),
        "filed_by": tool_set.get("filed_by"),
        "arc_id": tool_set.get("arc_id"),
        "tools": tools,
    }


def _catalogue_from_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    """Reconstruct the {read_only:[...], agent_authority:[...]} catalogue shape
    from an enriched manifest, so the server consumes one shape regardless of
    source. Requires fw_command per tool (T-2459 enrichment); a pre-enrichment
    manifest raises so the failure is loud, not a silently broken server."""
    read_only: list[dict[str, Any]] = []
    agent_authority: list[dict[str, Any]] = []
    for tool in manifest.get("tools", []):
        if "fw_command" not in tool:
            raise ValueError(
                f"manifest tool {tool.get('name')!r} lacks fw_command — "
                "stale manifest; regenerate via `fw mcp emit-manifest`"
            )
        entry = {
            "name": tool["name"],
            "fw_command": tool["fw_command"],
            "description": tool.get("description", ""),
        }
        (agent_authority if tool.get("gated") else read_only).append(entry)
    return {
        "read_only": read_only,
        "agent_authority": agent_authority,
        "version": manifest.get("source_version"),
        "filed_by": manifest.get("filed_by"),
        "arc_id": manifest.get("arc_id"),
    }


def load_catalogue(root: Path | None = None) -> dict[str, Any]:
    """Load the tool catalogue the MCP server registers from.

    Prefers ``policy/capability-overlay/tool-set.yaml`` (richest source, present
    in the framework repo / dev checkout); falls back to the vendored
    ``agents/mcp/framework-mcp-manifest.json`` (the consumer case, where policy/
    is not vendored). Returns the same {read_only, agent_authority} shape from
    either source. T-2459 (arc-010 slice 1C)."""
    fr = root or framework_root()
    ts_path = tool_set_path(fr)
    if ts_path.is_file():
        return load_tool_set(ts_path)
    mf_path = manifest_path(fr)
    if mf_path.is_file():
        with mf_path.open("r", encoding="utf-8") as fh:
            return _catalogue_from_manifest(json.load(fh))
    raise FileNotFoundError(
        f"no tool catalogue: neither {ts_path} (source) nor {mf_path} "
        "(vendored manifest) is present"
    )


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


def _check_drift() -> int:
    """T-2293: exit-code drift check for CI / pre-commit / scripts.

    Re-emit the manifest in memory, md5-compare to the on-disk file:
      0 → in sync
      1 → drift (regenerate via emit)
      2 → manifest absent or unreadable
    Sibling to `fw vendor self --dry-run` (T-2240) and the `fw doctor`
    content-compare branch (T-2290).
    """
    import hashlib
    target = manifest_path()
    if not target.exists():
        sys.stderr.write(f"ABSENT: {target} — run `fw mcp emit-manifest`\n")
        return 2
    try:
        on_disk = target.read_bytes()
    except OSError as exc:
        sys.stderr.write(f"ABSENT: cannot read {target} ({exc})\n")
        return 2
    ts = load_tool_set()
    manifest = build_manifest(ts)
    emitted = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    if hashlib.md5(on_disk).hexdigest() == hashlib.md5(emitted).hexdigest():
        sys.stdout.write(f"OK: manifest in sync ({len(manifest.get('tools', []))} tools)\n")
        return 0
    sys.stderr.write("DRIFT: manifest differs from tool-set.yaml — regenerate via `fw mcp emit-manifest`\n")
    return 1


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help", "help"):
        sys.stdout.write(
            "Usage: framework-mcp-manifest [emit|show|check]\n"
            "  emit   Read policy/capability-overlay/tool-set.yaml, write\n"
            "         agents/mcp/framework-mcp-manifest.json.\n"
            "  show   Print manifest JSON to stdout (no file write).\n"
            "  check  Exit 0 (sync), 1 (drift), or 2 (absent) — for CI/pre-commit.\n"
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
        if cmd == "check":
            return _check_drift()
        sys.stderr.write(f"ERROR: unknown command: {cmd}\n")
        return 2
    except (FileNotFoundError, ValueError) as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
