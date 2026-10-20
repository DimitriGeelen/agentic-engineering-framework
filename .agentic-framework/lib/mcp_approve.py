#!/usr/bin/env python3
"""Pre-approve the framework's own MCP servers for Claude Code (T-3715).

`fw upgrade` / `fw init` add servers to `.mcp.json`. Claude Code starts a
project-scoped server without asking only when its name is listed in
`enabledMcpjsonServers` (or `enableAllProjectMcpServers` is true) in a
settings file; otherwise a restarted session stops on the interactive
"New MCP server found" prompt, and an autonomous fleet agent hangs there
silently. This writes the approval into `.claude/settings.local.json`, the
same file Claude Code writes when a human answers that prompt.

Rules:
  - only FRAMEWORK servers present in .mcp.json are approved; a consumer's
    own servers stay the operator's call
  - a server listed in `disabledMcpjsonServers` is never approved (the
    operator said no); it is reported so the upgrade can say so
  - `enableAllProjectMcpServers: true` already approves everything: no-op
  - every other key in settings.local.json is preserved

Usage: mcp_approve.py <project_dir> [--dry-run]
Prints one line:  APPROVED a,b | DISABLED c | ALL | NONE | ERROR <why>
(several parts joined with "; ", e.g. "APPROVED fw; DISABLED playwright").
Exit 0 except on usage error.
"""
import json
import os
import sys

FRAMEWORK_SERVERS = ("context7", "playwright", "termlink", "fw")


def _servers(mcp_path):
    with open(mcp_path) as f:
        raw = json.load(f)
    if not isinstance(raw, dict):
        return {}
    s = raw.get("mcpServers") if isinstance(raw.get("mcpServers"), dict) else raw
    return s if isinstance(s, dict) else {}


def approve(project_dir, dry_run=False):
    mcp_path = os.path.join(project_dir, ".mcp.json")
    local_path = os.path.join(project_dir, ".claude", "settings.local.json")
    if not os.path.isfile(mcp_path):
        return "NONE"
    try:
        servers = _servers(mcp_path)
    except (ValueError, OSError) as e:
        return f"ERROR .mcp.json unreadable: {e}"

    settings = {}
    if os.path.isfile(local_path):
        try:
            with open(local_path) as f:
                settings = json.load(f)
        except (ValueError, OSError) as e:
            return f"ERROR settings.local.json unreadable: {e}"
        if not isinstance(settings, dict):
            return "ERROR settings.local.json is not a JSON object"

    if settings.get("enableAllProjectMcpServers") is True:
        return "ALL"

    enabled = settings.get("enabledMcpjsonServers")
    enabled = list(enabled) if isinstance(enabled, list) else []
    disabled = settings.get("disabledMcpjsonServers")
    disabled = disabled if isinstance(disabled, list) else []

    added, refused = [], []
    for name in FRAMEWORK_SERVERS:
        if name not in servers:
            continue
        if name in disabled:
            refused.append(name)
        elif name not in enabled:
            enabled.append(name)
            added.append(name)

    if added and not dry_run:
        settings["enabledMcpjsonServers"] = enabled
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        tmp = local_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(settings, f, indent=2)
            f.write("\n")
        os.replace(tmp, local_path)

    parts = []
    if added:
        parts.append("APPROVED " + ",".join(added))
    if refused:
        parts.append("DISABLED " + ",".join(refused))
    return "; ".join(parts) or "NONE"


def main(argv):
    args = [a for a in argv[1:] if a != "--dry-run"]
    if len(args) != 1:
        print("Usage: mcp_approve.py <project_dir> [--dry-run]", file=sys.stderr)
        return 2
    print(approve(args[0], dry_run="--dry-run" in argv[1:]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
