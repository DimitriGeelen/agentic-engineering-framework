#!/usr/bin/env python3
"""Extract the `## Decisions` section of a task file as YAML — T-3015.

Replaces the line-by-line shell parse in episodic.sh, which read a
block-structured document one line at a time and produced three defects from
that single assumption:

  1. It filtered the comment DELIMITERS `^<!--` / `^-->` but not the comment
     INTERIOR, and the task template's Decisions block is exactly such a
     multi-line comment. Its `### [date] - [topic]` and `- **Chose:** [what was
     decided]` lines survived and were emitted as real decisions. 2039 of 2649
     episodics in this tree (77%) carry that placeholder text.
  2. It ran `sed` on a single line, so a value wrapping onto continuation lines
     was cut at the first newline. This is the dangerous one: a phantom entry is
     visibly junk, a truncated rationale reads as complete.
  3. `head -20` dropped the tail of a longer section with no note.

Reported by 050-email-archive (G-EPISODIC-PLACEHOLDER-LEAK) and independently
reproduced by 832-Workflow-designer at 81%. Their key finding is why this is not
a regex filter: filtering placeholder TEXT closes symptom 1 only, and removes the
tell while 2 and 3 keep running. The output then looks clean. Strip the comment
SPANS instead, so the placeholders are gone because they were never content.

Emits single-quoted YAML scalars, `'` escaped as `''` — the L-392 / L-385 /
T-1871 rule. Do not switch to double quotes: backticks and backslashes in
decision prose trigger yaml.scanner.ScannerError there.

Usage:  extract_decisions.py <task-file>
Prints the YAML body of the `decisions:` list (entries only, no key), or nothing
at all when no real decision survives. Exit 0 either way; an unfilled Decisions
section is the normal case, not an error.
"""

import re
import sys

# Field label -> emitted YAML key. Order is not significant; membership is, since
# an unrecognised bolded label terminates the value being accumulated.
FIELDS = {
    "Chose": "chose",
    "Why": "rationale",
    "Rejected": "alternatives_rejected",
}

_COMMENT_SPAN = re.compile(r"<!--.*?-->", re.DOTALL)
_HEADING = re.compile(r"^###\s+(.*)$")
_FIELD = re.compile(r"^[-*]?\s*\*\*(\w+):\*\*\s*(.*)$")
_ANY_BOLD_LABEL = re.compile(r"^[-*]?\s*\*\*(\w+):\*\*")


def _section(text: str) -> str:
    """The `## Decisions` section body, comment spans removed.

    Comment spans are stripped BEFORE the section is sliced, so an unterminated
    or oddly-placed comment cannot smuggle its interior across the boundary.
    """
    text = _COMMENT_SPAN.sub("", text)
    out, inside = [], False
    for line in text.splitlines():
        if re.match(r"^##\s+Decisions\s*$", line):
            inside = True
            continue
        if inside and line.startswith("## "):
            break
        if inside:
            out.append(line)
    return "\n".join(out)


def _q(value: str) -> str:
    return "'" + " ".join(value.split()).replace("'", "''") + "'"


def parse(text: str):
    """-> list of {'topic': str|None, 'chose'/'rationale'/'alternatives_rejected': str}"""
    entries, current, field = [], None, None

    def close_field():
        nonlocal field
        field = None

    for line in _section(text).splitlines():
        stripped = line.strip()

        heading = _HEADING.match(stripped)
        if heading:
            close_field()
            current = {"topic": heading.group(1).strip()}
            entries.append(current)
            continue

        match = _FIELD.match(stripped)
        if match and match.group(1) in FIELDS:
            close_field()
            if current is None:
                # A field with no `### topic` above it. Real content, so keep it
                # rather than discarding — losing it silently is the bug's class.
                current = {"topic": None}
                entries.append(current)
            field = FIELDS[match.group(1)]
            current[field] = match.group(2).strip()
            continue

        # A blank line, a new heading of any level, or an unknown bolded label
        # closes the value being accumulated. Anything else is a continuation of
        # it — this is what symptom 2 threw away.
        if not stripped or stripped.startswith("#") or _ANY_BOLD_LABEL.match(stripped):
            close_field()
            continue

        if field and current is not None:
            current[field] = (current[field] + " " + stripped).strip()

    return [e for e in entries if e.get("topic") or len(e) > 1]


def to_yaml(entries) -> str:
    lines = []
    for entry in entries:
        topic = entry.get("topic")
        lines.append(f"  - decision: {_q(topic)}" if topic else "  - decision: '(untitled)'")
        for key in ("chose", "rationale"):
            if entry.get(key):
                lines.append(f"    {key}: {_q(entry[key])}")
        if entry.get("alternatives_rejected"):
            lines.append(f"    alternatives_rejected: [{_q(entry['alternatives_rejected'])}]")
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("usage: extract_decisions.py <task-file>\n")
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as handle:
            text = handle.read()
    except OSError as exc:
        sys.stderr.write(f"extract_decisions.py: cannot read {sys.argv[1]}: {exc}\n")
        return 1
    body = to_yaml(parse(text))
    if body:
        print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
