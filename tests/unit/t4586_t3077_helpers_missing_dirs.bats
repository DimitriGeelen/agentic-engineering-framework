#!/usr/bin/env bats
# T-4586 — the surface helpers in test_t3077_approvals_surface_isolation.bats
# must survive a fresh clone. .context/approvals is untracked, so it is absent
# there; an unguarded `find` on it exits 1 and bats' errexit aborted A1 before it
# measured anything. An absent directory is an empty surface, not an error.

FRAMEWORK_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
T3077="$FRAMEWORK_ROOT_REAL/tests/governance/test_t3077_approvals_surface_isolation.bats"

setup() {
    # Load only the two helper functions, against a root with neither directory.
    eval "$(sed -n '/^_surface_manifest()/,/^}/p; /^_live_surface_paths()/,/^}/p' "$T3077")"
    declare -F _surface_manifest >/dev/null
    declare -F _live_surface_paths >/dev/null
    FRAMEWORK_ROOT="$BATS_TEST_TMPDIR/fresh-clone"
    mkdir -p "$FRAMEWORK_ROOT"
}

@test "T-4586: _live_surface_paths returns 0 and prints nothing when both dirs are absent" {
    run bash -c "set -e; FRAMEWORK_ROOT='$FRAMEWORK_ROOT'; $(declare -f _live_surface_paths); _live_surface_paths; echo survived"
    [ "$status" -eq 0 ]
    [ "$output" = "survived" ]
}

@test "T-4586: _live_surface_paths returns 0 when only .context/working exists" {
    mkdir -p "$FRAMEWORK_ROOT/.context/working"
    run bash -c "set -e; FRAMEWORK_ROOT='$FRAMEWORK_ROOT'; $(declare -f _live_surface_paths); _live_surface_paths; echo survived"
    [ "$status" -eq 0 ]
    [ "$output" = "survived" ]
}

@test "T-4586: _surface_manifest returns 0 under errexit and pipefail when both dirs are absent" {
    run bash -c "set -eo pipefail; FRAMEWORK_ROOT='$FRAMEWORK_ROOT'; $(declare -f _surface_manifest); _surface_manifest; echo survived"
    [ "$status" -eq 0 ]
    [ "$output" = "survived" ]
}

@test "T-4586: helpers still report a pending card when one exists" {
    mkdir -p "$FRAMEWORK_ROOT/.context/approvals"
    : > "$FRAMEWORK_ROOT/.context/approvals/pending-abc.yaml"
    run bash -c "set -e; FRAMEWORK_ROOT='$FRAMEWORK_ROOT'; $(declare -f _live_surface_paths); _live_surface_paths"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending-abc.yaml"* ]]
}
