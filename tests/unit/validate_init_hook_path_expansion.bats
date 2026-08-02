#!/usr/bin/env bats
# T-2724 — lib/validate-init.sh must expand ${CLAUDE_PROJECT_DIR} before testing
# whether a hook script exists.
#
# Origin: every `fw init` ended with
#   ✗ hookpaths-6vc  Hook script paths all resolve — 19 hook script(s) not found
#   ✗ func-paths  Missing hook scripts: fw,fw,fw,...  (nineteen times)
#   Validation: 2 error(s) out of 42 checks
# on a completely correct install. `fw init` writes hook commands in the form
# '${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <event>'; the validator passed
# that literal string to os.path.exists(), which is always False, and reported
# os.path.basename() of it — hence 'fw' nineteen times instead of a script name.
#
# The check's passing state was therefore unreachable for the very config the framework
# itself generates. Both directions are pinned below, because a fix that merely silenced
# the check would satisfy the first test alone.

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-validate-hookpath-XXXXXX)"
    FW="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}/bin/fw"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _project_with_hook <command-string> — build a minimal project whose settings.json
# contains exactly one hook with the given command, and echo its path.
_project_with_hook() {
    local cmd="$1"
    local p="$TEST_TEMP_DIR/proj"
    rm -rf "$p"
    mkdir -p "$p/.claude" "$p/.agentic-framework/bin"
    touch "$p/.agentic-framework/bin/fw"
    CMD="$cmd" python3 -c "
import json, os
settings = {'hooks': {'PreToolUse': [
    {'matcher': 'Bash', 'hooks': [{'type': 'command', 'command': os.environ['CMD']}]}
]}}
with open(os.environ['OUT'], 'w') as f:
    json.dump(settings, f)
" OUT="$p/.claude/settings.json" 2>/dev/null || {
        CMD="$cmd" OUT="$p/.claude/settings.json" python3 -c "
import json, os
settings = {'hooks': {'PreToolUse': [
    {'matcher': 'Bash', 'hooks': [{'type': 'command', 'command': os.environ['CMD']}]}
]}}
with open(os.environ['OUT'], 'w') as f:
    json.dump(settings, f)
"
    }
    printf '%s' "$p"
}

# _hook_lines <project> — the two hook-path verdict lines, ANSI stripped.
# validate-init exits non-zero for unrelated reasons on a minimal fixture, so the
# exit status is deliberately not the assertion target; the verdict lines are.
_hook_lines() {
    "$FW" validate-init "$1" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "hookpaths-6vc|func-paths" || true
}

@test "T-2724: a correct \${CLAUDE_PROJECT_DIR} hook path validates as resolving" {
    local p; p=$(_project_with_hook '${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook pre-compact')
    run _hook_lines "$p"
    [ "$status" -eq 0 ]
    echo "$output"
    [[ "$output" == *"✓ hookpaths-6vc"* ]]
    [[ "$output" == *"✓ func-paths"* ]]
}

@test "T-2724: the pre-fix symptom is gone — no hook is reported missing as 'fw'" {
    local p; p=$(_project_with_hook '${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook pre-compact')
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" != *"Missing hook scripts: fw"* ]]
}

@test "T-2724 negative control: a genuinely missing script is still reported broken" {
    local p; p=$(_project_with_hook '${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/no-such-script run')
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" == *"✗ func-paths"* ]]
}

@test "T-2724 negative control: the broken script is named accurately, not as 'fw'" {
    # The pre-fix bug did not just produce false positives — it also destroyed the
    # identity of the offending script. A fix that resolves paths but still reports
    # the wrong name would leave the error message useless.
    local p; p=$(_project_with_hook '${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/no-such-script run')
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" == *"no-such-script"* ]]
}

@test "T-2724 negative control: an unknown variable does not silently resolve to a pass" {
    # os.path.expandvars leaves unrecognised variables untouched, so the path stays
    # non-existent and the check must still fail. If a future fix switched to a
    # permissive 'strip anything that looks like a variable' approach, this catches it.
    local p; p=$(_project_with_hook '${TOTALLY_UNKNOWN_VAR}/some-script run')
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" == *"✗ func-paths"* ]]
    [[ "$output" == *"some-script"* ]]
}

@test "T-2724: a bare absolute path that exists still validates (no regression)" {
    local p; p=$(_project_with_hook "$TEST_TEMP_DIR/proj/.agentic-framework/bin/fw hook pre-compact")
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" == *"✓ func-paths"* ]]
}

# ── T-2725: carrier shapes beyond the one T-2724 was measured against ───────────
# Applying 832's rail-379 finding: the selector fires on EVERY hook command shape,
# but T-2724 was verified against exactly one — the ${CLAUDE_PROJECT_DIR}/…/fw form,
# because that is the shape fw init writes and therefore the shape the fixture had.

@test "T-2725: a wrapper-style hook (bash \${CLAUDE_PROJECT_DIR}/x.sh) is not falsely broken" {
    # The selector picks 'bash', and os.path.exists('bash') is False — so before the
    # PATH-resolution fix this valid hook was reported broken. Same false positive as
    # T-2724, surviving under a different carrier shape.
    local p; p=$(_project_with_hook 'bash ${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw')
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" == *"✓ func-paths"* ]]
}

@test "T-2725 negative control: a bare command NOT on PATH is still reported broken" {
    local p; p=$(_project_with_hook 'definitely-not-a-real-binary-xyz run')
    run _hook_lines "$p"
    echo "$output"
    [[ "$output" == *"✗ func-paths"* ]]
    [[ "$output" == *"definitely-not-a-real-binary-xyz"* ]]
}
