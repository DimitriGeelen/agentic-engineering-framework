#!/usr/bin/env python3
"""printed-fw-commands-lint — T-5306 (slice 4 of T-5302).

Rule (T-5302 GO): a command printed for a person or an agent comes from the one
builder — shell `_fw_cmd` / `_emit_user_command` / `_emit_user_command_in`
(lib/fw-command.sh), Python `fw_path()` / `user_command()` (lib/fw_command.py),
Watchtower `{{ fw_cmd('...') }}` (web/app.py). A hand-written `bin/fw <verb>`
or `bin/watchtower.sh ...` is wrong as printed in every vendored project, whose
framework lives in .agentic-framework/ (no bin/ at the root).

This lint finds hand-written ones in EMITTED text and ratchets them against a
committed baseline (path -> count) that may only shrink.

What counts as a hit (HIT_RE): `bin/fw` followed by whitespace and a verb or
flag, or `bin/watchtower.sh` followed by whitespace and a verb or flag, where
the `bin/` is not itself part of a longer path (`$FRAMEWORK_ROOT/bin/fw`,
`.agentic-framework/bin/fw`, `./bin/fw`, `"$X"/bin/fw`) and not inside a `$(`
command substitution (that RUNS the path). Prose mentions count as well: in
emitted text `run bin/fw doctor` is an instruction to type a path that does not
exist in a vendored project, whatever sentence it sits in. A bare file name
with no verb (`bin/fw not found`) does not count.

Where it looks (emitted text only), under bin/ lib/ agents/ web/:
  shell  (*.sh, *.bash, extensionless files with a sh/bash shebang):
         non-comment lines that call echo or printf, and the bodies of
         `cat <<TAG` heredocs that are not redirected into a file.
  python (*.py, extensionless files with a python shebang), via ast:
         every string literal / f-string part, EXCEPT docstrings, strings
         inside a call to subprocess.* / os.system / os.exec* / os.spawn* /
         Popen / shlex.split / re.*, and strings that are an operand of a
         comparison or `in` test (those match commands, they do not print them).
         Heuristic on purpose: nearly every remaining literal that holds
         `bin/fw <verb>` is a message, hint or remedy.
  jinja  (web/templates/**/*.html): every line, minus {# #} and <!-- -->
         comments.

Skipped: the builders themselves (lib/fw-command.sh, lib/fw_command.py),
__pycache__, files that are neither shell, python nor templates (markdown,
yaml, js). tests/, docs/ and .agentic-framework/ are outside the scan roots.

Usage:
  printed-fw-commands-lint.py [--root DIR] [--baseline FILE] [--no-baseline]
                              [--regenerate] [--list] [PATH ...]
Exit: 0 ok (counts <= baseline), 1 new instances, 2 usage error.
"""
from __future__ import annotations

import argparse
import ast
import json
import os
import re
import sys

SCAN_ROOTS = ("bin", "lib", "agents", "web")
BUILDERS = {"lib/fw-command.sh", "lib/fw_command.py"}
DEFAULT_BASELINE = "tests/lint/fixtures/printed-fw-commands-baseline.json"
REGEN_CMD = "python3 tools/printed-fw-commands-lint.py --regenerate"

HIT_RE = re.compile(
    r"(?<![\w/.$}-])bin/(?:(fw)[ \t]+(-{0,2}[a-z][\w-]*)|watchtower\.sh[ \t]+-{0,2}[a-z])"
)
FW_VERBS: set[str] = set()  # filled by load_verbs(); `bin/fw <word>` counts only for a router verb
SUBST_RE = re.compile(r"\$\(\s*$")

EXEC_FUNCS = {"system", "Popen", "run", "call", "check_call", "check_output",
              "execv", "execvp", "execve", "execl", "execlp", "spawnv",
              "spawnvp", "split"}
EXEC_MODULES = {"subprocess", "os", "shlex", "re"}

FIX_HINT = {
    "shell": 'use $(_emit_user_command "<args>") or "$(_fw_cmd) <args>" (lib/fw-command.sh)',
    "python": "use user_command(\"<args>\") or fw_path() (lib/fw_command.py)",
    "jinja": "use {{ fw_cmd('<args>') }} (web/app.py)",
}


