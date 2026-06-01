---
id: T-1279
name: "Fix fw work-on / task-create race condition on task-ID allocation"
description: >
  agents/task-create/create-task.sh generate_id() reads max_id by scanning
  .tasks/active and .tasks/completed, then returns max_id+1. No lock between
  read and write — concurrent invocations all see the same max_id and all
  allocate the same new ID. Observed during T-1277/T-1278 investigation:
  four distinct `fw work-on` calls within ~2s all produced `T-1278-*.md`
  files with id: T-1278 in the frontmatter.
status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [bug, tooling, race-condition, task-system]
components: [C-004, agents/task-create/create-task.sh, tests/unit/task_id_race.bats, lib/keylock.sh]
related_tasks: [T-1277, T-1278]
created: 2026-04-17T10:35:00Z
last_update: 2026-04-20T19:43:31Z
date_finished: 2026-04-20T19:41:01Z
---

# T-1279: Fix fw work-on / task-create race condition on task-ID allocation

## Context

During the T-1277 + T-1278 investigation session, four `fw work-on` calls fired in parallel (one from my explicit command + three from concurrent sessions / autonomous cron triggers). All four produced colliding task files:

```
T-1278-e2e-test-inception-decide-on-consumer-pr.md    created 2026-04-17T10:16:32Z
T-1278-e2e-test-inception-decide-on-vendored-co.md    created 2026-04-17T10:16:32Z
T-1278-fix-inception-decide-on-consumer-project.md    created 2026-04-17T10:16:31Z
T-1278-fix-unbounded-git-push-in-handover-auto-.md    created 2026-04-17T10:16:33Z
```

Every file has `id: T-1278` in the YAML frontmatter. Timestamps span ~2 seconds.

Responsible code — `agents/task-create/create-task.sh:111-126`:

```bash
generate_id() {
    local max_id=0
    shopt -s nullglob
    for f in "$TASKS_DIR"/active/T-*.md "$TASKS_DIR"/completed/T-*.md; do
        [ -f "$f" ] || continue
        local id
        id=$(basename "$f" | grep -oE 'T-[0-9]+' | grep -oE '[0-9]+')
        if [ -n "$id" ] && [ "$((10#$id))" -gt "$max_id" ]; then
            max_id=$((10#$id))
        fi
    done
    shopt -u nullglob
    printf "T-%03d" $((max_id + 1))
}
```

Classic TOCTOU — `max_id` is observed, then (much later, after slug generation, path construction, template copy) a file is written. Nothing serialises readers against writers.

## Impact

- **ID collisions** — multiple tasks share the same ID. Downstream tools that assume `T-NNNN` is unique (episodic memory, fabric refs, audit, commit message validation) degrade unpredictably.
- **Filename collisions avoided only by slug divergence** — if two parallel invocations happened to have the same name, the second `cp` would silently overwrite the first. Data loss possible.
- **Commit-message enforcement fooled** — `git commit -m "T-1278: …"` matches ANY of four tasks; traceability is compromised.
- **Episodic memory confusion** — generate-episodic for T-1278 picks up content from whichever file comes first; the other three tasks have no episodic.
- **Human confusion** — agent or human running `fw task show T-1278` gets unpredictable results depending on which file glob hits first.

Not detected by any existing check (no audit gate, no bats test).

## Why it happens now

Multiple concurrent trigger sources:
- Autonomous cron agents (`bin/fw` liveness-checks, pickup processing)
- Cross-session TermLink dispatches calling `fw work-on`
- User + agent running `fw work-on` in overlapping sessions
- The ~6-minute `fw work-on` latency (on this repo, partly from RAG context enrichment) widens the race window significantly

## Acceptance Criteria

### Agent

- [x] `generate_id()` acquires a per-framework lock (via `lib/keylock.sh`) covering the entire read-max → write-file sequence, not just the ID computation
- [x] Lock key: `task-id-allocation` (or similar single-key), scope: project-wide
- [x] Bats test `tests/unit/task_id_race.bats` — spawns 5 parallel `create-task.sh` invocations and asserts 5 distinct IDs (also 10-parallel stress case)
- [x] `fw audit` check: detect any two task files sharing the same `id:` frontmatter value; report as FAIL with both paths
- [x] Follow-up work captured: T-1366 (keylock timeout), T-1367 (fw task reid repair tool). T-1278 stray-file cleanup already done in prior session via reassignment to T-1280/1281/1282.

### Human

- [ ] [REVIEW] After fix, spawn 10 parallel `fw work-on` with distinct names and verify all get distinct IDs
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework`
  2. `for i in $(seq 1 10); do bin/fw work-on "race-test-$i" --type build & done; wait`
  3. `ls .tasks/active/T-*race-test*.md | awk '{print $NF}' | grep -oE 'T-[0-9]+' | sort -u | wc -l`
  **Expected:** output is `10` (ten distinct IDs).
  **If not:** capture which IDs collided and reopen task.

## Verification

# Must pass before work-completed
bats tests/unit/task_id_race.bats
grep -q 'keylock_acquire.*task-id' agents/task-create/create-task.sh
# T-1412: was bin/fw audit (~25s, exceeds 20s sweep timeout). Direct check (~16ms):
test "$(ls .tasks/active/T-*.md .tasks/completed/T-*.md 2>/dev/null | grep -oE '/T-[0-9]+-' | sort | uniq -d | wc -l)" -eq 0

## Decisions

<!-- Record when choosing between alternatives -->

## Updates

### 2026-04-17T10:35:00Z — task-created [manual]
- **Action:** Created T-1279 directly (not via fw work-on — would've raced with itself)
- **Context:** Discovered during T-1277/T-1278 investigation. See docs… er, .context/working/observations/issue-report-fw-work-on-id-race.md.

### 2026-04-20T19:41:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-24T12:17:00Z — note [agent verification]
- **Evidence collected for Human AC (REVIEW: spawn 10 parallel distinct IDs)**
- Test v1 (10 × `bin/fw task create ... &`, no subshell wrap): produced 3-way collision on T-1424 — probe-3, probe-6, probe-7 each got T-1424 with different slugs → 3 separate files at same ID. **Fix is not watertight under tight concurrency.**
- Test v2 (10 × `( ... ) &` with subshell wrap): 10/10 distinct IDs — fix works when spawning has slight timing spread.
- Isolated keylock_acquire test (5 processes, cross-PID): serializes correctly — the keylock mechanism itself is fine.
- Hypothesis: `source "$FRAMEWORK_ROOT/lib/keylock.sh" 2>/dev/null || true` — when sources races or FRAMEWORK_ROOT propagation is ambiguous in forked children, some invocations skip the lock silently (type test at line 143 fails). Tight `&` bursts make this more likely.
- Recommendation: re-open — fix is not complete. Suggested hardening (a) remove `|| true` on keylock source so missing lock is a hard error, (b) assert `type keylock_acquire` after source or exit non-zero, (c) consider flock-on-allocation-file as defense-in-depth.
