#!/usr/bin/env bats
# T-2519: fw fabric drift — orphaned-card check exempts gitignored runtime artifacts.
#
# Pre-fix behavior: the orphaned-card check (drift.sh section 2) flagged ANY card
# whose location: file was missing on disk — including cards that legitimately
# point at gitignored, lazily-created runtime data artifacts (e.g. F-004
# budget-gate-counter → .context/working/.budget-gate-counter). When such a file
# was transiently absent at scan time, the audit reported a spurious "orphaned"
# WARN (origin: handover S-2026-0710-0647).
#
# Post-fix behavior:
#   (a) location missing AND gitignored → silent (runtime/generated artifact)
#   (b) location missing AND tracked (not ignored) → ORPHANED (real drift)
#
# Sibling suite: tests/unit/fabric_drift_data_artifact.bats (T-2427/G-070 — the
# analogous exemption for the stale-EDGES check, section 3). This suite is the
# orphaned-CARD (section 2) counterpart.
#
# The discriminator is `git check-ignore`, so the temp project MUST be a git repo
# with a .gitignore — otherwise git errors (128) and nothing is exempt.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    export TMP_PROJECT
    mkdir -p "$TMP_PROJECT/.fabric/components"
    mkdir -p "$TMP_PROJECT/agents/scanner"
    mkdir -p "$TMP_PROJECT/.context/working"
    mkdir -p "$TMP_PROJECT/.tasks"                    # anchor: paths.sh:101
    touch "$TMP_PROJECT/.framework.yaml"              # anchor: paths.sh:101
    touch "$TMP_PROJECT/agents/scanner/scanner.sh"   # present → not orphaned

    # git repo + .gitignore so `git check-ignore` resolves (the discriminator).
    # The .framework.yaml/.tasks anchors above are REQUIRED: without them,
    # `git init` makes fw's paths.sh fall through to git-worktree resolution
    # and PROJECT_ROOT escapes the temp dir (T-2519 test-authoring finding).
    git -C "$TMP_PROJECT" init -q
    cat > "$TMP_PROJECT/.gitignore" <<'EOF'
.context/working/.runtime-counter
EOF

    export PROJECT_ROOT="$TMP_PROJECT"
    export FW_DEV=1
    cat > "$TMP_PROJECT/.fabric/watch-patterns.yaml" <<EOF
patterns:
  - glob: "agents/*/*.sh"
    expected_type: script
EOF
}

teardown() {
    [ -d "${TMP_PROJECT:-}" ] && rm -rf "$TMP_PROJECT"
}

_card() {
    local path="$1"
    local content="$2"
    printf '%s\n' "$content" > "$TMP_PROJECT/.fabric/components/$path"
}

@test "T-2519-A: card → missing gitignored runtime file is silent (not orphaned)" {
    # .context/working/.runtime-counter is gitignored and does NOT exist on disk
    _card "budget-counter.yaml" "id: F-004
name: budget-gate-counter
type: data
location: .context/working/.runtime-counter
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"orphaned: 0"* ]]
    [[ "$output" != *"budget-gate-counter"* ]]
}

@test "T-2519-B: card → missing tracked source file IS orphaned (real drift)" {
    # agents/scanner/deleted.sh is NOT gitignored and does NOT exist → real drift
    _card "deleted-scanner.yaml" "id: agents/scanner/deleted.sh
name: deleted-scanner
type: script
location: agents/scanner/deleted.sh
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"orphaned: 1"* ]]
    [[ "$output" == *"deleted-scanner"* ]]
}

@test "T-2519-C: mixed — gitignored missing skipped, tracked missing flagged (count=1)" {
    _card "budget-counter.yaml" "id: F-004
name: budget-gate-counter
type: data
location: .context/working/.runtime-counter
depended_by: []"
    _card "deleted-scanner.yaml" "id: agents/scanner/deleted.sh
name: deleted-scanner
type: script
location: agents/scanner/deleted.sh
depended_by: []"
    cd "$TMP_PROJECT"
    run "$FRAMEWORK_ROOT/bin/fw" fabric drift
    [ "$status" -eq 0 ]
    [[ "$output" == *"orphaned: 1"* ]]
    [[ "$output" == *"deleted-scanner"* ]]
    [[ "$output" != *"budget-gate-counter"* ]]
}
