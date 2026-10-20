#!/usr/bin/env python3
"""Silent-zero store-grep detector (T-2680, Slice 1 of the T-2679 GO).

Static scan for the bug family behind T-2676 (harvest.sh, 4-space greps vs a
2-space store: "No learnings found" always) and T-2677 (audit graduation
counter, 2-space-only ID grep counted 0 of 550). Both failed with exit 0 and
plausible output, for months, because a grep that matches nothing is
indistinguishable from a store that holds nothing.

Two rules, both advisory (callers WARN / CONCERN, never FAIL):

  fixed-indent-store-grep  grep whose pattern pins a YAML key at an exact
                           indent (`^` + 2 or more literal spaces + `key:`)
                           against a YAML store. The store's indentation is a
                           serializer choice, not a contract; when it changes
                           the grep silently matches nothing.
  zero-fallback-count      `grep -c` against a `.context/` store whose failure
                           is folded into 0 (`|| echo 0`, `|| n=0`). "Store
                           unreadable" and "pattern stopped matching" both
                           read as "zero items".

Indent-tolerant forms (`^[[:space:]]*`, `^ *`, `^\\s*`) are not flagged; the
fix for a finding is usually one of them, or a YAML parse.

Usage:
  silent_zero_scan.py [--root DIR] [PATH ...]   default: lib agents bin
Output: one `path:line: rule: snippet` per finding. Exit 0 always (2 on usage
error) — the count is the signal, the exit code is not.
"""
from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path

DEFAULT_PATHS = ("lib", "agents", "bin")
SKIP_DIRS = {".agentic-framework", "__pycache__", "node_modules", ".git"}

# Words that name a .context/ store when they appear in a variable name.
_STORE_WORDS = re.compile(
    r"learning|pattern|decision|concern|practice|inbox|gap|episodic|handover|"
    r"focus|session|assumption|directive|observation",
    re.IGNORECASE,
)
_STORE_RHS = re.compile(r"\.context|CONTEXT_DIR|\.ya?ml\b")
# `^` + 2+ literal spaces + optional list dash + a YAML key, and NOT followed by
# a quantifier that would make the run of spaces tolerant (`^  *`, `^ +`).
_FIXED_INDENT = re.compile(r"^\^( {2,})(?![*+?{]|\\[+?{])(- )?[A-Za-z_\[\(][^:]*:")
_ZERO_FALLBACK = re.compile(r"\|\|\s*(echo\s+[\"']?0[\"']?|[A-Za-z_][A-Za-z0-9_]*=0)\b")
_VAR_REF = re.compile(r"^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?$")
_GREP = re.compile(r"(?<![\w-])grep\b")
_TERMINATORS = {"|", "||", "&&", ";", ")", "(", "&", ";;", "|&"}


