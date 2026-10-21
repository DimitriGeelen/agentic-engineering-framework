#!/usr/bin/env bats
# T-4515 (G-122): T-4403 made install-hooks keep a consumer's lines from an old
# framework hook, but COMMENTED OUT. 832's two pre-commit gates stopped running
# for five hours, and their installer check, which grepped for the gate's text,
# still read "installed" because the text survives inside the comment.
#
# So these tests do not look for text. In the shape 832 used (their T-1240) they
# COUNT the ACTIVE (uncommented) gate lines before and after install-hooks, and
# they RUN the hook to prove the gate still executes: a failing gate must block.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

BEGIN_RE='^# >>> agentic-framework hook'
END_LINE='# <<< agentic-framework hook <<<'
GATE='consumer-boundary-gate.sh'

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    HOOKS="$PROJ/.git/hooks"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email test@local
    git -C "$PROJ" config user.name test
    # The consumer's own gate: fails when GATE_FAIL is set, and leaves a trace.
    printf '#!/bin/bash\necho ran >> "%s/gate.ran"\n[ -z "${GATE_FAIL:-}" ]\n' "$TEST_TMP" > "$TEST_TMP/$GATE"
    chmod +x "$TEST_TMP/$GATE"
    GATE_LINE="\"$TEST_TMP/$GATE\" || exit 1"
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_install() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks "$@"
}

# Active (uncommented) lines that invoke the consumer gate.
_active_gate_lines() {
    grep -v '^[[:space:]]*#' "$1" | grep -c "$GATE" || true
}

# The pre-T-4403 shape: the raw framework template written whole, no markers.
_raw_old_framework_hook() {
    awk -v b="$BEGIN_RE" -v e="$END_LINE" '
        $0 ~ b {inb=1; next}
        $0 == e {inb=0; next}
        inb && ($0 == "(" || $0 == ") || exit $?") {next}
        {print}' "$1"
}

# Run the installed pre-commit hook the way git would, in the project.
_run_pre_commit() {
    cd "$PROJ"
    run env GATE_FAIL="${1:-}" bash "$HOOKS/pre-commit"
}

# fw doctor needs a minimal AEF project around the hooks.
_doctor() {
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed" "$PROJ/.tasks/templates"
    echo "# template" > "$PROJ/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    cd "$PROJ"
    run env FW_DOCTOR_SMOKE=0 PROJECT_ROOT="$PROJ" timeout 240 "$FRAMEWORK_ROOT/bin/fw" doctor --quick
}

@test "T-4515: an old framework hook carrying a consumer gate keeps the gate ACTIVE and it still blocks" {
    run _install
    [ "$status" -eq 0 ]
    _raw_old_framework_hook "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    # 832's shape: their gate placed before the old template's own end.
    sed -i "2i $GATE_LINE" "$TEST_TMP/raw"
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"; chmod +x "$HOOKS/pre-commit"
    before=$(_active_gate_lines "$HOOKS/pre-commit")
    [ "$before" -eq 1 ]

    run _install
    [ "$status" -eq 0 ]
    [ "$(grep -c "$BEGIN_RE" "$HOOKS/pre-commit")" -eq 1 ]
    # The count, not the text: still exactly one ACTIVE gate line.
    after=$(_active_gate_lines "$HOOKS/pre-commit")
    [ "$after" -eq "$before" ]
    bash -n "$HOOKS/pre-commit"

    # And it executes: a failing gate blocks the commit ...
    rm -f "$TEST_TMP/gate.ran"
    _run_pre_commit 1
    [ "$status" -ne 0 ]
    [ -f "$TEST_TMP/gate.ran" ]
    # ... and a passing gate lets it through.
    rm -f "$TEST_TMP/gate.ran"
    _run_pre_commit
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/gate.ran" ]
}

@test "T-4515: re-running install-hooks and --force keep the gate active and executing" {
    run _install
    _raw_old_framework_hook "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    sed -i "2i $GATE_LINE" "$TEST_TMP/raw"   # reachable: before the old exit 0 (T-4569)
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"
    run _install
    [ "$status" -eq 0 ]
    run _install
    [ "$status" -eq 0 ]
    run _install --force
    [ "$status" -eq 0 ]
    [ "$(_active_gate_lines "$HOOKS/pre-commit")" -eq 1 ]
    _run_pre_commit 1
    [ "$status" -ne 0 ]
}

@test "T-4515: install-hooks never writes a commented-out copy of a project line" {
    run _install
    _raw_old_framework_hook "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    sed -i "2i $GATE_LINE" "$TEST_TMP/raw"   # reachable: before the old exit 0 (T-4569)
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"
    run _install
    [ "$status" -eq 0 ]
    [ "$(grep '^[[:space:]]*#' "$HOOKS/pre-commit" | grep -c "$GATE" || true)" -eq 0 ]
}

@test "T-4515: a merge that would not parse is refused and the installed hook is left byte-identical" {
    run _install
    _raw_old_framework_hook "$HOOKS/pre-commit" > "$TEST_TMP/raw"
    # An opener whose closer is a line the template also has (so it is not kept):
    # the kept lines alone cannot parse after the block.
    # Reachable, before the old exit 0: lines after it stay inert (T-4569).
    sed -i "2i case x in" "$TEST_TMP/raw"; sed -i "2i $GATE_LINE" "$TEST_TMP/raw"
    cp "$TEST_TMP/raw" "$HOOKS/pre-commit"; chmod +x "$HOOKS/pre-commit"
    cp "$HOOKS/pre-commit" "$TEST_TMP/before"
    run _install
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"$GATE"* ]]
    cmp -s "$TEST_TMP/before" "$HOOKS/pre-commit"
    [ "$(_active_gate_lines "$HOOKS/pre-commit")" -eq 1 ]
}

@test "T-4515: a non-shell consumer hook is refused, not replaced by the block alone" {
    printf '#!/usr/bin/env python3\nimport sys; sys.exit(0)\n' > "$HOOKS/post-commit"
    chmod +x "$HOOKS/post-commit"
    cp "$HOOKS/post-commit" "$TEST_TMP/before"
    run _install
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED: post-commit is not a shell script"* ]]
    cmp -s "$TEST_TMP/before" "$HOOKS/post-commit"
    # The other hooks were still installed.
    [ "$(grep -c "$BEGIN_RE" "$HOOKS/pre-commit")" -eq 1 ]
}

@test "T-4515: fw doctor flags project lines the T-4403 installer commented out" {
    run _install
    {
        echo "# T-4403: kept from the previous pre-commit by fw git install-hooks (commented out — see G-122); original: pre-commit.pre-fw-block"
        echo "# $GATE_LINE"
    } >> "$HOOKS/pre-commit"
    _doctor
    [[ "$output" == *"commented out by install-hooks (T-4403): pre-commit(1)"* ]]
}

@test "T-4515: fw doctor is silent on a hook with active project lines" {
    run _install
    echo "$GATE_LINE" >> "$HOOKS/pre-commit"
    _doctor
    [[ "$output" == *"Git commit-msg hook"* ]]   # the hook section ran
    [[ "$output" != *"commented out by install-hooks"* ]]
}
