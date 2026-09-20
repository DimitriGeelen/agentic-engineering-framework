#!/usr/bin/env python3
"""port3000_hygiene.py — set-level classifier + ratchet for port-3000 hardcodes (T-2894).

T-2732 gave the framework a PER-ITEM close gate (`lib/verification-port.sh:
find_port_literals`) that refuses a task's `## Verification` block if it
contains a hard-coded `localhost:3000`/`127.0.0.1:3000` literal with no port
resolution on the same line. That gate fires once per task close — it says
nothing about the population of literals already in the repo, and it cannot
see a carrier that never reaches a close (a completed task, a doc, a shell
script). 832's sibling gap (rail 495) is the evidence: their own carrier
count grew from 11 to 17 in 7 days while the ban was documented prose. A
per-item checker enforces nothing about a set.

This module is the set-level counterpart:

  1. classify() / scan_repo() — separate true anti-pattern CARRIERS from
     CITATIONS (CLAUDE.md's own §Watchtower Port section, code comments/
     docstrings explaining the pattern, and the sanctioned same-line or
     nearby fallback idiom real framework code already uses).
  2. build_baseline_dict() / load_baseline() / save_baseline() — a baseline
     store keyed by BASENAME (not relpath — `--status work-completed` moves
     `.tasks/active/*.md` -> `.tasks/completed/*.md`; a relpath key would
     make a grandfathered task's carrier look brand new the moment it
     closes, which is the exact bug 832 shipped in their own version of this
     tool).
  3. compare() — the ratchet: a carrier not in the baseline (by content hash,
     not path) is NEW and fails; a baseline entry whose carrier no longer
     appears live is STALE and reported (never silently dropped, never
     auto-pruned); removing a carrier never fails.

CLI:
    python3 tools/port3000_hygiene.py scan             # counts only
    python3 tools/port3000_hygiene.py baseline-refresh # (re)write the baseline
    python3 tools/port3000_hygiene.py ratchet          # exit 0/1, prints new/stale
    python3 tools/port3000_hygiene.py doctor-line       # single pipe-delimited line for `fw doctor`
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tokenize
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BASELINE = REPO_ROOT / ".context" / "audits" / "port3000-baseline.json"

# .tasks/ task files are .md; the rest of the repo we care about is .sh/.py/.yaml.
SCAN_EXTENSIONS = {".sh", ".py", ".md", ".yaml", ".yml"}

# Directories pruned everywhere they occur (not just at repo root).
EXCLUDE_DIR_NAMES = {".git", "__pycache__", ".venv", "node_modules", ".pytest_cache"}

# Literal hit: localhost:3000 / 127.0.0.1:3000 / 0.0.0.0:3000, with or without scheme.
HIT_RE = re.compile(r"(https?://)?(localhost|127\.0\.0\.1|0\.0\.0\.0):3000\b")

# Resolution-idiom vocabulary. Mirrors lib/verification-port.sh:find_port_literals's
# exclusion regex (the P-011 predicate) and is broadened with the real vocabulary
# this repo's own sanctioned fallback code uses (`_watchtower_url`, `wt_url`-style
# guard assignments, `fw_config`) so genuine framework code that resolves the port
# before falling back to 3000 is not misclassified as the anti-pattern it exists to
# prevent (verified against agents/context/check-tier0.sh, lib/verify-acs.sh,
# lib/arc.sh, agents/designer/designer.sh, agents/ux-review/ux-review.py,
# tools/corpus_spec.py — all real sanctioned-fallback carriers found at authoring
# time, T-2894).
RESOLUTION_IDIOM_RE = re.compile(
    r"fw\s+watchtower\s+(url|port)"
    r"|fw\s+config\s+get\s+port"
    r"|fw_config"
    r"|watchtower.{0,6}?(url|port)"
    r"|\$\{?(WT_URL|WURL|WT_PORT|FW_PORT)\b",
    re.IGNORECASE,
)

CODE_EXTENSIONS = {".sh", ".py", ".yaml", ".yml"}

# How many lines back (within the same file) a code-file hit may look for the
# resolution idiom when it isn't on the hit line itself. Real sanctioned fallback
# code spans a few lines (try triple-file, try fw_config, THEN fall back) — see
# lib/arc.sh:789-796 for the canonical shape this constant was measured against.
CODE_LOOKBACK_LINES = 12

CARRIER = "carrier"
CITATION = "citation"


@dataclass
class Hit:
    path: str            # relpath from scan root, forward slashes
    basename: str
    line: int             # 1-indexed
    text: str             # stripped line content
    category: str         # CARRIER | CITATION
    reason: str
    content_hash: str

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "basename": self.basename,
            "line": self.line,
            "text": self.text,
            "category": self.category,
            "reason": self.reason,
            "content_hash": self.content_hash,
        }


def content_hash_of(text: str) -> str:
    return hashlib.sha256(text.strip().encode("utf-8", errors="replace")).hexdigest()


def _is_excluded_dir(relparts: tuple) -> bool:
    """True when a directory (given as relpath parts from scan root) must be
    pruned wholesale. Handles the two mandated exclusions (T-2894 constraints):
    the vendored mirror `.agentic-framework/` and any `.claude/worktrees/`."""
    if not relparts:
        return False
    if relparts[0] == ".agentic-framework":
        return True
    if len(relparts) >= 2 and relparts[0] == ".claude" and relparts[1] == "worktrees":
        return True
    return relparts[-1] in EXCLUDE_DIR_NAMES


def iter_scan_files(root: Path) -> Iterable[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root)
        relparts = () if str(rel_dir) == "." else rel_dir.parts
        if _is_excluded_dir(relparts):
            dirnames[:] = []
            continue
        dirnames[:] = [
            d for d in dirnames if not _is_excluded_dir(relparts + (d,))
        ]
        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix in SCAN_EXTENSIONS:
                yield p


def find_claude_watchtower_section(lines: list) -> set:
    """1-indexed line numbers of CLAUDE.md's own §Watchtower Port section
    (heading line through the line before the next top-level `## ` heading,
    or EOF). Any localhost:3000 hit in this range is the anti-pattern's own
    documentation, not an instance of it."""
    start = None
    end = None
    for i, line in enumerate(lines):
        if start is None:
            if re.match(r"^## Watchtower Port\b", line):
                start = i
            continue
        if re.match(r"^## ", line):
            end = i
            break
    if start is None:
        return set()
    if end is None:
        end = len(lines)
    return set(range(start + 1, end + 1))


def python_docstring_lines(filepath: Path) -> set:
    """1-indexed line numbers spanned by any multi-line string literal in a
    .py file (docstrings, and the equivalent inline-comment-block idiom).
    Best-effort: a file tokenize can't parse contributes no docstring lines
    (its hits fall through to the ordinary carrier/comment/idiom rules)."""
    lines_in_string = set()
    try:
        with open(filepath, "rb") as f:
            for tok in tokenize.tokenize(f.readline):
                if tok.type == tokenize.STRING and tok.start[0] != tok.end[0]:
                    lines_in_string.update(range(tok.start[0], tok.end[0] + 1))
    except (tokenize.TokenizeError, SyntaxError, UnicodeDecodeError, OSError):
        return set()
    except Exception:
        return set()
    return lines_in_string


def classify_line(
    *,
    line: str,
    line_no: int,
    is_code: bool,
    section_lines: set,
    docstring_lines: set,
    lookback_text: Optional[str],
) -> tuple:
    """Return (category, reason) for a single line already known to contain a
    HIT_RE match. Priority order: CLAUDE.md's own section, then same-line
    sanctioned fallback, then code comment, then docstring, then (code files
    only) a nearby sanctioned fallback within CODE_LOOKBACK_LINES."""
    if line_no in section_lines:
        return CITATION, "claude_md_watchtower_port_section"
    if RESOLUTION_IDIOM_RE.search(line):
        return CITATION, "sanctioned_fallback_same_line"
    stripped = line.strip()
    if is_code and stripped.startswith("#"):
        return CITATION, "code_comment"
    if line_no in docstring_lines:
        return CITATION, "docstring"
    if is_code and lookback_text and RESOLUTION_IDIOM_RE.search(lookback_text):
        return CITATION, "sanctioned_fallback_nearby"
    return CARRIER, "bare_hardcode"


def scan_file(path: Path, root: Path) -> list:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeDecodeError):
        return []
    lines = text.splitlines()
    relpath = path.relative_to(root).as_posix()
    basename = path.name
    is_claude_md = basename == "CLAUDE.md"
    section_lines = find_claude_watchtower_section(lines) if is_claude_md else set()
    is_code = path.suffix in CODE_EXTENSIONS
    docstring_lines = python_docstring_lines(path) if path.suffix == ".py" else set()

    hits = []
    for idx, line in enumerate(lines):
        if not HIT_RE.search(line):
            continue
        line_no = idx + 1
        lookback_text = None
        if is_code:
            window_start = max(0, idx - CODE_LOOKBACK_LINES)
            lookback_text = "\n".join(lines[window_start:idx])
        category, reason = classify_line(
            line=line,
            line_no=line_no,
            is_code=is_code,
            section_lines=section_lines,
            docstring_lines=docstring_lines,
            lookback_text=lookback_text,
        )
        stripped = line.strip()
        hits.append(
            Hit(
                path=relpath,
                basename=basename,
                line=line_no,
                text=stripped,
                category=category,
                reason=reason,
                content_hash=content_hash_of(stripped),
            )
        )
    return hits


def scan_repo(root: Path) -> list:
    hits = []
    for f in iter_scan_files(root):
        hits.extend(scan_file(f, root))
    return hits


def build_baseline_dict(hits: Iterable[Hit]) -> dict:
    entries: dict = {}
    for h in hits:
        if h.category != CARRIER:
            continue
        entries.setdefault(h.basename, []).append(
            {
                "path": h.path,
                "line": h.line,
                "content_hash": h.content_hash,
                "preview": h.text[:200],
            }
        )
    return {"version": 1, "entries": entries}


def load_baseline(path: Path) -> dict:
    if not path.exists():
        return {"version": 1, "entries": {}}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    data.setdefault("entries", {})
    return data


def save_baseline(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")


@dataclass
class RatchetResult:
    new: list
    stale: list
    unchanged_count: int
    collisions: list
    carrier_count: int
    citation_count: int

    @property
    def ok(self) -> bool:
        return len(self.new) == 0


def compare(live_hits: Iterable[Hit], baseline: dict) -> RatchetResult:
    entries = baseline.get("entries", {})
    live_hits = list(live_hits)
    live_carriers = [h for h in live_hits if h.category == CARRIER]
    citation_count = sum(1 for h in live_hits if h.category == CITATION)

    live_by_basename: dict = {}
    for h in live_carriers:
        live_by_basename.setdefault(h.basename, []).append(h)

    all_basenames = set(entries.keys()) | set(live_by_basename.keys())

    new_items = []
    stale_items = []
    unchanged = 0
    collisions = []

    for basename in sorted(all_basenames):
        baseline_entries = entries.get(basename, [])
        live_entries = live_by_basename.get(basename, [])

        # Multiset diff, NOT a dict-keyed-by-hash diff (T-2894 fix during
        # authoring: a dict collapses two DISTINCT occurrences that happen to
        # share a content_hash — e.g. the same line repeated at three
        # different line numbers in one file, or a genuine basename collision
        # between two different files whose carrier text is byte-identical —
        # into a single slot. That silently loses a real new/stale
        # occurrence: if the baseline had one instance of a hash and the live
        # scan now has two, the second is a genuinely new carrier instance,
        # not "already known" just because its sibling hash matches).
        baseline_by_hash: dict = {}
        for e in baseline_entries:
            baseline_by_hash.setdefault(e["content_hash"], []).append(e)
        live_by_hash: dict = {}
        for h in live_entries:
            live_by_hash.setdefault(h.content_hash, []).append(h)

        for h_hash, live_list in live_by_hash.items():
            baseline_list = baseline_by_hash.get(h_hash, [])
            n_common = min(len(baseline_list), len(live_list))
            unchanged += n_common
            for h in live_list[n_common:]:
                new_items.append(
                    {"basename": basename, "path": h.path, "line": h.line, "text": h.text}
                )

        for h_hash, baseline_list in baseline_by_hash.items():
            live_list = live_by_hash.get(h_hash, [])
            n_common = min(len(baseline_list), len(live_list))
            for e in baseline_list[n_common:]:
                stale_items.append(
                    {
                        "basename": basename,
                        "path": e.get("path"),
                        "line": e.get("line"),
                        "preview": e.get("preview", ""),
                    }
                )

        # Collision guard (AC2): two DIFFERENT live files sharing a basename.
        # Deliberately computed from the LIVE paths only — a baseline entry's
        # stale path vs. a moved file's new path is the ordinary active/ ->
        # completed/ lifecycle move (AC4), not a collision.
        distinct_live_paths = {h.path for h in live_entries}
        if len(distinct_live_paths) > 1:
            collisions.append({"basename": basename, "paths": sorted(distinct_live_paths)})

    return RatchetResult(
        new=new_items,
        stale=stale_items,
        unchanged_count=unchanged,
        collisions=collisions,
        carrier_count=len(live_carriers),
        citation_count=citation_count,
    )


# --------------------------------------------------------------------------- CLI


def _add_common_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--root", default=str(REPO_ROOT), help="repo root to scan")
    p.add_argument("--baseline", default=str(DEFAULT_BASELINE), help="baseline JSON path")


def cmd_scan(args) -> int:
    hits = scan_repo(Path(args.root))
    carriers = [h for h in hits if h.category == CARRIER]
    citations = [h for h in hits if h.category == CITATION]
    if args.json:
        print(json.dumps({"carrier": len(carriers), "citation": len(citations)}, indent=2))
    else:
        print(f"carrier: {len(carriers)}")
        print(f"citation: {len(citations)}")
    return 0


def cmd_baseline_refresh(args) -> int:
    hits = scan_repo(Path(args.root))
    data = build_baseline_dict(hits)
    save_baseline(Path(args.baseline), data)
    total = sum(len(v) for v in data["entries"].values())
    print(
        f"baseline written: {args.baseline} "
        f"({total} carrier entries across {len(data['entries'])} basenames)"
    )
    return 0


def cmd_ratchet(args) -> int:
    hits = scan_repo(Path(args.root))
    baseline = load_baseline(Path(args.baseline))
    result = compare(hits, baseline)
    print(
        f"carrier: {result.carrier_count}  citation: {result.citation_count}  "
        f"new: {len(result.new)}  stale: {len(result.stale)}  "
        f"unchanged: {result.unchanged_count}"
    )
    for c in result.collisions:
        print(f"COLLISION: basename={c['basename']} paths={c['paths']}")
    for s in result.stale:
        print(
            f"STALE: {s['path']}:{s['line']} (basename={s['basename']}) — "
            "carrier no longer found live; re-verify it's gone or prune from baseline"
        )
    for n in result.new:
        print(f"NEW CARRIER: {n['path']}:{n['line']}: {n['text']}")
    if args.json:
        print(
            json.dumps(
                {
                    "carrier": result.carrier_count,
                    "citation": result.citation_count,
                    "new": result.new,
                    "stale": result.stale,
                    "collisions": result.collisions,
                },
                indent=2,
            )
        )
    return 0 if result.ok else 1


def cmd_doctor_line(args) -> int:
    baseline_path = Path(args.baseline)
    if not baseline_path.exists():
        print(
            "SKIP|port3000 hygiene: no baseline yet|"
            "Run: python3 tools/port3000_hygiene.py baseline-refresh"
        )
        return 0
    hits = scan_repo(Path(args.root))
    baseline = load_baseline(baseline_path)
    result = compare(hits, baseline)
    if result.new:
        print(
            f"WARN|port3000 hygiene: {result.carrier_count} carriers "
            f"({result.citation_count} citations), {len(result.new)} new since "
            f"baseline, {len(result.stale)} stale|"
            "Run: python3 tools/port3000_hygiene.py ratchet"
        )
    else:
        print(
            f"OK|port3000 hygiene: {result.carrier_count} carriers "
            f"({result.citation_count} citations) — 0 new since baseline "
            f"({len(result.stale)} stale)|"
        )
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_scan = sub.add_parser("scan", help="classify and count carrier/citation hits")
    _add_common_args(p_scan)
    p_scan.add_argument("--json", action="store_true")
    p_scan.set_defaults(func=cmd_scan)

    p_base = sub.add_parser("baseline-refresh", help="(re)write the baseline from the current scan")
    _add_common_args(p_base)
    p_base.set_defaults(func=cmd_baseline_refresh)

    p_ratchet = sub.add_parser("ratchet", help="compare current scan against the baseline")
    _add_common_args(p_ratchet)
    p_ratchet.add_argument("--json", action="store_true")
    p_ratchet.set_defaults(func=cmd_ratchet)

    p_doctor = sub.add_parser("doctor-line", help="single pipe-delimited VERDICT|MSG|HINT line for fw doctor")
    _add_common_args(p_doctor)
    p_doctor.set_defaults(func=cmd_doctor_line)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
