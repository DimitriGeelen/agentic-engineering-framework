#!/usr/bin/env bats
# T-4373: log_bypass_entry wrote action and reason inside YAML double quotes
# with no escaping, so a double quote, a backslash or a newline in either made
# .context/bypass-log.yaml unparseable. The writer now emits single-quoted
# scalars ('' doubling, CR/LF collapsed to a space).
#
# Hermetic: same harness as t4349_bypass_log_indent.bats.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export BYPASS_LOG="$TEST_TEMP_DIR/bypass-log.yaml"
    RED="" GREEN="" NC=""
    ensure_context_dir() { :; }
    source "$FRAMEWORK_ROOT/agents/git/lib/bypass.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Prints "<action>|<reason>" of the last entry, or exits 3 if the file does not parse.
last_entry() {
    python3 -I -c 'import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1]))
except Exception:
    sys.exit(3)
e = d["bypasses"][-1]
print(e["action"] + "|" + e["reason"])' "$BYPASS_LOG"
}

@test "T4373: double quote in reason" {
    run log_bypass_entry "abc1234" "T-1: plain" 'operator said "ship it"'
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: plain|operator said "ship it"' ]
}

@test "T4373: double quote in action" {
    run log_bypass_entry "abc1234" 'T-1: fix "quoted" subject' "plain reason"
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: fix "quoted" subject|plain reason' ]
}

@test "T4373: backslash in reason" {
    run log_bypass_entry "abc1234" "T-1: plain" 'path C:\x\new and \q'
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: plain|path C:\x\new and \q' ]
}

@test "T4373: backslash in action" {
    run log_bypass_entry "abc1234" 'T-1: regex \d+ and \x' "plain reason"
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: regex \d+ and \x|plain reason' ]
}

@test "T4373: newline in reason collapses to a space" {
    run log_bypass_entry "abc1234" "T-1: plain" $'first line\n- second: line'
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: plain|first line - second: line' ]
}

@test "T4373: newline in action collapses to a space" {
    run log_bypass_entry "abc1234" $'T-1: subject\nbody: text' "plain reason"
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: subject body: text|plain reason' ]
}

@test "T4373: colon and single quote in reason and action" {
    run log_bypass_entry "abc1234" "T-1: it's key: value" "reason: don't # not a comment"
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = "T-1: it's key: value|reason: don't # not a comment" ]
}

@test "T4373: hostile values append cleanly to an indentless log (T-4349 layout)" {
    printf 'bypasses:\n- timestamp: 2026-02-13\n  action: a\n  commit: acb4594\n  authorized_by: human\n  reason: r\n  retroactive_task: null\n' > "$BYPASS_LOG"
    before="$(cat "$BYPASS_LOG")"
    run log_bypass_entry "abc1234" $'T-1: "q" \\ x\ny' $'"r" \\ z\nw: v'
    [ "$status" -eq 0 ]
    run last_entry
    [ "$status" -eq 0 ]
    [ "$output" = 'T-1: "q" \ x y|"r" \ z w: v' ]
    after="$(cat "$BYPASS_LOG")"
    [[ "$after" == "$before"* ]]
}
