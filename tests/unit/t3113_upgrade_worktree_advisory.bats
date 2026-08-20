#!/usr/bin/env bats
# T-3113: `fw upgrade` names which linked worktrees are behind (R7 leg L4).
#
# Exercises _t3113_emit_worktree_advisory directly against a REAL `git worktree
# add` fixture. The helper was extracted from do_upgrade for exactly this reason
# — the alternative is driving a ten-step upgrade to observe one advisory block,
# which tests the upgrade harness rather than the claim.
#
# THE CONSOLIDATION TESTS (bottom of the file) are the ones that protect the fix
# rather than the feature. T-3112 consolidated the hook-comparison predicate and
# asserted "bin/fw holds zero copies" — true, and blind to a THIRD copy sitting
# in lib/upgrade.sh that no assertion looked at. The scan here is repo-wide and
# counts definitions, so the next copy cannot hide in a file nobody thought to
# name.
#
# BOTH PARSE POLICIES are pinned. The lenient one (empty set on unparseable) is
# load-bearing for `fw upgrade`: it makes `missing` = everything, which sets
# needs_regen and regenerates a broken settings.json. Swapping it for the strict
# policy doctor uses would silently stop repairing broken consumers — a
# behaviour change with no failing test unless one is written for it.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$_FW_ROOT/lib/upgrade.sh" ] || skip "lib/upgrade.sh not found"
    [ -f "$_FW_ROOT/lib/hook_parity.py" ] || skip "lib/hook_parity.py not found"

    export FRAMEWORK_ROOT="$_FW_ROOT"
    # shellcheck source=/dev/null
    source "$_FW_ROOT/lib/colors.sh"
    # shellcheck source=/dev/null
    source "$_FW_ROOT/lib/upgrade.sh"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    mkdir -p "$MAIN/.claude"

    git -C "$MAIN" init -q
    git -C "$MAIN" config user.email t@t
    git -C "$MAIN" config user.name t

    cat > "$MAIN/.claude/settings.json" <<'JSON'
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [
  {"type": "command", "command": "$CLAUDE_PROJECT_DIR/bin/fw hook check-active-task"},
  {"type": "command", "command": "$CLAUDE_PROJECT_DIR/bin/fw hook check-worktree-governance-write"}
]}]}}
JSON
    echo seed > "$MAIN/seed.txt"
    git -C "$MAIN" add -A
    git -C "$MAIN" commit -qm "init"
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

# Add a linked worktree; $2 = settings content ("" = none), $3 = "behind" to pin
# it to the first commit while the authority moves on.
_add_wt() {
    local path="$1" content="$2" behind="${3:-}"
    git -C "$MAIN" worktree add -q -b "b-$(basename "$path")" "$path" >/dev/null 2>&1
    rm -rf "$path/.claude"
    if [ -n "$content" ]; then
        mkdir -p "$path/.claude"
        printf '%s' "$content" > "$path/.claude/settings.json"
    fi
    if [ "$behind" = "behind" ]; then
        echo more > "$MAIN/advance.txt"
        git -C "$MAIN" add -A
        git -C "$MAIN" commit -qm "advance authority"
    fi
}

@test "clean worktree reports OK, not stale" {
    _add_wt "$TEST_ROOT/wt1" "$(cat "$MAIN/.claude/settings.json")"
    run _t3113_emit_worktree_advisory "$MAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"*"wt1"* ]]
    [[ "$output" != *"STALE"* ]]
    [[ "$output" == *"examined 1 linked worktree(s), none stale"* ]]
}

@test "worktree behind the authority is named with its commit count" {
    _add_wt "$TEST_ROOT/wt1" "$(cat "$MAIN/.claude/settings.json")" behind
    run _t3113_emit_worktree_advisory "$MAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STALE"*"wt1"* ]]
    [[ "$output" == *"1 commit(s) behind"* ]]
    [[ "$output" == *"$TEST_ROOT/wt1"* ]]
}

