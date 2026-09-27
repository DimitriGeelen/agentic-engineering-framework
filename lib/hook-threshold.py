#!/usr/bin/env python3
"""T-1631 (B-3b of T-1626) — hook-failure threshold rule.

Reads `$PROJECT_ROOT/.context/working/.hook-counter` and
`.hook-failure-counter` (produced by T-1628 / `lib/hook-telemetry.sh`),
sums duplicate keys defensively (concurrent-write race in
mapfile-based update can interleave entries — same key may appear
multiple times), and reports any hook whose failure ratio exceeds
threshold over a minimum sample size.

Defaults: MIN_FIRES=20, FAIL_RATIO=0.10. Override via
`FW_HOOK_THRESHOLD_MIN_FIRES` and `FW_HOOK_THRESHOLD_FAIL_RATIO`.

Modes:
  scan (default): emit machine-readable lines, one per hook over
    threshold: <hook>|<total>|<failures>|<ratio>
  --all: include every hook with stats (under threshold too)
  --register: scan + upsert a G-XXX entry into
    .context/project/concerns.yaml. Idempotent — skips if any OPEN
    entry already exists with tag `hook:<name>` under
    `hook-failure-threshold`. Reoccurrence after closure creates
    a fresh entry (humans manage closure transitions; the threshold
    rule's job is to surface, not arbitrate lifecycle).

Why a separate helper file (L-332): keep Python > ~10 lines out of
hot-path bash dispatchers. Heredocs inside command substitution
parse-error fragilely and bin/fw parse errors brick PreToolUse hooks.

Why append-textually instead of round-tripping concerns.yaml: the
file uses single-quoted strings with embedded newlines and human-
authored block-style indentation. PyYAML round-trip would reformat
existing entries; ruamel.yaml would preserve but adds a dep. Reading
to find next G-id + appending a textual block is the smallest-blast
option.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import yaml


HOOK_LINE_RE = re.compile(r"^([A-Za-z0-9_:.\-]+)=(\d+)\s*$")


def _read_counter(path: Path) -> dict[str, int]:
    """Sum counts per key. Defensive against duplicate keys / malformed lines."""
    counts: dict[str, int] = defaultdict(int)
    if not path.is_file():
        return counts
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return counts
    for line in text.splitlines():
        m = HOOK_LINE_RE.match(line)
        if not m:
            continue
        key, val = m.group(1), int(m.group(2))
        counts[key] += val
    return counts


def scan(
    project_root: Path,
    min_fires: int,
    fail_ratio: float,
    include_all: bool = False,
):
    """Yield (hook, total, failures, ratio) tuples."""
    fires = _read_counter(project_root / ".context/working/.hook-counter")
    failures = _read_counter(project_root / ".context/working/.hook-failure-counter")
    # Union of keys — failure-only hooks shouldn't disappear (rc=127 from missing
    # hook still records both fire and failure, but we union defensively).
    for hook in sorted(set(fires) | set(failures)):
        total = fires.get(hook, 0)
        fails = failures.get(hook, 0)
        if total <= 0:
            # No fires recorded — pure failure-counter ghost (shouldn't happen
            # given T-1628 records both on every fire). Skip.
            continue
        ratio = fails / total
        triggered = total >= min_fires and ratio >= fail_ratio
        if include_all or triggered:
            yield hook, total, fails, ratio, triggered


def _next_g_id(concerns_path: Path) -> str:
    """Next available G-XXX id by walking existing entries."""
    if not concerns_path.is_file():
        return "G-001"
    try:
        with concerns_path.open() as f:
            data = yaml.safe_load(f) or {}
    except (OSError, yaml.YAMLError):
        return "G-001"
    max_id = 0
    for entry in data.get("concerns", []) or []:
        gid = (entry or {}).get("id", "")
        m = re.match(r"^G-(\d+)$", str(gid))
        if m:
            max_id = max(max_id, int(m.group(1)))
    return f"G-{max_id + 1:03d}"


def _has_open_entry(concerns_path: Path, hook: str) -> bool:
    """True if an OPEN entry already exists for this hook under the
    hook-failure-threshold tag set."""
    if not concerns_path.is_file():
        return False
    try:
        with concerns_path.open() as f:
            data = yaml.safe_load(f) or {}
    except (OSError, yaml.YAMLError):
        return False
    closed_states = {"closed", "resolved", "mitigated"}
    hook_tag = f"hook:{hook}"
    for entry in data.get("concerns", []) or []:
        if not isinstance(entry, dict):
            continue
        tags = entry.get("tags") or []
        if not isinstance(tags, list):
            continue
        if "hook-failure-threshold" not in tags or hook_tag not in tags:
            continue
        if entry.get("status") not in closed_states:
            return True
    return False


def _append_concern(
    concerns_path: Path,
    hook: str,
    total: int,
    fails: int,
    ratio: float,
):
    """Append a new G-XXX entry textually. Idempotency must be checked
    by caller — this function is unconditional append."""
    gid = _next_g_id(concerns_path)
    today = datetime.now(timezone.utc).date().isoformat()
    pct = f"{ratio * 100:.1f}"
    block = f"""
