#!/usr/bin/env bats
# T-1392: Verify audit's uncommitted-changes check filters session-state noise.
#
# When ONLY session-state files are dirty (watchtower.log, audits/*, monitors/*,
# session-metrics, focus.yaml, etc.), audit MUST report "Working directory clean
# (... session-state file(s) churning, ignored)" — NOT a WARN. When real source
# files are dirty, the WARN MUST still fire.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMPREPO=$(mktemp -d)
    cd "$TMPREPO"
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    mkdir -p .context/working .context/audits .context/monitors .context/approvals .context/project .tasks/active .tasks/completed .tasks/templates
    touch .tasks/templates/zzz-default.md
    # Seed each .context dir with a tracked file so untracked-file additions
    # later show their full paths (git collapses untracked files in fully-
    # untracked directories to just the dir name; see git-status(1)). We
    # avoid `--untracked-files=all` per project rule (memory cost on large repos).
    for d in working audits monitors approvals project; do
        touch ".context/$d/.gitkeep"
    done
    echo "real" > README.md
    git add -A
    git commit -q -m "T-1392: baseline"
}

teardown() {
    cd /
    rm -rf "$TMPREPO"
}

@test "T-1392: audit ignores session-state churn (passes when only noise dirty)" {
    cd "$TMPREPO"
    # Dirty ONLY session-state files
    echo "log" > .context/working/watchtower.log
    echo "pid" > .context/working/watchtower.pid
    echo "12" > .context/working/.tool-counter
    echo "data" > .context/audits/2026-04-23.yaml
    echo "data" > .context/monitors/liveness.jsonl
    echo "data" > .context/working/.session-metrics.yaml
    echo "data" > .context/working/focus.yaml

    PROJECT_ROOT="$TMPREPO" run bash "$AUDIT" --section traceability
    [ "$status" -le 1 ]
    # MUST report clean PASS, with informational note about ignored noise
    [[ "$output" == *"Working directory clean"* ]]
    [[ "$output" == *"session-state"* ]]
    # MUST NOT fire the noisy WARN
    if [[ "$output" == *"Uncommitted changes present"* ]]; then
        echo "FAIL: WARN fired despite only session-state files dirty"
        echo "$output"
        false
    fi
}

@test "T-1392: audit still WARNs when real source files are dirty" {
    cd "$TMPREPO"
    # Dirty session-state AND a real source file
    echo "noise" > .context/working/watchtower.log
    echo "noise" > .context/audits/2026-04-23.yaml
    echo "real change" > README.md

    PROJECT_ROOT="$TMPREPO" run bash "$AUDIT" --section traceability
    [ "$status" -le 1 ]
    # MUST WARN about uncommitted changes (real files present)
    [[ "$output" == *"Uncommitted changes present"* ]]
    # The WARN message MUST credit the noise filter (count noise vs real)
    [[ "$output" == *"session-state"* ]]
}

@test "T-1392: audit reports clean when truly clean (no regression)" {
    cd "$TMPREPO"
    PROJECT_ROOT="$TMPREPO" run bash "$AUDIT" --section traceability
    [ "$status" -le 1 ]
    [[ "$output" == *"Working directory clean"* ]]
}
