#!/usr/bin/env python3
"""T-3138: find bats assertions that cannot fail.

Bash exempts a command from `errexit` when "the command's return value is being
inverted with `!`" (bash manual, `set -e`). Bats runs each `@test` body under
`set -e` and reports the body's exit status. Put those two together:

    @test "x" {
        run some_command
        ! echo "$output" | grep -q "must not appear"   # <- CANNOT fail this test
        [ "$status" -eq 0 ]                            # <- this is the verdict
    }

The `!` line is exempt from errexit, so a non-zero result does not abort the
body; and it is not the last statement, so its status is not the body's status
either. The assertion is inert. It reads exactly like a working one.

A `!`-inverted line that IS the last statement of its body is fine — bats takes
the body's exit status from it. Those are counted and NOT flagged.

This is a lint over source text, not a runtime check, because the defect is
invisible at runtime by construction: a dead assertion and a passing assertion
produce identical output.

Usage:
    tools/bats-dead-negation-lint.py [PATH ...] [--json]

Exit 0 when nothing is flagged, 1 when dead assertions are found, 2 on bad usage.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Iterator, List, NamedTuple

_TEST_START = re.compile(r"^\s*@test\b")
# `<<EOF`, `<<-EOF`, `<<'EOF'`, `<<"EOF"`. `<<<` is a here-STRING, not a heredoc,
# and consumes no following lines.
#
# Distinguishing them needs BOTH a lookbehind and a lookahead. A lookahead alone
# still matches `<<< hi`: starting one character in, the second and third `<` are
# a valid two-char `<<` with a space after it, so (?!<) is satisfied and `hi`
# becomes a delimiter that swallows the rest of the file as data — every real
# finding below it silently disappears.
#
# Two rounds of measurement were needed to get here, and each was prompted by a
# control rather than by reading the regex. Mutation testing surfaced the first:
# deleting the guard outright left the suite green, because the fixture used a
# QUOTED here-string that the backreference rejected for an unrelated reason, so
# the guard was never exercised at all. Switching the fixture to `<<< hi` then
# went red against the lookahead-only form, which is what found this.
#
# Consumers of a finding: the reported line is the FIRST PHYSICAL line of a
# possibly line-continued statement. Replacing that line alone orphans the
# continuation, which bash then runs as its own command. T-3138's own sweep did
# exactly that at two sites before this note existed.
_HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def _top_level_or(stmt: str) -> bool:
    """True when the statement has a `||` outside quotes.

    `! cmd || { echo ...; return 1; }` is NOT dead. The `!` exempts its own
    pipeline from errexit, but the pipeline is not the last command of the `||`
    list — whatever follows the final `||` is checked normally, and in this repo
    that branch is always a `{ ...; return 1; }` or `(...; false)` guard. Four
    such sites were flagged by the first draft of this lint and are live.

    `&&` is deliberately NOT treated the same way. In `! cmd && cmd2`, the
    failure that matters (cmd unexpectedly succeeding) makes `! cmd` return 1,
    which short-circuits — so the status that reaches errexit IS the inverted
    one, and IS exempt. The asymmetry is real; it was measured, not assumed.
    """
    q = None
    i = 0
    while i < len(stmt):
        c = stmt[i]
        if q:
            if c == "\\" and q == '"':
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "|" and stmt[i + 1:i + 2] == "|":
            return True
        i += 1
    return False


class Finding(NamedTuple):
    path: str
    line: int
    test: str
    text: str


def _strip_heredoc_bodies(lines: List[str]) -> List[bool]:
    """Mark lines that are heredoc *body* (data, not code).

    Without this the lint reads `! foo` inside a heredoc as an assertion. Bats
    suites in this repo write fixture scripts and expected-output blocks via
    heredocs constantly, so this is not a hypothetical.
    """
    in_body: List[bool] = [False] * len(lines)
    delim: str | None = None
    dash = False
    for i, raw in enumerate(lines):
        if delim is not None:
            in_body[i] = True
            end = raw.strip() if dash else raw.rstrip("\n")
            if end == delim or (dash and raw.strip() == delim):
                in_body[i] = True  # the terminator itself is not code
                delim = None
            continue
        m = _HEREDOC.search(raw)
        if m:
            delim = m.group(2)
            dash = "<<-" in raw
    return in_body


def _join_continuations(lines: List[str], is_body: List[bool]) -> List[str]:
    """Fold `foo \\` + next line into one logical statement, in place.

    A continued statement is one command, so its `!` may well be the block's
    last statement even though the physical `!` line is not the last physical
    line. Without this the lint reports a live assertion as dead — and the
    conversion built on that report would splice `if` into the middle of a
    continuation and break the file. Four sites here are continued.
    """
    out = list(lines)
    i = 0
    while i < len(out) - 1:
        if not is_body[i] and out[i].rstrip().endswith("\\"):
            merged = out[i].rstrip()[:-1].rstrip() + " " + out[i + 1].strip()
            out[i] = merged
            out[i + 1] = ""          # keep indices stable: line numbers are reported
            is_body[i + 1] = True    # and must not be re-read as a statement
            continue
        i += 1
    return out


def _blocks(lines: List[str]) -> Iterator[tuple[int, int, str]]:
    """Yield (body_start, body_end_exclusive, test_name) for each @test block.

    Block end is the first line that is exactly `}` at column 0. Every bats file
    in this repo closes that way; a file that does not simply yields one long
    block, which over-reports rather than under-reports — the safe direction for
    a lint whose job is to stop things being missed.
    """
    i = 0
    n = len(lines)
    while i < n:
        if _TEST_START.match(lines[i]):
            name = lines[i].strip()
            j = i + 1
            while j < n and lines[j].rstrip() != "}":
                j += 1
            yield i + 1, j, name
            i = j
        i += 1


def _last_statement(lines: List[str], start: int, end: int,
                    is_body: List[bool]) -> int | None:
    for k in range(end - 1, start - 1, -1):
        s = lines[k].strip()
        if s and not s.startswith("#") and not is_body[k]:
            return k
    return None


def scan(path: Path) -> tuple[List[Finding], int]:
    """Return (dead assertions, count of live `!` assertions).

    Live means: final position in its block, or guarded by a top-level `||`.
    """
    raw = path.read_text(errors="replace").splitlines()
    is_body = _strip_heredoc_bodies(raw)
    lines = _join_continuations(raw, is_body)
    dead: List[Finding] = []
    live = 0
    for start, end, name in _blocks(lines):
        last = _last_statement(lines, start, end, is_body)
        for k in range(start, end):
            if is_body[k]:
                continue
            s = lines[k].strip()
            # `!=` is a comparison operator, not the negation keyword. `!` must
            # be followed by whitespace or `[` to be the reserved word.
            if not s.startswith("!") or re.match(r"!\s*=", s):
                continue
            if not re.match(r"!(\s|\[)", s):
                continue
            if k == last or _top_level_or(s):
                live += 1
            else:
                dead.append(Finding(str(path), k + 1, name, s))
    return dead, live


def main(argv: List[str]) -> int:
    as_json = "--json" in argv
    args = [a for a in argv if not a.startswith("--")]
    roots = [Path(a) for a in args] or [Path("tests")]
    files: List[Path] = []
    for r in roots:
        if r.is_dir():
            files.extend(sorted(r.rglob("*.bats")))
        elif r.suffix == ".bats":
            files.append(r)
    if not files:
        print(f"no .bats files under {', '.join(map(str, roots))}", file=sys.stderr)
        return 2

    dead: List[Finding] = []
    live = 0
    for f in files:
        d, l = scan(f)
        dead.extend(d)
        live += l

    if as_json:
        print(json.dumps({
            "verdict": "PASS" if not dead else "FAIL",
            "files_scanned": len(files),
            "dead": len(dead),
            "live_negations": live,
            "findings": [f._asdict() for f in dead],
        }, indent=2))
    else:
        for f in dead:
            print(f"{f.path}:{f.line}: dead negation (not last statement): {f.text}")
        touched = len({f.path for f in dead})
        print(f"scanned {len(files)} file(s) | dead {len(dead)} in {touched} file(s) "
              f"| live (final or ||-guarded) {live}")
        if not dead:
            print("  clean: no assertions in dead position")
    return 0 if not dead else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
