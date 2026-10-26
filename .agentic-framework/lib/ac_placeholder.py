#!/usr/bin/env python3
"""T-3528: the ONE Python decision point for "is this acceptance-criterion text
a template placeholder?"

Origin — OBS-560. `fw bvp judge T-3471` returned GREEN on a task whose entire
Acceptance Criteria section was the shipped template stubs (the ordinal
`[<Ordinal> criterion]` forms this module's CANONICAL_SAMPLES enumerates).

The judge's SUFFICIENCY criterion ("are the criteria good enough to justify the
score claimed?") was implemented as a pure length threshold, and the first
ordinal stub is 17 characters against a floor of 15. So the check that exists to
refuse template text approved it, and did so while printing "2/2 AC item(s)
substantive" as its evidence — a false green that reads exactly like a real one.

**Why this module exists rather than a fourth regex.** At the time OBS-560 was
filed the framework already had THREE readers of this predicate, none of which
the judge reused:

  1. `agents/context/check-active-task.sh` (the G-020 build-readiness gate) —
     the narrowest: ordinal criterion stubs only, case-insensitive
  2. `lib/task-audit.sh:79` `audit_task_placeholders()` — the widest pattern set,
     and the one this module mirrors
  3. `lib/resolver.py` `_ac_is_placeholder()` — now delegates here

That is the same shape as the arc-membership predicate, which reached five
implementations disagreeing three ways and cost a day to consolidate. The two
Python readers are consolidated here. The two bash readers are deliberately NOT
folded in: one of them runs inside a PreToolUse hook on every Write/Edit, and
making that hook shell out to `python3` trades a false green for a latency and
availability risk on the framework's busiest gate. Instead the coupling is
pinned by a test that runs the REAL bash regex from `lib/task-audit.sh` against
this module's CANONICAL_SAMPLES — see
`tests/unit/test_ac_placeholder.py::test_bash_and_python_readers_agree`. If
either side drops a pattern, that test goes red; drift cannot be silent.

**Deliberately wider than the bash on one axis: case.** `task-audit.sh` matches
case-sensitively, `check-active-task.sh` matches case-insensitively. The two
already disagree, so this module takes the wider reading. A placeholder detector
that fails open on a lowercased stub is the exact defect class this module was
written to close, and over-flagging here costs an author one edit while
under-flagging ships a false green.

**One known cost of that widening, stated rather than discovered.** This
predicate cannot tell a MENTION from an INSTANCE: prose that quotes a stub in
order to discuss it matches too. `task-audit.sh` mitigates that by stripping
fenced blocks and inline backtick spans before matching; this module does not,
because its callers feed it single AC items and dispatch-eligibility blocks
rather than whole documents. Callers that scan authored prose should strip code
spans first. (Measured while building this: T-3528's own acceptance criteria
tripped the G-020 gate by naming the stub inside backticks.)
"""

from __future__ import annotations

import re

#: Literal template stubs the framework's own templates ship. Mirrors
#: `lib/task-audit.sh:79`. Each entry is chosen because it NEVER appears in
#: legitimate authored content — only in an unfilled template.
#:
#: Kept as source-of-truth for the cross-language parity test, which feeds every
#: sample below through the bash reader's real regex.
CANONICAL_SAMPLES = (
    "[First criterion]",
    "[Second criterion]",
    "[Third criterion]",
    "[Fourth criterion]",
    "[Fifth criterion]",
    "[Criterion 1]",
    "[Criterion 12]",
    "[TODO]",
    "[PLACEHOLDER]",
    "[Your recommendation here]",
    "[REQUIRED before this ships]",
)

#: Strings that must NOT match. The routing prefixes are the load-bearing ones:
#: `[REVIEW]` and `[REVIEWER]` are real AC markers (CLAUDE.md §AC Classification
#: Guidance), and a predicate that swallowed them would refuse every correctly
#: routed human criterion in the corpus.
CANONICAL_NON_SAMPLES = (
    "[REVIEW] Layout reads clean at mobile width",
    "[REVIEWER] Block message names both bypass mechanisms",
    "[RUBBER-STAMP] Publish the release notes",
    "Criterion coverage is measured by the audit rail",
    "Tests pass under `bin/fw test unit`",
    "[REQUIREMENT] tracked separately",
)

#: The predicate. Union of `lib/task-audit.sh:79`, case-insensitive (see the
#: module docstring for why the widening is deliberate).
PLACEHOLDER_RE = re.compile(
    r"\[Criterion\s+[0-9]+\]"
    r"|\[(?:First|Second|Third|Fourth|Fifth)\s+criterion\]"
    r"|\[TODO\]"
    r"|\[PLACEHOLDER\]"
    r"|\[Your\s+recommendation\s+here\]"
    r"|\[REQUIRED\s+before",
    re.I,
)

#: T-4741: an inline code span per CommonMark — a run of N backticks, the
#: content, then a closing run of exactly N backticks (neither run touching a
#: further backtick). T-4762: DOTALL, because a span may run across a line
#: break inside one block; `_blocks` keeps it from crossing a block boundary.
_CODE_SPAN_RE = re.compile(r"(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)", re.S)

