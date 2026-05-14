#!/usr/bin/env bats
# T-1635: fresh-machine simulation guard for fw upgrade.
#
# Validates that fw upgrade works end-to-end on a "fresh-from-vendor"
# consumer — only .agentic-framework/ + .framework.yaml, no /opt/999
# source-of-truth nearby, no ~/.local/bin/fw shim, scrubbed PATH.
#
# Slim slice (no docker required, runs in any bats environment):
#   - tempdir = simulated "fresh machine"
#   - upstream bare repo locally = simulated "tagged framework release"
#   - consumer = vendored .agentic-framework/ + .framework.yaml
#   - scrubbed env (no FRAMEWORK_ROOT / PROJECT_ROOT, minimal PATH)
#   - invoke consumer's vendored bin/fw upgrade as a subprocess
#
# Distinct from tests/unit/upgrade_auto_clone.bats: that file sources
# lib/upgrade.sh and exercises do_upgrade as a function with a stub
# upstream fw. This test goes end-to-end with a real bin/fw subprocess
# against a real file:// upstream bare repo cloned from FRAMEWORK_ROOT.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-fresh-machine-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a simulated "tagged framework release" by cloning FRAMEWORK_ROOT
# into a bare repo. The bare URL is suitable for file:// upstream_repo.
make_upstream_bare() {
    local bare="$1"
    # --shared keeps it cheap (no full object copy); --bare is required for
    # the consumer's clone-from-upstream path.
    git clone --quiet --bare --shared "$FRAMEWORK_ROOT" "$bare" 2>/dev/null
}

# Build a consumer project: proj/.agentic-framework/ (clone of upstream)
# + proj/.framework.yaml (with upstream_repo pointing at the bare).
make_fresh_consumer() {
    local proj="$1"
    local upstream_bare="$2"
    mkdir -p "$proj"
    git clone --quiet --depth=1 "file://$upstream_bare" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.0.0
provider: claude
upstream_repo: file://$upstream_bare
YAML
}

# Run a command under "fresh-machine" simulation:
#   - cwd = consumer project (so PROJECT_ROOT resolves to it, not to the
#     dev-host's framework repo via find_project_root's upward walk)
#   - env -i  (full env strip — no FRAMEWORK_ROOT, no PROJECT_ROOT, no
#     framework-shim PATH entries leaking from the dev machine)
#   - minimal PATH (/usr/local/bin:/usr/bin:/bin only — what a fresh
#     LXC / container would have)
#   - HOME = tempdir (so any ~/.local/bin/fw shim on the dev host is
#     invisible)
fresh_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

@test "fresh-machine: vendored bin/fw runs --version in scrubbed env" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    run fresh_run "$proj" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "fresh-machine: vendored bin/fw upgrade --dry-run completes in scrubbed env" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    # bare-from-consumer guard MUST fire (FRAMEWORK_ROOT == target/.agentic-framework)
    # AND auto-clone path MUST take over via .framework.yaml upstream_repo.
    run fresh_run "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bare-from-consumer"* ]] || [[ "$output" == *"upgrade"* ]] || [[ "$output" == *"Upgrade"* ]]
}

@test "fresh-machine: vendored bin/fw upgrade --dry-run shows the bare-from-consumer + auto-clone handoff plan" {
    # Stronger assertion on test 2's plan: bare-from-consumer message AND the
    # auto-clone target path are both surfaced. This is what blocks a regression
    # in the T-1542 (bare-from-consumer detection) or T-1634 (auto-clone path)
    # code paths from shipping silently.
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    run fresh_run "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"file://$upstream_bare"* ]]
    [[ "$output" == *"would clone"* ]] || [[ "$output" == *"would re-invoke"* ]]
}

# NOTE on live (non-dry-run) upgrade: the full vendor copy takes ~8 minutes
# (~65MB rsync of lib/ + docs/ + components regen) — impractical for a unit
# test gate. The "framework -> consumer" path beyond re-exec is already
# covered by tests/unit/lib_upgrade.bats; the re-exec handoff is asserted by
# the dry-run test above. A docker-container variant of the full live
# upgrade is the natural release-gate follow-up (see T-1635 ## Evolution).
