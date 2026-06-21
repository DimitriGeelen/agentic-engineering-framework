#!/usr/bin/env bats
# Unit tests for agents/observe/observe.sh (fw note)
# Origin: T-932, T-943 (isolation fix)

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

# Isolate capture tests from real inbox
setup() {
    export TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/.context/working"
    # Create a minimal focus.yaml so get_focus_task works
    echo 'current_task: T-001' > "$TEST_DIR/.context/working/focus.yaml"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# --- Help ---

@test "observe --help shows usage" {
    run "$OBSERVE" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw note"* ]]
    [[ "$output" == *"observation"* ]] || [[ "$output" == *"capture"* ]]
}

@test "observe -h shows usage" {
    run "$OBSERVE" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw note"* ]]
}

# --- Count ---

@test "observe count shows pending count" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" count
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending"* ]] || [[ "$output" =~ [0-9]+ ]]
}

# --- List ---

@test "observe list runs without error" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" list
    [ "$status" -eq 0 ]
}

# --- Capture (isolated) ---

@test "observe captures a note" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" "Test observation from bats"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OBS-"* ]] || [[ "$output" == *"Captured"* ]] || [[ "$output" == *"observation"* ]]
    # Verify it went to temp dir, not real inbox
    [ -f "$TEST_DIR/.context/inbox.yaml" ]
}

@test "observe captures with --tag" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" "Tagged observation" --tag "test"
    [ "$status" -eq 0 ]
}

# --- Empty input ---

@test "observe fails with empty text" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" ""
    # Should fail or show help
    [ "$status" -ne 0 ] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"fw note"* ]]
}

# --- Promote (T-1458) ---

@test "promote --help shows usage with --type flag" {
    run "$OBSERVE" promote --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--type"* ]]
}

@test "promote without OBS-NNN errors with usage hint" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" promote
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: fw note promote"* ]]
    [[ "$output" == *"--type"* ]]
}

@test "promote rejects unknown flag" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" promote OBS-001 --frobnicate
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown flag"* ]]
}

@test "promote --type inception is parsed (no syntax/flag error)" {
    export PROJECT_ROOT="$TEST_DIR"
    # OBS-001 won't exist in fresh inbox — should fail with 'not found', NOT with flag-parse error
    run "$OBSERVE" promote OBS-001 --type inception
    [ "$status" -ne 0 ]
    # Confirms --type was accepted; failure is the missing-observation path
    [[ "$output" == *"not found"* ]]
}

# --- Heredoc indent regression (T-2316) ---

@test "two sequential captures produce parseable YAML (T-2316)" {
    export PROJECT_ROOT="$TEST_DIR"
    "$OBSERVE" "first obs"  >/dev/null
    "$OBSERVE" "second obs" >/dev/null
    # The original bug: second capture appended with mismatched indent, breaking the parse.
    run python3 -c "import yaml; d=yaml.safe_load(open('$TEST_DIR/.context/inbox.yaml')); print(len(d.get('observations',[])))"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "captured observation appends at root list level not nested (T-2316)" {
    export PROJECT_ROOT="$TEST_DIR"
    "$OBSERVE" "first obs"  >/dev/null
    "$OBSERVE" "second obs" >/dev/null
    # Root-level dash (matches OBS-001..OBS-067 in production inbox.yaml)
    n_root=$(grep -cE "^- id: OBS-" "$TEST_DIR/.context/inbox.yaml" || true)
    n_nested=$(grep -cE "^  - id: OBS-" "$TEST_DIR/.context/inbox.yaml" || true)
    [ "$n_root" -eq 2 ]
    [ "$n_nested" -eq 0 ]
}

# --- Backslash/quote escaping regression (T-2456 / OBS-084) ---
# A note body with a backslash (e.g. a regex '\d+') or an embedded double-quote
# used to be interpolated raw into a `text: "$text"` double-quoted YAML scalar,
# producing an "unknown escape character" ScannerError that crashed EVERY
# `fw note list/triage` (yaml.safe_load) and left the whole inbox unreadable.
# Origin: OBS-081's '- **IW-(\d+):' broke the production inbox for ~a day.

@test "note with a backslash (regex) keeps inbox parseable and round-trips (T-2456)" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" 'regex matches \d+ and a path C:\dir\x'
    [ "$status" -eq 0 ]
    # inbox must still parse (the bug: ScannerError 'unknown escape character')
    run python3 -c "
import yaml
d = yaml.safe_load(open('$TEST_DIR/.context/inbox.yaml'))
print(d['observations'][0]['text'])
"
    [ "$status" -eq 0 ]
    # exact round-trip: the single backslashes survive unchanged
    [ "$output" = 'regex matches \d+ and a path C:\dir\x' ]
}

@test "note with an embedded double-quote keeps inbox parseable and round-trips (T-2456)" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" 'he said "hello" then left'
    [ "$status" -eq 0 ]
    run python3 -c "
import yaml
d = yaml.safe_load(open('$TEST_DIR/.context/inbox.yaml'))
print(d['observations'][0]['text'])
"
    [ "$status" -eq 0 ]
    [ "$output" = 'he said "hello" then left' ]
}

@test "backslash note then a second note: both entries still parse (T-2456)" {
    export PROJECT_ROOT="$TEST_DIR"
    "$OBSERVE" 'first with \d+ regex' >/dev/null
    "$OBSERVE" 'second plain note'    >/dev/null
    run python3 -c "import yaml; d=yaml.safe_load(open('$TEST_DIR/.context/inbox.yaml')); print(len(d['observations']))"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}
