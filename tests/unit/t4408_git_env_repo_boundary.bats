#!/usr/bin/env bats
#
# T-4408: GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR (and GIT_INDEX_FILE,
# GIT_OBJECT_DIRECTORY) select the repository git reads, exactly as -C /
# --git-dir do (T-4343), and that repository's config can run commands. The
# env-prefix stripper admitted any value, so `GIT_DIR=/tmp/evil/.git git log`
# was SAFE (ring20-dashboard, msg 16c721c9). A value is now admitted only when
# it resolves inside PROJECT_ROOT; GIT_CONFIG* (bar NOSYSTEM), GIT_EXEC_PATH and
# GIT_ALTERNATE_OBJECT_DIRECTORIES are denied by name.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions
# use `if cmd; then false; fi`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT/agents/context/lib/safe-commands.sh"
    PROJ="$(realpath "$(mktemp -d)")"
    OUT="$PROJ.out"
    mkdir -p "$PROJ/.git" "$PROJ/sub" "$OUT/.git"
    export PROJECT_ROOT="$PROJ"
    export _FW_PAYLOAD_CWD="$PROJ"
}

teardown() {
    rm -rf "$PROJ" "$OUT"
}

# --- the reporter's cases: NOT SAFE ----------------------------------------------

@test "T-4408: GIT_DIR=/tmp/evil/.git git log is NOT SAFE" {
    if is_bash_safe_command "GIT_DIR=/tmp/evil/.git git log"; then false; fi
}

@test "T-4408: GIT_WORK_TREE=/tmp/evil git status is NOT SAFE" {
    if is_bash_safe_command "GIT_WORK_TREE=/tmp/evil git status"; then false; fi
}

@test "T-4408: GIT_COMMON_DIR=/tmp/evil/.git git status is NOT SAFE" {
    if is_bash_safe_command "GIT_COMMON_DIR=/tmp/evil/.git git status"; then false; fi
}

@test "T-4408: GIT_DIR=<outside fixture> git log is NOT SAFE" {
    if is_bash_safe_command "GIT_DIR=$OUT/.git git log"; then false; fi
}

# --- the other shapes ------------------------------------------------------------

@test "T-4408: env GIT_DIR=<outside> git log is NOT SAFE (env re-entry)" {
    if is_bash_safe_command "env GIT_DIR=$OUT/.git git log"; then false; fi
}

@test "T-4408: env -i GIT_WORK_TREE=<outside> git status is NOT SAFE" {
    if is_bash_safe_command "env -i GIT_WORK_TREE=$OUT git status"; then false; fi
}

@test "T-4408: export GIT_DIR=<outside>; git log is NOT SAFE" {
    if is_bash_safe_command "export GIT_DIR=$OUT/.git; git log"; then false; fi
}

@test "T-4408: export GIT_DIR=<outside> && git log is NOT SAFE" {
    if is_bash_safe_command "export GIT_DIR=$OUT/.git && git log"; then false; fi
}

@test "T-4408: bare assignment GIT_DIR=<outside>; git log is NOT SAFE" {
    if is_bash_safe_command "GIT_DIR=$OUT/.git; git log"; then false; fi
}

@test "T-4408: a denied repo prefix behind an allowed one is NOT SAFE" {
    if is_bash_safe_command "FOO=1 GIT_DIR=$OUT/.git git log"; then false; fi
}

@test "T-4408: relative GIT_DIR=../x escaping the project is NOT SAFE" {
    if is_bash_safe_command "GIT_DIR=../$(basename "$OUT")/.git git log"; then false; fi
}

@test "T-4408: relative GIT_DIR after cd outside is NOT SAFE (tracked cwd)" {
    if is_bash_safe_command "cd $OUT && GIT_DIR=.git git log"; then false; fi
}

@test "T-4408: quoted GIT_DIR value is NOT SAFE (not resolvable)" {
    if is_bash_safe_command "GIT_DIR=\"$PROJ/.git\" git log"; then false; fi
}

@test "T-4408: GIT_DIR with PROJECT_ROOT unset is NOT SAFE (fail closed)" {
    unset PROJECT_ROOT
    if is_bash_safe_command "GIT_DIR=.git git log"; then false; fi
}

@test "T-4408: GIT_INDEX_FILE=<outside> git status is NOT SAFE" {
    if is_bash_safe_command "GIT_INDEX_FILE=$OUT/index git status"; then false; fi
}

@test "T-4408: GIT_OBJECT_DIRECTORY=<outside> git log is NOT SAFE" {
    if is_bash_safe_command "GIT_OBJECT_DIRECTORY=$OUT/objects git log"; then false; fi
}

@test "T-4408: GIT_ALTERNATE_OBJECT_DIRECTORIES is NOT SAFE (denied by name)" {
    if is_bash_safe_command "GIT_ALTERNATE_OBJECT_DIRECTORIES=$PROJ/.git/objects git log"; then false; fi
}

@test "T-4408: GIT_CONFIG_PARAMETERS is NOT SAFE (the git -c channel)" {
    if is_bash_safe_command "GIT_CONFIG_PARAMETERS='core.fsmonitor=x' git status"; then false; fi
}

@test "T-4408: GIT_EXEC_PATH is NOT SAFE (git runs helpers from it)" {
    if is_bash_safe_command "GIT_EXEC_PATH=$PROJ git fetch"; then false; fi
}

# --- inside the project: SAFE ----------------------------------------------------

@test "T-4408: GIT_DIR=.git git log is SAFE (relative, inside)" {
    is_bash_safe_command "GIT_DIR=.git git log"
}

@test "T-4408: GIT_DIR=<absolute inside> GIT_WORK_TREE=<inside> git status is SAFE" {
    is_bash_safe_command "GIT_DIR=$PROJ/.git GIT_WORK_TREE=$PROJ git status"
}

@test "T-4408: env GIT_DIR=.git git log is SAFE" {
    is_bash_safe_command "env GIT_DIR=.git git log"
}

@test "T-4408: GIT_INDEX_FILE inside the project git status is SAFE" {
    is_bash_safe_command "GIT_INDEX_FILE=$PROJ/.git/index git status"
}

@test "T-4408: GIT_CEILING_DIRECTORIES git status is SAFE (can only stop discovery)" {
    is_bash_safe_command "GIT_CEILING_DIRECTORIES=/opt git status"
}

@test "T-4408: GIT_CONFIG_NOSYSTEM=1 git status is SAFE (only removes config)" {
    is_bash_safe_command "GIT_CONFIG_NOSYSTEM=1 git status"
}
