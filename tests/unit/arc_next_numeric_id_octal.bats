#!/usr/bin/env bats
# T-1877 (T-NEW-13): _arc_next_numeric_id must allocate IDs across the 008/009
# boundary without bash octal-parse errors.
#
# Bug: `max="009"` (string) being fed into `$((max + 1))` errors with "value too
# great for base" because bash arithmetic expansion interprets `008`/`009` as
# invalid octal. POSIX `[ -gt ]` is leading-zero tolerant; `$(( ))` is not. The
# fix normalizes via `10#` prefix.

setup() {
    export PROJECT_ROOT="$(mktemp -d)"
    export ARCS_DIR="$PROJECT_ROOT/.context/arcs"
    mkdir -p "$ARCS_DIR"

    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    # shellcheck disable=SC1090
    source "${FRAMEWORK_ROOT}/lib/arc.sh"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

_seed_arc() {
    # Usage: _seed_arc <NNN>
    local nnn="$1"
    cat > "${ARCS_DIR}/arc-${nnn}-test.yaml" <<YAML
id: arc-${nnn}
slug: arc-${nnn}-test
name: "test"
status: draft
YAML
}

@test "next id from empty dir is arc-001" {
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-001" ]
}

@test "next id after arcs 001..005 is arc-006" {
    for n in 001 002 003 004 005; do _seed_arc "$n"; done
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-006" ]
}

@test "next id after arc-007 is arc-008 (no octal trouble yet)" {
    for n in 001 002 003 004 005 006 007; do _seed_arc "$n"; done
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-008" ]
}

@test "next id after arc-008 is arc-009 (octal boundary 1)" {
    for n in 001 002 003 004 005 006 007 008; do _seed_arc "$n"; done
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-009" ]
    # Critical: stderr must NOT contain the bash octal-error signature.
    [[ "$output" != *"value too great for base"* ]]
}

@test "next id after arc-009 is arc-010 (octal boundary 2)" {
    for n in 001 002 003 004 005 006 007 008 009; do _seed_arc "$n"; done
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-010" ]
    [[ "$output" != *"value too great for base"* ]]
}

@test "next id after arc-099 is arc-100 (3-digit boundary)" {
    for n in 098 099; do _seed_arc "$n"; done
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-100" ]
}

@test "ids with gaps return max+1, never reusing missing slots (D-Immutability)" {
    # Skip 003 and 005 — D-Immutability says NEVER reuse.
    for n in 001 002 004 006 007; do _seed_arc "$n"; done
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-008" ]
}

@test "non-arc-NNN yamls are ignored" {
    cat > "${ARCS_DIR}/some-other-thing.yaml" <<'YAML'
id: arc-grooming
slug: arc-grooming
YAML
    _seed_arc "001"
    run _arc_next_numeric_id
    [ "$status" -eq 0 ]
    [ "$output" = "arc-002" ]
}
