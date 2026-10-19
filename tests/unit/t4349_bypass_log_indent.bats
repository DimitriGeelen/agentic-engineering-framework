#!/usr/bin/env bats
# T-4349: log_bypass_entry appended a hard-coded 2-space-indented item to a
# bypass log whose sequence was indentless (PyYAML re-dump: `bypasses:` with
# `- timestamp:` at column 0). The result was unparseable YAML, and the
# post-append check only printed a WARNING and returned 0.
#
# Hermetic: each test works in its own temp dir and sources the real
# agents/git/lib/bypass.sh. Colour vars and ensure_context_dir are stubbed.

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

# Indentless layout, exactly what yaml.safe_dump(sort_keys=False) produces.
write_indentless_log() {
    cat > "$BYPASS_LOG" <<'EOF'
bypasses:
- timestamp: 2026-02-13 18:46:10+00:00
  action: v0.1 base start
  commit: acb4594
  authorized_by: human
  reason: Bootstrap exception
  retroactive_task: null
EOF
}

# The 2-space layout the writer has always produced.
write_two_space_log() {
    cat > "$BYPASS_LOG" <<'EOF'
bypasses:
  - timestamp: 2026-02-13 18:46:10+00:00
    action: v0.1 base start
    commit: acb4594
    authorized_by: human
    reason: Bootstrap exception
    retroactive_task: null
EOF
}

# Prints the bypass count if the file parses, or exits 3 if it does not.
parsed_count() {
    python3 -I -c 'import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1]))
except Exception:
    sys.exit(3)
print(len(d["bypasses"]))' "$BYPASS_LOG"
}

@test "T4349: append to indentless log keeps the file parseable" {
    write_indentless_log
    [ "$(parsed_count)" = "1" ]
    run log_bypass_entry "abc1234" "T-1: test action" "regression reason"
    [ "$status" -eq 0 ]
    run parsed_count
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "T4349: appended entry in indentless log holds the right fields" {
    write_indentless_log
    log_bypass_entry "abc1234" "T-1: test action" "regression reason" >/dev/null 2>&1
    run python3 -I -c 'import sys, yaml
e = yaml.safe_load(open(sys.argv[1]))["bypasses"][-1]
print(e["commit"], e["action"], e["reason"])' "$BYPASS_LOG"
    [ "$status" -eq 0 ]
    [ "$output" = "abc1234 T-1: test action regression reason" ]
}

@test "T4349: append to 2-space log still parses (control)" {
    write_two_space_log
    run log_bypass_entry "def5678" "T-2: second" "control reason"
    [ "$status" -eq 0 ]
    run parsed_count
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "T4349: a post-append parse failure is a non-zero return, not a warning only" {
    # Pre-existing damage the append cannot repair: the file stays unparseable,
    # so the post-append check must fail the call.
    printf 'bypasses:\n- timestamp: 2026-01-01\n  action: [unclosed\n' > "$BYPASS_LOG"
    run log_bypass_entry "fee9999" "T-3: broken" "broken reason"
    [ "$status" -ne 0 ]
}

@test "T4349: append is append-only; prior bytes are unchanged" {
    write_indentless_log
    before="$(cat "$BYPASS_LOG")"
    log_bypass_entry "abc1234" "T-1: test action" "regression reason" >/dev/null 2>&1
    after="$(cat "$BYPASS_LOG")"
    [[ "$after" == "$before"* ]]
}
