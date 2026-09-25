#!/usr/bin/env python3
# Fabric — watch-set coverage of the fabric's own registered surface (T-2253, Pen).
#
# WHAT THIS ANSWERS, AND WHY NOTHING ELSE DID
#
# drift.sh section 1 computes:
#
#     unregistered = expand_patterns(watch-patterns.yaml) - card_locations
#
# i.e. "is there a watched file with no card". Every term on the right is bounded by the
# watch set, so the check can only ever produce a finding about a file the watch set
# already reaches. Nothing asks the converse — whether the watch set still reaches
# everywhere the fabric ALREADY HOLDS CARDS. When it does not, `unregistered: 0` is not
# evidence of a registered tree; it is evidence of a narrow glob, and the two are
# indistinguishable in the output.
#
# Measured in Pen on 2026-09-25: 76 of 724 on-disk card locations (10.5%) lay outside the
# watch set across 39 directories. Worked example — `src/config/` holds three files; two
# have cards (so the project already decided the directory is in-fabric) and the third,
# `src/config/paths.js` with 38 importers, has none. No pattern covers `src/config/**`, so
# section 1 could never flag it, and reported 0. It surfaced only because T-2250's
# divergence detector — a different reader — counted it among 37 anonymous "detected
# import(s) whose target has no card".
#
# This is deliberately NOT a policy check. It does not decide which files deserve cards.
# It reports only where the fabric's own cards prove a directory is in scope while the
# watch set does not cover it, so the two inputs can no longer silently disagree.
#
# WHY IT SHELLS OUT TO expand_patterns.py
#
# Same reason T-1842 centralised that expansion in the first place: a second, independent
# reimplementation of "what is watched" would be free to disagree with section 1, and a
# coverage report that disagrees with the check it is reporting on is worse than none.
# One reader, one answer. If that reader fails, this script fails loudly (exit 2) so the
# caller can print UNKNOWN — a coverage checker that cannot read its input must never be
# mistaken for one that found full coverage.
#
# Usage:
#   python3 watchset_coverage.py <watch-patterns.yaml> <project_root> <components_dir>
#
# Output: one "  ! <dir>  (<n> card(s))" line per uncovered directory, then sentinels
#   ##UNWATCHED_LOCATIONS=<n>##
#   ##UNWATCHED_DIRS=<n>##
# Exit codes: 0 ok, 2 pattern expansion failed, 3 missing argv / unreadable components dir.

from __future__ import annotations

import collections
import os
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 4:
        sys.stderr.write(
            "usage: watchset_coverage.py <watch-patterns.yaml> <project_root> "
            "<components_dir>\n"
        )
        return 3

    watch_file, project_root, components_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    lib_dir = os.path.dirname(os.path.abspath(__file__))

    if not os.path.isdir(components_dir):
        sys.stderr.write(f"watchset_coverage.py: no components dir: {components_dir}\n")
        return 3

    # Single source of truth for "what is watched" — see header.
    try:
        proc = subprocess.run(
            [sys.executable, os.path.join(lib_dir, "expand_patterns.py"),
             watch_file, project_root],
            capture_output=True, text=True, timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        sys.stderr.write(f"watchset_coverage.py: could not run expand_patterns.py: {exc}\n")
        return 2
    if proc.returncode != 0:
        sys.stderr.write(
            f"watchset_coverage.py: expand_patterns.py exited {proc.returncode}\n"
        )
        return 2

    watched = {line.strip() for line in proc.stdout.splitlines() if line.strip()}

    # Card locations. Read with the same `^location:` convention drift.sh uses so a card
    # this script counts is a card that check counts.
    locations = []
    try:
        for fn in sorted(os.listdir(components_dir)):
            if not fn.endswith(".yaml"):
                continue
            try:
                with open(os.path.join(components_dir, fn), "r", errors="replace") as fh:
                    for line in fh:
                        if line.startswith("location:"):
                            loc = line.split("location:", 1)[1].strip()
                            if loc:
                                locations.append(loc)
                            break
            except OSError:
                continue
    except OSError as exc:
        sys.stderr.write(f"watchset_coverage.py: cannot list {components_dir}: {exc}\n")
        return 3

    # A card whose file is absent from disk is drift's section 2 (orphaned), not ours.
    # Counting it here would double-report one defect as two, the exact error T-2112 made
    # on the Qdrant join key.
    uncovered = collections.Counter()
    total = 0
    for loc in set(locations):
        if loc in watched:
            continue
        if not os.path.isfile(os.path.join(project_root, loc)):
            continue
        total += 1
        uncovered[os.path.dirname(loc) or "."] += 1

    for directory, count in sorted(uncovered.items()):
        print(f"  ! {directory}  ({count} card location(s) not covered)")

    print(f"##UNWATCHED_LOCATIONS={total}##")
    print(f"##UNWATCHED_DIRS={len(uncovered)}##")
    return 0


if __name__ == "__main__":
    sys.exit(main())
