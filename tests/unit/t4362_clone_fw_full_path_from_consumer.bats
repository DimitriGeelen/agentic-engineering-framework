#!/usr/bin/env bats
# T-4362 (GitHub #105): a clone's bin/fw, called by full path from inside a vendored
# consumer, must run ITSELF for `upgrade` — not the consumer's .agentic-framework copy.
#
# Field report (v1.8.11): `cd $PROJECT && $CLONE/bin/fw upgrade $PROJECT --dry-run`
# printed "Bare-from-consumer detected — auto-cloning upstream": resolve_framework's
# T-498 rule picked $PROJECT/.agentic-framework, so lib/upgrade.sh saw source == target.
# T-4453 fixed the clean-env case. This file pins #105's exact table, plus the case a
# consumer's own agent session produces: FRAMEWORK_ROOT (and PROJECT_ROOT) already
# exported as the consumer's vendored copy, which T-4453's `-z FRAMEWORK_ROOT` guard
# skipped.
#
# Hermetic: private TMPDIR, file:// upstream, env -i, cwd = consumer.

load ../test_helper
load ../fresh_machine_helper

_make_clone() {
    local co="$1"
    git clone --quiet --shared "$FRAMEWORK_ROOT" "$co" 2>/dev/null
    cp "${T4362_BIN_FW:-$FRAMEWORK_ROOT/bin/fw}" "$co/bin/fw"
    cp "$FRAMEWORK_ROOT/lib/upgrade.sh" "$co/lib/upgrade.sh"
}

# _run_from_consumer <clone> <proj> <fw args...>
# Extra environment (the inherited-session case) comes from T4362_ENV, word-split.
_run_from_consumer() {
    local co="$1" proj="$2"; shift 2
    # shellcheck disable=SC2086
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        TMPDIR="$TEST_TEMP_DIR" \
        ${T4362_ENV:-} \
        "$co/bin/fw" "$@" </dev/null)
}

_setup_pair() {
    upstream_bare="$TEST_TEMP_DIR/upstream.git"
    proj="$TEST_TEMP_DIR/proj"
    co="$TEST_TEMP_DIR/clone"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"
    _make_clone "$co"
    co_canon=$(cd "$co" && pwd -P)
}

@test "T-4362 #105 row 1: clone's bin/fw by full path from the consumer previews the clone" {
    _setup_pair
    run _run_from_consumer "$co" "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"Bare-from-consumer"* ]]
    [[ "$output" == *"Framework: $co_canon"* ]]
}

@test "T-4362 #105: inherited FRAMEWORK_ROOT/PROJECT_ROOT = the consumer's vendored copy does not re-route" {
    _setup_pair
    T4362_ENV="FRAMEWORK_ROOT=$proj/.agentic-framework PROJECT_ROOT=$proj"
    run _run_from_consumer "$co" "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"Bare-from-consumer"* ]]
    [[ "$output" == *"Framework: $co_canon"* ]]
}

@test "T-4362 #105 row 3 control: explicit FRAMEWORK_ROOT=<clone> still previews the clone" {
    _setup_pair
    T4362_ENV="FRAMEWORK_ROOT=$co PROJECT_ROOT=$proj"
    run _run_from_consumer "$co" "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" != *"Bare-from-consumer"* ]]
    [[ "$output" == *"Framework: $co"* ]]
}

@test "T-4362 control: the consumer's own vendored bin/fw still takes the bare-from-consumer path" {
    _setup_pair
    cp "$FRAMEWORK_ROOT/bin/fw" "$proj/.agentic-framework/bin/fw"
    run fresh_run "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bare-from-consumer"* ]]
}
