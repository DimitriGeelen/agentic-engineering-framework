#!/usr/bin/env bats
# T-3711: `fw upgrade` step 5 must keep hooks registered with `fw hook-enable
# --script` — 055 lost its check-messages hook (UserPromptSubmit + SessionStart)
# upgrading to 1.7.740. Fixed by T-3833 (e34a32a75: settings regeneration carries
# project hooks, KEPT). T-3833's own test pins a PreToolUse matcher hook; this one
# pins the reported shape: hook-enable --script, matcher "", two non-tool events,
# through both step-5 branches (regenerate, then merge on the second upgrade).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/scripts" "$PROJ/.claude"
    git -C "$PROJ" init -q
    git -C "$PROJ" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init
    _fw vendor --target "$PROJ" >/dev/null 2>&1
    printf 'project_name: proj\nversion: %s\n' "$(tr -d '\n' < "$PROJ/.agentic-framework/VERSION")" > "$PROJ/.framework.yaml"
    printf '#!/bin/sh\nexit 0\n' > "$PROJ/scripts/check-messages.sh"
    chmod +x "$PROJ/scripts/check-messages.sh"
    echo '{}' > "$PROJ/.claude/settings.json"
    local ev
    for ev in UserPromptSubmit SessionStart; do
        ( cd "$PROJ" && PROJECT_ROOT="$PROJ" "$FRAMEWORK_ROOT/bin/fw" hook-enable \
            --script "$PROJ/scripts/check-messages.sh" --matcher "" --event "$ev" \
            --file "$PROJ/.claude/settings.json" ) >/dev/null
    done
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_fw() {
    ( cd "$FRAMEWORK_ROOT" && env -u PROJECT_ROOT FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$FRAMEWORK_ROOT/bin/fw" "$@" )
}

# Count check-messages commands registered under event $1.
_count() {
    python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(sum(1 for g in d.get("hooks", {}).get(sys.argv[2], [])
          for h in g.get("hooks", []) if "check-messages.sh" in h.get("command", "")))
' "$PROJ/.claude/settings.json" "$1"
}

@test "T-3711: hook-enable --script hooks survive step 5 regenerate and merge branches" {
    [ "$(_count UserPromptSubmit)" -eq 1 ]
    [ "$(_count SessionStart)" -eq 1 ]

    run _fw upgrade "$PROJ"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [[ "$output" == *"KEPT  UserPromptSubmit"*"check-messages.sh"* ]] || { echo "$output"; false; }
    [[ "$output" == *"KEPT  SessionStart"*"check-messages.sh"* ]]
    [ "$(_count UserPromptSubmit)" -eq 1 ]
    [ "$(_count SessionStart)" -eq 1 ]
    grep -q 'fw hook check-active-task' "$PROJ/.claude/settings.json"

    run _fw upgrade "$PROJ"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(_count UserPromptSubmit)" -eq 1 ]
    [ "$(_count SessionStart)" -eq 1 ]
}
