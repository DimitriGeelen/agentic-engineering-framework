#!/usr/bin/env bats
# T-4700: session-silent-scanner.sh log must stay bounded — old transcripts are
# counted, not logged one line each, and the log rotates past a size limit.
# Uses a fake CLAUDE_PROJECTS_DIR — never touches the real ~/.claude/projects.

SCANNER="$BATS_TEST_DIRNAME/../../agents/context/session-silent-scanner.sh"

setup() {
    ROOT="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/proj"
    CP="$BATS_TEST_TMPDIR/claude-projects"
    SLUG=$(printf '%s' "$ROOT" | sed 's/[^A-Za-z0-9]/-/g')
    LOG="$ROOT/.context/working/.session-silent-scanner.log"
    mkdir -p "$ROOT/.context/working" "$ROOT/.context/handovers" "$CP/$SLUG"
    for i in $(seq 1 50); do
        printf '{"type":"user","cwd":"%s"}\n' "$ROOT" > "$CP/$SLUG/S-OLD-$i.jsonl"
        touch -d "30 days ago" "$CP/$SLUG/S-OLD-$i.jsonl"
    done
}

run_scanner() {
    PROJECT_ROOT="$ROOT" CLAUDE_PROJECTS_DIR="$CP" DRY_RUN=1 run "$SCANNER"
}

@test "a run over 50 old transcripts appends a bounded number of lines" {
    run_scanner
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$LOG")" -le 5 ]
    grep -q "skip-too-old-total count=50" "$LOG"
    ! grep -q "skip-too-old session=" "$LOG" || false
}

@test "a log over the size limit is rotated to .1" {
    head -c 2000 /dev/zero | tr '\0' 'x' > "$LOG"
    PROJECT_ROOT="$ROOT" CLAUDE_PROJECTS_DIR="$CP" DRY_RUN=1 \
        SESSION_SILENT_LOG_MAX_BYTES=1000 run "$SCANNER"
    [ "$status" -eq 0 ]
    [ -f "$LOG.1" ]
    [ "$(wc -c < "$LOG.1")" -eq 2000 ]
    [ "$(wc -c < "$LOG")" -lt 1000 ]
}

@test "a log under the size limit is not rotated" {
    echo "previous" > "$LOG"
    run_scanner
    [ "$status" -eq 0 ]
    [ ! -e "$LOG.1" ]
    grep -q "^previous$" "$LOG"
}
