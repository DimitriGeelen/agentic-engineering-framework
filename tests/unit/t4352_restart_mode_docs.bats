#!/usr/bin/env bats
# T-4352 (GH #95) — the auto-restart docs must state the mode bin/claude-fw defaults to.
#
# T-3166 made the restart a FRESH session (${FW_RESTART_MODE:-fresh}) so it frees the
# context it restarts to escape; `-c` survives only under FW_RESTART_MODE=continue.
# CLAUDE.md, the consumer template and docs/harnesses.md kept saying the wrapper
# "auto-restarts with `claude -c`" — conversation kept — because nothing read the
# prose against the code. This reads the default FROM the code, so a later change of
# default without the docs turns this suite red.

load ../test_helper

REPO="$FRAMEWORK_ROOT"

# The single default every FW_RESTART_MODE expansion in claude-fw uses.
_default_mode() {
    grep -o 'FW_RESTART_MODE:-[a-z]*' "$REPO/bin/claude-fw" | sort -u | sed 's/.*:-//'
}

# Body of the "## Auto-Restart" section of a markdown file.
_restart_section() {
    awk '/^## Auto-Restart/{on=1; next} on && /^## /{exit} on' "$1"
}

@test "claude-fw has exactly one restart-mode default" {
    run _default_mode
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
}

@test "CLAUDE.md Auto-Restart states the code's default and the continue override" {
    mode=$(_default_mode)
    sec=$(_restart_section "$REPO/CLAUDE.md")
    [ -n "$sec" ]
    echo "$sec" | grep -qF "FW_RESTART_MODE=$mode"
    echo "$sec" | grep -qF "FW_RESTART_MODE=continue"
    ! echo "$sec" | grep -qF 'auto-restarts with `claude -c`' || false
    ! echo "$sec" | grep -qF '→ `claude -c` →' || false
}

@test "consumer template Auto-Restart states the code's default and the continue override" {
    mode=$(_default_mode)
    sec=$(_restart_section "$REPO/lib/templates/claude-project.md")
    [ -n "$sec" ]
    echo "$sec" | grep -qF "FW_RESTART_MODE=$mode"
    echo "$sec" | grep -qF "FW_RESTART_MODE=continue"
    ! echo "$sec" | grep -qF 'auto-restarts with `claude -c`' || false
    ! echo "$sec" | grep -qF '→ `claude -c` →' || false
}

@test "docs/harnesses.md does not say claude-fw restarts with claude -c" {
    mode=$(_default_mode)
    ! grep -qF 'restarts with `claude -c`' "$REPO/docs/harnesses.md" || false
    grep -qF "FW_RESTART_MODE=$mode" "$REPO/docs/harnesses.md"
}
