#!/usr/bin/env bats
# T-4699: session-silent-scanner.sh must scan only THIS project's transcript
# dir(s) and never recover a session whose cwd is outside PROJECT_ROOT.
# Uses a fake CLAUDE_PROJECTS_DIR — never touches the real ~/.claude/projects.

SCANNER="$BATS_TEST_DIRNAME/../../agents/context/session-silent-scanner.sh"

setup() {
    ROOT="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/proj"
    OTHER="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/other"
    CP="$BATS_TEST_TMPDIR/claude-projects"
    SLUG=$(printf '%s' "$ROOT" | sed 's/[^A-Za-z0-9]/-/g')
    OSLUG=$(printf '%s' "$OTHER" | sed 's/[^A-Za-z0-9]/-/g')
    mkdir -p "$ROOT/.context/working" "$ROOT/.context/handovers" \
             "$ROOT/.agentic-framework/bin" "$OTHER" \
             "$CP/$SLUG" "$CP/$OSLUG" "$CP/${SLUG}-sibling" \
             "$CP/${SLUG}--claude-worktrees-wt1"
    export RECOVERY_LOG="$BATS_TEST_TMPDIR/recoveries.log"
    : > "$RECOVERY_LOG"
    cat > "$ROOT/.agentic-framework/bin/fw" <<'MOCK'
#!/bin/bash
[ "${1:-}" = "handover" ] && echo "SESSION=${RECOVERED_SESSION_ID:-none}" >> "$RECOVERY_LOG"
exit 0
MOCK
    chmod +x "$ROOT/.agentic-framework/bin/fw"
}

# stale_session <dir> <session-id> <cwd>
stale_session() {
    printf '{"type":"user","cwd":"%s"}\n' "$3" > "$CP/$1/$2.jsonl"
    touch -d "2 hours ago" "$CP/$1/$2.jsonl"
}

run_scanner() {
    PROJECT_ROOT="$ROOT" CLAUDE_PROJECTS_DIR="$CP" SESSION_SILENT_THRESHOLD_MIN=30 \
        DRY_RUN=0 run "$SCANNER"
}

@test "own project's stale session is recovered" {
    stale_session "$SLUG" S-OWN "$ROOT"
    run_scanner
    [ "$status" -eq 0 ]
    grep -q "SESSION=S-OWN" "$RECOVERY_LOG"
}

@test "another project's transcript dir is never scanned" {
    stale_session "$OSLUG" S-FOREIGN "$OTHER"
    stale_session "${SLUG}-sibling" S-SIBLING "$ROOT-sibling"
    run_scanner
    [ "$status" -eq 0 ]
    ! grep -q "S-FOREIGN\|S-SIBLING" "$RECOVERY_LOG" || false
    ! grep -q "S-FOREIGN\|S-SIBLING" "$ROOT/.context/working/.session-silent-scanner.log" || false
}

@test "worktree transcript dir of the same repo is scanned" {
    stale_session "${SLUG}--claude-worktrees-wt1" S-WT "$ROOT/.claude/worktrees/wt1"
    run_scanner
    [ "$status" -eq 0 ]
    grep -q "SESSION=S-WT" "$RECOVERY_LOG"
}

@test "session in own dir with a foreign cwd is skipped and logged once" {
    stale_session "$SLUG" S-ALIEN "$OTHER"
    printf '{"type":"user"}\n' > "$CP/$SLUG/S-NOCWD.jsonl"
    touch -d "2 hours ago" "$CP/$SLUG/S-NOCWD.jsonl"
    run_scanner
    [ "$status" -eq 0 ]
    ! grep -q "S-ALIEN\|S-NOCWD" "$RECOVERY_LOG" || false
    [ "$(grep -c 'skip-foreign-cwd session=S-ALIEN' "$ROOT/.context/working/.session-silent-scanner.log")" -eq 1 ]
    [ "$(grep -c 'skip-foreign-cwd session=S-NOCWD' "$ROOT/.context/working/.session-silent-scanner.log")" -eq 1 ]
}
