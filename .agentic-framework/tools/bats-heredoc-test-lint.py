#!/usr/bin/env python3
"""T-4521: find `@test` lines inside heredoc bodies of .bats files.

Bats before 1.11 finds tests by matching the SOURCE TEXT of a .bats file against
its test pattern, line by line, with no idea what a heredoc is. A fixture
written inside a test file:

    cat > "$WORK/suite/passing.bats" <<'EOF'
    @test "fixture passing test" { true; }
    EOF

is counted as a real test of the outer file. Two such fixtures with the same
name abort the whole run before anything executes:

    Error: Duplicate test name(s) in file "...": test_fixture_passing_test

Bats 1.11+ registers tests at run time, so the heredoc stays data and nothing
goes wrong there — which is why the suite was green on this host (1.13) and
dead on a clean Ubuntu 24.04 (apt ships 1.10). Origin: ring20's clean-room run.

Fix shape for an offender: keep `@test` out of the start of the heredoc line,
e.g. write the fixture through a helper that prefixes it at run time
(`printf '%s\\n' "@test ..."` is a quoted string, not a heredoc line).

Usage:
    tools/bats-heredoc-test-lint.py [PATH ...] [--json]

Exit 0 when clean, 1 when an `@test` sits in a heredoc body, 2 on bad usage.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import List, NamedTuple, Tuple

# Same patterns bats 1.10's bats-preprocess / bats-exec-suite match on.
_BATS_TEST_PATTERN = re.compile(r"^[ \t]*@test[ \t]+(.*[^ \t])[ \t]+\{(.*)$")
_BATS_TEST_PATTERN_COMMENT = re.compile(
    r"[ \t]*([^ \t()]+)[ \t]*\(?\)?[ \t]+\{[ \t]+#[ \t]*@test[ \t]*$")
# Heredoc delimiter word after `<<` / `<<-`: bare, 'quoted' or "quoted".
_DELIM = re.compile(r"-?[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


class Finding(NamedTuple):
    path: str
    line: int
    text: str


def _openers(line: str) -> List[Tuple[str, bool]]:
    """Heredoc openers on one line of shell, as (delimiter, dash), in order.

    Quote- and comment-aware: this repo's bats files are full of `<<EOF` inside
    test names and quoted command strings handed to classifiers. A regex over
    the raw line opens phantom heredocs there and then reports every real test
    below as a fixture (195 false findings on the first draft). `<<<` is a
    here-string and opens nothing.
    """
    out: List[Tuple[str, bool]] = []
    # Context stack: "'" / "$'" / '"' quotes, "(" a $( ) or ( ) group. Empty or
    # "(" on top means unquoted code, where `<<` is a real heredoc opener.
    # `"$(printf "... <<'EOF' ...")"` is the shape that needs the stack: the
    # inner quotes open a fresh context inside the outer double quote.
    st: List[str] = []
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        top = st[-1] if st else None
        if top == "'":
            if c == "'":
                st.pop()
        elif top in ('"', "$'"):
            if c == "\\":
                i += 1
            elif top == '"' and line.startswith("$(", i):
                st.append("(")
                i += 1
            elif c == top[-1]:
                st.pop()
        elif c == "\\":
            i += 1
        elif c == "$" and line[i + 1:i + 2] == "'":
            st.append("$'")
            i += 1
        elif c in ("'", '"', "("):
            st.append(c)
        elif c == ")" and top == "(":
            st.pop()
        elif c == "#" and (i == 0 or line[i - 1] in " \t;&|()"):
            break
        elif line.startswith("<<<", i):
            i += 2
        elif line.startswith("<<", i):
            m = _DELIM.match(line, i + 2)
            if m:
                out.append((m.group(2), line[i + 2:i + 3] == "-"))
                i = m.end() - 1
            else:
                i += 1
        i += 1
    return out


def scan(path: Path) -> List[Finding]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    found: List[Finding] = []
    pending: List[Tuple[str, bool]] = []
    for i, raw in enumerate(lines, start=1):
        if pending:
            delim, dash = pending[0]
            end = raw.lstrip("\t") if dash else raw
            if end == delim:
                pending.pop(0)
                continue
            if _BATS_TEST_PATTERN.match(raw) or _BATS_TEST_PATTERN_COMMENT.match(raw):
                found.append(Finding(str(path), i, raw.strip()))
            continue
        pending = _openers(raw)
    return found


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

    found: List[Finding] = []
    for f in files:
        found.extend(scan(f))

    if as_json:
        print(json.dumps({
            "verdict": "PASS" if not found else "FAIL",
            "files_scanned": len(files),
            "findings": [f._asdict() for f in found],
        }, indent=2))
    else:
        for f in found:
            print(f"{f.path}:{f.line}: @test inside a heredoc (bats <1.11 counts it "
                  f"as a real test): {f.text}")
        print(f"scanned {len(files)} file(s) | heredoc @test lines {len(found)}")
        if not found:
            print("  clean: no @test inside a heredoc")
    return 0 if not found else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
