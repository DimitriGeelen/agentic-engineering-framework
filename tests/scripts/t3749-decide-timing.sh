#!/usr/bin/env bash
# T-3749 — measure the wall time of an inception decide, step by step.
#
# Never decides a task in the real repo. It clones the repo (local, hardlinked)
# into a scratch directory, files a synthetic inception there, and runs the
# CLONE's own bin/fw exactly as Watchtower does (CLAUDECODE stripped,
# --from-watchtower). Corpus size is the real one, which is the point: the
# reviewer, episodic and git-mining steps scale with it.
#
# Every output line is prefixed with seconds since start; with --xtrace each
# bash line of the chain is too (PS4 carries $EPOCHREALTIME), which is how the
# per-step table in the task was built.
#
# Usage: tests/scripts/t3749-decide-timing.sh [--xtrace] [--keep] [SCRATCH_DIR]
set -euo pipefail

XTRACE=0 KEEP=0
while [ $# -gt 0 ]; do
    case "$1" in
        --xtrace) XTRACE=1; shift ;;
        --keep) KEEP=1; shift ;;
        *) break ;;
    esac
done
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="${1:-$(mktemp -d /tmp/t3749-timing.XXXXXX)}"
FIX="T-99901"

git clone -q --local "$SRC" "$DIR/repo"
cd "$DIR/repo"
git checkout -q "$(git -C "$SRC" rev-parse --abbrev-ref HEAD)"
git config user.name timing && git config user.email timing@invalid
mkdir -p .context/working
cat > ".tasks/active/$FIX-fixture-decide-timing.md" <<'EOF'
---
id: T-99901
name: "Fixture inception for decide timing"
description: "T-3749 measurement fixture"
status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-03T00:00:00Z
last_update: 2026-10-03T00:00:00Z
date_finished:
---

# T-99901: Fixture inception for decide timing

## Problem Statement

Measure.

## Acceptance Criteria

### Agent
- [x] Research done

### Human
- [ ] [REVIEW] Decide go/no-go
  **Steps:** 1. read **Expected:** decided **If not:** defer

## Recommendation

**Recommendation:** GO
**Rationale:** fixture for timing only; the decision content is irrelevant to the measurement.
**Evidence:**
- none

## Decisions

## Decision

## Updates
EOF
git add ".tasks/active/$FIX-fixture-decide-timing.md"
git commit -q -m "$FIX: timing fixture"
: > ".context/working/.reviewed-$FIX"

env_args=(env -u CLAUDECODE PROJECT_ROOT="$DIR/repo")
if [ "$XTRACE" = 1 ]; then
    # BASH_ENV is sourced by every non-interactive bash in the chain. PS4 has to
    # be set there: bash ignores an inherited PS4 when running as root.
    printf '%s\n' 'PS4='"'"'+ ${EPOCHREALTIME} ${BASH_SOURCE##*/}:${LINENO}: '"'"'' 'set -x' > "$DIR/bash_env"
    env_args+=(BASH_ENV="$DIR/bash_env")
fi

"${env_args[@]}" bin/fw inception decide "$FIX" go --rationale "timing" --from-watchtower \
    > "$DIR/decide.out" 2> "$DIR/decide.err" &
pid=$!
python3 - "$DIR" "$pid" <<'PY'
import os, sys, time
d, pid = sys.argv[1], int(sys.argv[2])
t0 = time.time()
marks = {}
task = os.path.join(d, "repo/.tasks/completed")
while True:
    try:
        os.kill(pid, 0)
    except OSError:
        break
    if "moved" not in marks and any(f.startswith("T-99901-") for f in os.listdir(task)):
        marks["moved"] = time.time() - t0
    time.sleep(0.05)
marks["exit"] = time.time() - t0
print(" ".join(f"{k}={v:.1f}s" for k, v in marks.items()))
PY
rc=0; wait "$pid" || rc=$?; echo "decide exit=$rc"
echo "out: $DIR/decide.out  err: $DIR/decide.err"
[ "$KEEP" = 1 ] || { cd /; rm -rf "$DIR/repo"; }
