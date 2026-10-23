#!/usr/bin/env bats
# T-4498: a refused fw upgrade must be side-effect free (T-4278 rule) — the
# inline self-vendor sync included.
#
# Origin: dimitri-mint-dev (msg ae5a4e7f). An upgrade from a SHALLOW clone of a
# be tag was refused as foreign-source (the consumer's version_sha is not visible
# in truncated history), but `Self-vendor: synced 3 file(s) to
# .agentic-framework/lib/` had already run. do_upgrade called the _self_vendor_*
# helpers before the T-1912 version precheck and the T-4278 vendor precheck, and
# those helpers write into the SOURCE's own .agentic-framework/ — a tree the
# T-4278 test never hashed.
#
# Contract: a refusal leaves the consumer AND the source byte-identical; an
# accepted upgrade still self-vendors (T-1217).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4498-XXXXXX)"
    export NO_COLOR=1
    export REAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    REAL_FW="$FRAMEWORK_ROOT"
    source "$REAL_FW/lib/colors.sh"
    source "$REAL_FW/lib/upgrade.sh"

    # Upstream: commit A (the consumer's recorded version_sha), then commit B
    # whose committed vendored lib lags its lib/ — the drift self-vendor syncs.
    local g=(git -c user.name=t4498 -c user.email=t4498@example.invalid)
    UP="$TEST_TEMP_DIR/up"
    mkdir -p "$UP/lib/templates" "$UP/.agentic-framework/lib"
    git init -q "$UP"
    echo "v1" > "$UP/lib/a.sh"
    cp "$REAL_FW/lib/templates/claude-project.md" "$UP/lib/templates/claude-project.md"
    "${g[@]}" -C "$UP" add -A
    "${g[@]}" -C "$UP" commit -q -m A
    A_SHA="$(git -C "$UP" rev-parse HEAD)"
    echo "v2" > "$UP/lib/a.sh"
    echo "v1" > "$UP/.agentic-framework/lib/a.sh"
    "${g[@]}" -C "$UP" add -A
    "${g[@]}" -C "$UP" commit -q -m B

    SRC="$TEST_TEMP_DIR/src"
    git clone -q --depth 1 "file://$UP" "$SRC"
    export FRAMEWORK_ROOT="$SRC"
    export FW_VERSION="1.0.1"

    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ"
    printf 'project_name: proj\nversion: 1.0.0\nversion_sha: %s\n' "$A_SHA" > "$PROJ/.framework.yaml"
}

teardown() {
    export HOME="$REAL_HOME"
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Every file and directory under $1 (except .git), with content hashes.
_tree_hash() {
    ( cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
        if [ -f "$p" ]; then printf '%s %s\n' "$(sha256sum < "$p" | cut -d' ' -f1)" "$p"
        else printf 'dir %s\n' "$p"; fi
      done ) | sha256sum | cut -d' ' -f1
}

@test "T-4498: fixture — source is shallow, its vendored lib is stale, relation refuses" {
    run fw_source_is_shallow "$SRC"; [ "$status" -eq 0 ]
    ! cmp -s "$SRC/lib/a.sh" "$SRC/.agentic-framework/lib/a.sh" || false
    fw_version_relation 1.0.0 1.0.1 "$A_SHA" "$SRC" >/dev/null
    [ "$FW_VERSION_RELATION" = "foreign-source" ]
}

@test "T-4498: shallow-source foreign-source refusal leaves consumer and source byte-identical" {
    local proj_before src_before
    proj_before=$(_tree_hash "$PROJ")
    src_before=$(_tree_hash "$SRC")
    # T-4235: upgrade now unshallows a fetchable source itself; drop the remote
    # so the shallow source stays unverifiable and the refusal path is exercised.
    git -C "$SRC" remote remove origin

    run do_upgrade "$PROJ"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"foreign-source"* ]]
    [[ "$output" != *"Self-vendor"*"synced"* ]]

    [ "$(_tree_hash "$PROJ")" = "$proj_before" ]
    [ "$(_tree_hash "$SRC")" = "$src_before" ]
    [ "$(cat "$SRC/.agentic-framework/lib/a.sh")" = "v1" ]
}

@test "T-4498/T-4688: an upgrade past the refusal checks does not self-vendor either" {
    # Unshallow: the same pair resolves to `behind`, so no precheck refuses.
    git -C "$SRC" fetch -q --unshallow
    # Stop the run at step 1 (T-3150 unmatched project-owned marker), after the
    # pre-write checks and the self-vendor block, before any consumer rewrite.
    printf '# CLAUDE.md\n<!-- project-owned: begin -->\n\n## Core Principle\n' > "$PROJ/CLAUDE.md"

    run do_upgrade "$PROJ"
    [[ "$output" != *"REFUSED  Consumer"* ]]
    # T-4688: the source is never written by an upgrade it serves; it was T-1217's
    # inline self-vendor until then. `fw vendor self` owns that sync.
    [[ "$output" == *"Self-vendor skipped"* ]]
    [[ "$output" != *"Self-vendor:"*"synced"* ]] || false
    [ "$(cat "$SRC/.agentic-framework/lib/a.sh")" = "v1" ]
}
