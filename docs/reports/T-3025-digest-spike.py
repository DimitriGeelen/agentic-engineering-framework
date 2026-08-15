#!/usr/bin/env python3
"""T-3025 IW-2 spike: produce the option-(3) digest-plus-reference variant of a handover.

Exploration only — this is not the generator. It exists to make one falsifiable
claim testable: does a recovering session reconstitute from a digest?

Rule applied: narrative sections pass through verbatim; the three state dumps are
replaced by (count, top-N entries, the live command that regenerates the rest).
N is deliberately small — the question is whether a *bounded* head is enough, and
a generous N would answer a different, easier question.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# (command, noun, entry_pattern)
#
# entry_pattern differs per section and that is the whole point: an "entry" is
# section-specific. v1 of this script used a single bullet regex everywhere and
# reported "720 active tasks" for a section holding 119 — it had counted each
# task's four bullet FIELDS as separate tasks. The number was wrong and looked
# entirely plausible, which is the dangerous kind. See §Spike 11.
DUMP_SECTIONS = {
    "## Observation Inbox": (
        "bin/fw note triage", "observations", r"^[-*]\s+\S",
    ),
    "## Work in Progress": (
        "bin/fw task list --status started-work", "active tasks", r"^###\s+T-\d+",
    ),
    "## Awaiting Your Action (Human)": (
        "bin/fw review-queue", "items awaiting the human", r"^[-*]\s+\S",
    ),
}
TOP_N = 5

# Independent oracle: most dump sections state their own count in a bold lead-in
# ("**153 pending observations...**"). That figure is produced by the handover
# generator, not by this script, so agreement is real corroboration rather than
# a tautology. Disagreement means the entry_pattern above is wrong.
SELF_COUNT = re.compile(r"\*\*(\d[\d,]*)\s")


def split_sections(text: str) -> list[tuple[str, str]]:
    """Return [(heading, body)] preserving order; text before the first ## is ('', body)."""
    parts = re.split(r"^(## .+)$", text, flags=re.M)
    out = [("", parts[0])]
    for i in range(1, len(parts), 2):
        out.append((parts[i], parts[i + 1]))
    return out


def count_entries(body: str, pattern: str) -> int:
    return len(re.findall(pattern, body, flags=re.M))


def head_entries(body: str, pattern: str, n: int) -> list[str]:
    """First n entries, each truncated to one line."""
    out = []
    for line in body.splitlines():
        if re.match(pattern, line):
            out.append(line.strip()[:200])
            if len(out) >= n:
                break
    return out


def check_against_self_report(heading: str, body: str, counted: int) -> None:
    """Warn loudly when our count disagrees with the section's own stated figure."""
    m = SELF_COUNT.search(body)
    if not m:
        print(f"  NOTE {heading}: no self-reported count to check against "
              f"(counted {counted})", file=sys.stderr)
        return
    stated = int(m.group(1).replace(",", ""))
    if stated != counted:
        print(f"  MISMATCH {heading}: section says {stated}, we counted "
              f"{counted} — entry_pattern is wrong", file=sys.stderr)
    else:
        print(f"  ok {heading}: {counted} (agrees with self-report)", file=sys.stderr)


def digest(text: str) -> str:
    chunks = []
    for heading, body in split_sections(text):
        if heading in DUMP_SECTIONS:
            cmd, noun, pattern = DUMP_SECTIONS[heading]
            total = count_entries(body, pattern)
            check_against_self_report(heading, body, total)
            head = head_entries(body, pattern, TOP_N)
            shown = len(head)
            lines = [heading, ""]
            lines.append(
                f"**{total} {noun}.** Showing the first {shown}; "
                f"the rest is live state, not history — regenerate with `{cmd}`."
            )
            lines.append("")
            lines.extend(head)
            if total > shown:
                lines.append("")
                lines.append(
                    f"_{total - shown} more not embedded. This section was "
                    f"{len(body):,} bytes when embedded by value._"
                )
            lines.append("")
            chunks.append("\n".join(lines))
        else:
            # `body` already carries the newline that followed the heading —
            # re-adding one shifts every narrative section by a blank line and
            # breaks byte-comparison against the original.
            chunks.append(heading + body)
    return "".join(
        c if c.endswith("\n") else c + "\n" for c in chunks
    )


if __name__ == "__main__":
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    original = src.read_text()
    out = digest(original)
    dst.write_text(out)
    print(f"{src.name}: {len(original):,} B  ->  {dst.name}: {len(out):,} B "
          f"({100 * len(out) / len(original):.1f}%)")
