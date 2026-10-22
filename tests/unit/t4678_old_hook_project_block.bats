#!/usr/bin/env bats
# T-4678: ring20's pre-commit (be.4) was an OLD framework template that is not
# stock any more — # VERSION=1.5, its secret-scan echo lines — plus their own
# multi-line project block (if ... fi, their T-2215 gate). install-hooks REFUSED
# it: the kept-lines extract carried old-template residue and cut the project
# block between `if` and `fi` (its inner `exit 1` and its `fi` are also template
# lines), so the merged hook did not parse. A project block must be kept whole
# and stay active; old template lines must not survive outside the block.
#
# The fixture is the real pre-commit template of commit ff447472f (VERSION=1.5),
# read from history, with a project block inserted into it.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

V15=ff447472f
END_LINE='# <<< agentic-framework hook <<<'

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJ="$TEST_TMP/proj"
    HOOKS="$PROJ/.git/hooks"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" config user.email test@local
    git -C "$PROJ" config user.name test
    git -C "$FRAMEWORK_ROOT" show "$V15:agents/git/lib/hooks.sh" |
        awk '/pre_commit_hook" << '"'"'HOOK_EOF'"'"'$/ { on = 1; next }
             /^HOOK_EOF$/ { if (on) exit } on' > "$TEST_TMP/tmpl"
    # The project block: a comment, an if/then/fi with a nested if; its blank
    # echo, `exit 1` and `fi` lines are identical to template lines.
    cat > "$TEST_TMP/block" <<'EOF'
# T-2215: ring20 project gate — no staged .env files
if git diff --cached --name-only | grep -q '\.env$'; then
    echo "" >&2
    echo "ERROR: Commit blocked — a .env file is staged (ring20 T-2215)" >&2
    if [ "${RING20_ALLOW_ENV:-0}" != "1" ]; then
        exit 1
    fi
fi
EOF
}

teardown() {
    cd /
    rm -rf "$TEST_TMP"
}

_install() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks "$@"
}

# Fixture A: the block at the end, just before the template's final `exit 0`.
_fixture_end() {
    awk -v b="$TEST_TMP/block" '
        $0 == "exit 0" && !done { while ((getline l < b) > 0) print l; print ""; done = 1 }
        { print }' "$TEST_TMP/tmpl" > "$HOOKS/pre-commit"
    chmod +x "$HOOKS/pre-commit"
}

# Fixture B: the block between template lines (before the T-3110 corpus guard).
_fixture_middle() {
    awk -v b="$TEST_TMP/block" '
        $0 == "# FW-HOOK-BLOCK: t3110-corpus-guard" { while ((getline l < b) > 0) print l; print "" }
        { print }' "$TEST_TMP/tmpl" > "$HOOKS/pre-commit"
    chmod +x "$HOOKS/pre-commit"
}

# What install-hooks carried over: everything after the block end, minus the
# one provenance comment it writes.
_after() {
    awk -v e="$END_LINE" 'f { print } $0 == e { f = 1 }' "$HOOKS/pre-commit" |
        grep -v '^# T-4515: project lines kept ACTIVE' | grep -v '^# T-4569: project lines kept INERT'
}

_commit_env() {
    echo 'SECRET=1' > "$PROJ/x.env"
    git -C "$PROJ" add x.env
    git -C "$PROJ" commit -q -m "add env" 2>&1
}

@test "fixture: an old non-stock framework pre-commit (VERSION=1.5, secret-scan echo) with a project block" {
    grep -qx '# VERSION=1.5' "$TEST_TMP/tmpl"
    grep -q 'SECRET SCAN IS NOT RUNNING' "$TEST_TMP/tmpl"
    _fixture_middle
    bash -n "$HOOKS/pre-commit"
    grep -q 'Agentic Engineering Framework' "$HOOKS/pre-commit"
}

@test "block at the end: merges, kept whole, no template residue, parses" {
    _fixture_end
    run _install
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q 'REFUSED' || false
    bash -n "$HOOKS/pre-commit"
    _after > "$TEST_TMP/after"
    diff "$TEST_TMP/block" "$TEST_TMP/after"
    ! grep -qx '# VERSION=1.5' "$HOOKS/pre-commit" || false
    [ -f "$HOOKS/pre-commit.pre-fw-block" ]
}

@test "block between template lines: merges, kept whole, no template residue, parses" {
    _fixture_middle
    run _install
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q 'REFUSED' || false
    bash -n "$HOOKS/pre-commit"
    _after > "$TEST_TMP/after"
    diff "$TEST_TMP/block" "$TEST_TMP/after"
    ! grep -qx '# VERSION=1.5' "$HOOKS/pre-commit" || false
}

@test "the kept project block is ACTIVE: it still refuses a staged .env, and allows without one" {
    _fixture_middle
    _install
    run _commit_env
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'a .env file is staged (ring20 T-2215)'
    git -C "$PROJ" reset -q
    rm -f "$PROJ/x.env"
    echo ok > "$PROJ/ok.txt"
    git -C "$PROJ" add ok.txt
    git -C "$PROJ" commit -q -m "T-001: ok"
}

@test "a project block after the old hook's unconditional exit stays whole and INERT (T-4569)" {
    _fixture_middle
    { echo; sed 's/ring20 T-2215/ring20 DEAD-BLOCK/' "$TEST_TMP/block"; } >> "$HOOKS/pre-commit"
    run _install
    [ "$status" -eq 0 ]
    bash -n "$HOOKS/pre-commit"
    # The live block is active once, the dead one is commented out whole.
    [ "$(grep -c 'ring20 T-2215' "$HOOKS/pre-commit")" -eq 1 ]
    grep -q '^# if git diff --cached' "$HOOKS/pre-commit"
    grep -q '^#     echo "ERROR: Commit blocked — a .env file is staged (ring20 DEAD-BLOCK)"' "$HOOKS/pre-commit"
    ! grep -v '^[[:space:]]*#' "$HOOKS/pre-commit" | grep -q 'DEAD-BLOCK' || false
}

@test "residue set: every pre-block template line list is committed and holds the old template's lines" {
    f="$FRAMEWORK_ROOT/agents/git/lib/stock-hook-lines.txt"
    [ -s "$f" ]
    grep -qxF '# VERSION=1.5' "$f"
    grep -qxF '    echo "Every commit is going through WITHOUT secret scanning." >&2' "$f"
}

@test "a merge that still does not parse is REFUSED with the exact line numbers and the fix" {
    _fixture_middle
    # A project line that opens a construct nobody closes.
    sed -i 's/^# FW-HOOK-BLOCK: t3110-corpus-guard$/while true; do\n&/' "$HOOKS/pre-commit"
    cp "$HOOKS/pre-commit" "$TEST_TMP/before"
    run _install
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'REFUSED'
    ln=$(grep -n '^while true; do$' "$TEST_TMP/before" | cut -d: -f1)
    echo "$output" | grep -q "line $ln: while true; do"
    echo "$output" | grep -q 'Fix:'
    cmp "$HOOKS/pre-commit" "$TEST_TMP/before"
}
