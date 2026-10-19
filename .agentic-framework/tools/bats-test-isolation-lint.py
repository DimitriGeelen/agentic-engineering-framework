#!/usr/bin/env python3
"""T-4379: find bats tests that are pointed at THIS repo instead of a private one.

Three defect classes recur in this suite (arc-026, docs/reports/T-4376-test-suite-refactor.md):

  live-audit       a test runs agents/audit/audit.sh, `fw doctor`, `fw audit` or
                   `fw handover` with no temp PROJECT_ROOT in scope. It audits the
                   live corpus, races the repo-wide audit lock, and its verdict moves
                   with the corpus (T-4372's ratchet loop, the 32 files of T-4401).
  repo-state       a test joins a repo-root variable to `/.framework.yaml` or
                   `/.context/` — it reads (or writes) this project's own config or
                   memory, so the result depends on this host (the t4347 key-0 test).
  fw-no-temp-root  a test drives bin/fw (any other verb) with no temp PROJECT_ROOT in
                   scope. bin/fw falls back to its own repo when nothing else
                   resolves (bin/fw:94), so the command runs against the live project
                   and passes (T-2746, T-4313).

"In scope" means an assignment `PROJECT_ROOT=<value>` (export or not, inline on the
same line or earlier in the same @test/function, in setup()/setup_file(), or at file
level) whose value is not a repo-root expression. Anything that is not recognisably
this repo counts as a temp root: the lint prefers missing a case to crying wolf.

Deliberate exceptions carry an allow comment, at line level (same line or the line
above), block level (anywhere inside the @test/function) or file level (outside any
block):

    # test-isolation: allow live-audit — pins the wiring of the real cron line

`<rule>` is one of the three names above, or `all`.

Baseline (ratchet): tests/lint/test-isolation-baseline.txt holds `<rule> <path> <count>`
for the offenders that existed when the lint landed. A file at or under its count is
not reported; a count above it, or an offender in a file with no entry, is NEW.
`--write-baseline` regenerates the file from the current corpus.

Usage:
    tools/bats-test-isolation-lint.py [PATH ...] [--json] [--all]
        [--baseline FILE | --no-baseline] [--write-baseline]

Exit 0 when nothing is new, 1 when new offenders are found, 2 on bad usage.
Wired into `fw test lint` as a WARN (it starts advisory; the baseline is the work
queue for T-4401 / T-4378).
"""
from __future__ import annotations

import importlib.util
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent
_DEFAULT_BASELINE = _REPO / "tests" / "lint" / "test-isolation-baseline.txt"

# Reuse the dead-negation lint's heredoc and continuation handling: the same parser
# questions, already answered and pinned there (T-3138).
_spec = importlib.util.spec_from_file_location("_dnl", _HERE / "bats-dead-negation-lint.py")
assert _spec is not None and _spec.loader is not None
_dnl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_dnl)  # type: ignore[union-attr]

RULES = ("live-audit", "repo-state", "fw-no-temp-root")

_ALLOW = re.compile(r"#\s*test-isolation:\s*allow\s+([a-z-]+)")
_BLOCK_START = re.compile(
    r"^(@test\b.*|(?:function\s+)?([A-Za-z_][A-Za-z0-9_:.-]*)\s*\(\)\s*\{?\s*$|function\s+([A-Za-z_][A-Za-z0-9_]*)\b.*)")
_ASSIGN = re.compile(r"(?:^|[\s;&|(])(?:export\s+|local\s+|declare\s+(?:-x\s+)?)?([A-Za-z_][A-Za-z0-9_]*)=(\S*)")
_PR_ASSIGN = re.compile(r"(?:^|[\s;&|(])(?:export\s+|local\s+)?PROJECT_ROOT=(\"[^\"]*\"|'[^']*'|\S*)")

# A value that IS the repo root: <bats dir>/../.. ending there, or git's toplevel.
_REPO_ROOT_VALUE = re.compile(
    r"(BATS_TEST_DIRNAME\}?|dirname\s+\"?\$\{?BATS_TEST_FILENAME\}?\"?\s*\)\"?)/\.\./\.\.\"?\s*(&&\s*pwd\s*\)|\)|\"|$)"
    r"|BATS_TEST_DIRNAME\}?/\.\./\.\.\"?$"
    r"|git\s+rev-parse\s+--show-toplevel"
    r"|/opt/999-Agentic-Engineering-Framework\"?$")
_FW_PATH_VALUE = re.compile(r"/bin/fw\"?'?$")
_AUDIT_PATH_VALUE = re.compile(r"agents/(audit/audit|handover/handover)\.sh\"?'?$")

