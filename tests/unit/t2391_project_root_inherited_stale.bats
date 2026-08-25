#!/usr/bin/env bats
# T-2391: bin/fw validates an INHERITED (non-empty) PROJECT_ROOT and re-resolves
# when stale, instead of using it verbatim. Origin: T-2389/T-2390 live-fire — the
# tmux-server daemon (PID 6177) carries a stale PROJECT_ROOT=$HOME (/root) in its
# env; every spawned session inherited it, the `-z` guard short-circuited, the
# poison was used as-is, and the budget gauge went blind (continuous loop never
# armed). The T-2390 CLAUDE_PROJECT_DIR-preference block was dead code in that path.
#
# Surface under test: bin/fw "_project_root_is_stale" + "Resolve PROJECT_ROOT"
# block. Observed via `fw version` ("Project: <root>"), same harness as
# t2390_project_root_claude_dir.bats.
#
# Staleness is NARROW (preserve "env wins" for legitimate overrides):
#   stale  := non-empty AND ( = $HOME  OR  not a dir  OR  no .framework.yaml/.tasks )
#   kept   := real project root, marker present, != $HOME
#
# NOTE on env(1) arg order: `env -u NAME VAR=val cmd` — the `-u` MUST precede the
# VAR=val assignments, else env treats `-u` as the command name (exit 127).
#
# AC mapping:
#   t1 poison =$HOME re-resolves to cwd's real project        — fix core
#   t2 stale + valid CLAUDE_PROJECT_DIR → CLAUDE_PROJECT_DIR  — dead-code revived
#   t3 legit inherited root kept from UNRELATED cwd           — env-wins (no regression)
#   t4 legit inherited root kept from its OWN subdir          — env-wins
#   t5 markerless inherited dir re-resolves                   — garbage rejected
#   t6 non-existent inherited dir re-resolves                 — garbage rejected

load ../test_helper

FW="$BATS_TEST_DIRNAME/../../bin/fw"

setup() {
    # POISON resembles a real $HOME that ALSO carries a stray .tasks marker — so
    # only the "= $HOME" rule (not the marker rule) can catch it. This is the
    # /root-with-stray-.tasks analogue.
    POISON="$(mktemp -d -t fw-t2391-home-XXXXXX)"
    mkdir -p "$POISON/.tasks"
    # REAL is the legitimate project the cwd lives in.
    REAL="$(mktemp -d -t fw-t2391-real-XXXXXX)"
    mkdir -p "$REAL/.tasks"
    printf 'version: test\n' > "$REAL/.framework.yaml"
    # REAL2 is a SECOND legitimate project, used to prove explicit env override wins.
    REAL2="$(mktemp -d -t fw-t2391-real2-XXXXXX)"
    mkdir -p "$REAL2/.tasks"
    printf 'version: test2\n' > "$REAL2/.framework.yaml"
}

teardown() {
    rm -rf "$POISON" "$REAL" "$REAL2"
}

@test "t1: inherited PROJECT_ROOT == \$HOME (poison) re-resolves to cwd's real project" {
    cd "$REAL"
    run env -u CLAUDE_PROJECT_DIR HOME="$POISON" PROJECT_ROOT="$POISON" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL"
    ! echo "$output" | grep -q "Project:.*$POISON"
}

@test "t2: stale (=\$HOME) PROJECT_ROOT + valid CLAUDE_PROJECT_DIR → CLAUDE_PROJECT_DIR (dead code revived)" {
    # cwd is a markerless dir so the $PWD walk would NOT find REAL2 — only the
    # CLAUDE_PROJECT_DIR preference can. This proves the T-2390 block is now reachable.
    local nowhere; nowhere="$(mktemp -d -t fw-t2391-nowhere-XXXXXX)"
    cd "$nowhere"
    run env HOME="$POISON" PROJECT_ROOT="$POISON" CLAUDE_PROJECT_DIR="$REAL2" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL2"
    if echo "$output" | grep -q "Project:.*$POISON"; then false; fi
    rm -rf "$nowhere"
}

@test "t3: legitimate inherited PROJECT_ROOT is KEPT from an UNRELATED cwd (env wins)" {
    # PROJECT_ROOT=REAL2 (real, marker, != $HOME); cwd is under REAL. Env must win —
    # we must NOT re-resolve to REAL just because cwd is elsewhere.
    cd "$REAL"
    run env -u CLAUDE_PROJECT_DIR HOME="/nonexistent-home-xyz" PROJECT_ROOT="$REAL2" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL2"
    ! echo "$output" | grep -q "Project:.*$REAL/"
}

@test "t4: legitimate inherited PROJECT_ROOT is KEPT from its own subdir (env wins)" {
    mkdir -p "$REAL2/sub"
    cd "$REAL2/sub"
    run env -u CLAUDE_PROJECT_DIR HOME="/nonexistent-home-xyz" PROJECT_ROOT="$REAL2" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL2"
}

@test "t5: markerless inherited dir (not \$HOME) is stale → re-resolves to cwd's project" {
    local empty; empty="$(mktemp -d -t fw-t2391-empty-XXXXXX)"
    cd "$REAL"
    run env -u CLAUDE_PROJECT_DIR HOME="/nonexistent-home-xyz" PROJECT_ROOT="$empty" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL"
    if echo "$output" | grep -q "Project:.*$empty"; then false; fi
    rm -rf "$empty"
}

@test "t6: non-existent inherited dir is stale → re-resolves to cwd's project" {
    cd "$REAL"
    run env -u CLAUDE_PROJECT_DIR HOME="/nonexistent-home-xyz" PROJECT_ROOT="/no/such/dir/anywhere" bash "$FW" version
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Project:.*$REAL"
}
