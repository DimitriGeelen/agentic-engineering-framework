#!/usr/bin/env bats
# T-4453: `<framework checkout>/bin/fw upgrade <consumer>` must vendor THAT checkout.
#
# Field instance (dimitri-mint-dev T-158): a v1.8.14-be.1 clone's bin/fw, run from
# inside the consumer, resolved FRAMEWORK_ROOT to the consumer's vendored copy
# (bin/fw resolve_framework, T-498 rule), so lib/upgrade.sh took the bare-from-consumer
# branch, cloned upstream_repo (master) and vendored that. The -be fix never landed.
#
# Hermetic: private TMPDIR, file:// upstream, env -i, cwd = consumer. The checkout is
# a clone of FRAMEWORK_ROOT carrying the working-tree bin/fw + lib/upgrade.sh under
# test (override with T4453_BIN_FW / T4453_UPGRADE_SH to rehearse the unfixed files),
# plus a marker commit tagged v9.9.9-be.1 that upstream does not have.

load ../test_helper
load ../fresh_machine_helper

_make_be_checkout() {
    local co="$1"
    git clone --quiet --shared "$FRAMEWORK_ROOT" "$co" 2>/dev/null
    cp "${T4453_BIN_FW:-$FRAMEWORK_ROOT/bin/fw}" "$co/bin/fw"
    cp "${T4453_UPGRADE_SH:-$FRAMEWORK_ROOT/lib/upgrade.sh}" "$co/lib/upgrade.sh"
    echo '# t4453-be-marker' >> "$co/lib/compat.sh"
    git -C "$co" -c user.email=t@t -c user.name=t commit -qam "t4453 be marker"
    git -C "$co" tag v9.9.9-be.1
}

_run_checkout_upgrade() {
    local co="$1" proj="$2"; shift 2
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        TMPDIR="$TEST_TEMP_DIR" \
        "$co/bin/fw" upgrade "$proj" "$@")
}

@test "T-4453: -be checkout's bin/fw upgrade vendors the checkout, not upstream_repo" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    local co="$TEST_TEMP_DIR/be-checkout"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"
    git init -q "$proj"
    _make_be_checkout "$co"
    local sha
    sha=$(git -C "$co" rev-parse --short=12 HEAD)

    run _run_checkout_upgrade "$co" "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Bare-from-consumer"* ]]
    [[ "$output" == *"Framework: $(cd "$co" && pwd -P)"* ]]
    [[ "$output" == *"Commit:    $sha (v9.9.9-be.1)"* ]]
    grep -q 't4453-be-marker' "$proj/.agentic-framework/lib/compat.sh"
}

@test "T-4453: --dry-run from the checkout plans the checkout as source and names its tag" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    local co="$TEST_TEMP_DIR/be-checkout"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"
    _make_be_checkout "$co"

    run _run_checkout_upgrade "$co" "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"would clone"* ]]
    [[ "$output" == *"(v9.9.9-be.1)"* ]]
}

@test "T-4453 control: the consumer's own vendored bin/fw still auto-clones upstream" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"
    cp "$FRAMEWORK_ROOT/bin/fw" "$proj/.agentic-framework/bin/fw"

    run fresh_run "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bare-from-consumer"* ]]
    [[ "$output" == *"would clone file://$upstream_bare"* ]]
}
