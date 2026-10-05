#!/usr/bin/env bats
# T-3881: `fw upgrade` step [5/10] computes "expected hooks" from the framework
# repo's own .claude/settings.json and compares them with what
# lib/init.sh generate_claude_code_config writes for a consumer. A hook added
# here but not to the template made EVERY consumer upgrade end
# "1 step(s) failed" (ring20-dashboard, v1.8.0 -> v1.8.2: check-paid-backend,
# check-worktree-governance-write, stop-driver). This pins the parity at the
# source, before a consumer ever sees it.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export FRAMEWORK_ROOT="${BATS_TEST_DIRNAME}/../.."
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    C="$TEST_TEMP_DIR/consumer"
    mkdir -p "$C/.agentic-framework/bin"
    printf 'project_name: c\n' > "$C/.framework.yaml"
    ( cd "$C" && source "$FRAMEWORK_ROOT/lib/colors.sh" && source "$FRAMEWORK_ROOT/lib/errors.sh" \
      && source "$FRAMEWORK_ROOT/lib/init.sh" && generate_claude_code_config "$C" >/dev/null 2>&1 )
}

_gap() {   # prints "<missing-from-template>|<template-only>" as sorted reprs
    python3 - "$FRAMEWORK_ROOT/.claude/settings.json" "$C/.claude/settings.json" <<'EOF'
import sys, os
sys.path.insert(0, os.path.join(os.environ["FRAMEWORK_ROOT"], "lib"))
from hook_parity import extract_hooks
a, t = extract_hooks(sys.argv[1]), extract_hooks(sys.argv[2])
print(sorted(a - t), "|", sorted(t - a))
EOF
}

@test "t3881: the generated template is valid JSON with hooks" {
    run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d['hooks']" "$C/.claude/settings.json"
    [ "$status" -eq 0 ]
}

@test "t3881: every hook the framework registers is one the consumer template writes" {
    run _gap
    [ "$status" -eq 0 ]
    [[ "$output" == "[] |"* ]]
}

@test "t3881: the three hooks from the field report are in the template" {
    run grep -c -E 'hook (check-paid-backend|check-worktree-governance-write|stop-driver)"' "$C/.claude/settings.json"
    [ "$output" -eq 3 ]
}

@test "t3881: a direct agents/context/X.sh command and 'fw hook X' are one hook name" {
    printf '%s' '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/agents/context/stop-driver.sh"}]}]}}' > "$TEST_TEMP_DIR/a.json"
    printf '%s' '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook stop-driver"}]}]}}' > "$TEST_TEMP_DIR/b.json"
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
from hook_parity import extract_hooks
assert extract_hooks('$TEST_TEMP_DIR/a.json') == extract_hooks('$TEST_TEMP_DIR/b.json') == {('Stop','stop-driver')}"
    [ "$status" -eq 0 ]
}