#: T-4762: lines that end the current block. A fence line (passed through
#: untouched, as is everything inside the fence) ...
_FENCE_RE = re.compile(r"^ {0,3}(?:```|~~~)")
#: ... a markdown block start (list item, heading, blockquote, table row,
#: thematic break / frontmatter delimiter) ...
_MD_BLOCK_START_RE = re.compile(r"^\s*(?:[-*+]\s|[0-9]+[.)]\s|#{1,6}(?:\s|$)|>|\|)|^---\s*$")
#: ... or, inside frontmatter, a top-level YAML key or the closing `---`.
_YAML_KEY_RE = re.compile(r"^(?:[A-Za-z_][\w-]*\s*:|---\s*$)")

#: T-4741: a double-quoted string on one line.
_DQUOTE_RE = re.compile(r'"[^"\n]*"')


def _blocks(lines):
    """Group lines into (strippable, [lines]) runs (T-4762).

    A code span may continue onto the next line of the same paragraph, list
    item or frontmatter scalar (a folded `description: >` is one paragraph),
    but never past a blank line or the start of another block. Fenced code is
    yielded as non-strippable runs, one line each, so a fence's backticks
    never pair with a span outside it.
    """
    in_front = bool(lines) and lines[0].strip() == "---"
    in_fence = False
    cur = []
    for n, line in enumerate(lines):
        if _FENCE_RE.match(line):
            if cur:
                yield True, cur
                cur = []
            in_fence = not in_fence
            yield False, [line]
            continue
        if in_fence:
            yield False, [line]
            continue
        if in_front and n > 0:
            starts = bool(_YAML_KEY_RE.match(line))
            if line.strip() == "---":
                in_front = False
        else:
            starts = bool(_MD_BLOCK_START_RE.match(line))
        if not line.strip() or starts:
            if cur:
                yield True, cur
            cur = []
        cur.append(line)
    if cur:
        yield True, cur


def _drop_span(m):
    # Keep the span's line breaks so every later line keeps its number.
    return "\n" * m.group(0).count("\n")


def strip_quoted_spans(text: str) -> str:
    """Remove text that MENTIONS a stub rather than being one (T-4741).

    Code spans of any backtick length go first, then same-line double-quoted
    strings. A stub quoted to talk about it ("the [Criterion 1] stub", or one
    inside a double-backtick span) disappears, while a bare stub on the same
    line survives and is still flagged. This is the ONE implementation of the
    rule: `lib/task-audit.sh` calls it through
    `python3 lib/ac_placeholder.py --strip`.

    T-4762: spans are matched per block, not per line, so a span that opens
    on one line and closes on the next (a wrapped paragraph, a YAML folded
    scalar) is stripped whole. The output has exactly the input's lines.
    """
    out = []
    for strippable, lines in _blocks((text or "").split("\n")):
        if not strippable:
            out.extend(lines)
            continue
        joined = _CODE_SPAN_RE.sub(_drop_span, "\n".join(lines))
        out.extend(_DQUOTE_RE.sub("", l) for l in joined.split("\n"))
    return "\n".join(out)


#: A checkbox item carrying at least one non-space character of content.
#: Used by `is_placeholder_block`.
_REAL_ITEM_RE = re.compile(r"-\s*\[[ xX]\]\s*\S")


def is_placeholder_item(item: str) -> bool:
    """True when a single AC item is template stub text.

    Takes the item verbatim — do NOT strip prefix markers first. `[REVIEW]` and
    `[REVIEWER]` are real routing prefixes and must not read as placeholders,
    which is why this matches specific stub literals rather than "any bracketed
    span". CANONICAL_NON_SAMPLES pins that.
    """
    return bool(PLACEHOLDER_RE.search(strip_quoted_spans(item or "")))


def all_placeholder(items) -> bool:
    """True when every item present is a placeholder.

    Empty input returns False — "nothing is here" is an ABSENCE, a different
    finding from "template text is here", and the callers report them
    differently (RED-for-absence vs RED-for-template). Answering True for an
    empty list would collapse that distinction, and a predicate that answers the
    question next to the one it was asked is how OBS-560 happened.
    """
    items = list(items or [])
    if not items:
        return False
    return all(is_placeholder_item(i) for i in items)


def placeholder_items(items) -> list:
    """The subset of `items` that is template stub text."""
    return [i for i in (items or []) if is_placeholder_item(i)]


def is_placeholder_block(ac_block: str) -> bool:
    """True when a whole Acceptance Criteria BLOCK is template-only / unscoped.

    Wider than `is_placeholder_item`: an empty block and a block with no real
    checkbox at all are both unscoped. This is the shape
    `lib/resolver.py:_ac_is_placeholder` needs for dispatch eligibility, where
    "unscoped" and "absent" get the same answer because neither is dispatchable.
    """
    s = (ac_block or "").strip()
    if not s:
        return True
    if is_placeholder_item(s):
        return True
    return not _REAL_ITEM_RE.search(s)


if __name__ == "__main__":
    # T-4741: `--strip` filters stdin to stdout, line count preserved, so
    # lib/task-audit.sh can pair each output line with its input line.
    # T-4762: the whole input is stripped at once (spans can cross lines), so
    # pass the whole file, not a selection of its lines.
    import sys

    if sys.argv[1:] != ["--strip"]:
        sys.stderr.write("usage: ac_placeholder.py --strip < text\n")
        sys.exit(2)
    import io

    # newline="\n": a stray \r must not split a line and shift the pairing.
    src = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8",
                           errors="surrogateescape", newline="\n")
    dst = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8",
                           errors="surrogateescape", newline="\n")
    data = src.read()
    if data:
        if data.endswith("\n"):
            data = data[:-1]
        dst.write(strip_quoted_spans(data) + "\n")
    dst.flush()
