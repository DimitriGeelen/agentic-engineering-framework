"""Structural HTML-comment stripping — the single canonical rule (T-2954).

THE RULE
--------
`<!--` opens a comment span only when it is the **first non-blank token on its
line**. A `<!--` appearing mid-line does not open anything. The span ends on the
first line containing `-->`. Comment lines are dropped whole; every other line
survives byte-identical.

WHY THIS RULE AND NOT `re.sub(r'<!--.*?-->', '', s, flags=re.DOTALL)`
---------------------------------------------------------------------
Under DOTALL, `.*?` crosses newlines, so a mid-line `<!--` pairs with the next
`-->` anywhere below — usually the close of an unrelated comment block — and
every line between them is deleted. T-2921 measured that on the P-011 extractor:
a three-command Verification block whose middle member was a failing assertion
reported `Running 2 verification command(s)` / `2/2 passed`. The failing check
had ceased to exist. Nothing red, nothing logged, and the output was
indistinguishable from a genuine pass.

WHEN TO STRIP AT ALL (the direction rule — T-2921 / T-2948 / T-2954)
--------------------------------------------------------------------
Stripping is not universally correct. Three dispositions, decided entirely by
what the consumer does with the surviving text:

  span is DISCARDED as prose  -> strip        (G-067, G-020, lib/review.sh)
  span is COUNTED             -> strip        (this module's callers)
  span is EXECUTED            -> do NOT strip (T-2921: P-011 hands it to eval)

Collapsed to one sentence: **strip iff the consumer does anything with the
surviving text other than show it to a human.** T-2921's `extract_verification_block`
is the one caller that strips for the *counting* stage and must not let the
strip cross a command boundary — hence this rule rather than the regex.

WHY A MODULE RATHER THAN A FOURTH COPY
--------------------------------------
Before T-2954 this logic existed at four sites with three different semantics:

  lib/verification-port.sh   structural (correct)          <- now imports this
  agents/context/check-human-ac-tick.py   none at all      <- now imports this
  agents/audit/audit.sh:3406 drops any line CONTAINING <!-- (OBS-238 / T-2950)
  lib/review.sh              treats <!-- ANYWHERE as opening (see below)

`verification-port.sh` previously asserted parity with `update-task.sh`'s copy
*in a comment*, and that comment recorded that the claim had already been found
false once and repaired by editing the copy. Parity claimed in prose between two
copies is not parity (T-2949). The two Python-reachable sites now share this
function, so their parity is by construction. The two remaining shell sites are
registered, not silently left: audit.sh under OBS-238/T-2950, review.sh under
OBS-239 — its rule under-counts a real AC that carries a trailing comment
(`- [ ] Real AC <!-- note`), which is conservatively wrong rather than unsafe.

Usable as a filter so shell callers get the same bytes as Python callers:

    printf '%s' "$text" | python3 lib/comment_strip.py
"""
from __future__ import annotations

import sys

__all__ = ["strip_html_comment_lines"]


def strip_html_comment_lines(text: str) -> str:
    """Drop whole-line HTML comment spans; leave every other line untouched.

    A line opens a comment only when `<!--` is its first non-blank token. If that
    same line also carries `-->` after the opener, the span closes on it.
    """
    out: list[str] = []
    in_comment = False
    for line in text.split("\n"):
        stripped = line.lstrip()
        if in_comment:
            if "-->" in line:
                in_comment = False
            continue
        if stripped.startswith("<!--"):
            if "-->" not in stripped[4:]:
                in_comment = True
            continue
        out.append(line)
    return "\n".join(out)


def unclosed_comment_line(text: str) -> int | None:
    """1-based line number of a whole-line `<!--` whose span never closes, else None.

    T-5188: a COUNTING caller must not let an unclosed span swallow the rest of what it
    counts (P-010 counted 0 criteria behind `- [ ] one` + a later bare `<!--`)."""
    opened_at = None
    for n, line in enumerate(text.split("\n"), start=1):
        stripped = line.lstrip()
        if opened_at is not None:
            if "-->" in line:
                opened_at = None
            continue
        if stripped.startswith("<!--") and "-->" not in stripped[4:]:
            opened_at = n
    return opened_at


if __name__ == "__main__":
    # T-4608: decode strict UTF-8 from bytes, never through the locale. With
    # LANG unset or C, Python runs in UTF-8 mode (PEP 540) and sys.stdin uses
    # surrogateescape (C.UTF-8 too), so an undecodable byte passed silently and
    # extract_verification_block returned 0 where it must return 2 (T-3232).
    # T-5188: --lenient decodes with U+FFFD for COUNTING callers (P-010): a bad byte
    # must not make the strip fail and the count come out 0; it cannot create or hide a
    # `<!--`, `-->` or box marker. --fail-unclosed exits 3 naming an unclosed span.
    args = sys.argv[1:]
    raw = sys.stdin.buffer.read()
    text = raw.decode("utf-8", errors="replace") if "--lenient" in args else raw.decode("utf-8")
    if "--fail-unclosed" in args:
        n = unclosed_comment_line(text)
        if n is not None:
            line = text.split("\n")[n - 1].strip()
            sys.stderr.write(f"unclosed HTML comment opened at line {n} of the section: "
                             f"{line[:80]!r} — everything after it would be hidden\n")
            sys.exit(3)
    sys.stdout.buffer.write(strip_html_comment_lines(text).encode("utf-8"))
