#!/usr/bin/env bats
# T-1852 (T-NEW-5a): arc lifecycle state machine.
#
# Four allowed states (ARC_STATES): draft, in-progress, closed, abandoned.
# Transitions:
#   arc_create  → status: draft (T-1852 changed default; pre-T-1852 arcs
#                                untouched, remain in-progress per D3)
#   arc_start   → draft → in-progress
#   arc_close   → in-progress → closed
#   arc_abandon → draft|in-progress → abandoned (T-1854, not in this slice)
#
# Refusals exit non-zero with actionable error citing the allowed transitions.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/lib/arc.sh" ] || skip "lib/arc.sh not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.context/arcs" "$TEST_ROOT/.context/working" \
             "$TEST_ROOT/.tasks/active"

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

# Helper: run a snippet against the live arc.sh.
arc_sh() {
    cd "$FRAMEWORK_ROOT"
    bash -c "source lib/arc.sh; $*"
}

# Read status from a fixture arc.
arc_status() {
    awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' \
        "$TEST_ROOT/.context/arcs/$1.yaml" | tr -d ' "'
}

# --- arc_create writes draft ---

@test "T-1852: arc_create writes status: draft (was in-progress pre-T-1852)" {
    arc_sh "arc_create life --name 'lifecycle test' --anchor T-9999 --headline-mechanic 'user sees the lifecycle test firing on the page'"
    [ "$(arc_status life)" = "draft" ]
}

# --- arc_start: draft → in-progress ---

@test "T-1852: arc_start on draft → in-progress" {
    arc_sh "arc_create life --name 'lifecycle test' --anchor T-9999 --headline-mechanic 'user sees the lifecycle test firing on the page'"
    run arc_sh "arc_start life"
    [ "$status" -eq 0 ]
    [[ "$output" == *"draft → in-progress"* ]]
    [ "$(arc_status life)" = "in-progress" ]
}

# --- arc_start on in-progress refused ---

@test "T-1852: arc_start on in-progress arc is refused" {
    arc_sh "arc_create life --name 'lifecycle test' --anchor T-9999 --headline-mechanic 'user sees the lifecycle test firing on the page'"
    arc_sh "arc_start life"
    run arc_sh "arc_start life"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
    [[ "$output" == *"in-progress"* ]]
}

# --- arc_close on draft refused ---

@test "T-1852: arc_close on draft is refused" {
    arc_sh "arc_create life --name 'lifecycle test' --anchor T-9999 --headline-mechanic 'user sees the lifecycle test firing on the page'"
    run arc_sh "arc_close life --demo none --justification 'test rationale - draft cannot close' --i-am-human"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
    [[ "$output" == *"draft"* ]]
    [ "$(arc_status life)" = "draft" ]
}

# --- arc_close on in-progress works (back-compat) ---

@test "T-1852: arc_close on in-progress works (in-progress → closed)" {
    arc_sh "arc_create life --name 'lifecycle test' --anchor T-9999 --headline-mechanic 'user sees the lifecycle test firing on the page'"
    arc_sh "arc_start life"
    run arc_sh "arc_close life --demo none --justification 'test rationale - in-progress can close' --i-am-human"
    [ "$status" -eq 0 ]
    [ "$(arc_status life)" = "closed" ]
}

# --- arc_close on closed refused (no double-close) ---

@test "T-1852: arc_close on closed arc is refused" {
    arc_sh "arc_create life --name 'lifecycle test' --anchor T-9999 --headline-mechanic 'user sees the lifecycle test firing on the page'"
    arc_sh "arc_start life"
    arc_sh "arc_close life --demo none --justification 'test rationale - first close of the lifecycle smoke arc' --i-am-human"
    run arc_sh "arc_close life --demo none --justification 'test rationale - second close attempt of the same arc, should refuse' --i-am-human"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused"* ]]
    [[ "$output" == *"closed"* ]]
}

# --- D3: existing pre-T-1852 in-progress arcs untouched ---

# T-3913: the invariant T-1852 promised is "no migration" — every pre-existing
# arc still carries a VALID lifecycle state. The old form demanded `in-progress`
# forever, a mutable-corpus anchor (T-3326): the operator closing arc-grooming
# on 2026-10-05 turned it red and blocked a release push.
_arc_status_valid() {  # file -> 0 when status is an ARC_STATE (and a closed arc has closed_at)
    local f="$1" status_val
    status_val=$(awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' "$f" | tr -d ' "')
    case "$status_val" in
        draft|in-progress|abandoned) return 0 ;;
        closed) grep -Eq '^closed_at:[[:space:]]*[0-9]' "$f" ;;
        *) return 1 ;;
    esac
}

@test "T-1852: pre-existing in-tree arcs keep a valid lifecycle status (no migration)" {
    for arc in dispatch-safety embeddings-strategy orchestrator-rethink project-shape-resilience arc-grooming; do
        f="$FRAMEWORK_ROOT/.context/arcs/${arc}.yaml"
        [ -f "$f" ] || continue
        _arc_status_valid "$f"
    done
}

@test "T-3913/control: an arc with an invalid or migrated status fails the same check" {
    d="$(mktemp -d)"
    printf 'id: arc-x\nstatus: migrated\n' > "$d/bad.yaml"
    printf 'id: arc-y\nstatus: closed\nclosed_at: null\n' > "$d/closed-no-date.yaml"
    printf 'id: arc-z\nstatus: closed\nclosed_at: 2026-10-05T18:34:40Z\n' > "$d/ok.yaml"
    run _arc_status_valid "$d/bad.yaml"
    [ "$status" -ne 0 ]
    run _arc_status_valid "$d/closed-no-date.yaml"
    [ "$status" -ne 0 ]
    _arc_status_valid "$d/ok.yaml"
    rm -rf "$d"
}

# --- list registry sanity ---

@test "T-1852: ARC_STATES variable is defined and has 4 entries" {
    run arc_sh 'echo "${#ARC_STATES[@]}"'
    [ "$status" -eq 0 ]
    [ "$output" = "4" ]
}

@test "T-1852: ARC_STATES contains all four canonical states" {
    run arc_sh 'echo "${ARC_STATES[@]}"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"draft"* ]]
    [[ "$output" == *"in-progress"* ]]
    [[ "$output" == *"closed"* ]]
    [[ "$output" == *"abandoned"* ]]
}

# --- sanity ---

@test "T-1852: lib/arc.sh parses cleanly under bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/arc.sh"
    [ "$status" -eq 0 ]
}
