#!/usr/bin/env bats
# T-2904: outbound rail posts must not be signed by the shared host key.
#
# On a host whose termlink identity is shared across sessions, every co-resident
# agent signs identically — so a peer gating on producer identity cannot attribute
# a post to a project. Measured live: the same rail carried our posts under two
# different producers depending on which code path sent them.
#
# WHAT THESE LEGS DELIBERATELY DO NOT DO: post to a hub. The guard is ours; the
# signing is termlink's. Legs that posted would be testing termlink over the
# network and would write to a shared hub from CI.
#
# The load-bearing legs are (f) and (g). (a)-(e) all pass trivially if identity
# resolution is broken — (f) proves the host fingerprint actually resolves, and
# (g) pins the specific regression that shipped in this file's first cut: calling
# fw_config with 2>/dev/null made a MISSING DEPENDENCY resolve to "", which is
# byte-identical to "no project identity configured". The guard then reported the
# plausible answer for the wrong reason, which is the exact false-green class this
# task exists to close.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    command -v termlink >/dev/null 2>&1 || skip "termlink not installed"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- (f) non-vacuity: identity resolution works at all -----------------------

@test "rail-identity: the host fingerprint resolves (else every other leg is vacuous)" {
    cd "$FRAMEWORK_ROOT"
    run bin/fw rail identity
    [ "$status" -eq 0 ]
    # a 16-hex-char fingerprint, not "<unresolved>"
    echo "$output" | grep -qE 'fingerprint: [0-9a-f]{16}'
}

# --- (a)/(b) state classification --------------------------------------------

@test "rail-identity: unconfigured project reports state=host" {
    cd "$FRAMEWORK_ROOT"
    run env -u FW_RAIL_IDENTITY_FILE bin/fw rail identity
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "state:       host"
}

@test "rail-identity: a project-owned key reports state=project with a DIFFERENT fingerprint" {
    cd "$FRAMEWORK_ROOT"
    host_fp="$(env -u FW_RAIL_IDENTITY_FILE bin/fw rail identity | awk '/fingerprint:/{print $2}')"

    run env FW_RAIL_IDENTITY_FILE="$TEST_TEMP_DIR/proj.key" bin/fw rail identity
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "state:       project"

    proj_fp="$(echo "$output" | awk '/fingerprint:/{print $2}')"
    # The whole point: a project identity that equals the host key is not a
    # project identity. If these ever match, the guard is decorative.
    [ "$proj_fp" != "$host_fp" ]
}

# --- (c)/(d)/(e) the guard ----------------------------------------------------

@test "rail-identity: post is BLOCKED (exit 2) when it would be host-signed" {
    cd "$FRAMEWORK_ROOT"
    run bash -c 'echo body | env -u FW_RAIL_IDENTITY_FILE bin/fw rail post --hub 127.0.0.1:9 sink-topic'
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "BLOCKED"
    # The block message must name the way out, or the agent invents one (L-399).
    echo "$output" | grep -q "RAIL_IDENTITY_FILE"
    echo "$output" | grep -q "FW_ALLOW_HOST_SIGNED_RAIL"
}

@test "rail-identity: the guard itself passes when a project identity is configured" {
    cd "$FRAMEWORK_ROOT"
    # Guard only — an unroutable hub means we assert the guard let us THROUGH to
    # the network attempt, without this test depending on a live hub.
    run bash -c "source lib/rail-identity.sh; FW_RAIL_IDENTITY_FILE='$TEST_TEMP_DIR/proj.key' rail_identity_guard"
    [ "$status" -eq 0 ]
}

@test "rail-identity: FW_ALLOW_HOST_SIGNED_RAIL=1 bypasses, and says so on stderr" {
    cd "$FRAMEWORK_ROOT"
    run bash -c 'source lib/rail-identity.sh; env -u FW_RAIL_IDENTITY_FILE FW_ALLOW_HOST_SIGNED_RAIL=1 bash -c "source lib/rail-identity.sh; rail_identity_guard" 2>&1'
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "FW_ALLOW_HOST_SIGNED_RAIL"
}

# --- (g) the regression that shipped in the first cut -------------------------

@test "rail-identity: a MISSING fw_config warns rather than resolving silently to host" {
    cd "$FRAMEWORK_ROOT"
    # Simulate the dependency being absent by pointing the self-source at a tree
    # with no lib/config.sh, so fw_config cannot be defined.
    mkdir -p "$TEST_TEMP_DIR/fakeroot"
    cp lib/rail-identity.sh "$TEST_TEMP_DIR/fakeroot/rail-identity.sh"

    run bash -c "FRAMEWORK_ROOT='$TEST_TEMP_DIR/fakeroot' PROJECT_ROOT='$TEST_TEMP_DIR/fakeroot' \
        bash -c 'source $TEST_TEMP_DIR/fakeroot/rail-identity.sh; rail_identity_configured_path' 2>&1"
    # It may legitimately return empty — what it must NOT do is return empty in
    # silence, because that is indistinguishable from a real "unconfigured".
    echo "$output" | grep -q "fw_config unavailable"
}