- id: {gid}
  type: gap
  title: "Hook {hook!r} failing at {pct}% ({fails}/{total} fires) — auto-registered by T-1631"
  description: "Auto-registered by lib/hook-threshold.py (T-1631). The PreToolUse/PostToolUse hook {hook!r} has fired {total} times with {fails} non-clean exits ({pct}%). Telemetry source: .context/working/.hook-counter + .hook-failure-counter (T-1628). Threshold: total>={total} AND ratio>={ratio:.3f}. This is the T-1626 detection signal: the agent's hook is failing in production, not just on the /tmp probe. Investigate the hook directly; if it has decayed silently, run fw upgrade (regenerates absolute paths) or fw doctor for diagnosis."
  spec_reference: "lib/hook-threshold.py, lib/hook-telemetry.sh, .claude/settings.json"
  severity: medium
  trigger_fired: true
  trigger_event: "{today}: hook-threshold scan crossed default thresholds (min_fires=20, fail_ratio=0.10) for hook={hook}."
  what_works_now: "T-1628 telemetry records every hook fire/failure. T-1629 doctor probe catches resolution failures from /tmp. T-1630 SessionStart resume warning surfaces broken hooks at session start."
  what_remains: "Investigate why this specific hook is failing in production. Common causes: (1) bare-relative path under cd-drift (T-1626 witness — fw upgrade fixes), (2) missing dependency, (3) script bug that exits non-zero where it shouldn't."
  status: open
  created: {today}
  last_reviewed: {today}
  tags: [hook-failure-threshold, hook:{hook}]
  related_tasks: [T-1626, T-1628, T-1631]
"""
    with concerns_path.open("a") as f:
        f.write(block)
    return gid


def cmd_scan(args):
    project_root = Path(args.project_root)
    triggered = 0
    for hook, total, fails, ratio, was_triggered in scan(
        project_root, args.min_fires, args.fail_ratio, include_all=args.all
    ):
        if was_triggered:
            triggered += 1
        marker = "FAIL" if was_triggered else "ok"
        print(f"{marker}|{hook}|{total}|{fails}|{ratio:.4f}")
    return 1 if triggered > 0 and not args.all else 0


def cmd_register(args):
    project_root = Path(args.project_root)
    concerns_path = project_root / ".context/project/concerns.yaml"
    registered = 0
    skipped = 0
    for hook, total, fails, ratio, was_triggered in scan(
        project_root, args.min_fires, args.fail_ratio, include_all=False
    ):
        if not was_triggered:
            continue
        if _has_open_entry(concerns_path, hook):
            print(f"SKIP|{hook}|already-open")
            skipped += 1
            continue
        gid = _append_concern(concerns_path, hook, total, fails, ratio)
        print(f"REGISTERED|{hook}|{gid}")
        registered += 1
    print(f"summary|registered={registered}|skipped={skipped}")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument(
        "--project-root",
        default=os.environ.get("PROJECT_ROOT", os.getcwd()),
        help="Project root (default: $PROJECT_ROOT or cwd)",
    )
    p.add_argument(
        "--min-fires",
        type=int,
        default=int(os.environ.get("FW_HOOK_THRESHOLD_MIN_FIRES", "20")),
        help="Minimum total fires before threshold applies (default 20).",
    )
    p.add_argument(
        "--fail-ratio",
        type=float,
        default=float(os.environ.get("FW_HOOK_THRESHOLD_FAIL_RATIO", "0.10")),
        help="Failure ratio threshold (default 0.10 = 10%%).",
    )
    p.add_argument(
        "--all", action="store_true", help="Print every hook, not just those over threshold."
    )
    p.add_argument(
        "--register",
        action="store_true",
        help="Upsert G-XXX into concerns.yaml for hooks over threshold.",
    )
    args = p.parse_args(argv)

    if args.register:
        return cmd_register(args)
    return cmd_scan(args)


if __name__ == "__main__":
    sys.exit(main())
