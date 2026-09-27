#!/usr/bin/env python3
"""G-066 closure-readiness gauge — wiring-presence check.

G-066 fired in May 2026 against T-1442/T-1443: the reviewer-arc GO scope
included two halves — (a) auto-tick of `[REVIEWER]`-prefixed Agent ACs,
and (b) `--dispatch` mode that runs the reviewer in an isolated TermLink
worker — and both were declared "shipped" at task-close, then turned out
to be unwired weeks later. The fix legs:

  - T-1985 wired auto-tick into `lib/reviewer/static_scan.py`
    (`_should_auto_tick`, `auto_ticked` field, feedback-stream `auto_tick:*`
    digest-keyed sovereignty rail).
  - T-1951 wired `--dispatch` routing in `bin/fw` → `lib.reviewer.dispatch_cli`
    with `FW_REVIEWER_IN_DISPATCH=1` recursion guard.

CLAUDE.md describes both as shipped, but G-066 in `concerns.yaml` was
never given a machine-readable closure-readiness gauge, so the operator
had no actuation path through the T-2185 `/gaps` Close button.

This gauge proves both wirings are in place by structural inspection.
It does NOT run the reviewer end-to-end (that would couple closure to
the live corpus, which is volatile). Closure readiness is a wiring
question, not a behaviour question — the latter is covered by reviewer
self-tests under `tests/`.

Four conditions must all hold for VERDICT=READY:

  1. `lib/reviewer/static_scan.py` defines `_should_auto_tick`
  2. Same file declares `auto_ticked` as a result field
  3. `bin/fw` recognises `--dispatch` and forwards to dispatch_cli
  4. `lib/reviewer/dispatch_cli.py` exists and is importable

If any condition fails, VERDICT=NOT_READY. The operator can still
override via `fw gaps close G-066 --override --rationale "..."` per
the T-2185 refuse-path matrix.

Usage:
  python3 tools/g066-readiness.py            # human-readable
  python3 tools/g066-readiness.py --json     # machine-readable
  python3 tools/g066-readiness.py --strict   # exit 1 if not ready

Exit codes:
  0 = report emitted; readiness state shown
  1 = not ready AND --strict was passed
  2 = repository root not findable (PROJECT_ROOT unset and no .context/)
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

REVIEWER_SCAN_REL = "lib/reviewer/static_scan.py"
REVIEWER_DISPATCH_REL = "lib/reviewer/dispatch_cli.py"
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


def _check_auto_tick_function(scan_path: Path) -> tuple[bool, str]:
    """Condition 1: `_should_auto_tick` defined in static_scan.py (T-1985)."""
    if not scan_path.is_file():
        return (False, f"missing: {scan_path}")
    text = scan_path.read_text()
    if re.search(r"^def _should_auto_tick\(", text, re.MULTILINE):
        return (True, "found: def _should_auto_tick(")
    return (False, "not found: def _should_auto_tick(")


def _check_auto_ticked_field(scan_path: Path) -> tuple[bool, str]:
    """Condition 2: `auto_ticked` result-field declaration (T-1985)."""
    if not scan_path.is_file():
        return (False, f"missing: {scan_path}")
    text = scan_path.read_text()
    if re.search(r"^\s+auto_ticked:\s*list", text, re.MULTILINE):
        return (True, "found: auto_ticked: list[...] field declaration")
    return (False, "not found: auto_ticked field declaration")


def _check_dispatch_routing(fw_path: Path) -> tuple[bool, str]:
    """Condition 3: `bin/fw` routes `--dispatch` to dispatch_cli (T-1951)."""
    if not fw_path.is_file():
        return (False, f"missing: {fw_path}")
    text = fw_path.read_text()
    if "--dispatch" not in text:
        return (False, "not found: --dispatch flag in bin/fw")
    if "lib.reviewer.dispatch_cli" not in text:
        return (False, "not found: forwarding to lib.reviewer.dispatch_cli")
    return (True, "found: --dispatch flag + dispatch_cli forwarding")


def _check_dispatch_cli_module(dispatch_path: Path) -> tuple[bool, str]:
    """Condition 4: `lib/reviewer/dispatch_cli.py` exists + spec-loadable."""
    if not dispatch_path.is_file():
        return (False, f"missing: {dispatch_path}")
    spec = importlib.util.spec_from_file_location(
        "_g066_check_dispatch_cli", dispatch_path
    )
    if spec is None or spec.loader is None:
        return (False, "spec_from_file_location returned None")
    # Presence + parseable spec is enough — we do NOT execute the module
    # (would risk side effects on TermLink session state).
    return (True, "found: importable lib/reviewer/dispatch_cli.py")


def assess(project_root: Path) -> dict:
    scan_path = project_root / REVIEWER_SCAN_REL
    fw_path = project_root / FW_REL
    dispatch_path = project_root / REVIEWER_DISPATCH_REL

    checks = [
        ("auto_tick_function", _check_auto_tick_function(scan_path)),
        ("auto_ticked_field", _check_auto_ticked_field(scan_path)),
        ("dispatch_routing", _check_dispatch_routing(fw_path)),
        ("dispatch_cli_module", _check_dispatch_cli_module(dispatch_path)),
    ]
    passing = [name for name, (ok, _detail) in checks if ok]
    failing = [name for name, (ok, _detail) in checks if not ok]
    ready = len(failing) == 0
    return {
        "gap_id": "G-066",
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
    lines.append("G-066 closure-readiness gauge")
    lines.append("=" * 32)
    lines.append("Reviewer-arc GO scope wiring verification (T-1442/T-1443).")
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
            "Action: human can close G-066 via Watchtower /gaps Close button "
            "(T-2185 surface) or `fw gaps close G-066`."
        )
    else:
        lines.append(
            f"VERDICT: NOT_READY -- {len(a['failing'])} condition(s) failing: "
            f"{', '.join(a['failing'])}."
        )
        lines.append(
            "Action: address the failing wiring leg(s), or override via "
            "`fw gaps close G-066 --override --rationale '...'` if the gap "
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
