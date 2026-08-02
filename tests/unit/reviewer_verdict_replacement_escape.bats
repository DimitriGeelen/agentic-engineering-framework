#!/usr/bin/env bats
# T-2730 — a rendered verdict is DATA, and must never reach `re.sub` as a
# replacement *template*.
#
# `re.sub(repl, string)` parses `repl` for template escapes. The reviewer passed
# its rendered verdict straight in, and the verdict quotes evidence lines out of
# the task body — so any backslash the author wrote was interpreted. CLAUDE.md
# itself instructs authors to write `sed 's/\x1b\[[0-9;]*m//g'` to strip ANSI, so
# the reviewer crashed on precisely the tasks that follow the documented idiom:
#
#   re.error: bad escape \x at position 386
#
# Measured population at fix time: 7 task files (`\x`, and also `\s` and `\d`
# from regex idioms in Verification blocks), out of 486 containing a backslash
# and 2717 total. Latent second-run exposure: 0 — of the 8 backslash-carrying
# tasks with no verdict section yet, none render a hostile verdict.
#
# `\1` is the quieter half of the same defect: it would not raise, it would
# splice a capture group into the task file.

load ../test_helper

# A task carrying the documented ANSI idiom AND an existing verdict section, so
# the `.sub()` path is the one exercised rather than the append path.
_make_fixture() {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active" "$proj/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"

    cat > "$proj/.tasks/active/T-9998-fixture.md" <<'TASK'
---
id: T-9998
name: "verdict replacement escape fixture"
description: fixture
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-08-02T00:00:00Z
last_update: '2026-08-02T01:00:00Z'
---

## Context

Fixture for T-2730.

## Acceptance Criteria

### Agent
- [x] fixture criterion

## Verification

out=$(bin/fw doctor 2>&1); echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "OK"

## Reviewer Verdict (v1.5)

- **Overall:** PASS
TASK
    echo "$proj"
}

# PROJECT_ROOT is exported by update-task.sh when this file runs as a P-011
# verification command; inherited, it aims the reviewer at the real repo. See
# tests/unit/episodic_yaml_timeline_escape.bats for the same trap (T-2729).
_review() {
    ( unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED
      cd "$1" && "$FRAMEWORK_ROOT/bin/fw" reviewer T-9998 2>&1 )
}

@test "T-2730: reviewer completes on a task using the documented \\x1b idiom" {
    local proj out
    proj="$(_make_fixture)"
    out="$(_review "$proj")" || true
    [[ "$out" != *"re.error"* ]] || {
        echo "reviewer still raises:" >&2; echo "$out" | tail -5 >&2; false
    }
    [[ "$out" == *"Overall:"* ]]
}

@test "T-2730: the task's backslash text survives the rewrite byte-for-byte" {
    local proj f
    proj="$(_make_fixture)"
    f="$proj/.tasks/active/T-9998-fixture.md"
    _review "$proj" >/dev/null 2>&1 || true

    # The rewrite must actually have HAPPENED. Without this the test passes when
    # the reviewer crashes and leaves the file untouched — which is exactly what
    # it did when the fix was reverted to check the suite's teeth.
    grep -q '^- \*\*Scan ID:\*\*' "$f"

    # …and the Verification line must be unchanged through that rewrite.
    grep -q "sed 's/\\\\x1b\\\\\[\[0-9;\]\*m//g'" "$f"
}

@test "T-2730 control: the fixture verdict is genuinely hostile as a template" {
    # Without this, the tests above would pass against any reviewer whose verdict
    # happened to contain no backslash. Renders the REAL verdict for the fixture
    # and applies the PRE-FIX call shape, which must raise.
    local proj
    proj="$(_make_fixture)"
    run python3 - "$FRAMEWORK_ROOT" "$proj" <<'PY'
import os, re, sys
fw, proj = sys.argv[1], sys.argv[2]
sys.path.insert(0, fw)
os.environ["PROJECT_ROOT"] = proj
os.environ["FRAMEWORK_ROOT"] = fw
from pathlib import Path
from lib.reviewer.static_scan import (
    scan_task, render_verdict_md, load_catalogue, _VERDICT_SECTION_RE)
task = Path(proj) / ".tasks/active/T-9998-fixture.md"
cat = load_catalogue(Path(fw) / "policy/anti-patterns.yaml")
esc = Path(fw) / "policy/escalation-patterns.yaml"
sec = render_verdict_md(scan_task(task, cat,
        load_catalogue(esc) if esc.exists() else None, overrides=[]))
assert "\\" in sec, "rendered verdict carries no backslash — fixture is toothless"
try:
    _VERDICT_SECTION_RE.sub(sec, task.read_text())
except re.error as e:
    print("CONTROL OK:", e); sys.exit(0)
sys.exit("CONTROL FAILED — pre-fix shape did not raise; fixture is toothless")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONTROL OK"* ]]
}

