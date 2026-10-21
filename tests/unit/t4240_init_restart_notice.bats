#!/usr/bin/env bats
# T-4240 — `fw init` / install.sh must tell the operator to restart Claude Code.
#
# Claude Code reads CLAUDE.md and .claude/settings.json hooks at session START.
# A session that ran `fw init --provider claude` (or the installer) keeps running
# ungoverned until it is restarted in the project, yet the closing lines said only
# "Done! Governance is active." + "Next step: Start your AI agent" (dimitri-mint-dev
# P-017 B2). These tests pin the restart notice in the END of the real output —
# the place the operator reads last — for the providers that write Claude Code
# config, and its absence for cursor (negative control).

bats_require_minimum_version 1.5.0

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup_file() {
    FW="$FRAMEWORK_ROOT/bin/fw"
    export FW
    # Outside the framework tree (OBS-162: an ancestor .agentic-framework changes
    # the vendoring path), and with no enclosing repo or inherited project env.
    RDIR="${BATS_FILE_TMPDIR:-/tmp}/t4240"
    export RDIR
    rm -rf "$RDIR"; mkdir -p "$RDIR/home"
    export GIT_CEILING_DIRECTORIES="$RDIR"
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com
    export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
    for p in claude generic cursor; do
        mkdir -p "$RDIR/$p"
        env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u FW_PROJECT_ROOT HOME="$RDIR/home" \
            "$FW" init "$RDIR/$p" --provider "$p" > "$RDIR/$p.log" 2>&1 || true
    done
}

tail_of() {
    sed 's/\x1b\[[0-9;]*m//g' "$RDIR/$1.log" | tail -20
}

@test "claude: closing block tells the operator to restart Claude Code in the project with claude-fw" {
    run tail_of claude
    [ "$status" -eq 0 ]
    [[ "$output" == *"Restart Claude Code in $RDIR/claude with claude-fw"* ]]
    [[ "$output" == *"not active in this session"* ]]
}

@test "generic (writes Claude Code hooks too): restart notice present" {
    run tail_of generic
    [ "$status" -eq 0 ]
    [[ "$output" == *"Restart Claude Code in $RDIR/generic with claude-fw"* ]]
    [[ "$output" == *"$RDIR/generic/.claude/settings.json"* ]]
}

@test "cursor (no Claude Code config): no Claude Code restart notice" {
    run tail_of cursor
    [ "$status" -eq 0 ]
    # Guard against a vacuous pass on a failed init.
    [[ "$output" == *"Done!"* ]]
    [[ "$output" != *"Restart Claude Code"* ]]
}

@test "install.sh: project install ends with the restart notice" {
    local branch
    branch="$(git -C "$FRAMEWORK_ROOT" rev-parse --abbrev-ref HEAD)"
    [[ "$branch" == "HEAD" ]] && skip "detached HEAD -- --local install needs a real branch name"
    local repo="$RDIR/fixture-repo" home="$RDIR/install-home" target="$RDIR/install-target"
    git clone -q --depth 1 --branch "$branch" --single-branch "file://$FRAMEWORK_ROOT" "$repo"
    mkdir -p "$home" "$target"
    git init -q "$target"
    run env -i HOME="$home" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        GIT_CEILING_DIRECTORIES="$RDIR" \
        GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com \
        GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com \
        bash "$FRAMEWORK_ROOT/install.sh" "$target" --local "$repo" --branch "$branch" --no-scan --provider claude
    [ "$status" -eq 0 ]
    local tail
    tail=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | tail -15)
    [[ "$tail" == *"Restart Claude Code in $target with claude-fw"* ]]
    # T-4263 integration: install.sh runs fw init and then prints its own banner;
    # the operator must read the restart notice ONCE in the whole output.
    [ "$(printf '%s\n' "$output" | grep -c 'Restart Claude Code')" -eq 1 ]
}
