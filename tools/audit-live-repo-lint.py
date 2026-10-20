#!/usr/bin/env python3
"""T-4401: flag unit tests that run a sectioned audit against the real repo.

audit.sh takes a repo-wide flock on $CONTEXT_DIR/locks/audit.lock for every
`--section` run and exits 75 when another audit holds it (audit.sh:614-631).
The lock path derives from PROJECT_ROOT, so a test that runs a sectioned audit
without pointing PROJECT_ROOT at a fixture shares the lock with every cron
audit, pre-push gate and sibling worker in the checkout. It then either skips
(bats reports `ok ... # skip`: green, nothing measured) or wins the lock and
pays the whole live section. That lottery is what this lint refuses.

A statement is an AUDIT CALL when it runs audit.sh (or `$AUDIT`, or `fw audit`)
with `--section` / `--sections`. It is FIXTURE-ROOTED when:
  - the statement itself sets PROJECT_ROOT to something other than the repo
    (`$FRAMEWORK_ROOT`, `$REPO_ROOT`, `$FW_ROOT`, `$PWD`, `.`), or
  - the file makes a PERSISTENT assignment of PROJECT_ROOT to such a value (a
    setup() `export PROJECT_ROOT=...`, a python `env["PROJECT_ROOT"] = ...`)
    and the statement does not reset it to the repo. A statement-prefix
    assignment roots only its own statement.
The lockless `--check <id>` path (T-4209) is not an audit call: it takes no lock.

Escape hatch: a comment line directly above the statement reading
`# live-audit-ok: <reason>` (the reason is required). Use it only for a test
whose subject is the live repo's own audit cost, and say why in the reason.

Usage: audit-live-repo-lint.py [PATH ...]   (files or directories; default tests/unit)
Exit 0 and "clean" when nothing is flagged; 1 with one line per offender.
"""
import os
import re
import sys

SECTION = re.compile(r"--sections?\b")
AUDIT_CALL = re.compile(
    r"audit\.sh\b|\$\{?AUDIT\}?\b|\bfw\"?\s+audit\b|[\"']audit[\"']\s*,\s*[\"']--sections?[\"']"
)
REPO_VALUE = r"(?:[\"']?\$\{?(?:FRAMEWORK_ROOT|REPO_ROOT|FW_ROOT|PWD)\}?[\"']?|\.|[\"']\.[\"'])(?=\s|$|;|\))"
PR_ASSIGN = re.compile(r"\bPROJECT_ROOT=(\S*)")
PERSISTENT_ASSIGN = re.compile(r"^[ \t]*(?:export[ \t]+)?PROJECT_ROOT=(\S+)[ \t]*(?:;[ \t]*)?(?:#.*)?$", re.M)
PY_ASSIGN =re.compile(r"""\[\s*["']PROJECT_ROOT["']\s*\]\s*=\s*(.+)""")
MARKER = re.compile(r"^\s*#\s*live-audit-ok:\s*\S")
# Lines that only NAME an audit call: prose, generated cron/yaml text, help output.
NOT_A_CALL = re.compile(r"^\s*(#|echo\b|printf\b|command:|\*/|\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+root\b)|^\s*[\"']|^\s*-\s")


def _is_repo_value(v):
    return re.fullmatch(REPO_VALUE, v) is not None or v.strip("\"'") in (
        "$FRAMEWORK_ROOT", "${FRAMEWORK_ROOT}", "$REPO_ROOT", "$FW_ROOT", "$PWD", ".")


def _py_repo_value(v):
    v = v.strip()
    return bool(re.match(r"str\(\s*REPO_ROOT\s*\)|REPO_ROOT\b|os\.getcwd\(\)", v))


def _statements(lines):
    """Yield (first_lineno, joined_text) with backslash continuations joined."""
    buf, start = [], 0
    for i, line in enumerate(lines, 1):
        if not start:
            start = i
        stripped = line.rstrip("\n")
        if stripped.endswith("\\"):
            buf.append(stripped[:-1])
            continue
        buf.append(stripped)
        yield start, " ".join(buf)
        buf, start = [], 0
    if buf:
        yield start, " ".join(buf)


def _file_has_fixture_root(text, is_py):
    if is_py:
        return any(not _py_repo_value(m.group(1)) for m in PY_ASSIGN.finditer(text))
    # Only a PERSISTENT assignment (`export PROJECT_ROOT=x`, or the assignment as
    # the whole statement) roots the file. A prefix (`PROJECT_ROOT=x cmd`,
    # `env PROJECT_ROOT=x cmd`) is local to its own statement, so it must not
    # excuse a bare call elsewhere in the file.
    for m in PERSISTENT_ASSIGN.finditer(text):
        if not _is_repo_value(m.group(1)):
            return True
    return False


def lint_file(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    is_py = path.endswith(".py")
    lines = text.splitlines(True)
    file_fixture = _file_has_fixture_root(text, is_py)
    findings = []
    for lineno, stmt in _statements(lines):
        if NOT_A_CALL.match(stmt):
            continue
        if not (SECTION.search(stmt) and AUDIT_CALL.search(stmt)):
            continue
        prev = lines[lineno - 2] if lineno >= 2 else ""
        if MARKER.match(prev):
            continue
        assigns = [m.group(1) for m in PR_ASSIGN.finditer(stmt)]
        if is_py:
            rooted = file_fixture
        elif assigns:
            rooted = any(a and not _is_repo_value(a) for a in assigns)
        else:
            rooted = file_fixture
        if not rooted:
            findings.append((path, lineno, stmt.strip()))
    return findings


def _targets(args):
    for a in args or ["tests/unit"]:
        if os.path.isdir(a):
            for root, _dirs, files in os.walk(a):
                for f in sorted(files):
                    if f.endswith(".bats") or (f.startswith("test_") and f.endswith(".py")):
                        yield os.path.join(root, f)
        else:
            yield a


def main(argv):
    findings = []
    for path in _targets(argv):
        findings.extend(lint_file(path))
    if not findings:
        print("audit-live-repo-lint: clean")
        return 0
    for path, lineno, stmt in findings:
        print(f"{path}:{lineno}: sectioned audit in the real repo (shared audit lock): {stmt[:160]}")
    print(
        f"audit-live-repo-lint: {len(findings)} finding(s). Point PROJECT_ROOT at a fixture "
        "(private lock), use the lockless `audit.sh --check <id>`, or mark the line above "
        "with `# live-audit-ok: <reason>` (T-4401)."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
