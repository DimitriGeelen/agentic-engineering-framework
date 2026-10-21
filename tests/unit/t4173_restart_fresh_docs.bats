#!/usr/bin/env bats
# T-4173 (dimitri-mint-dev P-011) — the surfaces T-4352 did not pin must not say a
# claude-fw budget auto-restart continues with `claude -c`.
#
# T-3166 made the restart a FRESH session (${FW_RESTART_MODE:-fresh}); T-4352 fixed
# CLAUDE.md, the consumer template and docs/harnesses.md. docs/context-compaction.md
# and the header of the hook that serves the restart (post-compact-resume.sh) kept
# the old `claude -c` claim. The default is read from the code, so these assertions
# only bite while the default is fresh.

load ../test_helper

REPO="$FRAMEWORK_ROOT"

_default_mode() {
    grep -o 'FW_RESTART_MODE:-[a-z]*' "$REPO/bin/claude-fw" | sort -u | sed 's/.*:-//'
}

@test "docs/context-compaction.md: auto-restart row matches the code's default" {
    [ "$(_default_mode)" = "fresh" ] || skip "default is no longer fresh"
    row=$(grep -i 'auto-restart' "$REPO/docs/context-compaction.md" | grep '^|')
    [ -n "$row" ]
    ! echo "$row" | grep -qF 'claude -c' || false
    echo "$row" | grep -qi 'fresh'
}

@test "post-compact-resume.sh header does not attribute auto-restart to claude -c" {
    [ "$(_default_mode)" = "fresh" ] || skip "default is no longer fresh"
    hdr=$(sed -n '1,60p' "$REPO/agents/context/post-compact-resume.sh")
    ! echo "$hdr" | grep -E 'claude -c.*auto-restart|auto-restart.*claude -c' || false
    ! echo "$hdr" | grep -qF 'claude-fw → `claude -c`' || false
}
