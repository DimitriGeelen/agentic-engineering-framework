#!/usr/bin/env bats
# T-4183 (832 OBS-380, their T-1150): audit WARN/FAIL mitigations hard-code the
# framework-repo path `bin/fw`. A consumer has no PROJECT_ROOT/bin/fw — its fw is
# .agentic-framework/bin/fw — so a pasted mitigation failed with "No such file".
# The emitters (warn/fail/info) now rewrite a standalone `bin/fw` token to the
# resolved framework command. Same class T-3964 fixed for the arc rescore.

load ../test_helper

AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMPROOT=$(mktemp -d)
    # Pull only the emitters (and any helper they call) out of audit.sh; sourcing
    # the whole script would run the audit.
    EMITTERS="$TMPROOT/emitters.sh"
    awk '/^(_fw_cmd_text|warn|fail|info)\(\) \{/{f=1} f{print} f&&/^}/{f=0}' "$AUDIT" > "$EMITTERS"
    grep -q '^warn() {' "$EMITTERS"
}

teardown() {
    [ -d "${TMPROOT:-}" ] && rm -rf "$TMPROOT"
}

# _emit <project_root> <framework_root> <fn> <title> <evidence> <mitigation>
_emit() {
    local pr="$1" fr="$2"; shift 2
    PROJECT_ROOT="$pr" FRAMEWORK_ROOT="$fr" bash -c '
        source "$1"; shift
        PASS_COUNT=0 WARN_COUNT=0 FAIL_COUNT=0 FAIL_REF_COUNT=0 FAIL_WORKTREE_COUNT=0
        declare -a PRIORITY_ACTIONS FINDINGS FAIL_WORKTREE_TITLES
        "$@"
        printf "ACTION=%s\n" "${PRIORITY_ACTIONS[@]:-}"
        printf "FINDING=%s\n" "${FINDINGS[@]}"
    ' _ "$EMITTERS" "$@"
}

@test "vendored consumer: warn mitigation names .agentic-framework/bin/fw" {
    mkdir -p "$TMPROOT/proj/.agentic-framework/bin"
    run _emit "$TMPROOT/proj" "$TMPROOT/proj/.agentic-framework" \
        warn "x" "e" "Run: bin/fw sidecar inbox --peek, then bin/fw sidecar inbox"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mitigation: Run: .agentic-framework/bin/fw sidecar inbox --peek, then .agentic-framework/bin/fw sidecar inbox"* ]]
    [[ "$output" == *"ACTION=Run: .agentic-framework/bin/fw sidecar inbox --peek"* ]]
    [[ "$output" == *"FINDING=WARN|x|Run: .agentic-framework/bin/fw sidecar"* ]]
    ! grep -Eq '(^|[ :])bin/fw' <<<"$output" || false
}

@test "vendored consumer: fail and info titles are rewritten too" {
    mkdir -p "$TMPROOT/proj/.agentic-framework/bin"
    run _emit "$TMPROOT/proj" "$TMPROOT/proj/.agentic-framework" \
        fail "t" "e" "Restore it: bin/fw vendor self (or fw upgrade)"
    [[ "$output" == *"Mitigation: Restore it: .agentic-framework/bin/fw vendor self (or fw upgrade)"* ]]
    run _emit "$TMPROOT/proj" "$TMPROOT/proj/.agentic-framework" \
        info "see: bin/fw review-queue"
    [[ "$output" == *"see: .agentic-framework/bin/fw review-queue"* ]]
}

@test "framework outside the project: absolute framework path" {
    mkdir -p "$TMPROOT/proj" "$TMPROOT/fwhome/bin"
    run _emit "$TMPROOT/proj" "$TMPROOT/fwhome" \
        warn "x" "e" "Sweep with: bin/fw task archive-eligible"
    [[ "$output" == *"Mitigation: Sweep with: $TMPROOT/fwhome/bin/fw task archive-eligible"* ]]
}

@test "framework repo itself: text unchanged" {
    mkdir -p "$TMPROOT/fwrepo/bin"
    run _emit "$TMPROOT/fwrepo" "$TMPROOT/fwrepo" \
        warn "x" "e" "Run: bin/fw watchtower restart"
    [[ "$output" == *"Mitigation: Run: bin/fw watchtower restart"* ]]
}

@test "already-qualified .agentic-framework/bin/fw is not double-prefixed" {
    mkdir -p "$TMPROOT/proj/.agentic-framework/bin"
    run _emit "$TMPROOT/proj" "$TMPROOT/proj/.agentic-framework" \
        warn "x" "e" "No catalogue: .agentic-framework/bin/fw upgrade (consumer)"
    [[ "$output" == *"Mitigation: No catalogue: .agentic-framework/bin/fw upgrade (consumer)"* ]]
    ! grep -q '\.agentic-framework/\.agentic-framework' <<<"$output" || false
}
