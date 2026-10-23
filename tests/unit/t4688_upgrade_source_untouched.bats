#!/usr/bin/env bats
# T-4688: `<clone>/bin/fw upgrade <consumer>` must not write into the clone.
#
# Field instance (TermLink be.6, sidecar 150d6e99): after an upgrade run FROM a
# framework clone, the clone had .agentic-framework/tools/corpus_lenses.yaml
# modified and gen-framework-hook-lines.sh added. do_upgrade ran the _self_vendor_*
# helpers against FRAMEWORK_ROOT (the clone) whatever the target was, so a
# rehearse-then-real-run from one clone upgraded from a mutated source.
#
# Hermetic: private TMPDIR, file:// upstream, env -i, cwd = consumer. The clone
# carries the working-tree bin/fw + lib/upgrade.sh under test (override with
# T4688_UPGRADE_SH to rehearse the unfixed file) and a committed tools/ file the
# clone's .agentic-framework/tools/ does not have — the drift self-vendor syncs.

load ../test_helper
load ../fresh_machine_helper

_make_drifted_clone() {
    local co="$1"
    git clone --quiet --shared "$FRAMEWORK_ROOT" "$co" 2>/dev/null
    cp "$FRAMEWORK_ROOT/bin/fw" "$co/bin/fw"
    cp "${T4688_UPGRADE_SH:-$FRAMEWORK_ROOT/lib/upgrade.sh}" "$co/lib/upgrade.sh"
    echo '# t4688 drift marker' > "$co/tools/t4688-drift-marker.sh"
    git -C "$co" add -A
    git -C "$co" -c user.email=t@t -c user.name=t commit -qm "t4688 drift"
}

_run_clone_upgrade() {
    local co="$1" proj="$2"; shift 2
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        TMPDIR="$TEST_TEMP_DIR" \
        "$co/bin/fw" upgrade "$proj" "$@")
}

@test "T-4688: dry run then real run from a clone leave the clone byte-identical" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    local co="$TEST_TEMP_DIR/src-clone"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"
    git init -q "$proj"
    _make_drifted_clone "$co"
    [ -z "$(git -C "$co" status --porcelain)" ]

    run _run_clone_upgrade "$co" "$proj" --dry-run
    [ "$status" -eq 0 ]
    [ -z "$(git -C "$co" status --porcelain)" ]
    [[ "$output" != *"would sync"*"to .agentic-framework/tools/"* ]] || false

    run _run_clone_upgrade "$co" "$proj"
    [ "$status" -eq 0 ]
    [ -z "$(git -C "$co" status --porcelain)" ]
    [ ! -e "$co/.agentic-framework/tools/t4688-drift-marker.sh" ]
    [[ "$output" == *"Self-vendor skipped"* ]]
    # The consumer still receives the source's tools/ (vendor step is unaffected).
    [ -f "$proj/.agentic-framework/tools/t4688-drift-marker.sh" ]
}

@test "T-4688 control: the drift is real — the clone's own fw vendor self syncs it" {
    # Self-vendoring lives in `fw vendor self` (do_upgrade refuses target ==
    # FRAMEWORK_ROOT). Proves test 1's fixture carries drift a self-vendor WOULD
    # write, so its clean status is the fix and not an empty fixture.
    local co="$TEST_TEMP_DIR/src-clone"
    _make_drifted_clone "$co"

    run env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        TMPDIR="$TEST_TEMP_DIR" FW_VENDOR_ONLY="tools/t4688-drift-marker.sh" \
        bash -c "cd '$co' && bin/fw vendor self"
    [ -f "$co/.agentic-framework/tools/t4688-drift-marker.sh" ]
    [ -n "$(git -C "$co" status --porcelain)" ]
}

@test "T-4688: a dry run leaves the consumer byte-identical too" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    local co="$TEST_TEMP_DIR/src-clone"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"
    _make_drifted_clone "$co"
    local before
    before=$(cd "$proj" && find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)

    run _run_clone_upgrade "$co" "$proj" --dry-run
    [ "$status" -eq 0 ]
    [ "$(cd "$proj" && find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)" = "$before" ]
}
