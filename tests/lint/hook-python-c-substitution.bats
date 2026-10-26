#!/usr/bin/env bats
# T-4782: no backtick or $( inside a double-quoted `python3 -c "..."` block in a
# hook script. Bash substitutes them in the python SOURCE before python starts,
# python comments included, on every call of the hook.
#
# Origin: 055 T-641 (2026-10-26). A local edit to the vendored check-tier0.sh put
# a backtick-quoted tmux command in a python comment; every Bash tool call of every
# 055 session ran it and took the host's tmux servers down for six hours.
#
# Sibling: no-backticks-in-inline-python.bats (T-2707) covers backticks tree-wide
# and allows $( by design. Hooks get the stricter rule; see the scanner's docstring.
# Fixtures under fixtures/t4782/ are DATA (.sh.fixture, never executed).

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/hook-python-c-substitution-lint.py"
    FIX="$ROOT/tests/lint/fixtures/t4782"
}

@test "tree: no command substitution inside python -c blocks in hook scripts" {
    run python3 "$LINT" --root "$ROOT"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean: "* ]]
}

@test "tree: the scan covers the tier0 gate and the settings.json-direct scripts" {
    # A scanner that silently scans nothing is green for free.
    run python3 - "$ROOT" <<'PY'
import importlib.util, sys
from pathlib import Path
root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("lint", root / "tools/hook-python-c-substitution-lint.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
names = {str(p.relative_to(root)) for p in m.hook_files(root)}
for need in ("agents/context/check-tier0.sh", "agents/context/check-active-task.sh",
             "agents/context/stop-driver.sh", "agents/context/lib/focus.sh"):
    assert need in names, need
print(len(names))
PY
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "fixture: 055's case, a backtick-quoted command in a python comment, is flagged" {
    run python3 "$LINT" "$FIX/bad-055-tier0-comment.sh.fixture"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad-055-tier0-comment.sh.fixture:7: backtick:"* ]]
}

@test "fixture: \$( inside the python body is flagged" {
    run python3 "$LINT" "$FIX/bad-dollar-paren.sh.fixture"
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad-dollar-paren.sh.fixture:6: \$(:"* ]]
}

@test "fixture: \$VAR, escaped \\\$( and \\\`, single quotes and quoted heredocs pass" {
    run python3 "$LINT" "$FIX/clean.sh.fixture"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean: 1 hook script(s)"* ]]
}

@test "check-tier0 approval card still writes a timestamp after the heredoc move" {
    S="$BATS_TEST_TMPDIR/card"
    mkdir -p "$S"
    # Run only the approval-card block, extracted from the hook, against a temp path.
    python3 - "$ROOT/agents/context/check-tier0.sh" "$S/block.py" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
m = re.search(r"python3 - \"\$APPROVAL_YAML\" 2>/dev/null <<'PY' \|\| true\n(.*?)\nPY\n", src, re.S)
assert m, "approval-card heredoc not found"
open(sys.argv[2], "w").write(m.group(1))
PY
    T0_RISK=r T0_CMD=c T0_HASH=h T0_ROOT="$S" T0_FRAMEWORK_ROOT="$ROOT" \
        run python3 "$S/block.py" "$S/pending.yaml"
    [ "$status" -eq 0 ]
    grep -Eq "^timestamp: '?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z'?$" "$S/pending.yaml"
}
