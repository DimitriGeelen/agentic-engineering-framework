#!/usr/bin/env bats
# T-2843: `fw doctor` framework-path-ambiguity predicate.
#
# The bug this pins: the check compared `upstream_repo` (a pull source) against
# FRAMEWORK_ROOT (the running copy) as a plain inequality. In vendored mode those
# differ by construction, so the WARN fired on every consumer unconditionally.
#
# Test 3 is the negative control and matters most: it asserts the check still
# fires where T-1097 intended it to. Without it, "make the WARN stop" is
# satisfiable by deleting the check, and the suite would agree.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    source "$FW_ROOT/lib/doctor-upstream.sh"
}

@test "vendored mode with a URL upstream is not ambiguous" {
    run doctor_upstream_ambiguous \
        "https://onedev.example.com/agentic-engineering-framework" \
        "/proj/.agentic-framework" "vendored"
    [ "$status" -eq 1 ]
}

@test "vendored mode with a local-path upstream is not ambiguous" {
    # The operator's /opt/001-test-install shape: upstream_repo is a real
    # directory, the running fw is the project's own vendored copy. Different
    # paths, and correctly so.
    run doctor_upstream_ambiguous \
        "/opt/agentic-engineering-framework" \
        "/opt/001-test-install/.agentic-framework" "vendored"
    [ "$status" -eq 1 ]
}

@test "NEGATIVE CONTROL: global mode with a divergent local upstream still warns" {
    run doctor_upstream_ambiguous \
        "/opt/agentic-engineering-framework" \
        "/root/.agentic-framework" "global"
    [ "$status" -eq 0 ]
}

@test "global mode running the very framework it is pinned to is not ambiguous" {
    run doctor_upstream_ambiguous \
        "/opt/agentic-engineering-framework" \
        "/opt/agentic-engineering-framework" "global"
    [ "$status" -eq 1 ]
}

@test "global mode with a URL upstream is not ambiguous (nothing path-like to compare)" {
    run doctor_upstream_ambiguous \
        "https://github.com/DimitriGeelen/agentic-engineering-framework.git" \
        "/root/.agentic-framework" "global"
    [ "$status" -eq 1 ]
}

@test "scp-style git remote is treated as a URL, not a path" {
    run doctor_upstream_ambiguous \
        "git@github.com:DimitriGeelen/agentic-engineering-framework.git" \
        "/root/.agentic-framework" "global"
    [ "$status" -eq 1 ]
}

@test "empty upstream_repo is never ambiguous" {
    run doctor_upstream_ambiguous "" "/root/.agentic-framework" "global"
    [ "$status" -eq 1 ]
}

@test "trailing-slash and dot-segment differences do not count as ambiguity" {
    run doctor_upstream_ambiguous \
        "/opt/agentic-engineering-framework/" \
        "/opt/./agentic-engineering-framework" "global"
    [ "$status" -eq 1 ]
}

@test "no realpath is applied to a URL (regression: \$PWD prefix rewrite)" {
    # Before T-2843, `realpath -m https://host/x` produced "$PWD/https:/host/x".
    # Running from two different directories would then yield two different
    # "resolved" upstreams for the same config. Assert the verdict is
    # cwd-invariant, which it can only be if realpath never touched the URL.
    # `run` is required, not stylistic: bats runs each test under `set -e`, and
    # the answer we are asserting IS a non-zero return, so a bare call aborts the
    # test at the point it succeeds.
    local a b
    cd /tmp; run doctor_upstream_ambiguous "https://host/x" "/root/.agentic-framework" "global"; a=$status
    cd /;    run doctor_upstream_ambiguous "https://host/x" "/root/.agentic-framework" "global"; b=$status
    [ "$a" -eq "$b" ]
    [ "$a" -eq 1 ]
}
