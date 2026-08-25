#!/usr/bin/env bats
# T-3052 — a pickup id is a filename (lib/pickup.sh:566 builds
# `${pickup_id}-${type}.yaml`), so reissuing one aims two envelopes at one path.
#
# Two gaps had to line up and each is harmless alone:
#   A  pickup_next_id skipped auto-deferred/, so ids parked there were reissued
#   B  every landing was a clobbering `mv ... 2>/dev/null || true`
# A decided WHERE B fired. B is what made the loss silent — no error, no count
# change, `fw pickup status` identical before and after.
#
# So the suite tests them separately, and mutates them separately: a test that
# only passes when BOTH fixes are present cannot tell you which one is load-bearing.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
PICKUP_LIB="$FRAMEWORK_ROOT/lib/pickup.sh"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.tasks/active" "$TMP_PROJECT/.tasks/completed"
    mkdir -p "$TMP_PROJECT/.context/pickup"/{inbox,processed,rejected,auto-deferred}
    export PROJECT_ROOT="$TMP_PROJECT"
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    D="$TMP_PROJECT/.context/pickup"
    # shellcheck source=lib/pickup.sh
    source "$PICKUP_LIB"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

# --- fixtures ---------------------------------------------------------------

# envelope <dir> <filename> <marker> [source_task]
# The marker is the payload's only distinguishing content — it is how a test
# proves WHICH of two same-named files survived.
envelope() {
    local dir="$1" fname="$2" marker="$3" stask="${4:-T-900}"
    cat > "$D/$dir/$fname" <<EOF
version: "1"
type: learning
supersedes:
source:
  project: "elsewhere"
  task_id: "$stask"
payload:
  summary: "$marker"
  detail: "$marker"
pickup_id: "$(printf '%s' "$fname" | sed -n 's/^\(P-[0-9]*\).*/\1/p')"
EOF
}

# Source a copy of lib/pickup.sh with one construct removed, in a subshell.
# Mutants are sourced, not exec'd, so a mutation that breaks the file is SILENT
# (L-616) — hence the positive controls below, which assert a mutant still does
# the thing the mutation did not touch.
mutant_source() {  # mutant_source <sed-expr>
    local m="$TMP_PROJECT/pickup-mutant.sh"
    sed "$1" "$PICKUP_LIB" > "$m"
    ! cmp -s "$m" "$PICKUP_LIB"     # the substitution must have landed
    # shellcheck disable=SC1090
    source "$m"
}

MUT_A='s#"\$PICKUP_REJECTED" "\$PICKUP_AUTO_DEFERRED"; do#"$PICKUP_REJECTED"; do#'
MUT_B='s#^    if \[ -e "\$dest" \]; then#    if false; then#'

# =============================================================================
# A1 — the allocator sees all four directories
# =============================================================================

@test "A1 — an id parked in auto-deferred/ is not reissued" {
    envelope auto-deferred "P-007-learning.yaml" "original"
    run pickup_next_id
    [ "$status" -eq 0 ]
    [ "$output" = "P-008" ]
}

@test "A1 — mutation: dropping auto-deferred/ from the loop reissues the id" {
    envelope auto-deferred "P-007-learning.yaml" "original"
    run bash -c "PROJECT_ROOT='$TMP_PROJECT'; source '$PICKUP_LIB'
                 sed '$MUT_A' '$PICKUP_LIB' > '$TMP_PROJECT/m.sh'
                 source '$TMP_PROJECT/m.sh'; pickup_next_id"
    [ "$output" = "P-001" ]
}

@test "A1 — positive control: the mutant still counts the dirs it kept" {
    # Required by L-616. A mutant that failed to load would also emit nothing
    # useful above, which is indistinguishable from a detected mutation. This
    # proves the mutant is alive and only blind where intended.
    envelope processed "P-042-learning.yaml" "kept"
    run bash -c "PROJECT_ROOT='$TMP_PROJECT'; source '$PICKUP_LIB'
                 sed '$MUT_A' '$PICKUP_LIB' > '$TMP_PROJECT/m.sh'
                 source '$TMP_PROJECT/m.sh'; pickup_next_id"
    [ "$output" = "P-043" ]
}

@test "A1 — the high-water mark is the max across all four, wherever it sits" {
    envelope inbox     "P-002-learning.yaml" a
    envelope processed "P-005-learning.yaml" b
    envelope rejected  "P-009-learning.yaml" c
    envelope auto-deferred "P-031-learning.yaml" d
    run pickup_next_id
    [ "$output" = "P-032" ]
}

