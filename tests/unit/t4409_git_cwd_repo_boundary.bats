#!/usr/bin/env bats
#
# T-4409: git with no -C / --git-dir / GIT_DIR discovers its repository from the
# cwd, and that repository's config can run commands (T-4343). The git arm never
# looked at the cwd, so `cd /tmp/evil && git status` was SAFE (ring20-dashboard,
# msg 16c721c9). The effective cwd (tracked through cd; else the payload cwd; else
# PWD only when it is PROJECT_ROOT) must now resolve inside PROJECT_ROOT, and a cd
# carries into the next segment only across `&&` and `;`. After `|`, `||` or `&`
# the cwd is unknown and git fails closed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions
# use `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
    PROJ="$(realpath "$(mktemp -d)")"
    OUT="$PROJ.out"
    mkdir -p "$PROJ/docs" "$OUT/.git" /tmp/evil
    export PROJECT_ROOT="$PROJ"
    export _FW_PAYLOAD_CWD="$PROJ"
}

teardown() {
    rm -rf "$PROJ" "$OUT"
}

# --- the reporter's cases: NOT SAFE ----------------------------------------------

@test "T-4409: cd /tmp/evil && git status is NOT SAFE" {
    if is_bash_safe_command "cd /tmp/evil && git status"; then false; fi
}

@test "T-4409: cd /tmp/evil; git log is NOT SAFE" {
    if is_bash_safe_command "cd /tmp/evil; git log"; then false; fi
}

@test "T-4409: cd /tmp/evil || git status is NOT SAFE (verdict does not depend on cd failing)" {
    if is_bash_safe_command "cd /tmp/evil || git status"; then false; fi
}

@test "T-4409: cd <outside> && git status is NOT SAFE" {
    if is_bash_safe_command "cd $OUT && git status"; then false; fi
}

# --- operator awareness ------------------------------------------------------------

@test "T-4409: cd <outside> | git status is NOT SAFE (cwd unknown after |)" {
    if is_bash_safe_command "cd $OUT | git status"; then false; fi
}

@test "T-4409: cd <outside> & git status is NOT SAFE (cwd unknown after &)" {
    if is_bash_safe_command "cd $OUT & git status"; then false; fi
}

@test "T-4409: cd <outside> || true; git log is NOT SAFE (either cwd is possible)" {
    if is_bash_safe_command "cd $OUT || true; git log"; then false; fi
}

@test "T-4409: cd docs || git status is NOT SAFE (|| never carries a known cwd)" {
    if is_bash_safe_command "cd docs || git status"; then false; fi
}

@test "T-4409: cd <outside> newline git log is NOT SAFE (newline reads as ;)" {
    if is_bash_safe_command "cd $OUT
git log"; then false; fi
}

@test "T-4409: cd <outside> && X=\$(git rev-parse HEAD) is NOT SAFE (nested call inherits cwd)" {
    if is_bash_safe_command "cd $OUT && X=\$(git rev-parse HEAD)"; then false; fi
}

@test "T-4409: cd \$VAR && git status is NOT SAFE (cwd unknown)" {
    if is_bash_safe_command "cd \$HOME && git status"; then false; fi
}

# --- the starting cwd ----------------------------------------------------------------

@test "T-4409: payload cwd outside the project: git status is NOT SAFE" {
    _FW_PAYLOAD_CWD="$OUT"
    if is_bash_safe_command "git status"; then false; fi
}

@test "T-4409: no payload cwd, PWD outside PROJECT_ROOT: git status is NOT SAFE" {
    unset _FW_PAYLOAD_CWD
    cd "$OUT"
    if is_bash_safe_command "git status"; then false; fi
}

@test "T-4409: no payload cwd, PWD is PROJECT_ROOT: git status is SAFE" {
    unset _FW_PAYLOAD_CWD
    cd "$PROJ"
    is_bash_safe_command "git status"
}

@test "T-4409: PROJECT_ROOT unset: git status is NOT SAFE (fail closed)" {
    unset PROJECT_ROOT
    if is_bash_safe_command "git status"; then false; fi
}

# --- inside the project: SAFE ----------------------------------------------------

@test "T-4409: git status is SAFE (payload cwd = project)" {
    is_bash_safe_command "git status"
}

@test "T-4409: cd <project>/docs && git status is SAFE" {
    is_bash_safe_command "cd $PROJ/docs && git status"
}

@test "T-4409: cd docs; git log is SAFE (relative, inside)" {
    is_bash_safe_command "cd docs; git log"
}

@test "T-4409: git status && git log is SAFE" {
    is_bash_safe_command "git status && git log"
}

@test "T-4409: ls | git status is SAFE (no directory change)" {
    is_bash_safe_command "ls | git status"
}

@test "T-4409: cd <outside> && git -C <project> status is SAFE (-C names the repository)" {
    is_bash_safe_command "cd $OUT && git -C $PROJ status"
}

@test "T-4409: cd <outside> && ls is SAFE (only git consults the cwd)" {
    is_bash_safe_command "cd $OUT && ls"
}

@test "T-4409: for loop over git log in the project is SAFE" {
    is_bash_safe_command "for t in a b; do git log -1; done"
}

# --- the commit-checkpoint allowance (null focus / partial-complete) -------------

@test "T-4409: commit checkpoint — cd <outside> && git commit is refused" {
    if is_commit_checkpoint_command "cd $OUT && git commit -m 'T-1: x'"; then false; fi
}

@test "T-4409: commit checkpoint — cd <outside>; git add -A && git commit is refused" {
    if is_commit_checkpoint_command "cd $OUT; git add -A && git commit -m 'T-1: x'"; then false; fi
}

@test "T-4409: commit checkpoint — payload cwd outside: git commit is refused" {
    _FW_PAYLOAD_CWD="$OUT"
    if is_commit_checkpoint_command "git commit -m 'T-1: x'"; then false; fi
}

@test "T-4409: commit checkpoint — git add -A && git commit in the project is admitted" {
    is_commit_checkpoint_command "git add -A && git commit -m 'T-1: x'"
}

@test "T-4409: commit checkpoint — cd <project> && git commit is admitted" {
    is_commit_checkpoint_command "cd $PROJ && git commit -m 'T-1: x'"
}
