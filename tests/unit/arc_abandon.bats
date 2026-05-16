#!/usr/bin/env bats
# T-1854 (T-NEW-6): fw arc abandon CLI verb.
#
# Allowed source states: draft, in-progress (refused from closed, abandoned).
# Refuses without --reason or with --reason text under 30 chars.
# Refuses under $CLAUDECODE=1 unless --i-am-human or --from-watchtower.
# Appends JSON row to .context/audits/arc-abandon.jsonl.
# Mutates arc YAML: status: abandoned, abandoned_at: <iso>, abandonment_reason: <text>.
# D-Immutability: arc YAML stays in .context/arcs/ (no move, no delete).

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/lib/arc.sh" ] || skip "lib/arc.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.context/working" \
             "$TEST_ROOT/.context/audits" "$TEST_ROOT/.tasks/active"

    cat > "$TEST_ROOT/.tasks/active/T-9999-stub.md" <<'MD'
---
id: T-9999
name: stub
---
MD

    export PROJECT_ROOT="$TEST_ROOT"
    export CONTEXT_DIR="$TEST_ROOT/.context"
    unset CLAUDECODE
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

arc_sh() {
    cd "$FRAMEWORK_ROOT"
    bash -c "source lib/arc.sh; $*"
}

arc_status() {
    awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' \
        "$TEST_ROOT/.context/arcs/$1.yaml" | tr -d ' "'
}

mk_arc() {
    arc_sh "arc_create $1 --name 'abandon test' --anchor T-9999 --headline-mechanic 'user sees the abandon test firing on the page'"
}

# --- happy path: draft → abandoned ---

@test "T-1854: arc_abandon on draft → abandoned" {
    mk_arc gone
    run arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Abandoned arc 'gone'"* ]]
    [[ "$output" == *"was: draft"* ]]
    [ "$(arc_status gone)" = "abandoned" ]
}

# --- happy path: in-progress → abandoned ---

@test "T-1854: arc_abandon on in-progress → abandoned" {
    mk_arc gone
    arc_sh "arc_start gone"
    run arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"was: in-progress"* ]]
    [ "$(arc_status gone)" = "abandoned" ]
}

# --- refusal: closed → abandoned blocked ---

@test "T-1854: arc_abandon on closed arc is refused" {
    mk_arc gone
    arc_sh "arc_start gone"
    arc_sh "arc_close gone --demo none --justification 'test closure rationale for lifecycle smoke arc' --i-am-human"
    run arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
    [[ "$output" == *"closed"* ]]
    [ "$(arc_status gone)" = "closed" ]
}

# --- refusal: abandoned → abandoned blocked (no double-abandon) ---

@test "T-1854: arc_abandon on already-abandoned arc is refused" {
    mk_arc gone
    arc_sh "arc_abandon gone --reason 'first abandon rationale, more than thirty chars long'"
    run arc_sh "arc_abandon gone --reason 'second abandon rationale, more than thirty chars long'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
    [[ "$output" == *"abandoned"* ]]
}

# --- refusal: --reason required ---

@test "T-1854: arc_abandon refuses without --reason" {
    mk_arc gone
    run arc_sh "arc_abandon gone"
    [ "$status" -eq 2 ]
    [[ "$output" == *"--reason"* ]]
    [ "$(arc_status gone)" = "draft" ]
}

# --- refusal: --reason too short ---

@test "T-1854: arc_abandon refuses --reason under 30 chars" {
    mk_arc gone
    run arc_sh "arc_abandon gone --reason 'too short'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"30 chars"* ]]
    [ "$(arc_status gone)" = "draft" ]
}

# --- refusal: $CLAUDECODE=1 agent-gate (T-1671 pattern) ---

@test "T-1854: arc_abandon refused under CLAUDECODE=1 without override" {
    mk_arc gone
    CLAUDECODE=1 run arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"agents must not invoke"* ]]
    [[ "$output" == *"--i-am-human"* ]]
    [ "$(arc_status gone)" = "draft" ]
}

# --- CLAUDECODE bypass via --i-am-human ---

@test "T-1854: --i-am-human bypasses CLAUDECODE gate" {
    mk_arc gone
    CLAUDECODE=1 run arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate' --i-am-human"
    [ "$status" -eq 0 ]
    [ "$(arc_status gone)" = "abandoned" ]
}

# --- audit log: JSONL row appended ---

@test "T-1854: arc_abandon appends row to .context/audits/arc-abandon.jsonl" {
    mk_arc gone
    arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    [ -f "$TEST_ROOT/.context/audits/arc-abandon.jsonl" ]
    run cat "$TEST_ROOT/.context/audits/arc-abandon.jsonl"
    [[ "$output" == *'"arc":"gone"'* ]]
    [[ "$output" == *'"status_at_abandon":"draft"'* ]]
    [[ "$output" == *"abandonment_reason"* ]]
    # one row per abandon
    [ "$(wc -l < "$TEST_ROOT/.context/audits/arc-abandon.jsonl")" -eq 1 ]
}

# --- YAML fields written ---

@test "T-1854: arc YAML gains abandoned_at + abandonment_reason fields" {
    mk_arc gone
    arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    run cat "$TEST_ROOT/.context/arcs/gone.yaml"
    [[ "$output" == *"status: abandoned"* ]]
    [[ "$output" == *"abandoned_at:"* ]]
    [[ "$output" == *"abandonment_reason:"* ]]
    [[ "$output" == *"rationale that is at least thirty"* ]]
}

# --- D-Immutability: file stays in place ---

@test "T-1854: arc YAML file stays in .context/arcs/ after abandonment" {
    mk_arc gone
    arc_sh "arc_abandon gone --reason 'rationale that is at least thirty chars long for the gate'"
    [ -f "$TEST_ROOT/.context/arcs/gone.yaml" ]
}

# --- bash -n sanity ---

@test "T-1854: lib/arc.sh parses cleanly under bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/arc.sh"
    [ "$status" -eq 0 ]
}