# =============================================================================
# A2 — no pickup file is ever overwritten by a move
# =============================================================================

@test "A2 — a colliding arrival keeps both files" {
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL"
    envelope inbox         "P-007-learning.yaml" "ARRIVING"

    run pickup_move_preserving "$D/inbox/P-007-learning.yaml" "$D/auto-deferred"
    [ "$status" -eq 0 ]

    grep -q ORIGINAL "$D/auto-deferred/P-007-learning.yaml"
    [ -e "$D/auto-deferred/P-007-learning.dup-1.yaml" ]
    grep -q ARRIVING "$D/auto-deferred/P-007-learning.dup-1.yaml"
    [ ! -e "$D/inbox/P-007-learning.yaml" ]
}

@test "A2 — mutation: without the collision branch the original is destroyed" {
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL"
    envelope inbox         "P-007-learning.yaml" "ARRIVING"

    run bash -c "PROJECT_ROOT='$TMP_PROJECT'; source '$PICKUP_LIB'
                 sed '$MUT_B' '$PICKUP_LIB' > '$TMP_PROJECT/m.sh'
                 source '$TMP_PROJECT/m.sh'
                 pickup_move_preserving '$D/inbox/P-007-learning.yaml' '$D/auto-deferred'"
    [ "$status" -eq 0 ]
    # This is the bug, reproduced: one file in, one file out, ORIGINAL gone.
    grep -q ARRIVING "$D/auto-deferred/P-007-learning.yaml"
    [ ! -e "$D/auto-deferred/P-007-learning.dup-1.yaml" ]
}

@test "A2 — positive control: the mutant still moves when there is no collision" {
    envelope inbox "P-007-learning.yaml" "ARRIVING"
    run bash -c "PROJECT_ROOT='$TMP_PROJECT'; source '$PICKUP_LIB'
                 sed '$MUT_B' '$PICKUP_LIB' > '$TMP_PROJECT/m.sh'
                 source '$TMP_PROJECT/m.sh'
                 pickup_move_preserving '$D/inbox/P-007-learning.yaml' '$D/processed'"
    [ "$status" -eq 0 ]
    [ -e "$D/processed/P-007-learning.yaml" ]
}

@test "A2 — the echoed path is the one actually written" {
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL"
    envelope inbox         "P-007-learning.yaml" "ARRIVING"
    # stdout only — the WARN goes to stderr precisely so the echoed path stays
    # machine-readable for the callers that capture it (A4).
    run bash -c "PROJECT_ROOT='$TMP_PROJECT' NO_COLOR=1
                 source '$PICKUP_LIB'
                 pickup_move_preserving '$D/inbox/P-007-learning.yaml' '$D/auto-deferred' 2>/dev/null"
    [ "$status" -eq 0 ]
    [ -e "$output" ]
    grep -q ARRIVING "$output"
}

@test "A2 — the collision is announced on stderr, naming both files" {
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL"
    envelope inbox         "P-007-learning.yaml" "ARRIVING"
    run bash -c "PROJECT_ROOT='$TMP_PROJECT' NO_COLOR=1
                 source '$PICKUP_LIB'
                 pickup_move_preserving '$D/inbox/P-007-learning.yaml' '$D/auto-deferred' \
                   >/dev/null 2>'$TMP_PROJECT/err'
                 cat '$TMP_PROJECT/err'"
    [[ "$output" == *"P-007-learning.yaml"* ]]
    [[ "$output" == *"P-007-learning.dup-1.yaml"* ]]
    [[ "$output" == *collision* ]]
}

@test "A2 — a third arrival gets dup-2, not a second dup-1" {
    envelope auto-deferred "P-007-learning.yaml"       "FIRST"
    envelope auto-deferred "P-007-learning.dup-1.yaml" "SECOND"
    envelope inbox         "P-007-learning.yaml"       "THIRD"
    run pickup_move_preserving "$D/inbox/P-007-learning.yaml" "$D/auto-deferred"
    grep -q SECOND "$D/auto-deferred/P-007-learning.dup-1.yaml"
    grep -q THIRD  "$D/auto-deferred/P-007-learning.dup-2.yaml"
}

