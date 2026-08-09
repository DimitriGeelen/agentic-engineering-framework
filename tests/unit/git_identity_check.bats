#!/usr/bin/env bats
# T-2883 — "can this machine commit?" must be answered the way git answers it.
#
# Six surfaces asked that question by reading `git config user.email` /
# `user.name`. That read misses identity supplied through the environment, which
# is how CI, cron and dispatch workers supply it — so the framework told machines
# whose commits succeed that their commits would fail.
#
# Measured before the fix: GIT_AUTHOR_*/GIT_COMMITTER_* set, no config →
# `fw doctor` printed "commits will fail", `git commit` returned RC=0.
#
# This suite holds BOTH directions. "Stop warning" would satisfy the false-positive
# leg on its own, so every no-warning assertion is paired with a warning one in the
# state that genuinely cannot commit.
#
# The absent-identity state is git's real refusal, not a stub: isolated HOME with
# GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM at /dev/null. A stubbed absence would
# pass whether or not the predicate resolves identity the way git does, which is
# the whole property under test (L-530).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"     # test_helper's setup, re-stated because
    export TEST_TEMP_DIR             # defining setup() here overrides it
    LIB="$FRAMEWORK_ROOT/lib/git-identity.sh"
    REPO="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$REPO" "$BATS_TEST_TMPDIR/home"
    git init -q "$REPO"
}

# _bare <cmd...> — run a command with NO identity resolvable anywhere.
# GNU env requires -u before any NAME=VALUE assignment; put the other way round
# it reads "-u" as the command name and dies 127, which looks like a broken
# fixture rather than a broken invocation.
_bare() {
    env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL \
        -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
        HOME="$BATS_TEST_TMPDIR/home" \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_SYSTEM=/dev/null \
        "$@"
}

# _env_ident <cmd...> — no config anywhere, identity ONLY through env vars.
_env_ident() {
    env HOME="$BATS_TEST_TMPDIR/home" \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_SYSTEM=/dev/null \
        GIT_AUTHOR_NAME="Env Person" GIT_AUTHOR_EMAIL="env@example.invalid" \
        GIT_COMMITTER_NAME="Env Person" GIT_COMMITTER_EMAIL="env@example.invalid" \
        "$@"
}

_predicate() {  # echoes the predicate's exit code under the given runner
    local runner="$1"
    local rc=0
    "$runner" bash -c "source '$LIB'; fw_git_identity_ok '$REPO'" || rc=$?
    echo "$rc"
}

# --- ground truth: what git itself does in each state ----------------------
# Everything below is only meaningful if these two hold. They are the positive
# control for the whole suite — they establish that the two environments really
# do differ in the way the predicate claims to detect.

@test "T-2883: GROUND TRUTH — a bare environment genuinely cannot commit" {
    echo x > "$REPO/f.txt"
    _bare git -C "$REPO" add f.txt
    run _bare git -C "$REPO" commit -m "probe"
    [ "$status" -ne 0 ]
    [[ "$output" == *"identity unknown"* ]]
}

@test "T-2883: GROUND TRUTH — env-supplied identity genuinely CAN commit" {
    echo x > "$REPO/f.txt"
    _env_ident git -C "$REPO" add f.txt
    run _env_ident git -C "$REPO" commit -m "probe"
    [ "$status" -eq 0 ]
}

# --- the predicate agrees with git in both directions ----------------------

@test "T-2883: predicate says NO exactly where git says no" {
    [ "$(_predicate _bare)" -ne 0 ]
}

@test "T-2883: THE FIX — predicate says YES for env-supplied identity" {
    [ "$(_predicate _env_ident)" -eq 0 ]
}

@test "T-2883: predicate says YES for repo-local config" {
    git -C "$REPO" config user.name "Local Person"
    git -C "$REPO" config user.email "local@example.invalid"
    [ "$(_predicate _bare)" -eq 0 ]
}

@test "T-2883: the old probe is what was wrong — it disagrees where the new one is right" {
    # Pins the defect as the cause rather than asserting the fix in the abstract:
    # in the env-identity state the discarded probe reports missing, the shared
    # predicate reports present, and git sides with the predicate.
    run _env_ident bash -c "git -C '$REPO' config user.email"
    [ "$status" -ne 0 ]            # old probe: "missing"
    [ "$(_predicate _env_ident)" -eq 0 ]   # new predicate: present
}

