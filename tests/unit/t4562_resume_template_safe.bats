#!/usr/bin/env bats
# T-4562 — every command /resume tells an agent to run must pass the read-only
# gate with NO task in focus. /resume runs at session start, before any focus is
# set; a step the gate refuses is a step that cannot run. Since T-4512 the old
# step 5 (`WURL=$(cat …watchtower.url …); curl -sf "$WURL/" …`) was refused —
# its curl word starts with an expansion of a value read from a file — and 832
# hit it on be.2. The template now calls `.agentic-framework/bin/fw watchtower reachable`
# (T-4244: the vendored launcher, which consumers actually have).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    export PROJECT_ROOT="$FRAMEWORK_ROOT" _FW_PAYLOAD_CWD="$FRAMEWORK_ROOT"
    TMPL="$FRAMEWORK_ROOT/lib/templates/resume-md.md"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Same order as check-active-task.sh: a write pattern anywhere wins, then the allowlist.
gate_safe() {
    ! has_bash_write_pattern "$1" && is_bash_safe_command "$1"
}

# Inline-code spans on the numbered Step-1 lines that are commands (contain a
# space, or name bin/fw) — bare paths like `.tasks/active/` are not commands.
template_commands() {
    awk '/^## Step 1/{on=1; next} /^## /{on=0} on && /^[0-9]+\. /' "$1" \
        | grep -oE '`[^`]+`' | tr -d '`' | grep -E ' |^bin/fw' || true
}

@test "resume template: every Step-1 shell command passes the read-only gate" {
    local n=0 c
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        n=$((n + 1))
        gate_safe "$c" || { echo "refused with no focus: $c"; return 1; }
    done < <(template_commands "$TMPL")
    # git status, git log, cat tool-counter, watchtower check — extraction must find them
    [ "$n" -ge 4 ]
}

@test "resume template: the Watchtower step is the self-resolving verb" {
    template_commands "$TMPL" | grep -qx '.agentic-framework/bin/fw watchtower reachable'
    ! grep -q 'WURL' "$TMPL" || false
}

@test "the old step-5 shape stays refused (gate not loosened)" {
    local old='WURL=$(cat .context/working/watchtower.url 2>/dev/null || echo "http://localhost:$(bin/fw config get PORT 2>/dev/null || echo 3000)"); curl -sf "$WURL/" > /dev/null && echo "running at $WURL" || echo "stopped"'
    ! gate_safe "$old" || false
}

@test "init.sh inline fallback carries the same Watchtower step as the template" {
    local want
    want=$(grep -E '^5\. Check web server:' "$TMPL")
    grep -qxF "$want" "$FRAMEWORK_ROOT/lib/init.sh"
    ! grep -q 'WURL' "$FRAMEWORK_ROOT/lib/init.sh" || false
}

@test "watchtower reachable: nothing answering -> 'stopped', rc 3" {
    WATCHTOWER_URL="http://127.0.0.1:1" run "$FRAMEWORK_ROOT/bin/watchtower.sh" reachable
    [ "$status" -eq 3 ]
    [ "$output" = "stopped" ]
}
