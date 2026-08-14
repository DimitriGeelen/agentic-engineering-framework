#!/usr/bin/env python3
"""T-2193: One-shot migration — backfill target_blast_radius + voi_score on existing inceptions.

After T-2188 shipped the inception frontmatter schema, existing inceptions
(390 at landing time) lacked the new fields. The PreToolUse hook
check-inception-schema only fires on Write/Edit, so on-disk inceptions
remain valid until next edited — but the BVP estimator (T-2189) can't rank
them. This script backfills both fields with sane defaults:

  target_blast_radius: 3   (M = small-subsystem floor; conservative)
  voi_score: 0.5           (medium value of information; conservative)

Defaults are intentionally mid-range so human review can refine.

Usage:
  python3 tools/migrate-inception-schema.py --dry-run     # default: report only
  python3 tools/migrate-inception-schema.py --apply       # write changes
  python3 tools/migrate-inception-schema.py --report-file PATH  # save dry-run output

Origin: T-2186 inception recalibration arc, Slice 7.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", "/opt/999-Agentic-Engineering-Framework"))
DEFAULT_TBR = 3
DEFAULT_VOI = 0.5


def find_inception_tasks(root: Path) -> list[Path]:
    """Return all inception task files in active/ + completed/."""
    paths: list[Path] = []
    for sub in ("active", "completed"):
        d = root / ".tasks" / sub
        if not d.is_dir():
            continue
        for p in sorted(d.glob("T-*.md")):
            try:
                head = p.read_text(encoding="utf-8")[:4096]
            except (OSError, UnicodeDecodeError):
                continue
            if re.search(r"^workflow_type:\s*inception\s*$", head, re.MULTILINE):
                paths.append(p)
    return paths


def has_field(text: str, field: str) -> bool:
    """Check frontmatter (between first --- ... ---) for a top-level key."""
    if not text.startswith("---\n"):
        return False
    end = text.find("\n---\n", 4)
    if end == -1:
        return False
    fm = text[4:end]
    return bool(re.search(rf"^{re.escape(field)}\s*:", fm, re.MULTILINE))


def insert_fields(text: str, tbr: int, voi: float) -> str:
    """Insert target_blast_radius + voi_score before closing '---' of frontmatter.

    Idempotent: only inserts fields that don't already exist. Keeps the rest
    of the frontmatter intact (preserving comments, ordering, etc.).
    """
    if not text.startswith("---\n"):
        return text
    end = text.find("\n---\n", 4)
    if end == -1:
        return text

    fm = text[4:end]
    body = text[end + 5 :]  # skip past '\n---\n'

    additions: list[str] = []
    if not re.search(r"^target_blast_radius\s*:", fm, re.MULTILINE):
        additions.append(f"target_blast_radius: {tbr}   # T-2193 migration default (M=small-subsystem floor)")
    if not re.search(r"^voi_score\s*:", fm, re.MULTILINE):
        additions.append(f"voi_score: {voi}            # T-2193 migration default (medium)")

    if not additions:
        return text

    # Insert after the last non-blank line of frontmatter so trailing comments stay attached.
    fm_clean = fm.rstrip("\n")
    new_fm = fm_clean + "\n" + "\n".join(additions) + "\n"
    return "---\n" + new_fm + "---\n" + body


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="Write changes to disk (default: dry-run)")
    parser.add_argument("--dry-run", action="store_true", help="Report only — no writes (default mode)")
    parser.add_argument("--report-file", type=Path, default=None, help="Save report to file (in addition to stdout)")
    parser.add_argument("--tbr", type=int, default=DEFAULT_TBR, help=f"Default target_blast_radius (default: {DEFAULT_TBR})")
    parser.add_argument("--voi", type=float, default=DEFAULT_VOI, help=f"Default voi_score (default: {DEFAULT_VOI})")
    args = parser.parse_args()

    if args.apply and args.dry_run:
        print("ERROR: --apply and --dry-run are mutually exclusive", file=sys.stderr)
        return 2

    mode = "APPLY" if args.apply else "DRY-RUN"

    paths = find_inception_tasks(PROJECT_ROOT)
    lines: list[str] = [
        f"T-2193 inception schema migration — mode: {mode}",
        f"PROJECT_ROOT: {PROJECT_ROOT}",
        f"Defaults: target_blast_radius={args.tbr}, voi_score={args.voi}",
        f"Inception tasks found: {len(paths)}",
        "",
    ]

    already_set = 0
    needs_backfill = 0
    applied = 0
    backfilled_files: list[Path] = []

    for p in paths:
        try:
            text = p.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        has_tbr = has_field(text, "target_blast_radius")
        has_voi = has_field(text, "voi_score")
        if has_tbr and has_voi:
            already_set += 1
            continue
        needs_backfill += 1
        backfilled_files.append(p)
        if args.apply:
            new_text = insert_fields(text, args.tbr, args.voi)
            if new_text != text:
                p.write_text(new_text, encoding="utf-8")
                applied += 1

    lines.append(f"already-set: {already_set}")
    lines.append(f"needs-backfill: {needs_backfill}")
    if args.apply:
        lines.append(f"applied: {applied}")
    lines.append("")
    if needs_backfill and not args.apply:
        lines.append("Files needing backfill (sample, up to 20):")
        for p in backfilled_files[:20]:
            lines.append(f"  {p.relative_to(PROJECT_ROOT)}")
        if len(backfilled_files) > 20:
            lines.append(f"  ... and {len(backfilled_files) - 20} more")
    elif args.apply and applied:
        lines.append("Files modified:")
        for p in backfilled_files:
            lines.append(f"  {p.relative_to(PROJECT_ROOT)}")

    report = "\n".join(lines)
    print(report)
    if args.report_file:
        args.report_file.parent.mkdir(parents=True, exist_ok=True)
        args.report_file.write_text(report + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    sys.exit(main())
