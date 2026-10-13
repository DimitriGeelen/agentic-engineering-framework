#!/usr/bin/env python3
"""Lint capability cards on .fabric/subsystems.yaml entries.

T-4153 (leg 1 of T-4142). A subsystem entry may carry a `capability_card:` block:

    capability_card:
      capabilities:   [what it can do, ...]          required, non-empty
      problem_solved: "the symptom someone searches"  required, not a placeholder
      tags:           [technology/topic, ...]         required, non-empty
      entry_points:   [how to reuse it, ...]          optional
      status:         live|experimental|retired       required
      owner:          "project + contact"             required
      limits:         "known limits"                  optional

Exit 1 when a present card breaks the bar. Subsystems with no card are listed
(exit 0), or fail under --strict.

Usage: cardlint.py [subsystems.yaml] [--strict]
"""

import re
import sys

import yaml

STATUSES = ("live", "experimental", "retired")
REQUIRED = ("capabilities", "problem_solved", "tags", "status", "owner")
PLACEHOLDER = re.compile(r"\b(TODO|FIXME|TBD|XXX|lorem ipsum|placeholder)\b|^\s*(n/?a|none|\.\.\.|\?)\s*$", re.I)


def placeholder(value):
    return bool(PLACEHOLDER.search(str(value)))


def check_card(card):
    """Return a list of problem strings for one card."""
    if not isinstance(card, dict):
        return ["capability_card is not a mapping"]
    problems = []
    for key in REQUIRED:
        if card.get(key) in (None, "", [], {}):
            problems.append(f"{key} missing or empty")
    for key in ("capabilities", "tags", "entry_points"):
        val = card.get(key)
        if val in (None, "", []):
            continue
        if not isinstance(val, list):
            problems.append(f"{key} must be a list")
            continue
        if any(placeholder(v) for v in val):
            problems.append(f"{key} has placeholder text")
    for key in ("problem_solved", "owner", "limits"):
        val = card.get(key)
        if val and placeholder(val):
            problems.append(f"{key} has placeholder text")
    status = card.get("status")
    if status and status not in STATUSES:
        problems.append(f"status '{status}' not one of {'/'.join(STATUSES)}")
    return problems


def main(argv):
    strict = "--strict" in argv
    args = [a for a in argv if not a.startswith("--")]
    path = args[0] if args else ".fabric/subsystems.yaml"
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    subsystems = data.get("subsystems") or []
    carded, bare, failed = 0, [], 0
    for sub in subsystems:
        sid = sub.get("id", "?")
        if "capability_card" not in sub or sub["capability_card"] is None:
            bare.append(sid)
            continue
        carded += 1
        for p in check_card(sub["capability_card"]):
            failed += 1
            print(f"FAIL {sid}: {p}")
    print(f"capability cards: {carded} card(s) checked, {failed} problem(s), {len(bare)} subsystem(s) without a card")
    if bare:
        print("without a card: " + ", ".join(bare))
    return 1 if failed or (strict and bare) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
