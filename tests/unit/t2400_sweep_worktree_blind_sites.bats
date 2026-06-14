#!/usr/bin/env bats
# T-2400: sweep remaining worktree-blind transcript-dir reconstruction sites onto
# the shared fw_claude_project_dirs resolver (T-2392). Two newest-pick legs:
#   - agents/handover/discard-manifest.sh  _jsonl_dir()
#   - agents/capture/read-transcript.py    find_transcript()
# (costs.sh union leg deferred — see task Decisions.)
#
# Both must, in a worktree session, find the live transcript in the MAIN-repo-keyed
# projects dir rather than the stale worktree-keyed one. Tests drive REAL git
# worktrees + the REAL function bodies (zero mocks).

load ../test_helper

FW_REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
enc() { printf '%s' "$1" | tr -c 'a-zA-Z0-9' '-'; }

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    ROOT="$(mktemp -d -t fw-t2400-XXXXXX)"
    MAIN="$ROOT/main"; WT="$ROOT/wt"; HOME_DIR="$ROOT/home"

    git init -q -b master "$MAIN"
    git -C "$MAIN" config user.email t@t.local
    git -C "$MAIN" config user.name tester
    echo base > "$MAIN/f"; git -C "$MAIN" add -A; git -C "$MAIN" commit -qm base
    git -C "$MAIN" worktree add -q "$WT" -b feat

    mkdir -p "$HOME_DIR/.claude/projects"
    MAIN_DIR="$HOME_DIR/.claude/projects/$(enc "$MAIN")"
    WT_DIR="$HOME_DIR/.claude/projects/$(enc "$WT")"
    mkdir -p "$MAIN_DIR" "$WT_DIR"
    # Stale transcript in the worktree-keyed dir; live (newer) one in main-keyed.
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"stale"}}' > "$WT_DIR/stale.jsonl"
    touch -d '2020-01-01' "$WT_DIR/stale.jsonl"
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"live"}}' > "$MAIN_DIR/live.jsonl"
    touch -d '2025-01-01' "$MAIN_DIR/live.jsonl"
}

teardown() { cd /; rm -rf "$ROOT"; }

@test "t1: discard-manifest _jsonl_dir() returns the main-keyed dir (live transcript) in a worktree" {
    # Extract + run the REAL function body verbatim from the file.
    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" FRAMEWORK_ROOT="$FW_REPO" bash -c '
        source "$FRAMEWORK_ROOT/lib/paths.sh"
        eval "$(sed -n "/^_jsonl_dir() {/,/^}/p" "$FRAMEWORK_ROOT/agents/handover/discard-manifest.sh")"
        _jsonl_dir
    '
    [ "$status" -eq 0 ]
    [ "$output" = "$MAIN_DIR" ]
}

@test "t2: discard-manifest _jsonl_dir() falls back to PROJECT_ROOT-keyed name when no transcript exists" {
    rm -f "$WT_DIR"/*.jsonl "$MAIN_DIR"/*.jsonl
    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" FRAMEWORK_ROOT="$FW_REPO" bash -c '
        source "$FRAMEWORK_ROOT/lib/paths.sh"
        eval "$(sed -n "/^_jsonl_dir() {/,/^}/p" "$FRAMEWORK_ROOT/agents/handover/discard-manifest.sh")"
        _jsonl_dir
    '
    [ "$status" -eq 0 ]
    [ "$output" = "$WT_DIR" ]
}

@test "t3: read-transcript.py find_transcript() picks the live main-keyed transcript in a worktree" {
    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" python3 - "$FW_REPO" <<'PY'
import importlib.util, os, sys
repo = sys.argv[1]
spec = importlib.util.spec_from_file_location("rt", os.path.join(repo, "agents/capture/read-transcript.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.find_transcript() or "")
PY
    [ "$status" -eq 0 ]
    [ "$output" = "$MAIN_DIR/live.jsonl" ]
}

@test "t4: read-transcript.py _candidate_project_dirs emits both candidate dirs (worktree)" {
    run env HOME="$HOME_DIR" PROJECT_ROOT="$WT" python3 - "$FW_REPO" <<'PY'
import importlib.util, os, sys
repo = sys.argv[1]
spec = importlib.util.spec_from_file_location("rt", os.path.join(repo, "agents/capture/read-transcript.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
for d in m._candidate_project_dirs(os.environ["PROJECT_ROOT"]):
    print(d)
PY
    [ "$status" -eq 0 ]
    echo "$output" | grep -qF "$WT_DIR"
    echo "$output" | grep -qF "$MAIN_DIR"
}
