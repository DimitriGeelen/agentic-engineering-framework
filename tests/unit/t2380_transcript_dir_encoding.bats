#!/usr/bin/env bats
# T-2380 — the three transcript-dir read-surfaces (fw costs, discard-manifest,
# read-transcript.py) must encode the ~/.claude/projects/<dir> name the way
# Claude Code does: EVERY non-alnum char → '-'. The old slash-only sanitizer
# (tr '/' '-' / .replace('/', '-')) left dots intact and so looked in a
# non-existent directory for any worktree path (which contains '.claude').
#
# Drives REAL code: lib/paths.sh helper, the sourced lib/costs.sh resolver, and
# the real agents/capture/read-transcript.py CLI (--dry-run). Plus one static
# guard asserting no slash-only sanitizer survives in any of the three files.

setup() {
    REAL="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    command -v python3 >/dev/null || skip "python3 unavailable"
    TMP="$(mktemp -d)"

    # A project path that contains a dot — i.e. any git worktree under .claude/.
    DOTTED="/opt/x/.claude/worktrees/y"
    # Correct (Claude Code) encoding: every non-alnum → '-'. The '/.': → '--'.
    CORRECT="-opt-x--claude-worktrees-y"
    # Old broken (slash-only) encoding: the dot survives.
    OLDBROKEN="-opt-x-.claude-worktrees-y"
}

teardown() {
    [ -n "${TMP:-}" ] && rm -rf "$TMP"
    return 0
}

_mk_fixture() {  # dir-name
    local d="$TMP/home/.claude/projects/$1"
    mkdir -p "$d"
    printf '%s\n%s\n' '{"type":"user"}' '{"type":"assistant"}' > "$d/sess.jsonl"
}

@test "helper: fw_claude_project_dir_name encodes the dot to a dash" {
    source "$REAL/lib/paths.sh"
    run fw_claude_project_dir_name "$DOTTED"
    [ "$status" -eq 0 ]
    [ "$output" = "$CORRECT" ]
}

@test "costs: _costs_jsonl_dir resolves the dot-encoded dir, not the dotted one" {
    export FRAMEWORK_ROOT="$REAL" PROJECT_ROOT="$DOTTED" HOME="$TMP/home"
    run bash -c 'source "$FRAMEWORK_ROOT/lib/colors.sh"; source "$FRAMEWORK_ROOT/lib/costs.sh"; _costs_jsonl_dir'
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.claude/projects/$CORRECT" ]
    # negative: the surviving-dot form must NOT appear
    [[ "$output" != *"$OLDBROKEN"* ]]
}

@test "read-transcript.py: finds the transcript under the dot-encoded dir (--dry-run OK)" {
    _mk_fixture "$CORRECT"
    run env HOME="$TMP/home" PROJECT_ROOT="$DOTTED" python3 "$REAL/agents/capture/read-transcript.py" --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Format canary: OK"
}

@test "read-transcript.py: negative control — a fixture under only the OLD slash-only name is NOT found" {
    _mk_fixture "$OLDBROKEN"
    run env HOME="$TMP/home" PROJECT_ROOT="$DOTTED" python3 "$REAL/agents/capture/read-transcript.py" --dry-run
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "transcript directory not found"
}

@test "static guard: no slash-only sanitizer remains in the three migrated surfaces" {
    run grep -nE "tr '/' '-'|replace\('/', '-'\)" \
        "$REAL/lib/costs.sh" \
        "$REAL/agents/handover/discard-manifest.sh" \
        "$REAL/agents/capture/read-transcript.py"
    # grep exits 1 (no match) when clean — that is the pass condition
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}
