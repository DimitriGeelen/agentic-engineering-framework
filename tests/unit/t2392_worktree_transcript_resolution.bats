#!/usr/bin/env bats
# T-2392: budget gauge blind in git-worktree sessions.
#
# Claude Code keys the transcript projects dir on the session's LAUNCH cwd (the
# MAIN repo), not on PROJECT_ROOT (the worktree). Reconstructing from
# PROJECT_ROOT alone searched a stale/empty sibling dir → tokens=0 → the
# continuous loop never armed.
#
# Fix (lib/paths.sh `fw_claude_project_dirs`): emit BOTH the PROJECT_ROOT-keyed
# dir AND the primary-worktree (main-repo, via git-common-dir → parent) keyed
# dir; callers pick the globally-newest transcript across them.
#
# Tests drive REAL git worktrees + the REAL checkpoint.sh status path (zero mocks)
# and the REAL fw_claude_project_dirs resolver.

load ../test_helper

# Repo root (tests/unit → repo)
FW_REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

enc() { printf '%s' "$1" | tr -c 'a-zA-Z0-9' '-'; }

setup() {
    ROOT="$(mktemp -d -t fw-t2392-XXXXXX)"
    MAIN="$ROOT/main"
    WT="$ROOT/wt"
    HOME_DIR="$ROOT/home"

    git init -q -b master "$MAIN"
    git -C "$MAIN" config user.email t@t.local
    git -C "$MAIN" config user.name tester
    echo base > "$MAIN/f"
    git -C "$MAIN" add -A
    git -C "$MAIN" commit -qm base
    git -C "$MAIN" worktree add -q "$WT" -b feat

    mkdir -p "$HOME_DIR/.claude/projects"
    MAIN_DIR="$HOME_DIR/.claude/projects/$(enc "$MAIN")"
    WT_DIR="$HOME_DIR/.claude/projects/$(enc "$WT")"
    mkdir -p "$MAIN_DIR" "$WT_DIR"
}

teardown() {
    cd /
    rm -rf "$ROOT"
}

# --- direct resolver unit checks -------------------------------------------

@test "t1: worktree session — fw_claude_project_dirs emits BOTH candidate dirs" {
    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" FRAMEWORK_ROOT="$FW_REPO" bash -c '
        source "$FRAMEWORK_ROOT/lib/paths.sh"
        fw_claude_project_dirs
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "$WT_DIR"
    echo "$output" | grep -qF "$MAIN_DIR"
}

@test "t2: globally-newest pick selects the live main-keyed transcript over stale worktree one" {
    echo '{}' > "$WT_DIR/stale.jsonl";  touch -d '2020-01-01' "$WT_DIR/stale.jsonl"
    echo '{}' > "$MAIN_DIR/live.jsonl"; touch -d '2025-01-01' "$MAIN_DIR/live.jsonl"
    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" FRAMEWORK_ROOT="$FW_REPO" bash -c '
        source "$FRAMEWORK_ROOT/lib/paths.sh"
        while IFS= read -r d; do
            find "$d" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null
        done < <(fw_claude_project_dirs) | xargs -r -0 ls -t 2>/dev/null | head -1
    '
    [ "$status" -eq 0 ]
    [ "$output" = "$MAIN_DIR/live.jsonl" ]
}

@test "t3: non-worktree (PROJECT_ROOT=main) — single candidate dir, no duplication" {
    run env HOME="$HOME_DIR" PROJECT_ROOT="$MAIN" FRAMEWORK_ROOT="$FW_REPO" bash -c '
        source "$FRAMEWORK_ROOT/lib/paths.sh"
        fw_claude_project_dirs
    '
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | grep -c .)" -eq 1 ]
    [ "$output" = "$MAIN_DIR" ]
}

@test "t4: not-a-git-repo root — only the PROJECT_ROOT-keyed dir emitted (graceful)" {
    NOGIT="$ROOT/nogit"
    mkdir -p "$NOGIT"
    NOGIT_DIR="$HOME_DIR/.claude/projects/$(enc "$NOGIT")"
    mkdir -p "$NOGIT_DIR"
    run env HOME="$HOME_DIR" PROJECT_ROOT="$NOGIT" FRAMEWORK_ROOT="$FW_REPO" bash -c '
        source "$FRAMEWORK_ROOT/lib/paths.sh"
        fw_claude_project_dirs
    '
    [ "$status" -eq 0 ]
    [ "$output" = "$NOGIT_DIR" ]
}

# --- end-to-end: REAL checkpoint.sh status reads the live token count ---------

@test "t5: checkpoint.sh status reads live tokens from main-keyed dir despite stale worktree dir" {
    # Worktree-keyed dir: stale, near-zero usage, OLD mtime.
    printf '%s\n' '{"timestamp":"2020-01-01T00:00:00Z","message":{"model":"claude","usage":{"input_tokens":5}}}' > "$WT_DIR/stale.jsonl"
    touch -d '2020-01-01' "$WT_DIR/stale.jsonl"
    # Main-keyed dir: the live session transcript, real usage, NEWER mtime.
    printf '%s\n' '{"timestamp":"2025-01-01T00:00:00Z","message":{"model":"claude","usage":{"input_tokens":150000}}}' > "$MAIN_DIR/live.jsonl"
    touch -d '2025-01-01' "$MAIN_DIR/live.jsonl"

    mkdir -p "$WT/.context/working"

    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" FW_TRANSCRIPT_PATH="" \
        bash "$FW_REPO/agents/context/checkpoint.sh" status
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Context tokens: 150000"
}
