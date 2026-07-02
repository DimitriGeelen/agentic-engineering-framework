---
id: T-1087
name: "Budget gate post-compact stale read — safety net fix"
description: >
  Option 2 from T-1087 RCA: post-compact-resume.sh should seed .budget-status with
  {ok, 0, now} instead of deleting it, so fast-path serves correct state during the
  window before the first post-compact assistant message with usage lands in the JSONL.
  Regression of T-145/T-271/T-712/T-713.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-11T10:29:58Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-11T10:32:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1087: Budget gate post-compact stale read — safety net fix

## Context

5th recurrence of the same class (T-145, T-271, T-712, T-713, now T-1087). On `/compact`, `post-compact-resume.sh` deletes `.budget-status`, but `budget-gate.sh`'s slow path then re-reads the resumed JSONL and picks up the pre-compact final usage entry as the "last usage entry" (because `claude -c` continues writing to the same JSONL and the first post-compact assistant message with a usage block hasn't landed yet). Result: false critical reading blocks Write/Edit/Bash during a 1–5 tool-call window after compaction. Option 1 (filter JSONL entries by timestamp) is the real fix and is queued as T-1088.

## Acceptance Criteria

### Agent
- [x] `post-compact-resume.sh` removes `.budget-status` from `VOLATILE_FILES` and writes a fresh `{"level": "ok", "tokens": 0, "timestamp": now, "source": "post-compact-resume"}` record instead.
- [x] Same change mirrored to `.agentic-framework/agents/context/post-compact-resume.sh`.
- [x] After a simulated post-compact recovery (run the script manually), `.budget-status` contains `level: ok` with a fresh timestamp.
- [x] T-1088 follow-up task created at `horizon: next` for the real fix (Option 1: timestamp filter in `budget-gate.sh` slow-path Python loop).

## Verification

python3 -c "import json; s=json.load(open('.context/working/.budget-status')); assert s['level']=='ok', s; assert s['source']=='post-compact-resume', s; print('ok')"
grep -q "T-1087" agents/context/post-compact-resume.sh
grep -q "T-1087" .agentic-framework/agents/context/post-compact-resume.sh
test -f .tasks/active/T-1088-*.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-11T10:29:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1087-budget-gate-post-compact-stale-read--saf.md
- **Context:** Initial task creation

### 2026-04-11T10:32:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7c921911
- **Timestamp:** 2026-06-02T14:55:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
