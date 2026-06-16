#!/usr/bin/env bats
# T-2427 / G-070: fw fabric drift — distinguish data-artifact deps from real drift.
#
# Pre-fix behavior: any depends_on target without a fabric card emitted a
# "stale edge" — even when the target was a real on-disk artifact (handover
# symlink, .tasks/active/ dir, write-target log). 20 noise lines drowned real
# drift in the audit/drift reports.
#
# Post-fix behavior:
#   (a) target exists on disk (file/dir/symlink) → silent (data-artifact dep)
#   (b) target is a `type: writes*` edge → silent (script creates lazily)
#   (c) target missing on disk AND type ∉ writes* → STALE (real drift)
#   (d) target is a bare name resolving in $PATH (system binary) → silent
#
# Sibling suites:
#   tests/unit/fabric_register_slug.bats — register slug derivation
#   tests/unit/fabric_globstar.bats — glob pattern handling

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    export TMP_PROJECT
    mkdir -p "$TMP_PROJECT/.fabric/components"
    mkdir -p "$TMP_PROJECT/agents/scanner"
    mkdir -p "$TMP_PROJECT/.context/working"
    mkdir -p "$TMP_PROJECT/.tasks/active"
    touch "$TMP_PROJECT/agents/scanner/scanner.sh"
    touch "$TMP_PROJECT/.context/working/scanner.log"   # exists on disk
    # .tasks/active/ exists as a dir
    # NO .context/working/.absent.log → real drift after fix

    export PROJECT_ROOT="$TMP_PROJECT"
    export FW_DEV=1
    # Minimal watch-patterns.yaml so drift can read it
    cat > "$TMP_PROJECT/.fabric/watch-patterns.yaml" <<EOF
patterns:
  - glob: "agents/*/*.sh"
    expected_type: script
EOF
}

teardown() {
    [ -d "${TMP_PROJECT:-}" ] && rm -rf "$TMP_PROJECT"
}

# Helper: write a fabric card under the test project
_card() {
    local path="$1"
    local content="$2"
    printf '%s\n' "$content" > "$TMP_PROJECT/.fabric/components/$path"
}

@test "T-2427-A: depends_on existing dir (no card) is silent (data-artifact)" {
    _card "agents-scanner-scanner.yaml" "id: agents/scanner/scanner.sh
name: scanner
type: script
location: agents/scanner/scanner.sh
depends_on:
  - target: .tasks/active/
    type: reads
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale: 0"* ]]
    [[ "$output" != *".tasks/active/ (unresolved)"* ]]
}

@test "T-2427-B: depends_on existing file (no card) is silent" {
    _card "agents-scanner-scanner.yaml" "id: agents/scanner/scanner.sh
name: scanner
type: script
location: agents/scanner/scanner.sh
depends_on:
  - target: .context/working/scanner.log
    type: reads
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale: 0"* ]]
}

@test "T-2427-C: depends_on missing file with type=reads is STALE (real drift)" {
    _card "agents-scanner-scanner.yaml" "id: agents/scanner/scanner.sh
name: scanner
type: script
location: agents/scanner/scanner.sh
depends_on:
  - target: .context/working/.absent.log
    type: reads
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale: 1"* ]]
    [[ "$output" == *".absent.log (unresolved)"* ]]
}

@test "T-2427-D: depends_on missing file with type=writes is silent (lazy-create)" {
    _card "agents-scanner-scanner.yaml" "id: agents/scanner/scanner.sh
name: scanner
type: script
location: agents/scanner/scanner.sh
depends_on:
  - target: .context/working/.absent-write.log
    type: writes
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale: 0"* ]]
}

@test "T-2427-E: depends_on bare name in \$PATH (system binary) is silent" {
    _card "agents-scanner-scanner.yaml" "id: agents/scanner/scanner.sh
name: scanner
type: script
location: agents/scanner/scanner.sh
depends_on:
  - target: ls
    type: calls
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale: 0"* ]]
}

@test "T-2427-F: depends_on bare name NOT in PATH AND missing on disk is STALE" {
    _card "agents-scanner-scanner.yaml" "id: agents/scanner/scanner.sh
name: scanner
type: script
location: agents/scanner/scanner.sh
depends_on:
  - target: nonexistent-binary-xyz-12345
    type: calls
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale: 1"* ]]
}
