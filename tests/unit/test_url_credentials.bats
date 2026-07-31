#!/usr/bin/env bats
# T-2693 — lib/url-credentials.sh, the single dialect for URL credential handling.
#
# Origin: OBS-106. `bin/fw` wrote the vendored `.upstream` sentinel from
# `git remote get-url origin` verbatim, so a credentialed origin put a live
# token into a tracked file — and echoed it to stdout for good measure. The
# strip already existed in lib/consumer-recover.sh and had never been applied
# on the write path (L-399 producer/consumer split).
#
# The tokens below are synthesized fixtures, not real credentials.

load ../test_helper

HELPER="$FRAMEWORK_ROOT/lib/url-credentials.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    # shellcheck source=/dev/null
    source "$HELPER"
}

teardown() {
    cd /
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_mkrepo() {
    local d="$TEST_TEMP_DIR/$1"
    mkdir -p "$d"
    git -C "$d" init -q
    echo "$d"
}

# --- fw_strip_url_credentials ---

@test "T-2693: bare token userinfo is stripped" {
    run fw_strip_url_credentials "https://Aa0Bb1Cc2Dd3Ee4Ff5Gg6@git.example.com/r.git"
    [ "$output" = "https://git.example.com/r.git" ]
}

@test "T-2693: user:password userinfo is stripped" {
    run fw_strip_url_credentials "https://deploybot:hunter2secret@git.example.com/r.git"
    [ "$output" = "https://git.example.com/r.git" ]
}

@test "T-2693: a credential-free URL round-trips unchanged" {
    run fw_strip_url_credentials "https://github.com/DimitriGeelen/agentic-engineering-framework.git"
    [ "$output" = "https://github.com/DimitriGeelen/agentic-engineering-framework.git" ]
}

@test "T-2693: SSH-style URLs are left alone (git@ is a username, not a credential)" {
    # Stripping here would corrupt the URL — the scp-style form has no scheme
    # and its `git@` is load-bearing.
    run fw_strip_url_credentials "git@github.com:o/r.git"
    [ "$output" = "git@github.com:o/r.git" ]
    run fw_strip_url_credentials "ssh://git@host/r.git"
    [ "$output" = "ssh://git@host/r.git" ]
}

# --- fw_preferred_upstream_url ---

@test "T-2693: public mirror is preferred over a credentialed origin" {
    # The preference is the primary defence; the strip is defence in depth.
    # Preferring `github` also keeps the sentinel USABLE by a consumer with no
    # access to the private forge.
    local d; d="$(_mkrepo pref)"
    git -C "$d" remote add origin "https://Aa0Bb1Cc2Dd3Ee4Ff5Gg6@onedev.example.com/r.git"
    git -C "$d" remote add github "https://github.com/o/r.git"
    run fw_preferred_upstream_url "$d"
    [ "$output" = "https://github.com/o/r.git" ]
}

@test "T-2693: falls back to origin when no public mirror exists, and still strips" {
    local d; d="$(_mkrepo fallback)"
    git -C "$d" remote add origin "https://Aa0Bb1Cc2Dd3Ee4Ff5Gg6@onedev.example.com/r.git"
    run fw_preferred_upstream_url "$d"
    [ "$output" = "https://onedev.example.com/r.git" ]
}

@test "T-2693: a repo with no remotes yields nothing (vendored-without-sentinel is legal)" {
    local d; d="$(_mkrepo bare)"
    run fw_preferred_upstream_url "$d"
    [ "$output" = "" ]
}

@test "T-2693: a non-git directory yields nothing rather than erroring" {
    mkdir -p "$TEST_TEMP_DIR/plain"
    run fw_preferred_upstream_url "$TEST_TEMP_DIR/plain"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# --- write path + shared-dialect guards ---

@test "T-2693: the vendor write path resolves via the helper, not raw origin" {
    # Structural guard. It does NOT prove the sentinel is credential-free —
    # the behavioural proof is the strip/preference tests above plus the live
    # scan-tree in T-2692. What it does catch is the specific regression that
    # caused OBS-106: someone reaching for `remote get-url origin` again in
    # the block that writes a TRACKED file.
    #
    # Comments are stripped before matching. The first cut of this test grepped
    # the whole file and went red against a COMMENT that names the banned call
    # while explaining why it is banned — a text match cannot tell code from
    # prose about that code (L-519). A guard that prose can break is a guard
    # that gets weakened to make it pass.
    run grep -q 'fw_preferred_upstream_url "\$vendor_source"' "$FRAMEWORK_ROOT/bin/fw"
    [ "$status" -eq 0 ]
    run bash -c "grep -vE '^[[:space:]]*#' '$FRAMEWORK_ROOT/bin/fw' | grep -c 'remote get-url origin'"
    [ "$output" = "0" ]
}

@test "T-2693: consumer-recover delegates instead of keeping a second sed dialect" {
    # One transformation, one implementation — so a future fix lands everywhere.
    run grep -q 'fw_strip_url_credentials' "$FRAMEWORK_ROOT/lib/consumer-recover.sh"
    [ "$status" -eq 0 ]
    run grep -c "sed -E 's|\^(https\?://)" "$FRAMEWORK_ROOT/lib/consumer-recover.sh"
    [ "$output" = "0" ]
}

@test "T-2693: the live sentinel carries no credential" {
    local sentinel="$FRAMEWORK_ROOT/.agentic-framework/.upstream"
    [ -f "$sentinel" ]
    run grep -cE '://[^/[:space:]@]+@' "$sentinel"
    [ "$output" = "0" ]
    # …and still names a repository, so the scrub did not just empty it.
    run grep -qE '^https?://[^[:space:]]+\.git$' "$sentinel"
    [ "$status" -eq 0 ]
}
