#!/usr/bin/env bats
# T-3431 (D-592): SessionStart hook (post-compact-resume.sh) runs a bounded
# `fw fabric enrich --describe --quiet` on every start/resume/compact and
# injects one summary line; `fw resume status` mirrors the cached line rather
# than re-running the scan. Fixture project throughout (T-3326) — the live
# corpus's card counts move under a fixed-count assertion for reasons
# unrelated to this hook.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/post-compact-resume.sh"
RESUME="$FRAMEWORK_ROOT/agents/resume/resume.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.fabric/components" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/handovers" \
             "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/lib"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    touch "$PROJECT_ROOT/lib/a.sh" "$PROJECT_ROOT/lib/b.sh"
    printf 'subsystems: []\n' > "$PROJECT_ROOT/.fabric/subsystems.yaml"
    unset FW_FABRIC_DESCRIBE_TIMEOUT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_card_todo() {
    local slug="$1" loc="$2"
    cat > "$PROJECT_ROOT/.fabric/components/$slug.yaml" <<YAML
id: $loc
name: $slug
location: $loc
subsystem: unknown
purpose: "TODO: describe what this component does"
depends_on: []
depended_by: []
YAML
}

# Manual capture (not bats `run`) so stdout is never interleaved with stray
# stderr from the hook's other sections — the JSON parse below needs stdout
# to be exactly the hookSpecificOutput line.
_run_hook() {
    HOOK_OUT=$(printf '{"source":"resume"}' | bash "$HOOK" 2>"$TEST_TEMP_DIR/.hook_stderr.log")
    HOOK_RC=$?
}

_hook_context() {
    python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d['hookSpecificOutput']['additionalContext'])
" "$HOOK_OUT"
}

@test "T-3431: hook emits the Fabric Quality line on a fixture with 2 TODO cards" {
    _card_todo lib-a lib/a.sh
    _card_todo lib-b lib/b.sh
    _run_hook
    [ "$HOOK_RC" -eq 0 ]
    context=$(_hook_context)
    [[ "$context" == *"## Fabric Quality"* ]]
    [[ "$context" == *"Fabric: 2 cards"* ]]
    [[ "$context" == *"2 TODO purpose"* ]]
    [ -f "$PROJECT_ROOT/.context/working/.fabric-describe.last" ]
}

@test "T-3431: hook exits 0 and falls back to the last-known line when the describe pass is forced to fail" {
    _card_todo lib-a lib/a.sh
    _run_hook
    [ "$HOOK_RC" -eq 0 ]
    cached_before=$(cat "$PROJECT_ROOT/.context/working/.fabric-describe.last")

    # Force the live describe call to fail: a 0s timeout kills it immediately.
    export FW_FABRIC_DESCRIBE_TIMEOUT=0
    _run_hook
    [ "$HOOK_RC" -eq 0 ]
    context=$(_hook_context)
    [[ "$context" == *"## Fabric Quality"* ]]
    [[ "$context" == *"$cached_before"* ]]
    # The cache file is untouched by the failed run — still the prior value.
    cached_after=$(cat "$PROJECT_ROOT/.context/working/.fabric-describe.last")
    [ "$cached_before" = "$cached_after" ]
}

@test "T-3431: no Fabric Quality section when .fabric/components does not exist" {
    rm -rf "$PROJECT_ROOT/.fabric"
    _run_hook
    [ "$HOOK_RC" -eq 0 ]
    context=$(_hook_context)
    [[ "$context" != *"## Fabric Quality"* ]]
}

@test "T-3431: fw resume status prints the same cached fabric line" {
    _card_todo lib-a lib/a.sh
    _run_hook
    [ "$HOOK_RC" -eq 0 ]
    run "$RESUME" status
    [[ "$output" == *"Fabric Quality:"* ]]
    [[ "$output" == *"Fabric: 1 cards"* ]]
}

@test "T-3431: fw resume status is silent on fabric when no cache exists yet" {
    run "$RESUME" status
    [[ "$output" != *"Fabric Quality:"* ]]
}