_LIVE_VERBS = {"doctor", "audit", "handover"}
_HARMLESS = {"help", "--help", "-h", "version", "--version"}
# Words that, in front of a path, mean "this is data, not a command being run".
_NOT_A_RUN = re.compile(r"^(grep|egrep|sed|awk|cat|head|tail|wc|test|\[|\[\[|echo|printf|source|\.|ls|cp|mv|rm|"
                        r"chmod|ln|diff|cmp|md5sum|sha256sum|stat|readlink|realpath|dirname|basename|file|bash\s+-n|"
                        r"shellcheck|python3\s+-c|git)$")


class Finding(NamedTuple):
    rule: str
    path: str
    line: int
    test: str
    text: str


def _rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(_REPO))
    except ValueError:
        return str(path)


def _blocks(lines: List[str], is_body: List[bool]) -> List[Tuple[int, int, str]]:
    """(start, end_exclusive, header) for each @test / function at column 0."""
    out = []
    i, n = 0, len(lines)
    while i < n:
        s = lines[i]
        if not is_body[i] and s[:1] not in (" ", "\t", "#", "") and _BLOCK_START.match(s.strip()) \
                and ("{" in s or (i + 1 < n and lines[i + 1].strip() == "{")):
            j = i + 1
            while j < n and lines[j].rstrip() != "}":
                j += 1
            out.append((i, j, s.strip()))
            i = j
        i += 1
    return out


class _Vars:
    def __init__(self) -> None:
        self.repo: Set[str] = {"FRAMEWORK_ROOT"}
        self.fw: Set[str] = set()
        self.audit: Set[str] = set()

    def is_repo_value(self, v: str) -> bool:
        if _REPO_ROOT_VALUE.search(v):
            return True
        m = re.fullmatch(r"[\"']?\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?[\"']?", v.strip())
        return bool(m and m.group(1) in self.repo)

    def _refers_repo(self, v: str) -> bool:
        if re.search(r"BATS_TEST_(DIRNAME|FILENAME)|git\s+rev-parse|/opt/999-", v):
            return True
        return any(re.search(r"\$\{?" + re.escape(r) + r"\b", v) for r in self.repo)

    def learn(self, stmt: str) -> None:
        for name, val in _ASSIGN.findall(stmt):
            if val.lstrip("\"").startswith(("$(", "`")):
                continue  # captured OUTPUT of a command, not a path
            if name == "PROJECT_ROOT":
                if self.is_repo_value(val):
                    self.repo.add(name)
                continue
            if self.is_repo_value(val):
                self.repo.add(name)
            elif _FW_PATH_VALUE.search(val) and self._refers_repo(val):
                self.fw.add(name)
            elif _AUDIT_PATH_VALUE.search(val) and self._refers_repo(val):
                self.audit.add(name)


_CD = re.compile(r"(?:^|[\s;&|(])(?:cd|pushd)\s+(\"[^\"]*\"|'[^']*'|[^\s;&|)]+)")


def _subst_spans(s: str) -> List[Tuple[int, int]]:
    """Spans of every top-level $(...): a `cd` inside a command substitution (the
    `X="$(cd "$(dirname ...)/../.." && pwd)"` idiom) does not move the caller."""
    spans, depth, start, i = [], 0, 0, 0
    while i < len(s):
        if s.startswith("$(", i):
            if depth == 0:
                start = i
            depth += 1; i += 2; continue
        if depth and s[i] == "(":
            depth += 1
        elif depth and s[i] == ")":
            depth -= 1
            if depth == 0:
                spans.append((start, i + 1))
        i += 1
    if depth:
        spans.append((start, len(s)))
    return spans


_CD = re.compile(r"(?:^|[\s;&|(])(?:cd|pushd)\s+(\"[^\"]*\"|'[^']*'|[^\s;&|)]+)")


_CD = re.compile(r"(?:^|[\s;&|(])(?:cd|pushd)\s+(\"[^\"]*\"|'[^']*'|[^\s;&|)]+)")


def _subst_spans(s: str) -> List[Tuple[int, int]]:
    """Spans of every top-level $(...): a `cd` inside a command substitution (the
    `X="$(cd "$(dirname ...)/../.." && pwd)"` idiom) does not move the caller."""
    spans, depth, start, i = [], 0, 0, 0
    while i < len(s):
        if s.startswith("$(", i):
            if depth == 0:
                start = i
            depth += 1; i += 2; continue
        if depth and s[i] == "(":
            depth += 1
        elif depth and s[i] == ")":
            depth -= 1
            if depth == 0:
                spans.append((start, i + 1))
        i += 1
    if depth:
        spans.append((start, len(s)))
    return spans