def load_verbs(root: str) -> set[str]:
    """Top-level verbs of the fw router (`case "$cmd" in` entries indented 4
    spaces, same extraction as tests/lint/help-router-parity.bats). Read from
    ROOT/bin/fw, else from the bin/fw beside this tool."""
    for cand in (os.path.join(root, "bin", "fw"),
                 os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "fw")):
        try:
            text = open(cand, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        m = re.search(r'^case "\$cmd" in$(.*?)^esac', text, re.M | re.S)
        if not m:
            continue
        verbs: set[str] = set()
        for line in m.group(1).splitlines():
            mm = re.match(r"^ {4}([a-z][-a-z0-9|]+)\)", line)
            if mm:
                verbs.update(v for v in mm.group(1).split("|") if v and not v.startswith("-"))
        if verbs:
            return verbs
    return set()


def _hits_in(text: str) -> int:
    n = 0
    for m in HIT_RE.finditer(text):
        if SUBST_RE.search(text[: m.start()][-4:]):
            continue
        if m.group(1):
            word = m.group(2)
            if not word.startswith("-") and word not in FW_VERBS:
                continue  # prose about the file (`bin/fw is the shim`), not a command
        n += 1
    return n


def classify(path: str) -> str | None:
    rel = path.replace(os.sep, "/")
    if rel.endswith((".sh", ".bash")):
        return "shell"
    if rel.endswith(".py"):
        return "python"
    if rel.endswith(".html") and "/templates/" in "/" + rel:
        return "jinja"
    if "." in os.path.basename(rel):
        return None
    try:
        with open(path, "rb") as fh:
            first = fh.readline(200)
    except OSError:
        return None
    if not first.startswith(b"#!"):
        return None
    if b"python" in first:
        return "python"
    if b"sh" in first:
        return "shell"
    return None


# ── shell ────────────────────────────────────────────────────────────────────
ECHO_RE = re.compile(r"(^|[\s;&|({`])(echo|printf)(\s|$)")
HEREDOC_RE = re.compile(r"\bcat\b[^<]*<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1(.*)$")


def scan_shell(text: str):
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        if stripped.startswith("#"):
            i += 1
            continue
        hd = HEREDOC_RE.search(line)
        if hd:
            tag = hd.group(2)
            opener = line[: hd.start()] + line[hd.start():].replace("<<", "  ")
            # Written to a file or piped into a program: the body is CODE (a
            # generated hook, a python script) — only its own echo/printf lines
            # print anything. Otherwise the body itself is the message.
            as_code = (re.search(r"(?<![0-9&<])>\s*[^&\s]", opener) is not None
                       or re.search(r"\|(?!\|)", line[hd.end(2):]) is not None)
            j = i + 1
            while j < len(lines) and lines[j].strip() != tag:
                body = lines[j]
                if body.lstrip().startswith("#") or (as_code and not ECHO_RE.search(body)):
                    j += 1
                    continue
                for _ in range(_hits_in(body)):
                    yield j + 1, body
                j += 1
            i = j + 1
            continue
        if ECHO_RE.search(line):
            for _ in range(_hits_in(line)):
                yield i + 1, line
        i += 1


# ── python ───────────────────────────────────────────────────────────────────
def _is_exec_call(node: ast.Call) -> bool:
    f = node.func
    if isinstance(f, ast.Attribute):
        base = f.value
        if isinstance(base, ast.Name) and base.id in EXEC_MODULES:
            return True
        return f.attr in {"Popen", "check_output", "check_call", "system"}
    if isinstance(f, ast.Name):
        return f.id in {"Popen", "check_output", "check_call"}
    return False


def scan_python(text: str):
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return
    excluded: set[int] = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef,
                             ast.ClassDef)):
            body = getattr(node, "body", [])
            if body and isinstance(body[0], ast.Expr) and isinstance(
                    body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                excluded.add(id(body[0].value))
        if (isinstance(node, ast.Call) and _is_exec_call(node)) or isinstance(node, ast.Compare):
            for sub in ast.walk(node):
                excluded.add(id(sub))
    src_lines = text.splitlines()
    seen: set[tuple[int, int]] = set()
    for node in ast.walk(tree):
        if id(node) in excluded:
            continue
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            if "bin/" not in node.value:
                continue
            n = _hits_in(node.value)
            if not n:
                continue
            src = src_lines[node.lineno - 1] if node.lineno <= len(src_lines) else ""
            head = src.encode("utf-8")[node.col_offset:node.col_offset + 3]  # col_offset is bytes
            if re.match(rb"[bB]?[rR]['\"]", head):
                continue  # raw string: a regex/pattern, not a message
            for k in range(n):
                key = (node.lineno, getattr(node, "col_offset", 0) * 1000 + k)
                if key in seen:
                    continue
                seen.add(key)
                yield node.lineno, src_lines[node.lineno - 1] if node.lineno <= len(src_lines) else ""


# ── jinja ────────────────────────────────────────────────────────────────────
def scan_jinja(text: str):
    blank = lambda m: re.sub(r"[^\n]", " ", m.group(0))  # noqa: E731
    text = re.sub(r"\{#.*?#\}", blank, text, flags=re.S)
    text = re.sub(r"<!--.*?-->", blank, text, flags=re.S)
    for i, line in enumerate(text.splitlines(), 1):
        for _ in range(_hits_in(line)):
            yield i, line


SCANNERS = {"shell": scan_shell, "python": scan_python, "jinja": scan_jinja}


def iter_files(root: str, paths: list[str]):
    targets = paths or [os.path.join(root, r) for r in SCAN_ROOTS]
    for t in targets:
        if os.path.isfile(t):
            yield t
            continue
        for dp, dns, fns in os.walk(t):
            dns[:] = sorted(d for d in dns if d not in ("__pycache__", "node_modules", ".git"))
            for fn in sorted(fns):
                yield os.path.join(dp, fn)


def collect(root: str, paths: list[str]):
    hits: dict[str, list[tuple[int, str, str]]] = {}
    for path in iter_files(root, paths):
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        if rel in BUILDERS:
            continue
        kind = classify(path)
        if not kind:
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        for lineno, line in SCANNERS[kind](text):
            hits.setdefault(rel, []).append((lineno, line.strip()[:160], kind))
    return hits


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--root", default=None)
    ap.add_argument("--baseline", default=None)
    ap.add_argument("--no-baseline", action="store_true")
    ap.add_argument("--regenerate", action="store_true")
    ap.add_argument("--list", action="store_true", help="print every hit")
    a = ap.parse_args(argv)

    root = os.path.abspath(a.root or os.path.join(os.path.dirname(__file__), ".."))
    if not os.path.isdir(root):
        print(f"error: root {root} is not a directory", file=sys.stderr)
        return 2
    base_path = a.baseline or os.path.join(root, DEFAULT_BASELINE)
    FW_VERBS.update(load_verbs(root))
    if not FW_VERBS:
        print("error: could not read the fw router verbs from bin/fw", file=sys.stderr)
        return 2
    hits = collect(root, a.paths)
    counts = {p: len(v) for p, v in sorted(hits.items())}
    total = sum(counts.values())

    if a.regenerate:
        os.makedirs(os.path.dirname(base_path) or ".", exist_ok=True)
        with open(base_path, "w", encoding="utf-8") as fh:
            json.dump({"_comment": "T-5306 ratchet: hand-written bin/fw / bin/watchtower.sh "
                       "in printed text, per file. May only shrink. Regenerate: " + REGEN_CMD,
                       "total": total, "counts": counts}, fh, indent=1, sort_keys=False)
            fh.write("\n")
        print(f"wrote {base_path}: {total} instances in {len(counts)} files")
        return 0

    if a.list:
        for p, v in sorted(hits.items()):
            for lineno, line, _ in v:
                print(f"{p}:{lineno}: {line}")

    if a.no_baseline:
        print(f"total {total} in {len(counts)} files")
        return 1 if total else 0

    try:
        with open(base_path, encoding="utf-8") as fh:
            baseline = json.load(fh).get("counts", {})
    except (OSError, ValueError) as e:
        print(f"error: cannot read baseline {base_path}: {e}", file=sys.stderr)
        return 2

    new = 0
    for p, n in counts.items():
        b = int(baseline.get(p, 0))
        if n > b:
            new += n - b
            where = "new file, not in baseline" if p not in baseline else f"{n} now, baseline {b}"
            print(f"NEW {p}: {where}")
            for lineno, line, kind in hits[p]:
                print(f"  {p}:{lineno}: {line}")
            print(f"  fix: {FIX_HINT[hits[p][0][2]]}")
    shrunk = [(p, int(b), counts.get(p, 0)) for p, b in sorted(baseline.items())
              if counts.get(p, 0) < int(b)]
    for p, b, n in shrunk:
        print(f"NOTE {p}: {n} now, baseline {b} — shrink the baseline: {REGEN_CMD}")
    print(f"printed-fw-commands: total {total}, baseline {sum(int(v) for v in baseline.values())}, new {new}")
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main())