@test "hook-drifted worktree is named even when zero commits behind" {
    # The two facts are independent — this is the case that a commit-distance
    # check alone would report as perfectly healthy.
    _add_wt "$TEST_ROOT/wt1" '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/bin/fw hook check-active-task"}]}]}}'
    run _t3113_emit_worktree_advisory "$MAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STALE"*"wt1"* ]]
    [[ "$output" == *"check-worktree-governance-write"* ]]
    [[ "$output" != *"commit(s) behind"* ]]
}

@test "worktree with no settings.json is reported, not skipped" {
    _add_wt "$TEST_ROOT/wt1" ""
    run _t3113_emit_worktree_advisory "$MAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STALE"*"wt1"* ]]
    [[ "$output" == *"absent"* ]]
}

@test "zero linked worktrees reports the empty set explicitly" {
    run _t3113_emit_worktree_advisory "$MAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"examined 0 linked worktree(s)"* ]]
}

@test "non-git target reports unenumerable, never a silent clean bill" {
    run _t3113_emit_worktree_advisory "$TEST_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not a git repository"* ]]
    [[ "$output" == *"unenumerable"* ]]
}

@test "advisory always exits 0 — it can never fail an upgrade" {
    _add_wt "$TEST_ROOT/wt1" "" behind
    run _t3113_emit_worktree_advisory "$MAIN"
    [ "$status" -eq 0 ]
    run _t3113_emit_worktree_advisory "/definitely/not/a/path"
    [ "$status" -eq 0 ]
}

@test "stale summary names both remedies" {
    _add_wt "$TEST_ROOT/wt1" "" behind
    run _t3113_emit_worktree_advisory "$MAIN"
    [[ "$output" == *"fw integrate run master --push"* ]]
    [[ "$output" == *"fw upgrade <worktree-path>"* ]]
}

@test "do_upgrade calls the advisory on the live path" {
    run grep -c '_t3113_emit_worktree_advisory "\$target_dir"' "$_FW_ROOT/lib/upgrade.sh"
    [ "$output" = "1" ]
}

# ── Consolidation invariants (T-3113): the predicate has ONE definition ───────

@test "the hook predicate is defined exactly once in the whole repo" {
    run bash -c "cd '$_FW_ROOT' && grep -rl 'def extract_hooks' --include='*.sh' --include='*.py' --include='fw' . 2>/dev/null | grep -v '\.agentic-framework/' | grep -v '\.claude/worktrees/' | sort"
    [ "$output" = "./lib/hook_parity.py" ]
}

@test "lib/upgrade.sh imports the predicate rather than copying it" {
    run bash -c "grep -c 'from hook_parity import extract_hooks' '$_FW_ROOT/lib/upgrade.sh'"
    [ "$output" = "1" ]
}

@test "lib/upgrade.sh reuses fw_hook_parity_delta for the worktree hook check" {
    run bash -c "grep -c 'fw_hook_parity_delta' '$_FW_ROOT/lib/upgrade.sh'"
    [ "$output" -ge 1 ]
}

@test "lenient parse policy survives — upgrade still regenerates a broken settings.json" {
    # If this flips to the strict policy, `missing` stops being "everything" for
    # an unparseable consumer file, needs_regen stops firing, and broken
    # consumers silently stay broken across every upgrade.
    printf '%s' 'not json {{{' > "$TEST_ROOT/broken.json"
    run bash -c "cd '$_FW_ROOT/lib' && python3 -c \"
from hook_parity import extract_hooks
print(repr(extract_hooks('$TEST_ROOT/broken.json')))
\""
    [ "$output" = "set()" ]
}

@test "strict parse policy survives — doctor reports parse-error, not missing-all" {
    printf '%s' 'not json {{{' > "$TEST_ROOT/broken.json"
    run bash -c "cd '$_FW_ROOT/lib' && python3 -c \"
from hook_parity import extract_hooks
print(repr(extract_hooks('$TEST_ROOT/broken.json', strict=True)))
\""
    [ "$output" = "None" ]
}