_CD = re.compile(r"(?:^|[\s;&|(])(?:cd|pushd)\s+(\"[^\"]*\"|'[^']*'|[^\s;&|)]+)")


def _strip_subst(s: str) -> str:
    """Drop every $(...) span: a `cd` inside a command substitution (the
    `X="$(cd "$(dirname ...)/../.." && pwd)"` idiom) does not move the caller."""
    out, depth, i = [], 0, 0
    while i < len(s):
        if s.startswith("$(", i):
            depth += 1; i += 2; continue
        if depth and s[i] == "(":
            depth += 1
        elif depth and s[i] == ")":
            depth -= 1; i += 1; continue
        if not depth:
            out.append(s[i])
        i += 1
    return "".join(out)


_UNSET = re.compile(r"(?:^|[\s;&|(])unset\s+(?:-v\s+)?(?:[A-Za-z_][A-Za-z0-9_]*\s+)*PROJECT_ROOT\b")


def _root_event(stmt: str, v: _Vars) -> Optional[bool]:
    """What this statement does to the project root, by its LAST event:
    True = a temp root (PROJECT_ROOT=<not the repo>, or `cd <not the repo>` —
    bin/fw resolves the project from the working directory); False = the repo
    (PROJECT_ROOT=<repo>, `cd <repo>`, `unset PROJECT_ROOT`); None = no event."""
    events: List[Tuple[int, bool]] = []
    for m in _PR_ASSIGN.finditer(stmt):
        val = m.group(1)
        if val:
            events.append((m.start(), not v.is_repo_value(val)))
    for m in _UNSET.finditer(stmt):
        events.append((m.start(), False))
    spans = _subst_spans(stmt)
    for m in _CD.finditer(stmt):
        val = m.group(1)
        if val in ("-", "..") or any(a <= m.start() < b for a, b in spans):
            continue
        events.append((m.start(), not v.is_repo_value(val)))
    if not events:
        return None
    return max(events)[1]


_SHELL_C = re.compile(r"(?:^|\s)(?:bash|sh)\s+(?:-[a-z]+\s+)*-c\s+(\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*')")


def _parse(s: str, i: int, stop: str, parts: List[str]) -> int:
    """Split s[i:] into simple commands, appending them to parts; return the index
    after `stop` (or len(s)).

    Quoted text is DATA: `assert_allowed "cd x && bin/fw doctor"` hands a command
    line to a classifier under test and must not read as a run. Command
    substitution is CODE wherever it appears, double quotes included, so it is
    parsed recursively in its own quoting context: `out="$(bash audit.sh)"` runs.
    The raw text is kept in each segment so `bash -c "<script>"` can be re-split.
    """
    cur: List[str] = []
    dq = False
    n = len(s)
    while i < n:
        c = s[i]
        if c == "\\" and i + 1 < n:
            cur.append(s[i:i + 2]); i += 2; continue
        if s.startswith("$(", i) and not s.startswith("$((", i):
            j = _parse(s, i + 2, ")", parts)
            cur.append(s[i:j]); i = j; continue
        if c == "`":
            j = _parse(s, i + 1, "`", parts)
            cur.append(s[i:j]); i = j; continue
        if dq:
            cur.append(c)
            if c == '"':
                dq = False
            i += 1
            continue
        if c == stop:
            parts.append("".join(cur))
            return i + 1
        if c == "'":
            j = s.find("'", i + 1)
            j = n if j < 0 else j + 1
            cur.append(s[i:j]); i = j; continue
        if c == '"':
            dq = True
            cur.append(c)
        elif c in ";|&()":
            parts.append("".join(cur)); cur = []
        else:
            cur.append(c)
        i += 1
    parts.append("".join(cur))
    return n


def _segments(stmt: str) -> List[str]:
    parts: List[str] = []
    _parse(stmt, 0, "\0", parts)
    out: List[str] = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        out.append(p)
        m = _SHELL_C.search(p)
        if m:  # the script of `bash -c` / `sh -c` is code
            out.extend(_segments(m.group(1)[1:-1]))
    return out


def _command_words(seg: str) -> List[str]:
    """Drop leading assignments and transparent prefixes; return the words left."""
    words = seg.split()
    k = 0
    while k < len(words):
        w = words[k]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w):
            k += 1
        elif w in ("run", "!", "env", "exec", "command", "nohup", "bash", "sh", "then", "do", "else",
                   "if", "while", "until", "time", "-i") or re.fullmatch(r"--?(separate-stderr|\d+)", w):
            k += 1
        elif w == "timeout":
            k += 1
            while k < len(words) and re.fullmatch(r"-\S+|\d+[smh]?", words[k]):
                k += 1
        else:
            break
    return words[k:]


