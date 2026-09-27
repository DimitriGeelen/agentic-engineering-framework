#!/usr/bin/env python3
"""G-065 closure-readiness gauge — wiring-presence check.

G-065 fired in May 2026 against the project-boundary hook: the original
implementation blocked `cd /outside/...` but did NOT block Bash commands
whose ARGUMENTS pointed outside PROJECT_ROOT (e.g. `du /root/x`,
`find /root/x`, `grep -r ... /root/x`). The mechanical enforcement surface
was therefore narrower than the policy it claimed to enforce ("no
cross-project work without TermLink"). The fix legs:

  - T-1702 extended `agents/context/check-project-boundary.sh` with
    Pattern 4 — outside-path argument scanning + `READ_ALLOWED_PREFIXES`
    + `READ_ALLOWED_EXACT` allowlists for legitimate read targets
    (/tmp, /usr, /etc, etc).
  - T-1707 extended `bin/fw doctor` to tag findings by scope (project
    vs host) — `host_warnings` counter + `_scope_breakdown` summary
    so out-of-scope warnings are visually distinct and not bundled by
    agents into "housekeeping" lists.

Both legs landed but G-065 in `concerns.yaml` was never given a
machine-readable closure-readiness gauge, so the operator had no
actuation path through the T-2185 `/gaps` Close button.

This gauge proves both wirings are in place by structural inspection.
It does NOT exercise the hook end-to-end (that would couple closure to
hook-firing telemetry, which is volatile). Closure readiness is a
wiring question — behaviour is covered by hook self-tests and the
live `fw doctor` output the operator inspects when closing.

Four conditions must all hold for VERDICT=READY:

  1. `agents/context/check-project-boundary.sh` exists
  2. Hook references `Pattern 4` and `G-065` (the read-side
     outside-path argument leg from T-1702)
  3. Hook defines `READ_ALLOWED_PREFIXES` (the allowlist construct)
  4. `bin/fw` defines `host_warnings` AND `_scope_breakdown`
     (T-1707 doctor scope-tagging)

If any condition fails, VERDICT=NOT_READY. The operator can still
override via `fw gaps close G-065 --override --rationale "..."` per
the T-2185 refuse-path matrix.

Usage:
  python3 tools/g065-readiness.py            # human-readable
  python3 tools/g065-readiness.py --json     # machine-readable
  python3 tools/g065-readiness.py --strict   # exit 1 if not ready

Exit codes:
  0 = report emitted; readiness state shown
  1 = not ready AND --strict was passed
  2 = repository root not findable (PROJECT_ROOT unset and no .context/)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

BOUNDARY_HOOK_REL = "agents/context/check-project-boundary.sh"
FW_REL = "bin/fw"


def _project_root() -> Path:
    env = os.environ.get("PROJECT_ROOT")
    if env:
        return Path(env)
    here = Path(__file__).resolve()
    for parent in (here.parent, *here.parents):
        if (parent / ".context").is_dir():
            return parent
    return here.parents[1]


def _check_hook_exists(hook_path: Path) -> tuple[bool, str]:
    """Condition 1: boundary hook file exists."""
    if hook_path.is_file():
        return (True, f"found: {hook_path}")
    return (False, f"missing: {hook_path}")


def _check_pattern_4_comment(hook_path: Path) -> tuple[bool, str]:
    """Condition 2: hook references Pattern 4 + G-065 (T-1702 read-side leg)."""
    if not hook_path.is_file():
        return (False, f"missing: {hook_path}")
    text = hook_path.read_text()
    has_pattern_4 = bool(re.search(r"Pattern 4", text))
    has_g065 = "G-065" in text
    if has_pattern_4 and has_g065:
        return (True, "found: Pattern 4 + G-065 references (T-1702 read-side leg)")
    missing = []
    if not has_pattern_4:
        missing.append("'Pattern 4'")
    if not has_g065:
        missing.append("'G-065'")
    return (False, f"not found in hook: {', '.join(missing)}")


def _check_read_allowlist(hook_path: Path) -> tuple[bool, str]:
    """Condition 3: hook defines READ_ALLOWED_PREFIXES (allowlist construct)."""
    if not hook_path.is_file():
        return (False, f"missing: {hook_path}")
    text = hook_path.read_text()
    if re.search(r"^READ_ALLOWED_PREFIXES\s*=", text, re.MULTILINE):
        return (True, "found: READ_ALLOWED_PREFIXES = ... allowlist")
    return (False, "not found: READ_ALLOWED_PREFIXES allowlist definition")


def _check_doctor_scope_tagging(fw_path: Path) -> tuple[bool, str]:
    """Condition 4: bin/fw defines host_warnings + _scope_breakdown (T-1707)."""
    if not fw_path.is_file():
        return (False, f"missing: {fw_path}")
    text = fw_path.read_text()
    has_host_warnings = "host_warnings" in text
    has_scope_breakdown = "_scope_breakdown" in text
    if has_host_warnings and has_scope_breakdown:
        return (True, "found: host_warnings + _scope_breakdown (T-1707 scope-tag)")
    missing = []
    if not has_host_warnings:
        missing.append("'host_warnings'")
    if not has_scope_breakdown:
        missing.append("'_scope_breakdown'")
    return (False, f"not found in bin/fw: {', '.join(missing)}")


def assess(project_root: Path) -> dict:
    hook_path = project_root / BOUNDARY_HOOK_REL
    fw_path = project_root / FW_REL

    checks = [
        ("boundary_hook_exists", _check_hook_exists(hook_path)),
        ("pattern_4_comment", _check_pattern_4_comment(hook_path)),
        ("read_allowlist", _check_read_allowlist(hook_path)),
        ("doctor_scope_tagging", _check_doctor_scope_tagging(fw_path)),
    ]
    passing = [name for name, (ok, _detail) in checks if ok]
    failing = [name for name, (ok, _detail) in checks if not ok]
    ready = len(failing) == 0
    return {
        "gap_id": "G-065",
        "project_root": str(project_root),
        "checks": [
            {"name": name, "ok": ok, "detail": detail}
            for name, (ok, detail) in checks
        ],
        "passing": passing,
        "failing": failing,
        "passing_count": len(passing),
        "total_count": len(checks),
        "ready": ready,
        "verdict": "READY" if ready else "NOT_READY",
    }


def render_human(a: dict) -> str:
    lines = []
    lines.append("G-065 closure-readiness gauge")
    lines.append("=" * 32)
    lines.append("Boundary-hook arg-scan + doctor scope-tag wiring (T-1702 / T-1707).")
    lines.append(f"Project root: {a['project_root']}")
    lines.append("")
    lines.append(f"Conditions: {a['passing_count']}/{a['total_count']} passing")
    lines.append("")
    for c in a["checks"]:
        status = "PASS" if c["ok"] else "FAIL"
        lines.append(f"  [{status}] {c['name']}: {c['detail']}")
    lines.append("")
    if a["ready"]:
        lines.append("VERDICT: READY -- all four wiring conditions hold.")
        lines.append(
            "Action: human can close G-065 via Watchtower /gaps Close button "
            "(T-2185 surface) or `fw gaps close G-065`."
        )
    else:
        lines.append(
            f"VERDICT: NOT_READY -- {len(a['failing'])} condition(s) failing: "
            f"{', '.join(a['failing'])}."
        )
        lines.append(
            "Action: address the failing wiring leg(s), or override via "
            "`fw gaps close G-065 --override --rationale '...'` if the gap "
            "is being closed for a reason other than the wiring itself."
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true", help="emit JSON instead of human text")
    parser.add_argument("--strict", action="store_true", help="exit 1 if not ready")
    parser.add_argument(
        "--project-root",
        default=None,
        help="override project root (default: PROJECT_ROOT env or auto-discovery)",
    )
    args = parser.parse_args(argv)

    if args.project_root:
        root = Path(args.project_root)
    else:
        root = _project_root()

    if not (root / ".context").is_dir():
        msg = {"error": "project root has no .context/ directory", "path": str(root)}
        if args.json:
            print(json.dumps(msg))
        else:
            print(f"ERROR: {msg['error']}: {root}", file=sys.stderr)
        return 2

    a = assess(root)
    if args.json:
        print(json.dumps(a, indent=2))
    else:
        print(render_human(a))

    if args.strict and not a["ready"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