def _assignments(text: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for m in re.finditer(
        r"^\s*(?:local\s+|export\s+|readonly\s+|declare\s+(?:-\w+\s+)?)?"
        r"([A-Za-z_][A-Za-z0-9_]*)=(.*)$",
        text,
        re.MULTILINE,
    ):
        out.setdefault(m.group(1), []).append(m.group(2))
    return out


def _is_store_operand(op: str, assigns: dict[str, list[str]], *, strict: bool) -> bool:
    """strict=True: only a .context/ store (literal or resolved).
    strict=False: any YAML file, or a variable that plausibly names one."""
    if ".context" in op or "CONTEXT_DIR" in op:
        return True
    if not strict and re.search(r"\.ya?ml\b", op):
        return True
    m = _VAR_REF.match(op.strip("\"'"))
    if not m:
        return False
    name = m.group(1)
    for rhs in assigns.get(name, []):
        if ".context" in rhs or "CONTEXT_DIR" in rhs:
            return True
        if not strict and _STORE_RHS.search(rhs):
            return True
    if _STORE_WORDS.search(name):
        return True
    return not strict and bool(re.search(r"_(file|FILE)$", name))


def _parse_grep(tokens: list[str]) -> tuple[bool, list[str], list[str]]:
    """Return (count_flag, patterns, operands) for tokens following `grep`."""
    count = False
    patterns: list[str] = []
    rest: list[str] = []
    i = 0
    opts_done = False
    while i < len(tokens):
        t = tokens[i]
        if t in _TERMINATORS:
            break
        if not opts_done and t == "--":
            opts_done = True
        elif not opts_done and t in ("-e", "--regexp"):
            if i + 1 < len(tokens):
                patterns.append(tokens[i + 1])
            i += 1
        elif not opts_done and t.startswith("--"):
            if t == "--count":
                count = True
            elif t.startswith("--regexp="):
                patterns.append(t.split("=", 1)[1])
        elif not opts_done and t.startswith("-") and len(t) > 1:
            flags = t[1:]
            if "c" in flags:
                count = True
            if flags.endswith("e") and i + 1 < len(tokens):
                patterns.append(tokens[i + 1])
                i += 1
            elif flags.endswith(("m", "A", "B", "C")) and i + 1 < len(tokens) and tokens[i + 1].isdigit():
                i += 1
        else:
            rest.append(t)
        i += 1
    if not patterns and rest:
        patterns.append(rest.pop(0))
    operands = [r for r in rest if not re.fullmatch(r"\d*>&?\d*|/dev/null|2>/dev/null", r)]
    operands = [r for r in operands if not r.startswith((">", "<", "2>"))]
    return count, patterns, operands


def _lex(fragment: str) -> list[str] | None:
    lex = shlex.shlex(fragment, posix=True, punctuation_chars="|&;()<>")
    lex.whitespace_split = True
    lex.commenters = ""
    try:
        return list(lex)
    except ValueError:
        return None


def _tokens(fragment: str) -> list[str] | None:
    """Tokenise the text after `grep`. A grep nested in `"$( ... )"` leaves the
    closing quote unbalanced; retry on prefixes cut at each terminator."""
    toks = _lex(fragment)
    if toks is not None:
        return toks
    for i, ch in enumerate(fragment):
        if ch in ")|;&":
            toks = _lex(fragment[:i])
            if toks:
                return toks
    return None


def scan_text(text: str, path: str = "<text>") -> list[tuple[str, int, str, str]]:
    """Return (path, lineno, rule, snippet) findings for one file's text."""
    findings: list[tuple[str, int, str, str]] = []
    assigns = _assignments(text)
    for lineno, line in enumerate(text.splitlines(), start=1):
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#") or "grep" not in line:
            continue
        snippet = stripped[:160]
        for m in _GREP.finditer(line):
            toks = _tokens(line[m.end():])
            if not toks:
                continue
            count, patterns, operands = _parse_grep(toks)
            if not operands:
                continue  # reads stdin: not a store grep
            if any(_FIXED_INDENT.match(p) for p in patterns) and any(
                _is_store_operand(o, assigns, strict=False) for o in operands
            ):
                findings.append((path, lineno, "fixed-indent-store-grep", snippet))
            if count and _ZERO_FALLBACK.search(line[m.end():]) and any(
                _is_store_operand(o, assigns, strict=True) for o in operands
            ):
                findings.append((path, lineno, "zero-fallback-count", snippet))
    return findings


def _iter_files(root: Path, paths: list[str]):
    for p in paths:
        base = (root / p) if not Path(p).is_absolute() else Path(p)
        if base.is_file():
            yield base
            continue
        if not base.is_dir():
            continue
        for f in sorted(base.rglob("*")):
            if not f.is_file() or SKIP_DIRS.intersection(f.relative_to(root).parts if f.is_relative_to(root) else f.parts):
                continue
            if f.suffix == ".sh" or (f.suffix == "" and f.parent.name == "bin"):
                yield f


def scan_paths(root: Path, paths: list[str]) -> list[tuple[str, int, str, str]]:
    out: list[tuple[str, int, str, str]] = []
    for f in _iter_files(root, paths):
        try:
            text = f.read_text(errors="replace")
        except OSError:
            continue
        rel = str(f.relative_to(root)) if f.is_relative_to(root) else str(f)
        out.extend(scan_text(text, rel))
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Silent-zero store-grep detector (T-2680)")
    ap.add_argument("--root", default=".")
    ap.add_argument("paths", nargs="*")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve()
    for path, lineno, rule, snippet in scan_paths(root, args.paths or list(DEFAULT_PATHS)):
        print(f"{path}:{lineno}: {rule}: {snippet}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
