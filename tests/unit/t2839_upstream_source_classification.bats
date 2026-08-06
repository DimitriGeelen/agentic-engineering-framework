#!/usr/bin/env bats
# T-2839 — `upstream_repo` must not be assumed to be GitHub shorthand.
#
# lib/upgrade.sh recognised a fixed set of URL prefixes and treated EVERYTHING
# else as GitHub owner/repo, expanding it to https://github.com/<value>.git. A
# consumer carrying `upstream_repo: /opt/agentic-engineering-framework` therefore
# produced `https://github.com//opt/agentic-engineering-framework.git`, and the
# operator got "Repository not found" from GitHub — pointing at the wrong system,
# because the fault was in local config.
#
# Origin: a live by-hand onboarding run. `fw doctor` FAILed and prescribed
# `fw upgrade`; `fw upgrade` then died on this. The one command that would have
# fixed the install was the one that broke.
#
# Two properties are pinned: local paths are clone sources (never rewritten), and
# an unclassifiable value is REFUSED rather than guessed. The second is the one
# that cost time — a wrong-but-plausible URL sends the reader to GitHub.

setup() {
    # shellcheck source=lib/upgrade.sh
    source "$BATS_TEST_DIRNAME/../../lib/upgrade.sh" 2>/dev/null || true
}

@test "absolute local path is a clone source, not GitHub shorthand" {
    run _fw_classify_upstream_source "/opt/agentic-engineering-framework"
    [ "$status" -eq 0 ]
    [ "$output" = "/opt/agentic-engineering-framework" ]
    # The exact regression: never github.com with a doubled slash.
    [[ "$output" != *"github.com//"* ]]
}

@test "relative local paths are clone sources" {
    run _fw_classify_upstream_source "./upstream"
    [ "$status" -eq 0 ]
    [ "$output" = "./upstream" ]

    run _fw_classify_upstream_source "../upstream"
    [ "$status" -eq 0 ]
    [ "$output" = "../upstream" ]
}

@test "tilde paths are clone sources" {
    # Regression on the fix itself: bash performs tilde expansion on `case`
    # PATTERNS, so an unquoted ~/* becomes /root/* and never matches a literal
    # "~/…". The first draft of this fix had that bug and refused ~/x.
    run _fw_classify_upstream_source "~/framework"
    [ "$status" -eq 0 ]
    [ "$output" = "~/framework" ]
}

@test "GitHub owner/repo shorthand still expands (T-1634 behaviour preserved)" {
    run _fw_classify_upstream_source "DimitriGeelen/agentic-engineering-framework"
    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/DimitriGeelen/agentic-engineering-framework.git" ]
}

@test "recognised URL schemes pass through untouched" {
    for u in \
        "https://example.com/x.git" \
        "http://example.com/x.git" \
        "ssh://git@example.com/x.git" \
        "git://example.com/x.git" \
        "file:///tmp/x" \
        "git@example.com:owner/repo.git"
    do
        run _fw_classify_upstream_source "$u"
        [ "$status" -eq 0 ]
        [ "$output" = "$u" ]
    done
}

@test "unclassifiable values are refused, not guessed" {
    # Each of these previously became https://github.com/<value>.git.
    #
    # Note what is NOT in this list: anything starting with "/". A leading slash
    # makes it a path, and classifying it as one is correct even when the path is
    # nonsense — git will fail on it with a clear local error. This test asserted
    # "/../etc/passwd:x" was refused on first draft; the code was right and the
    # expectation was wrong.
    for bad in "not a repo" "owner/repo/extra" "owner/" "owner repo" ""
    do
        run _fw_classify_upstream_source "$bad"
        [ "$status" -ne 0 ]
        [ -z "$output" ]
    done
}

@test "classifier never emits a doubled-slash github URL for any path input" {
    # Property form of the origin defect: whatever a path-shaped value resolves
    # to, it must not be a manufactured github.com URL.
    for p in "/opt/x" "/opt/a/b/c" "./x" "../x" "~/x"
    do
        run _fw_classify_upstream_source "$p"
        [ "$status" -eq 0 ]
        [[ "$output" != *"github.com"* ]]
    done
}
