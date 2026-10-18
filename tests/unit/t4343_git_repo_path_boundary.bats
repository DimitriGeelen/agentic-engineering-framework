#!/usr/bin/env bats
#
# T-4343: git -C / --git-dir / --work-tree select the repository git reads, and
# that repository's config can run commands (core.fsmonitor, core.pager,
# diff.external, filters). The T-4264 skip of those globals judged the verb and
# never the path, so `git -C /tmp/evil status` was SAFE.
#
# A value is safe only when it resolves (realpath, cumulative through -C, against
# the command's effective cwd) to PROJECT_ROOT or a path inside it. Anything else
# — outside, a `..` escape, a symlink out, a quoted/variable/~/glob value, or a
# relative value whose cwd is unknown — is NOT SAFE.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions
# use `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"

    # A project, a sibling directory outside it, and a symlink pair crossing the
    # boundary. realpath the roots so the fixture is not skewed by a symlinked /tmp.
    PROJ="$(realpath "$(mktemp -d)")"
    OUT="$PROJ.out"
    OUTNAME="$(basename "$OUT")"
    mkdir -p "$PROJ/sub" "$OUT/deep"
    ln -s "$PROJ/sub" "$PROJ/link-in"
    ln -s "$OUT" "$PROJ/link-out"

    export PROJECT_ROOT="$PROJ"
    export _FW_PAYLOAD_CWD="$PROJ"
}

teardown() {
    rm -rf "$PROJ" "$OUT"
}

# --- inside the project: SAFE ----------------------------------------------------

@test "T-4343: git -C <absolute inside project> status is SAFE" {
    is_bash_safe_command "git -C $PROJ/sub status"
}

@test "T-4343: git -C <relative inside project> status is SAFE (against the payload cwd)" {
    is_bash_safe_command "git -C sub status"
}

@test "T-4343: git -C <symlink that stays inside> status is SAFE" {
    is_bash_safe_command "git -C $PROJ/link-in status"
}

@test "T-4343: git -C sub/../sub status is SAFE (.. normalised inside the project)" {
    is_bash_safe_command "git -C sub/../sub status"
}

@test "T-4343: git --git-dir=.git log is SAFE (= form, relative, inside)" {
    is_bash_safe_command "git --git-dir=.git log"
}

@test "T-4343: git --work-tree <absolute inside> status is SAFE (separate-word form)" {
    is_bash_safe_command "git --work-tree $PROJ status"
}

@test "T-4343: plain git status with no repo-selecting global is still SAFE" {
    is_bash_safe_command "git status"
}

# --- outside the project: NOT SAFE ------------------------------------------------

@test "T-4343 control: git -C <absolute outside project> status is NOT SAFE" {
    if is_bash_safe_command "git -C $OUT status"; then false; fi
}

@test "T-4343 control: git -C /tmp/evil status is NOT SAFE (the reported reproduction)" {
    if is_bash_safe_command "git -C /tmp/evil status"; then false; fi
}

@test "T-4343 control: git --git-dir=<outside>/.git log is NOT SAFE (= form)" {
    if is_bash_safe_command "git --git-dir=$OUT/.git log"; then false; fi
}

@test "T-4343 control: git --git-dir <outside>/.git log is NOT SAFE (separate-word form)" {
    if is_bash_safe_command "git --git-dir $OUT/.git log"; then false; fi
}

@test "T-4343 control: git --work-tree=<outside> status is NOT SAFE (= form)" {
    if is_bash_safe_command "git --work-tree=$OUT status"; then false; fi
}

@test "T-4343 control: git --work-tree <outside> status is NOT SAFE (separate-word form)" {
    if is_bash_safe_command "git --work-tree $OUT status"; then false; fi
}

@test "T-4343 control: git -C ../<sibling> status is NOT SAFE (relative .. escape)" {
    if is_bash_safe_command "git -C ../$OUTNAME status"; then false; fi
}

@test "T-4343 control: git -C sub/../../<sibling> status is NOT SAFE (.. after a real dir)" {
    if is_bash_safe_command "git -C sub/../../$OUTNAME status"; then false; fi
}

@test "T-4343 control: git -C link-out status is NOT SAFE (symlink pointing out)" {
    if is_bash_safe_command "git -C $PROJ/link-out status"; then false; fi
}

@test "T-4343 control: git -C link-out/deep status is NOT SAFE (symlink out, then a child)" {
    if is_bash_safe_command "git -C $PROJ/link-out/deep status"; then false; fi
}

@test "T-4343 control: git --git-dir=link-out/.git log is NOT SAFE (relative symlink out)" {
    if is_bash_safe_command "git --git-dir=link-out/.git log"; then false; fi
}

# --- values that cannot be proven inside: NOT SAFE (fail closed) --------------------

