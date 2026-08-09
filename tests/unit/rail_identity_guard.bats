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

# --- T-2905: the project label is emitted, not typed --------------------------
#
# 832 measured one fingerprint carrying six from_project values across 474
# envelopes — three of them this project spelled three ways — and 400 envelopes
# carrying no label at all. Absence is the larger half of that defect, so a leg
# that only checks normalisation would pass while the real problem shipped.

@test "rail-label: normalised to one spelling, whatever the source says" {
    cd "$FRAMEWORK_ROOT"
    run bash -c 'source lib/rail-identity.sh; FW_RAIL_PROJECT_LABEL="999 AEF_Test" rail_project_label'
    [ "$status" -eq 0 ]
    [ "$output" = "999-aef-test" ]
}

@test "rail-label: derived from the project dir when nothing is configured" {
    cd "$FRAMEWORK_ROOT"
    # NB: `env VAR=x fn` cannot work — env execs a binary and rail_project_label
    # is a shell function (this leg first failed 127 for exactly that reason).
    run bash -c 'source lib/rail-identity.sh; unset FW_RAIL_PROJECT_LABEL; PROJECT_ROOT=/tmp/999-Agentic-Engineering-Framework rail_project_label'
    [ "$status" -eq 0 ]
    # The point of the fix: the caller never types this, so it cannot vary.
    [ "$output" = "999-agentic-engineering-framework" ]
}

@test "rail-label: the label is ATTACHED to the post, not merely computable" {
    # The gap between "a function returns the right string" and "the envelope
    # carries it" is where the 400 unlabelled envelopes live. Assert on the
    # argv the post path would use, without needing a hub.
    cd "$FRAMEWORK_ROOT"
    run bash -c '
        source lib/rail-identity.sh
        termlink() { printf "%s\n" "$*"; }        # capture argv
        export -f termlink 2>/dev/null || true
        FW_RAIL_IDENTITY_FILE="'"$TEST_TEMP_DIR"'/k.key" do_rail post some-topic 2>/dev/null
    '
    echo "$output" | grep -q -- "--metadata from_project="
}

@test "rail-label: an explicit caller label WINS (floor, not seizure)" {
    cd "$FRAMEWORK_ROOT"
    run bash -c '
        source lib/rail-identity.sh
        termlink() { printf "%s\n" "$*"; }
        FW_RAIL_IDENTITY_FILE="'"$TEST_TEMP_DIR"'/k.key" do_rail post some-topic --metadata from_project=caller-choice 2>/dev/null
    '
    # exactly one from_project, and it is the caller's
    [ "$(echo "$output" | grep -o 'from_project=' | wc -l)" -eq 1 ]
    echo "$output" | grep -q "from_project=caller-choice"
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
