#!/usr/bin/env bats
# T-3112: fw doctor audits linked worktrees for enforcement drift (R7 leg L3).
#
# Two things are under test and they fail differently:
#
#   1. THE PREDICATE (lib/hook-parity.sh) — exercised against a REAL `git
#      worktree add`, because the claim being made is about git's worktree
#      model: `--git-common-dir` names the main checkout from every checkout
#      alike, which is what makes "the authority" resolvable from a replica.
#      A fabricated directory layout would assert nothing about that.
#
#   2. THE ZERO-COPY INVARIANT — `bin/fw` must hold no copy of the predicate.
#      This is the test that protects the fix from being undone by the next
#      person who needs the comparison in a third place and copies it. The
#      original bug WAS a single inline copy that could not be reused, so the
#      worktree surface went unaudited for seven weeks.
#
# The empty-set case is a first-class test, not an afterthought: T-3105's rule
# is that a check may only PASS over the set it actually evaluated. A repo with
# no linked worktrees must SAY it examined zero, because "no output" and "all
# clean" are indistinguishable to a reader and only one of them is true.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    LIB="$_FW_ROOT/lib/hook-parity.sh"
    [ -f "$LIB" ] || skip "lib not found: $LIB"
    # shellcheck source=/dev/null
    source "$LIB"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    mkdir -p "$MAIN/.claude"

    git -C "$MAIN" init -q
    git -C "$MAIN" config user.email t@t
    git -C "$MAIN" config user.name t

    # Authority hook set: three hooks across two events.
    cat > "$MAIN/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [
        {"type": "command", "command": "$CLAUDE_PROJECT_DIR/bin/fw hook check-active-task"},
        {"type": "command", "command": "$CLAUDE_PROJECT_DIR/bin/fw hook check-worktree-governance-write"}
      ]}
    ],
    "PostToolUse": [
      {"matcher": "Write", "hooks": [
        {"type": "command", "command": "$CLAUDE_PROJECT_DIR/bin/fw hook checkpoint"}
      ]}
    ]
  }
}
JSON
    git -C "$MAIN" add -A
    git -C "$MAIN" commit -qm "init"
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

# Add a linked worktree at $1 with settings content $2 ("" = no settings file).
_add_wt() {
    local path="$1" content="$2"
    git -C "$MAIN" worktree add -q -b "b-$(basename "$path")" "$path" >/dev/null 2>&1
    rm -f "$path/.claude/settings.json"
    if [ -n "$content" ]; then
        mkdir -p "$path/.claude"
        printf '%s' "$content" > "$path/.claude/settings.json"
    else
        rm -rf "$path/.claude"
    fi
}

@test "authority root resolves to the main checkout from a linked worktree" {
    _add_wt "$TEST_ROOT/wt1" ""
    run fw_hook_parity_authority_root "$TEST_ROOT/wt1"
    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$MAIN" && pwd -P)" ]
}

@test "authority root resolves to itself from the main checkout" {
    run fw_hook_parity_authority_root "$MAIN"
    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$MAIN" && pwd -P)" ]
}

@test "in-sync replica reports ok N/M" {
    _add_wt "$TEST_ROOT/wt1" "$(cat "$MAIN/.claude/settings.json")"
    run fw_hook_parity_delta "$MAIN/.claude/settings.json" "$TEST_ROOT/wt1/.claude/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" = "ok 3/3" ]
}

@test "drifted replica names the missing hooks" {
    _add_wt "$TEST_ROOT/wt1" '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/bin/fw hook check-active-task"}]}]}}'
    run fw_hook_parity_delta "$MAIN/.claude/settings.json" "$TEST_ROOT/wt1/.claude/settings.json"
    [ "$status" -eq 0 ]
    [[ "$output" == missing\ 2:* ]]
    [[ "$output" == *check-worktree-governance-write* ]]
    [[ "$output" == *checkpoint* ]]
}

@test "replica with no settings.json reports absent, not missing-all" {
    _add_wt "$TEST_ROOT/wt1" ""
    run fw_hook_parity_delta "$MAIN/.claude/settings.json" "$TEST_ROOT/wt1/.claude/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" = "absent" ]
}

@test "unparseable replica settings report parse-error, never a clean ok" {
    _add_wt "$TEST_ROOT/wt1" 'not json at all {{{'
    run fw_hook_parity_delta "$MAIN/.claude/settings.json" "$TEST_ROOT/wt1/.claude/settings.json"
    [ "$status" -eq 0 ]
    [ "$output" = "parse-error" ]
}

@test "extra hooks in the replica are not reported as drift" {
    _add_wt "$TEST_ROOT/wt1" "$(python3 -c "
import json
d = json.load(open('$MAIN/.claude/settings.json'))
d['hooks']['PreToolUse'][0]['hooks'].append({'type':'command','command':'\$CLAUDE_PROJECT_DIR/bin/fw hook project-local-extra'})
print(json.dumps(d))
")"
    run fw_hook_parity_delta "$MAIN/.claude/settings.json" "$TEST_ROOT/wt1/.claude/settings.json"
    [ "$status" -eq 0 ]
    [[ "$output" == ok\ * ]]
}

@test "linked worktree enumeration excludes the main checkout" {
    _add_wt "$TEST_ROOT/wt1" ""
    _add_wt "$TEST_ROOT/wt2" ""
    run fw_hook_parity_linked_worktrees "$MAIN"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" != *"$MAIN"$'\n'* ]]
    [[ "$output" == *wt1* ]]
    [[ "$output" == *wt2* ]]
}

@test "repo with zero linked worktrees enumerates an empty set, exit 0" {
    run fw_hook_parity_linked_worktrees "$MAIN"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "non-git directory is unenumerable (exit 1), not an empty set" {
    # The distinction the caller must not collapse: empty means "checked, none
    # found"; exit 1 means "could not check". T-3105 — the second is a WARN.
    run fw_hook_parity_linked_worktrees "$TEST_ROOT"
    [ "$status" -eq 1 ]
}

@test "bin/fw holds zero copies of the predicate" {
    run bash -c "grep -c 'def extract_hooks' '$_FW_ROOT/bin/fw' || true"
    [ "$output" = "0" ]
}

@test "the predicate exists exactly once, in lib/hook-parity.sh" {
    run bash -c "grep -c 'def extract_hooks' '$LIB'"
    [ "$output" = "1" ]
}

@test "fw doctor: Worktrees section reports its set, Consumer shape survived" {
    # Both claims are about ONE doctor run, so it is invoked once. Splitting
    # them cost a second full scan of 31 consumers — minutes, for an assertion
    # over the same bytes. A slow unit suite is a unit suite people stop running.
    run bash -c "cd '$_FW_ROOT' && bin/fw doctor --quick 2>&1"

    # New subject: the section exists and states the size of the set it examined.
    [[ "$output" == *"Worktrees"* ]]
    [[ "$output" == *"linked worktree"* ]]

    # Old subject: the extraction did not change what the consumer loop prints.
    # Either verdict string is fine; what must not happen is the predicate
    # silently no-opping into a blank/parse-error column for every consumer —
    # which is exactly what an unsourced function would look like.
    [[ "$output" == *"Consumer Projects"* ]]
    [[ "$output" == *"hooks)"* || "$output" == *"missing "* ]]
    [[ "$output" != *"parse-error"* ]]
}
