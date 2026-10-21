#!/usr/bin/env bats
# T-4244: the consumer CLAUDE.md template (and the /resume command template)
# told consumer agents to "use bin/fw", but a vendored consumer has no bin/fw
# at its root — only .agentic-framework/bin/fw. Origin: dimitri-mint-dev P-017
# proposal 6 (docs/reports/T-4237-inputs/P-017-feature-proposal.yaml).
#
# Pin: no consumer-facing template names a bare `bin/fw` launcher, and a fresh
# `fw init` consumer's generated files agree with what is on its disk.

load ../test_helper

setup() {
    unset PROJECT_ROOT  # L-456: avoid project-root leak from the parent shell
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Lines naming bin/fw that are NOT the vendored .agentic-framework/bin/fw.
bare_bin_fw() {
    grep -nE '(^|[^-a-z/.])bin/fw' "$1" | grep -v '\.agentic-framework/bin/fw' || true
}

@test "T-4244: consumer CLAUDE.md template names no bare bin/fw" {
    out=$(bare_bin_fw "$FRAMEWORK_ROOT/lib/templates/claude-project.md")
    [ -z "$out" ] || { echo "bare bin/fw in template: $out"; false; }
    grep -q 'Use `.agentic-framework/bin/fw` not `fw`' "$FRAMEWORK_ROOT/lib/templates/claude-project.md"
}

@test "T-4244: /resume command template names no bare bin/fw" {
    out=$(bare_bin_fw "$FRAMEWORK_ROOT/lib/templates/resume-md.md")
    [ -z "$out" ] || { echo "bare bin/fw in resume template: $out"; false; }
}

@test "T-4244: fresh fw init consumer — generated CLAUDE.md matches the launcher on disk" {
    run "$FRAMEWORK_ROOT/bin/fw" init "$TEST_TEMP_DIR" --provider claude
    [ -f "$TEST_TEMP_DIR/CLAUDE.md" ]
    [ -x "$TEST_TEMP_DIR/.agentic-framework/bin/fw" ]
    [ ! -e "$TEST_TEMP_DIR/bin/fw" ]
    out=$(bare_bin_fw "$TEST_TEMP_DIR/CLAUDE.md")
    [ -z "$out" ] || { echo "bare bin/fw in generated CLAUDE.md: $out"; false; }
    out=$(bare_bin_fw "$TEST_TEMP_DIR/.claude/commands/resume.md")
    [ -z "$out" ] || { echo "bare bin/fw in generated resume.md: $out"; false; }
}