def _classify(seg: str, v: _Vars) -> Optional[str]:
    words = _command_words(seg)
    if not words:
        return None
    raw_head = words[0]
    if raw_head[:1] in "\"'" and not (len(raw_head) > 1 and raw_head.endswith(raw_head[0])):
        return None  # first word of a multi-word quoted string: data, not a command
    head = raw_head.strip("\"'")
    if _NOT_A_RUN.match(head):
        return None
    rest = [w.strip("\"'") for w in words[1:]]
    var = re.fullmatch(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?", head)
    is_audit = head.endswith(("agents/audit/audit.sh", "agents/handover/handover.sh")) or \
        bool(var and var.group(1) in v.audit)
    is_fw = (head.endswith("/bin/fw") and (head.startswith("$") or head.startswith("bin/")
                                           or head.startswith("./bin/")) and
             not head.startswith("$" + "{TMP")) or head == "bin/fw" or bool(var and var.group(1) in v.fw)
    if is_fw and head.startswith("$") and not var:
        # "$X/bin/fw": only this repo's fw counts, not a fixture's vendored copy.
        m = re.match(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/bin/fw$", head)
        is_fw = bool(m and m.group(1) in v.repo) or bool(
            re.match(r"\$\{?BATS_TEST_DIRNAME\}?/\.\./\.\./bin/fw$", head))
    if any(w in ("--help", "-h") for w in rest):
        return None
    if is_audit:
        if rest and rest[0] in _HARMLESS:
            return None
        return "live-audit"
    if is_fw:
        if not rest or rest[0] in _HARMLESS:
            return None
        if "--target" in rest or (rest[0] in ("init", "upgrade") and len(rest) > 1
                                  and not rest[1].startswith("-")):
            return None  # an explicit target directory is the project root
        return "live-audit" if rest[0] in _LIVE_VERBS else "fw-no-temp-root"
    return None


def _allowed(rule: str, tags: Set[str]) -> bool:
    return rule in tags or "all" in tags


def scan(path: Path) -> List[Finding]:
    raw = path.read_text(errors="replace").splitlines()
    is_body = _dnl._strip_heredoc_bodies(raw)
    lines = _dnl._join_continuations(raw, list(is_body))
    blocks = _blocks(lines, is_body)
    in_block: Dict[int, Tuple[int, int, str]] = {}
    for b in blocks:
        for k in range(b[0], b[1] + 1):
            in_block[k] = b

    v = _Vars()
    file_allow: Set[str] = set()
    file_temp: Optional[bool] = None
    setup_temp: Optional[bool] = None
    # Pass 1: file-level facts — variables, allow comments, temp roots that cover
    # every test (file level, setup, setup_file).
    for k, s in enumerate(lines):
        if is_body[k]:
            continue
        st = s.strip()
        m = _ALLOW.search(st)
        if m and k not in in_block:
            file_allow.add(m.group(1))
        if not st or st.startswith("#"):
            continue
        v.learn(st)
        ev = _root_event(st, v)
        if ev is not None:
            b = in_block.get(k)
            if b is None:
                file_temp = ev
            elif re.match(r"^(function\s+)?(setup|setup_file)\b", b[2]):
                setup_temp = ev

    findings: List[Finding] = []
    block_cache: Dict[int, Tuple[Set[str], List[Tuple[int, bool]]]] = {}
    for k, s in enumerate(lines):
        if is_body[k]:
            continue
        st = s.strip()
        if not st or st.startswith("#"):
            continue
        b = in_block.get(k)
        if b is not None and k == b[0]:
            continue
        candidates: List[str] = []
        for m in re.finditer(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?\"?/\.(framework\.yaml|context/)", st):
            if m.group(1) in v.repo:
                candidates.append("repo-state")
        if re.search(r"BATS_TEST_DIRNAME\}?\"?/\.\./\.\./\.(framework\.yaml|context/)", st):
            candidates.append("repo-state")
        candidates = candidates[:1]
        for seg in _segments(st):
            r = _classify(seg, v)
            if r:
                candidates.append(r)
                break
        if not candidates:
            continue

        # Allow tags: line (same / previous physical line), block, file.
        tags = set(file_allow)
        for kk in (k, k - 1):
            if 0 <= kk < len(raw):
                m = _ALLOW.search(raw[kk])
                if m:
                    tags.add(m.group(1))
        if b is not None:
            if b[0] not in block_cache:
                bt, temps = set(), []
                for kk in range(b[0], b[1]):
                    m = _ALLOW.search(raw[kk])
                    if m:
                        bt.add(m.group(1))
                    ev = None if is_body[kk] else _root_event(lines[kk], v)
                    if ev is not None:
                        temps.append((kk, ev))
                block_cache[b[0]] = (bt, temps)
            tags |= block_cache[b[0]][0]

        # The nearest event wins: this line, then earlier in the block, then
        # setup, then file level. A test that `cd "$FRAMEWORK_ROOT"`s after a
        # temp setup is pointed at the repo again.
        rooted = _root_event(st, v)
        if rooted is None and b is not None:
            prior = [ev for t, ev in block_cache[b[0]][1] if t < k]
            rooted = prior[-1] if prior else None
        if rooted is None:
            rooted = setup_temp if setup_temp is not None else file_temp
        rooted = bool(rooted)
        name = b[2] if b else "(file level)"
        for rule in dict.fromkeys(candidates):
            if rule != "repo-state" and rooted:
                continue
            if _allowed(rule, tags):
                continue
            findings.append(Finding(rule, _rel(path), k + 1, name, st[:160]))
    return findings


def _read_baseline(p: Path) -> Dict[Tuple[str, str], int]:
    out: Dict[Tuple[str, str], int] = {}
    if not p.is_file():
        return out
    for ln in p.read_text().splitlines():
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        parts = ln.split()
        if len(parts) == 3 and parts[0] in RULES and parts[2].isdigit():
            out[(parts[0], parts[1])] = int(parts[2])
    return out


def main(argv: List[str]) -> int:
    as_json = "--json" in argv
    show_all = "--all" in argv
    write = "--write-baseline" in argv
    no_base = "--no-baseline" in argv
    baseline = _DEFAULT_BASELINE
    args: List[str] = []
    it = iter(argv)
    for a in it:
        if a == "--baseline":
            nxt = next(it, None)
            if nxt is None:
                print("--baseline needs a file", file=sys.stderr)
                return 2
            baseline = Path(nxt)
        elif a.startswith("--"):
            if a not in ("--json", "--all", "--write-baseline", "--no-baseline"):
                print(f"unknown option {a}", file=sys.stderr)
                return 2
        else:
            args.append(a)
    roots = [Path(a) for a in args] or [_REPO / "tests"]
    files: List[Path] = []
    for r in roots:
        if r.is_dir():
            files.extend(sorted(r.rglob("*.bats")))
        elif r.suffix == ".bats":
            files.append(r)
    if not files:
        print(f"no .bats files under {', '.join(map(str, roots))}", file=sys.stderr)
        return 2

    findings: List[Finding] = []
    for f in files:
        findings.extend(scan(f))
    counts = Counter((f.rule, f.path) for f in findings)

    if write:
        body = ["# T-4379: bats test-isolation lint baseline — `<rule> <path> <count>`.",
                "# Offenders that existed when the lint landed. Shrink only: fix a test, then",
                "# regenerate with `python3 tools/bats-test-isolation-lint.py tests/ --write-baseline`."]
        body += [f"{r} {p} {n}" for (r, p), n in sorted(counts.items())]
        baseline.write_text("\n".join(body) + "\n")
        print(f"wrote {len(counts)} entr{'y' if len(counts) == 1 else 'ies'} to {baseline}")
        return 0

    base = {} if no_base else _read_baseline(baseline)
    new: List[Finding] = []
    seen: Counter = Counter()
    for f in findings:
        key = (f.rule, f.path)
        seen[key] += 1
        if counts[key] > base.get(key, 0):
            new.append(f)
    per_rule = Counter(f.rule for f in findings)
    new_files = {(f.rule, f.path) for f in new}

    if as_json:
        print(json.dumps({
            "verdict": "PASS" if not new else "WARN",
            "files_scanned": len(files),
            "total": len(findings),
            "per_rule": {r: per_rule.get(r, 0) for r in RULES},
            "new": len(new),
            "findings": [f._asdict() for f in (findings if show_all else new)],
        }, indent=2))
    else:
        for f in (findings if show_all else new):
            tag = "" if show_all else " [new]"
            print(f"{f.path}:{f.line}: {f.rule}{tag}: {f.text}")
        for r, p in sorted(new_files):
            print(f"  {r} {p}: {counts[(r, p)]} now, baseline {base.get((r, p), 0)}")
        rule_txt = " ".join(f"{r}={per_rule.get(r, 0)}" for r in RULES)
        print(f"scanned {len(files)} file(s) | offenders {len(findings)} ({rule_txt}) | new {len(new)}")
        if not new:
            print("  clean: no offenders beyond the baseline")
    return 0 if not new else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