@test "T-2730 guard: no reviewer .sub() takes a non-literal replacement" {
    # Source-derived with no maintained allowlist (L-533): parse every reviewer
    # module and check the REPLACEMENT argument of each `.sub()` call. A lambda
    # or a plain string constant is data; a Name, an f-string or a call result is
    # a template built from runtime values, which is the defect.
    #
    # Argument position differs: `re.sub(pattern, repl, s)` -> arg 1, while a
    # compiled `PAT.sub(repl, s)` -> arg 0.
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import ast, glob, os, sys
bad = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "lib/reviewer/*.py"))):
    tree = ast.parse(open(path).read(), path)
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "sub"):
            continue
        module_level = (isinstance(node.func.value, ast.Name)
                        and node.func.value.id == "re")
        idx = 1 if module_level else 0
        if len(node.args) <= idx:
            continue
        repl = node.args[idx]
        if isinstance(repl, ast.Lambda):
            continue
        if isinstance(repl, ast.Constant) and isinstance(repl.value, str):
            continue                      # literal; author sees its backslashes
        bad.append("%s:%d  %s" % (os.path.basename(path), node.lineno,
                                  type(repl).__name__))
if bad:
    sys.exit("non-literal .sub() replacement(s):\n  " + "\n  ".join(bad))
print("clean")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]]
}

@test "T-2730 guard control: the guard flags a reintroduced template replacement" {
    # Runs against a COPY, never the real tree.
    local dir="$TEST_TEMP_DIR/fakepkg/lib/reviewer"
    mkdir -p "$dir"
    cat > "$dir/regressed.py" <<'PY'
import re
PAT = re.compile("x")
def f(section, text):
    return PAT.sub(section, text)
PY
    run python3 - "$TEST_TEMP_DIR/fakepkg" <<'PY'
import ast, glob, os, sys
bad = []
for path in sorted(glob.glob(os.path.join(sys.argv[1], "lib/reviewer/*.py"))):
    tree = ast.parse(open(path).read(), path)
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "sub"):
            continue
        module_level = (isinstance(node.func.value, ast.Name)
                        and node.func.value.id == "re")
        idx = 1 if module_level else 0
        if len(node.args) <= idx:
            continue
        repl = node.args[idx]
        if isinstance(repl, ast.Lambda):
            continue
        if isinstance(repl, ast.Constant) and isinstance(repl.value, str):
            continue
        bad.append("%s:%d" % (os.path.basename(path), node.lineno))
sys.exit(1 if bad else 0)
PY
    [ "$status" -eq 1 ]
}

@test "T-2730: the seven measured tasks all produce a verdict" {
    # The population that crashed at fix time, named rather than counted, so a
    # regression says WHICH task broke. Read-only: --no-write.
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import os, sys
fw = sys.argv[1]
sys.path.insert(0, fw)
os.environ["PROJECT_ROOT"] = fw
os.environ["FRAMEWORK_ROOT"] = fw
import re
from pathlib import Path
from lib.reviewer.static_scan import (
    scan_task, render_verdict_md, load_catalogue, _VERDICT_SECTION_RE)
NAMES = [
    "T-1774", "T-1980", "T-1536", "T-1860", "T-2724", "T-2726", "T-2727",
]
cat = load_catalogue(Path(fw) / "policy/anti-patterns.yaml")
esc = Path(fw) / "policy/escalation-patterns.yaml"
escc = load_catalogue(esc) if esc.exists() else None
missing, failed = [], []
for tid in NAMES:
    hits = list(Path(fw).glob(".tasks/*/%s-*.md" % tid))
    if not hits:
        missing.append(tid)           # archived/renamed — reported, not silent
        continue
    p = hits[0]
    text = p.read_text(errors="replace")
    sec = render_verdict_md(scan_task(p, cat, escc, overrides=[]))
    try:
        _VERDICT_SECTION_RE.sub(lambda _m: sec, text)
    except re.error as e:
        failed.append("%s: %s" % (tid, e))
if failed:
    sys.exit("still crashing: %r" % failed)
print("all produce a verdict; not-found (informational): %r" % missing)
PY
    [ "$status" -eq 0 ]
}
