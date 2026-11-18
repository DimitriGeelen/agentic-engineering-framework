#!/usr/bin/env bats
# T-5214 (1409 a8eb045c): with FRAMEWORK_ROOT exported to framework tree B, running
# tree A's bin/fw executed B's code. bin/fw now honours a foreign inherited
# FRAMEWORK_ROOT only when FW_FRAMEWORK_ROOT_HANDOFF=1 marks it as an intentional
# handoff (lib/upgrade.sh T-2099 clone handoff, bin/fw worktree re-exec), clears the
# marker, and otherwise runs its own tree and warns once per calling shell.

REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# A framework tree at $1: real bin/ copied (bin/fw resolves itself via readlink -f),
# everything else symlinked to the real repo (same harness as t4369).
_fw_tree() {
    local d="$1" e
    mkdir -p "$d"
    cp -r "$REAL/bin" "$d/bin"
    for e in lib agents policy FRAMEWORK.md status-transitions.yaml VERSION; do
        [ -e "$REAL/$e" ] && ln -s "$REAL/$e" "$d/$e"
    done
}

setup() {
    TMP="$(mktemp -d)"
    A="$TMP/treeA"; B="$TMP/treeB"
    _fw_tree "$A"; _fw_tree "$B"
    A="$(cd "$A" && pwd -P)"; B="$(cd "$B" && pwd -P)"
    mkdir -p "$TMP/work" "$TMP/tmpdir"
    unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY CLAUDE_PROJECT_DIR \
        FW_FRAMEWORK_ROOT_HANDOFF FW_REEXEC_DEPTH FW_NO_REEXEC
    export TMPDIR="$TMP/tmpdir"
}

teardown() { rm -rf "$TMP"; }

@test "T-5214: without the marker, A's bin/fw runs A, not the inherited B" {
    run bash -c "cd '$TMP/work' && FRAMEWORK_ROOT='$B' '$A/bin/fw' version 2>&1"
    [ "$status" -eq 0 ]
    grep -qx "Framework: $A" <<<"$output"
    grep -q "inherited FRAMEWORK_ROOT=$B is another framework tree" <<<"$output"
}

@test "T-5214: the warning is shown once per calling shell" {
    run bash -c "cd '$TMP/work' && export FRAMEWORK_ROOT='$B'; '$A/bin/fw' version 2>&1; '$A/bin/fw' version 2>&1"
    [ "$status" -eq 0 ]
    [ "$(grep -c "is another framework tree" <<<"$output")" -eq 1 ]
    [ "$(grep -cx "Framework: $A" <<<"$output")" -eq 2 ]
}

@test "T-5214: never warns from fw hook" {
    run bash -c "cd '$TMP/work' && FRAMEWORK_ROOT='$B' '$A/bin/fw' hook no-such-hook </dev/null 2>&1"
    [[ "$output" != *"is another framework tree"* ]]
    [ -z "$(ls -A "$TMP/tmpdir" | grep fw-foreign-root-warned)" ]
}

@test "T-5214: with FW_FRAMEWORK_ROOT_HANDOFF=1 the inherited B is honoured, silently" {
    run bash -c "cd '$TMP/work' && FRAMEWORK_ROOT='$B' FW_FRAMEWORK_ROOT_HANDOFF=1 '$A/bin/fw' version 2>&1"
    [ "$status" -eq 0 ]
    grep -qx "Framework: $B" <<<"$output"
    [[ "$output" != *"is another framework tree"* ]]
}

@test "T-5214: the marker is cleared, so it does not leak to fw's children" {
    # A fake git on PATH records the marker every child of fw sees (fw version runs git).
    mkdir -p "$TMP/fakebin"
    REALGIT="$(command -v git)"
    printf '#!/bin/bash\necho "marker=[${FW_FRAMEWORK_ROOT_HANDOFF:-}]" >> %q\nexec %q "$@"\n' \
        "$TMP/child.env" "$REALGIT" > "$TMP/fakebin/git"
    chmod +x "$TMP/fakebin/git"
    run bash -c "cd '$TMP/work' && PATH='$TMP/fakebin:$PATH' FRAMEWORK_ROOT='$B' FW_FRAMEWORK_ROOT_HANDOFF=1 '$A/bin/fw' version 2>&1"
    [ "$status" -eq 0 ]
    grep -qx "Framework: $B" <<<"$output"
    [ -s "$TMP/child.env" ] || { echo "fw ran no git child"; false; }
    [ -z "$(grep -v '^marker=\[\]$' "$TMP/child.env")" ]
}

@test "T-5214: same-tree FRAMEWORK_ROOT is untouched and silent" {
    run bash -c "cd '$TMP/work' && FRAMEWORK_ROOT='$A' '$A/bin/fw' version 2>&1"
    [ "$status" -eq 0 ]
    grep -qx "Framework: $A" <<<"$output"
    [[ "$output" != *"is another framework tree"* ]]
}

@test "T-5214: both intentional handoffs set the marker" {
    grep -q 'env FRAMEWORK_ROOT="$_tmpd/fw" FW_FRAMEWORK_ROOT_HANDOFF=1' "$REAL/lib/upgrade.sh"
    # the worktree re-exec exports it in the same step as FRAMEWORK_ROOT
    awk '/^_fw_reexec_authority\(\)/,/^}/' "$REAL/bin/fw" > "$TMP/reexec.sh"
    grep -q 'export FW_FRAMEWORK_ROOT_HANDOFF=1' "$TMP/reexec.sh"
    grep -q 'export FRAMEWORK_ROOT="$_auth_fw"' "$TMP/reexec.sh"
}