# --- the remedy the surfaces hand over -------------------------------------

@test "T-2883: the remedy is one pasteable line with an explicit cd" {
    run bash -c "source '$LIB'; fw_git_identity_remedy '$REPO'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | wc -l)" -eq 0 ]   # single line, no embedded newline
    [[ "$output" == "cd $REPO && "* ]]
    [[ "$output" == *"user.email"* ]]
    [[ "$output" == *"user.name"* ]]
}

@test "T-2883: the remedy actually fixes the state it is offered for" {
    # A remedy nobody ran end-to-end is a guess. Run it literally.
    [ "$(_predicate _bare)" -ne 0 ]
    local cmd
    cmd=$(bash -c "source '$LIB'; fw_git_identity_remedy '$REPO'")
    _bare bash -c "$cmd" >/dev/null
    [ "$(_predicate _bare)" -eq 0 ]
}

@test "T-2883: identity display strips git's timestamp trailer" {
    git -C "$REPO" config user.name "Shown Person"
    git -C "$REPO" config user.email "shown@example.invalid"
    run _bare bash -c "source '$LIB'; fw_git_identity_show '$REPO'"
    [ "$status" -eq 0 ]
    [ "$output" = "Shown Person <shown@example.invalid>" ]
}

# --- every surface routes through the one predicate ------------------------
# Six copies of a predicate can disagree and nothing makes them agree (L-399).
# This is what makes them agree.

@test "T-2883: every surface routes through the one predicate" {
    # Six copies of a predicate can disagree and nothing makes them agree (L-399).
    # Asserted positively — each file must source the lib AND call it — rather than
    # by hunting for absent old-probe text, which passes for a file that stopped
    # checking identity entirely.
    for f in bin/fw lib/init.sh lib/setup.sh lib/preflight.sh lib/validate-init.sh; do
        grep -q 'git-identity\.sh' "$FRAMEWORK_ROOT/$f" \
            || { echo "$f does not source lib/git-identity.sh"; false; }
        grep -q 'fw_git_identity_ok' "$FRAMEWORK_ROOT/$f" \
            || { echo "$f does not call fw_git_identity_ok"; false; }
    done
}

@test "T-2883: no surface still DECIDES from a raw user.email read" {
    # The negative direction, kept narrow: `if`/`||`-style control flow hanging off
    # a bare config read. Writes that SET an identity (init's inheritance copy,
    # the onboarding-test fixture) are legitimate and must not be caught.
    #
    # `--global` reads are excluded deliberately. init still reads global config to
    # answer a different question — "is there an identity here worth COPYING into
    # the new repo?" — which is about provenance, not capability, and which
    # `git var` structurally cannot answer (it resolves an identity without saying
    # where it came from). Capability is the predicate's job; provenance is not.
    for f in bin/fw lib/init.sh lib/setup.sh lib/preflight.sh lib/validate-init.sh; do
        run grep -nE '(if +!? *git|\|\| *_identity|= *\$\(git) [^|]*config +user\.(email|name)[^"]*$' \
            "$FRAMEWORK_ROOT/$f"
        [ "$status" -ne 0 ] || { echo "decision-read survives in $f:"; echo "$output"; false; }
    done
}

@test "T-2883: doctor is silent about identity in a repo that can commit" {
    # This repo has a working local identity, so the check must not fire here.
    # L-527: a line that always fires stops carrying information.
    run bash -c "cd '$FRAMEWORK_ROOT' && bin/fw doctor --quick 2>&1"
    [[ "$output" != *"Git user identity not configured"* ]]
}

@test "T-2883: doctor DOES warn where identity is unresolvable" {
    # Pairs with the leg above — without this, 'silent' is satisfiable by a check
    # that was accidentally deleted.
    run _bare bash -c "cd '$REPO' && '$FRAMEWORK_ROOT/bin/fw' doctor --quick 2>&1"
    [[ "$output" == *"Git user identity not configured"* ]]
}