@test "A2 — .yml keeps its extension; the suffix goes before it" {
    # A naive ${base%.yaml} strips nothing from a .yml name and produces
    # `P-007-learning.yml.dup-1`, which the *.yaml/*.yml globs then skip — the
    # file would survive on disk and be invisible to every scan. Worse than
    # clobbering, because it looks like nothing happened.
    envelope auto-deferred "P-007-learning.yml" "ORIGINAL"
    envelope inbox         "P-007-learning.yml" "ARRIVING"
    run pickup_move_preserving "$D/inbox/P-007-learning.yml" "$D/auto-deferred"
    [ -e "$D/auto-deferred/P-007-learning.dup-1.yml" ]
    grep -q ORIGINAL "$D/auto-deferred/P-007-learning.yml"
}

# =============================================================================
# A3/A4 — the real callers, end to end
# =============================================================================

@test "A3 — the G-046 auto-defer path preserves a colliding deferred envelope" {
    # Drives pickup_process_one, not the helper: A2 proves the helper is safe,
    # this proves the caller actually uses it.
    cat > "$TMP_PROJECT/.tasks/completed/T-901-done.md" <<'EOF'
---
id: T-901
name: "already done here"
---
EOF
    # G-046 fires only when the envelope's source project IS this project.
    local self; self=$(basename "$TMP_PROJECT")
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL" "T-901"
    envelope inbox         "P-007-learning.yaml" "ARRIVING" "T-901"
    sed -i "s/project: \"elsewhere\"/project: \"$self\"/" \
        "$D/inbox/P-007-learning.yaml"

    run pickup_process_one "$D/inbox/P-007-learning.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *AUTO-DEFER* ]]
    grep -q ORIGINAL "$D/auto-deferred/P-007-learning.yaml"
    grep -q ARRIVING "$D/auto-deferred/P-007-learning.dup-1.yaml"
}

@test "A4 — the triple-dedup breadcrumb names the file that actually landed" {
    # The breadcrumb used to be written for "$PICKUP_AUTO_DEFERRED/$basename_f",
    # which on a collision is the file ALREADY there — attributing this
    # envelope's blocker to a different pickup, and leaving the arriving one
    # with no breadcrumb at all, so promote-deferred reports it as an ORPHAN.
    cat > "$TMP_PROJECT/.tasks/active/T-902-blocker.md" <<'EOF'
---
id: T-902
source_task_id_in_origin: T-903
source_project_in_origin: "elsewhere"
tags: [pickup, learning]
---
EOF
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL" "T-903"
    envelope inbox         "P-007-learning.yaml" "ARRIVING" "T-903"

    run pickup_process_one "$D/inbox/P-007-learning.yaml"
    [[ "$output" == *AUTO-DEFER* ]]

    # Breadcrumb sits beside the RENAMED arrival and names its envelope.
    local crumb="$D/auto-deferred/P-007-learning.dup-1.yaml.breadcrumb.yaml"
    [ -e "$crumb" ]
    grep -q "envelope: P-007-learning.dup-1.yaml" "$crumb"
    grep -q "blocking_task: T-902" "$crumb"
}

@test "A4 — mutation: the assumed basename breadcrumbs the wrong envelope" {
    cat > "$TMP_PROJECT/.tasks/active/T-902-blocker.md" <<'EOF'
---
id: T-902
source_task_id_in_origin: T-903
source_project_in_origin: "elsewhere"
tags: [pickup, learning]
---
EOF
    envelope auto-deferred "P-007-learning.yaml" "ORIGINAL" "T-903"
    envelope inbox         "P-007-learning.yaml" "ARRIVING" "T-903"

    run bash -c "PROJECT_ROOT='$TMP_PROJECT' NO_COLOR=1
                 sed 's#pickup_write_breadcrumb \"\$deferred_path\"#pickup_write_breadcrumb \"\$PICKUP_AUTO_DEFERRED/\$basename_f\"#' \
                     '$PICKUP_LIB' > '$TMP_PROJECT/m4.sh'
                 if cmp -s '$TMP_PROJECT/m4.sh' '$PICKUP_LIB'; then false; fi
                 source '$TMP_PROJECT/m4.sh'
                 pickup_process_one '$D/inbox/P-007-learning.yaml' >/dev/null 2>&1"

    # The arrival landed as dup-1 (the helper is unmutated) but its breadcrumb
    # went to the file that was already there. promote-deferred would now read
    # T-902 as the blocker of the WRONG envelope, and call the real one an ORPHAN.
    [ ! -e "$D/auto-deferred/P-007-learning.dup-1.yaml.breadcrumb.yaml" ]
    [ -e "$D/auto-deferred/P-007-learning.yaml.breadcrumb.yaml" ]
}
