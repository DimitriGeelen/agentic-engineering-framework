#!/usr/bin/env python3
"""Publishing to Anthropic is blocked by default in every AEF project (T-5405).

Operator ruling 2026-11-24: claude.ai artifacts, Claude Docs and design sync are BLOCKED BY
DEFAULT; the project's operator can switch it off (config PUBLISH_TO_ANTHROPIC=allow) or
approve one use. Origin: an agent published an operator's personal data to a claude.ai
artifact (G-140, 050-email-archive).

Two layers: (1) seven `permissions.deny` entries in .claude/settings.json, which remove the
tools outright (written by fw init / fw upgrade); (2) the egress gate class `forbidden`
(lib/mcp_egress.py) for the two MCP servers, which a project without the deny rules still hits.

Verbs: ensure (add/remove the deny entries per the key), state, audit (TAB lines),
guard-set (refuse `allow` under agent control; used by `fw config set`).
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path

_LIB = os.path.dirname(os.path.abspath(__file__))
if _LIB not in sys.path:
    sys.path.insert(0, _LIB)

KEY = "PUBLISH_TO_ANTHROPIC"
RULING = "operator ruling 2026-11-24, T-5405"
TOOLS = ("Artifact", "ArtifactComments", "ArtifactData", "ArtifactCheck", "DesignSync",
         "mcp__claude-artifacts", "mcp__claude_ai_Claude_Docs")


def _proj() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def mode(proj: Path | None = None) -> str:
    """deny (default) | allow. Env FW_PUBLISH_TO_ANTHROPIC, then .framework.yaml."""
    v = os.environ.get("FW_" + KEY, "").strip().lower()
    if not v:
        try:
            import yaml
            d = yaml.safe_load(((proj or _proj()) / ".framework.yaml").read_text()) or {}
            v = str(d.get(KEY, "") if isinstance(d, dict) else "").strip().lower()
        except Exception:
            v = ""
    return "allow" if v == "allow" else "deny"


def _load(path: Path):
    try:
        d = json.loads(path.read_text())
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        raise ValueError("unparseable")
    if not isinstance(d, dict):
        raise ValueError("not an object")
    return d


def present(settings: Path) -> list[str]:
    try:
        d = _load(settings) or {}
    except ValueError:
        return []
    deny = (d.get("permissions") or {}).get("deny") or []
    return [t for t in TOOLS if t in deny]


def ensure(settings: Path, m: str) -> tuple[str, list[str]]:
    """Make permissions.deny match mode `m`. Returns (action, changed tools); action is one of
    none / added / removed / skipped (no file, or unparseable). Keeps every other key and entry;
    idempotent; atomic write."""
    try:
        d = _load(settings)
    except ValueError:
        return "skipped", []
    if d is None:
        return "skipped", []
    perms = d.get("permissions")
    if not isinstance(perms, dict):
        perms = {}
    deny = perms.get("deny")
    deny = list(deny) if isinstance(deny, list) else []
    if m == "allow":
        changed = [t for t in TOOLS if t in deny]
        new = [x for x in deny if x not in TOOLS]
        action = "removed"
    else:
        changed = [t for t in TOOLS if t not in deny]
        new = deny + changed
        action = "added"
    if not changed:
        return "none", []
    perms["deny"] = new
    if m == "allow" and not new:
        perms.pop("deny")
    if perms:
        d["permissions"] = perms
    else:
        d.pop("permissions", None)
    fd, tmp = tempfile.mkstemp(dir=str(settings.parent), prefix=".settings-")
    with os.fdopen(fd, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    os.replace(tmp, settings)
    return action, changed


def audit_lines(proj: Path | None = None) -> list[tuple[str, str]]:
    proj = proj or _proj()
    m = mode(proj)
    have = present(proj / ".claude" / "settings.json")
    if m == "allow":
        import datetime
        try:
            when = datetime.date.fromtimestamp((proj / ".framework.yaml").stat().st_mtime).isoformat()
            when = f", .framework.yaml last changed {when}"
        except OSError:
            when = ""
        return [("PASS", f"publishing to Anthropic: allowed by operator ({KEY}=allow{when}; "
                         "the default is blocked)")]
    if len(have) == len(TOOLS):
        return [("PASS", f"publishing to Anthropic: blocked (default; {len(TOOLS)} deny rules in "
                         ".claude/settings.json)")]
    missing = [t for t in TOOLS if t not in have]
    return [("FAIL", f"publishing to Anthropic: NOT blocked (rules missing: {', '.join(missing)}). "
                     f"Fix: fw upgrade (writes them); or {KEY}=allow if the operator wants it on")]


def guard_set(value: str) -> int:
    """`fw config set PUBLISH_TO_ANTHROPIC allow` is the operator's act."""
    if value.strip().lower() != "allow":
        return 0
    try:
        from mcp_egress import _is_agent
    except Exception:
        _is_agent = lambda: True  # noqa: E731  fail closed
    if _is_agent():
        sys.stderr.write(
            f"REFUSED: setting {KEY}=allow switches publishing to Anthropic on. That is the "
            f"operator's choice ({RULING}); it is never made under agent control "
            "(CLAUDECODE/AI_AGENT/CLAUDE_CODE_ENTRYPOINT set, or a Claude process is an ancestor). "
            "Ask the operator to run it in their own terminal.\n")
        return 2
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else ""
    if cmd == "ensure":
        action, changed = ensure(Path(argv[1]), argv[2] if len(argv) > 2 else mode())
        print(f"{action}\t{','.join(changed)}")
        return 0
    if cmd == "mode":
        print(mode())
        return 0
    if cmd == "audit":
        for lvl, msg in audit_lines():
            print(f"{lvl}\t{msg}")
        return 0
    if cmd == "guard-set":
        return guard_set(argv[1] if len(argv) > 1 else "")
    sys.stderr.write("usage: publish_ban.py ensure <settings.json> [deny|allow] | mode | audit | guard-set <value>\n")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