@test "T-4343 control: quoted -C value is NOT SAFE (cannot be judged without a shell)" {
    if is_bash_safe_command "git -C \"$PROJ/sub\" status"; then false; fi
}

@test "T-4343 control: variable-built -C value is NOT SAFE" {
    if is_bash_safe_command 'git -C $HOME status'; then false; fi
}

@test "T-4343 control: tilde -C value is NOT SAFE" {
    if is_bash_safe_command "git -C ~ status"; then false; fi
}

@test "T-4343 control: glob -C value is NOT SAFE" {
    if is_bash_safe_command "git -C su* status"; then false; fi
}

@test "T-4343 control: empty -C value is NOT SAFE" {
    if is_bash_safe_command "git -C '' status"; then false; fi
}

@test "T-4343 control: relative -C with a non-absolute payload cwd is NOT SAFE (base unknown)" {
    _FW_PAYLOAD_CWD="relative-cwd"
    if is_bash_safe_command "git -C sub status"; then false; fi
}

@test "T-4343 control: unset PROJECT_ROOT makes every repo-selecting global NOT SAFE" {
    unset PROJECT_ROOT
    if is_bash_safe_command "git -C $PROJ/sub status"; then false; fi
}

@test "T-4343 control: a missing PROJECT_ROOT directory makes -C NOT SAFE" {
    export PROJECT_ROOT="$PROJ/does-not-exist"
    if is_bash_safe_command "git -C $PROJ/sub status"; then false; fi
}

# --- cd tracking: the effective cwd is the cd target --------------------------------

@test "T-4343: cd <inside> && git -C .. status is SAFE (relative resolves against the cd target)" {
    is_bash_safe_command "cd $PROJ/sub && git -C .. status"
}

@test "T-4343: cd <inside> moves the base, so -C ../../<project name> resolves back inside" {
    # From PROJ/sub, ../../<PROJ basename> is PROJ again: SAFE. Judged against the
    # payload cwd (PROJ) the same value would be one level further up, outside.
    is_bash_safe_command "cd $PROJ/sub && git -C ../../$(basename "$PROJ") status"
}

@test "T-4343 control: cd <outside> && git -C . status is NOT SAFE (the cd target is outside)" {
    if is_bash_safe_command "cd $OUT && git -C . status"; then false; fi
}

@test "T-4343 control: cd <inside> && git -C ../../<sibling> status is NOT SAFE (escape from the cd target)" {
    if is_bash_safe_command "cd $PROJ/sub && git -C ../../$OUTNAME status"; then false; fi
}

@test "T-4343 control: cd <unknown dir> && git -C sub status is NOT SAFE (unknown base)" {
    if is_bash_safe_command "cd $PROJ/no-such-dir && git -C sub status"; then false; fi
}

@test "T-4343 control: cd - && git -C sub status is NOT SAFE (target not known)" {
    if is_bash_safe_command "cd - && git -C sub status"; then false; fi
}

@test "T-4343 control: cd \$VAR && git -C sub status is NOT SAFE (target not known)" {
    if is_bash_safe_command 'cd $HOME && git -C sub status'; then false; fi
}

@test "T-4343: an absolute inside -C stays SAFE after a cd to an unknown target" {
    # An absolute value does not depend on the cwd, so only RELATIVE values need a
    # known base. Pins that rule.
    is_bash_safe_command "cd - && git -C $PROJ/sub status"
}

# --- cumulative -C: each value is judged against the one before it -------------------

@test "T-4343: git -C sub -C .. status is SAFE (cumulative, still inside)" {
    is_bash_safe_command "git -C sub -C .. status"
}

@test "T-4343 control: git -C sub -C ../../<sibling> status is NOT SAFE (cumulative escape)" {
    if is_bash_safe_command "git -C sub -C ../../$OUTNAME status"; then false; fi
}

# --- chains: every segment is judged -------------------------------------------------

@test "T-4343 control: git -C <outside> status && git -C <inside> status is NOT SAFE (every clause counts)" {
    if is_bash_safe_command "git -C $OUT status && git -C $PROJ/sub status"; then false; fi
}

@test "T-4343: git -C <inside> status && git -C <inside> log is SAFE" {
    is_bash_safe_command "git -C $PROJ/sub status && git -C $PROJ/sub log --oneline -1"
}

# --- write verbs and -c stay refused whatever the path --------------------------------

@test "T-4343 control: git -C <inside> commit -m x is NOT SAFE (write verb)" {
    if is_bash_safe_command "git -C $PROJ/sub commit -m x"; then false; fi
}

@test "T-4343 control: git -c core.pager=x -C <inside> status is NOT SAFE (-c stays fail-closed)" {
    if is_bash_safe_command "git -c core.pager=x -C $PROJ/sub status"; then false; fi
}
