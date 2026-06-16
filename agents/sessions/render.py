#!/usr/bin/env python3
"""Generic session renderer for `fw sessions` (T-2417).

Consumes canonical JSONL on stdin (one session per line per
agents/sessions/SCHEMA.md) and prints a project-grouped tree on stdout.

Agent-neutral by design — this file contains zero provider-specific strings
or logic. Per-provider knowledge lives in agents/sessions/<provider>/.

Layout (locked in T-2417 Decisions section):
  // <project-A>
    Needs input
      ✻ <name>                <description>            2d
      ✻ <name>                <description>            1h
    Working
      ✻ <name>                <description>            5m
    Completed
      ∙ <name>                <description>            11m

  // <project-B>
    ...

  // (loose)
    ...

Order:
  - Real projects first (alphabetical by project name)
  - `(loose)` bucket last
  - Within each project: state-first (needs-input → working → completed)
  - Within each state: most-recent-activity first (smallest age_seconds first)

Age format:
  - age < 60s  → "< 1m"
  - age < 1h   → "Nm"
  - age < 1d   → "Nh"
  - age < 1w   → "Nd"
  - age >= 1w  → "Nw"
"""
import json
import sys
from collections import defaultdict

STATE_ORDER = ("needs-input", "working", "completed")
STATE_HEADER = {
    "needs-input": "Needs input",
    "working": "Working",
    "completed": "Completed",
}
STATE_GLYPH = {
    "needs-input": "✻",
    "working": "✻",
    "completed": "∙",
}
LOOSE = "(loose)"


def fmt_age(secs):
    """Format integer seconds as compact relative age."""
    if not isinstance(secs, (int, float)) or secs < 0:
        return "?"
    secs = int(secs)
    if secs < 60:
        return "< 1m"
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        return f"{secs // 3600}h"
    if secs < 604800:
        return f"{secs // 86400}d"
    return f"{secs // 604800}w"


def main():
    sessions = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            sessions.append(json.loads(line))
        except json.JSONDecodeError as e:
            print(f"render: skipping malformed JSONL line: {e}", file=sys.stderr)
            continue

    # Group by project, then by state.
    by_project = defaultdict(lambda: defaultdict(list))
    for s in sessions:
        proj = s.get("project") or LOOSE
        state = s.get("state") or "completed"
        if state not in STATE_ORDER:
            state = "completed"
        by_project[proj][state].append(s)

    # Sort projects: real ones alphabetical, then (loose) last.
    real_projects = sorted(p for p in by_project if p != LOOSE)
    ordered_projects = real_projects + ([LOOSE] if LOOSE in by_project else [])

    if not ordered_projects:
        print("(no sessions)")
        return 0

    out_lines = []
    for proj in ordered_projects:
        out_lines.append(f"// {proj}")
        states = by_project[proj]
        for state in STATE_ORDER:
            if state not in states or not states[state]:
                continue
            out_lines.append(f"  {STATE_HEADER[state]}")
            # most-recent first within state
            for s in sorted(states[state], key=lambda x: x.get("age_seconds", 0)):
                glyph = STATE_GLYPH[state]
                name = s.get("name") or "(unnamed)"
                desc = s.get("description") or ""
                age = fmt_age(s.get("age_seconds", 0))
                # Layout: name (left, truncated to ~40) | desc (middle, truncated to ~40) | age (right)
                # When no description, drop the description column entirely
                # instead of padding empty space — keeps the visual tight.
                name_col = name if len(name) <= 40 else name[:37] + "..."
                if desc:
                    desc_col = desc if len(desc) <= 40 else desc[:37] + "..."
                    out_lines.append(f"    {glyph} {name_col:<40}  {desc_col:<40}  {age:>5}")
                else:
                    out_lines.append(f"    {glyph} {name_col:<40}  {age:>5}")
        out_lines.append("")  # blank line between projects

    # Trim trailing blank
    while out_lines and not out_lines[-1]:
        out_lines.pop()

    print("\n".join(out_lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
