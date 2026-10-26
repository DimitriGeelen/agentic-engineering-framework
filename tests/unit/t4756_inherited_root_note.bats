#!/usr/bin/env bats
# T-4756: when bin/fw discards an inherited PROJECT_ROOT because it is not a project
# (markerless dir) and resolves another root, it says so in ONE stderr line. stdout is
# unchanged. No note when PROJECT_ROOT is unset, already the resolved root, a kept real
# project (env wins, T-2391 t3), the $HOME daemon poison (T-2391), or under `fw hook`.
# Counterpart of T-4753 (lib/sidecar_cli.py refuses a valid OTHER project).
#
# Observed via `fw version` ("Project: <root>" on stdout), as in t2391.

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    REAL="$(mktemp -d -t fw-t4756-real-XXXXXX)"
    mkdir -p "$REAL/.tasks"
    printf 'version: test\n' > "$REAL/.framework.yaml"
    REAL2="$(mktemp -d -t fw-t4756-real2-XXXXXX)"
    mkdir -p "$REAL2/.tasks"
    printf 'version: test2\n' > "$REAL2/.framework.yaml"
    SCRATCH="$(mktemp -d -t fw-t4756-scratch-XXXXXX)"
    OUT="$(mktemp -d -t fw-t4756-out-XXXXXX)"
}

teardown() {
    rm -rf "$REAL" "$REAL2" "$SCRATCH" "$OUT"
}

# Run fw version from $REAL with the given PROJECT_ROOT (empty = unset); split streams.
_fw_version() {
    cd "$REAL"
    if [ -n "$1" ]; then
        env -u CLAUDE_PROJECT_DIR -u _FW_PATHS_DERIVED_BY HOME="${2:-/nonexistent-home-xyz}" \
            PROJECT_ROOT="$1" bash "$FW" version >"$OUT/stdout" 2>"$OUT/stderr"
    else
        env -u CLAUDE_PROJECT_DIR -u _FW_PATHS_DERIVED_BY -u PROJECT_ROOT HOME="/nonexistent-home-xyz" \
            bash "$FW" version >"$OUT/stdout" 2>"$OUT/stderr"
    fi
}

@test "non-project inherited PROJECT_ROOT: one stderr note, stdout unchanged" {
    _fw_version "$SCRATCH"
    grep -q "Project:.*$REAL" "$OUT/stdout"
    [ "$(grep -c 'inherited PROJECT_ROOT=' "$OUT/stderr")" -eq 1 ]
    grep -qF "fw: inherited PROJECT_ROOT=$SCRATCH ignored (not a project); using " "$OUT/stderr"
    ! grep -q "inherited PROJECT_ROOT" "$OUT/stdout" || false
    # stdout is byte-identical to the run with PROJECT_ROOT unset
    cp "$OUT/stdout" "$OUT/with"
    _fw_version ""
    diff "$OUT/with" "$OUT/stdout"
}

@test "unset PROJECT_ROOT: no note" {
    _fw_version ""
    grep -q "Project:.*$REAL" "$OUT/stdout"
    ! grep -q "inherited PROJECT_ROOT" "$OUT/stderr" || false
}

@test "PROJECT_ROOT already the resolved root: no note" {
    _fw_version "$REAL"
    grep -q "Project:.*$REAL" "$OUT/stdout"
    ! grep -q "inherited PROJECT_ROOT" "$OUT/stderr" || false
}

@test "real other project is kept (env wins): no note" {
    _fw_version "$REAL2"
    grep -q "Project:.*$REAL2" "$OUT/stdout"
    ! grep -q "inherited PROJECT_ROOT" "$OUT/stderr" || false
}

@test "\$HOME daemon poison (T-2391) stays silent" {
    _fw_version "$SCRATCH" "$SCRATCH"
    grep -q "Project:.*$REAL" "$OUT/stdout"
    ! grep -q "inherited PROJECT_ROOT" "$OUT/stderr" || false
}

@test "fw hook stays silent" {
    cd "$REAL"
    env -u _FW_PATHS_DERIVED_BY HOME="/nonexistent-home-xyz" CLAUDE_PROJECT_DIR="$REAL" \
        PROJECT_ROOT="$SCRATCH" bash "$FW" hook no-such-hook-t4756 \
        </dev/null >"$OUT/stdout" 2>"$OUT/stderr" || true
    ! grep -q "inherited PROJECT_ROOT" "$OUT/stderr" || false
}
