---
id: T-1783
name: "fw outcome read --tail-events N: show last N events from blob for one-shot
  forensics"
description: >
  fw outcome read --tail-events N: show last N events from blob for one-shot forensics

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [cli, observability]
components: [lib/outcome.py, tests/unit/test_outcome.py]
related_tasks: [T-1777, T-1780]
arc_id: orchestrator-rethink
created: 2026-05-11T09:20:00Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-13T21:08:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1783: fw outcome read --tail-events N: show last N events from blob for one-shot forensics

## Context

`fw outcome read <dispatch_id>` joins dispatch + outcome and now (post-T-1780)
shows terminal_event sub-fields. But the per-dispatch events.jsonl blob still
requires manual `tail` to inspect. Adding `--tail-events N` makes forensics
one-shot: read the dispatch row's `blob_dir`, tail the events file, print
the last N events as a `type=X` summary line each.

This is the natural pair to T-1780 — both add forensic depth to
`fw outcome read`. T-1780 added terminal context (what terminated);
T-1783 adds the preceding event trail (what led to termination).

## Acceptance Criteria

### Agent

**1. CLI flag**
- [x] `fw outcome read <dispatch_id> --tail-events N` accepts integer N.
- [x] N must be >= 1; otherwise the command errors with a clear message
      and exits 1.

**2. Tail rendering**
- [x] When the dispatch row has `blob_dir` and `<blob_dir>/events.jsonl`
      exists, read the file, parse JSON per line (skip malformed), and
      print the last N event lines as `  · <type> (<key-summary>)`.
- [x] Key-summary: for `agent.done` → empty; for `error` →
      `retryable=<bool>, message=<truncated>`; for `result` →
      `is_error=<bool>`; for other types → first 60 chars of `json.dumps()`.
- [x] If blob_dir missing or events.jsonl absent, print
      `events: (no event log for this dispatch)` and continue (exit 0).
- [x] If `--tail-events` not passed, behavior unchanged (T-1780 surface
      stays the same).

**3. Tests**
- [x] `tests/unit/test_outcome.py` extends with:
      - --tail-events shows last N event type lines
      - --tail-events 0 / negative rejected with exit 1
      - missing blob_dir → "no event log" notice, exit 0
      - missing events.jsonl in present blob_dir → same notice
      - malformed event lines skipped (do not crash)
      - terminal_event rendering still present alongside event tail
- [x] `python3 -m pytest tests/unit/test_outcome.py -v` exits 0.
- [x] No regression: arc-suite green.

### Human

(Mechanical / deterministic — no Human ACs.)

## Verification

python3 -m pytest tests/unit/test_outcome.py -v

## Recommendation

**Recommendation:** GO — closes manual `tail` step in dispatch forensics.

**Rationale:** When a dispatch fails, the operator's first instinct is "what events fired before the error?" Today that requires opening `<blob_dir>/events.jsonl` manually. `--tail-events N` makes it a single CLI call. The flag is opt-in (no default-behavior change for legacy callers). Format is intentionally terse — full JSON is one `cat` away, but the type+key-summary view answers "did the model emit content then error, or did it never produce any output?" without needing to look.

**Evidence:**
- `lib/outcome.py:cmd_read` — `--tail-events` branch.
- `tests/unit/test_outcome.py` — 6 new T-1783 tests.
- Combined regression: arc-suite green.

**Headline mechanic:** `bin/fw outcome read <id> --tail-events 5` prints the 5 most recent events with type + key-field summary. Forensics is one command.

## Evolution

### 2026-05-11 — terse summary, not full JSON dump

- **What changed:** First sketch printed each event as full `json.dumps(event)` per line. That's noisy for ollama-loop where each event is 200+ chars. Switched to type-summary: `· <type> (key=value, ...)`. For deeper inspection, the user can still `cat <blob_dir>/events.jsonl`.
- **Plan impact:** Branch on event["type"] for key-summary; fallback to truncated json for unknown types. Tests pin all three branches.
- **Triggered:** None.

## Decisions

## Updates

### 2026-05-11T09:20:00Z — task-created
- **Action:** Created task; arc-tagged orchestrator-rethink
- **Context:** Forensics depth pair to T-1780 (which surfaces terminal context)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-604a38ea
- **Timestamp:** 2026-06-02T14:59:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-13T21:08:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
