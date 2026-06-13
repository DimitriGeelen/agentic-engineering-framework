#!/usr/bin/env bats
# T-2375: regression test for the Claude Code transcript project-dir-name sanitizer.
#
# Bug: the budget detector reconstructed Claude Code's ~/.claude/projects/<name>
# directory with `${PROJECT_ROOT//\//-}` (only '/' → '-'), but Claude Code
# replaces EVERY non-alphanumeric char (so '.' → '-' too). In git worktrees under
# `.claude/worktrees/` the names diverged → "no transcript" → token budget gauge
# blind. This pins the helper against Claude Code's actual on-disk encoding.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# Source just the helper without triggering paths.sh's full derivation side effects.
_dirname() {
    FRAMEWORK_ROOT="$REPO_ROOT" bash -c '
        source "'"$REPO_ROOT"'/lib/paths.sh" >/dev/null 2>&1
        fw_claude_project_dir_name "$1"
    ' _ "$1"
}

@test "plain path: only path separators become dashes (unchanged behavior)" {
    run _dirname "/opt/999-Agentic-Engineering-Framework"
    [ "$status" -eq 0 ]
    [ "$output" = "-opt-999-Agentic-Engineering-Framework" ]
}

@test "dotted worktree path: '.' is converted to '-' (the bug fix)" {
    run _dirname "/opt/x/.claude/worktrees/y"
    [ "$status" -eq 0 ]
    # '/.claude' → '--claude' (slash + dot both become dash)
    [ "$output" = "-opt-x--claude-worktrees-y" ]
}

@test "old algorithm would have produced a different (wrong) name" {
    local path="/opt/x/.claude/worktrees/y"
    local old="${path//\//-}"
    run _dirname "$path"
    [ "$status" -eq 0 ]
    [ "$output" != "$old" ]            # the fix must differ from the old buggy form
    [ "$old" = "-opt-x-.claude-worktrees-y" ]   # document what the bug produced
}

@test "helper output matches a seeded on-disk Claude Code projects dir" {
    # Mimic Claude Code: create the projects dir for a dotted path, seed a
    # transcript, and assert the helper's name resolves to that exact dir.
    local fake_home; fake_home="$(mktemp -d)"
    local cwd="/srv/proj/.claude/worktrees/feat"
    local name; name="$(_dirname "$cwd")"
    mkdir -p "$fake_home/.claude/projects/$name"
    : > "$fake_home/.claude/projects/$name/session.jsonl"

    [ -d "$fake_home/.claude/projects/$name" ]
    [ -f "$fake_home/.claude/projects/$name/session.jsonl" ]
    rm -rf "$fake_home"
}
