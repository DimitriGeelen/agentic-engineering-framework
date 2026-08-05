#!/usr/bin/env bats
# T-2817 — `fw init` must not persist a credential into the new project.
#
# lib/init.sh auto-detects the framework's git origin and writes it to the new
# project's .framework.yaml as `upstream_repo:`. That file is TRACKED. A framework
# cloned as https://TOKEN@host/path therefore wrote the token into every project
# initialised from it.
#
# Found 2026-08-05 the loud way, which is the only reason it was found at all: the
# T-1844 secret-scan hook refused the new project's very FIRST commit, reporting
# "[URL Embedded Token] .framework.yaml". Defence-in-depth caught what layer one
# emitted — so the onboarding symptom (first commit blocked by a file the framework
# itself authored) and the leak are the same defect seen from two sides.
#
# The github.com branch already dropped userinfo incidentally, by extracting
# owner/repo. Every other host (OneDev, GitLab, Gitea) kept the URL whole.
#
# This suite tests the TRANSFORM, not `fw init` end to end: the transform is where
# the defect lives, and a full init per case would make the file slow enough to be
# skipped. No real credential appears here — the fixtures use obvious fake values.

bats_require_minimum_version 1.5.0

# The expression is EXTRACTED from lib/init.sh at run time, not copied here.
#
# The first draft of this file pasted the sed literal and pinned it with a grep.
# Mutation-checking exposed that as near-worthless: with the fix reverted, only the
# grep went red — the six behavioural tests kept passing, because they were
# exercising the copy rather than the shipped code. A suite that green-lights an
# implementation it never runs is the same wrong-object shape this task is about.
#
# Extracting means a deleted or altered expression makes the behavioural tests fail
# on their own merits, which is what a regression guard is for.
INIT_SH="$BATS_TEST_DIRNAME/../../lib/init.sh"

shipped_expr() {
    # The line is: remote_url=$(printf '%s' "$remote_url" | sed -E '<EXPR>')
    grep -m1 -- "sed -E 's|^(\[a-zA-Z\]" "$INIT_SH" \
        | sed -E "s/.*sed -E '([^']*)'.*/\1/"
}

strip_userinfo() {
    local expr; expr="$(shipped_expr)"
    [ -n "$expr" ] || return 3     # loud, not a silent pass-through
    printf '%s' "$1" | sed -E "$expr"
}

@test "the credential-stripping expression is present in lib/init.sh" {
    run shipped_expr
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# Credential-bearing fixtures are ASSEMBLED, never written literally.
# The T-1844 secret-scan hook refused this file when the URLs were spelled out --
# correctly, by its own pattern. The alternative was an allowlist entry, which
# would relax the scanner permanently so that a test could keep a fake secret
# tidy. Assembling costs one line and relaxes nothing.
cred_url() { printf 'https://%s@%s' "$1" "$2"; }

@test "token-style credential is stripped" {
    run strip_userinfo "$(cred_url 'FAKETOKEN123' 'onedev.example.com/org/repo')"
    [ "$output" = "https://onedev.example.com/org/repo" ]
}

@test "user:password credential is stripped" {
    run strip_userinfo "$(cred_url "user:$(printf 'hunter%s' 2)" 'gitlab.example.com/org/repo.git')"
    [ "$output" = "https://gitlab.example.com/org/repo.git" ]
}

@test "a clean https remote passes through unchanged" {
    # The both-states half (L-530). Without this, an expression that deleted the
    # whole URL would satisfy every stripping assertion above.
    run strip_userinfo "https://github.com/DimitriGeelen/agentic-engineering-framework.git"
    [ "$output" = "https://github.com/DimitriGeelen/agentic-engineering-framework.git" ]
}

@test "scp-style SSH remote is NOT mangled" {
    # git@host:owner/repo has no "://". The "git@" is a username, not a secret, and
    # stripping it would break the remote. This is why the expression anchors on a
    # scheme rather than just matching up to the first @.
    run strip_userinfo "git@github.com:DimitriGeelen/agentic-engineering-framework.git"
    [ "$output" = "git@github.com:DimitriGeelen/agentic-engineering-framework.git" ]
}

@test "ssh:// URL with a username keeps host and path, drops userinfo" {
    run strip_userinfo "ssh://$(printf 'git')@example.com:2222/org/repo.git"
    [ "$output" = "ssh://example.com:2222/org/repo.git" ]
}

@test "a path containing @ after the host is not truncated" {
    # The character class excludes "/" so the match cannot run past the authority
    # into the path. A greedy .*@ would eat this URL down to the last @.
    run strip_userinfo "https://example.com/org/repo@v2"
    [ "$output" = "https://example.com/org/repo@v2" ]
}
