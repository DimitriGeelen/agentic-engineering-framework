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


if __name__ == "__main__":
    sys.stdout.write(strip_html_comment_lines(sys.stdin.read()))
