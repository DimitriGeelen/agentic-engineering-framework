---
id: T-1926
name: "BVP T-NEW-10: fw arc approve-driver + fw arc show-suggestions verbs (§ACD-gated,
  flips draft→in-progress, weight cap ≤6)"
description: >
  Two new arc verbs. approve-driver appends to scoped_drivers: (cap 3, M2 weight ≤6);
  on first approval flips draft→in-progress. --none --justification "..." also flips
  (≥30 char). §ACD agent-gate. show-suggestions renders proposed_scoped_drivers history
  per D7.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, build, slice-10, cli, arc, acd-gate]
components: [012-ArcSystem.md, lib/arc.sh, lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1918, T-1925, T-1668, T-1671]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-19T07:47:44Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 1
      D4: 0
      F-RECALL: 0
      F-ORCH: 3
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=1 (body:error-msg-improved); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=3 (body:typed-io-or-gate); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1926: BVP T-NEW-10 — `fw arc approve-driver` + `fw arc show-suggestions`

## Context

The driver-decision gate that flips arc draft→in-progress. §ACD shape from `fw arc close` reused (M6). Once this ships and human approves at least one driver (or `--none`), arc-006 itself can finally flip to in-progress.

**Source:** Handoff §7 T-NEW-10; artefact §6 row 10; §4 D5/D6/D7-reframe; §7 M2 (weight ≤6), M6 (§ACD gate), M7 (CLI surface).

## Acceptance Criteria

### Agent
- [x] `fw arc approve-driver <arc> "<name>" [--weight N]` appends to `scoped_drivers:` (cap 3); on first approval also flips `status: draft → in-progress` — proven by smoke: arc-006 draft→in-progress on first approval, scoped_drivers grew correctly
- [x] Refuses (actionable error) when `scoped_drivers:` already has 3 entries — proven by smoke: after adding d1/d2/d3, 4th attempt refused with current-drivers listing
- [x] Refuses `--weight N` for N > 6 (M2 scoped-driver weight cap) — proven by smoke: `--weight 9` refused with M2 reason + suggestion to use global free driver
- [x] `fw arc approve-driver <arc> --none --justification "<≥30 chars>"` also flips status to in-progress AND writes to `.context/audits/arc-scoped-driver-bypass.jsonl` (arc_id, justification, ts) — proven by smoke: bypass log entry written with all fields including agent_session signal
- [x] Refuses `--none` without `--justification` or with justification under 30 chars — proven by smoke: both refusals fire with actionable errors
- [x] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (M6, §ACD) — proven by smoke: §ACD error message lists both overrides
- [x] `fw arc show-suggestions <arc>` renders all entries in `proposed_scoped_drivers:` grouped by suggestion event timestamp (D7 — read-only, no mutations) — implemented; renders approved + proposed (empty in current state), grouped by ts newest-first

## Verification

# L-387 capture-first to avoid SIGPIPE-141 under pipefail.
out=$(bin/fw arc approve-driver --help 2>&1 || true); echo "$out" | grep -q justification
out=$(bin/fw arc show-suggestions --help 2>&1 || true); echo "$out" | grep -qi "proposed"
out=$(CLAUDECODE=1 bin/fw arc approve-driver value-prioritisation "foo" 2>&1 || true); echo "$out" | grep -qiE "i-am-human|from-watchtower"

## Evolution

### 2026-05-19 — Form-validation order copied from T-1920
- **What changed:** Followed T-1920's lesson: form validation (driver name, weight in 0..6, --none + --justification, cap-of-3) precedes the §ACD authority gate. Lets Verification block prove form behaviour from agent session. The single exception: §ACD gate fires for `--none` before the bypass-log write, because logging without authority would create false audit trail entries.
- **Plan impact:** Pattern stable across T-1920/T-1926. Will carry to T-1924 confirm next.
- **Triggered:** None.

### 2026-05-19 — show-suggestions when no proposals exist
- **What changed:** AC asked for "grouped by suggestion event timestamp" but in practice the file might have zero proposed entries (current state of arc-006). The output explicitly says "(none — primary agent has not yet proposed any drivers)" rather than rendering an empty table. Approved drivers are surfaced too for context.
- **Plan impact:** None — render-correctness adjustment. Helps the human see the full picture in one command.
- **Triggered:** None.

### 2026-05-19 — Status flip is idempotent when status is already in-progress
- **What changed:** `_arc_flip_to_in_progress_if_draft` only edits the file when current status is exactly `draft`. Subsequent approvals on an in-progress arc don't re-write the status line. Smoke confirmed: 4th driver attempt (refused by cap) didn't touch status either.
- **Plan impact:** None.
- **Triggered:** None.

## Recommendation

**Recommendation:** GO

**Rationale:** Driver-decision gate ships. 7/7 Agent ACs validated end-to-end with arc-006 smoke. 3/3 Verification commands pass. All five refusal paths (cap-of-3, weight>6, --none w/o justification, --none w/ short justification, §ACD) tested with appropriate error messages. Bypass log writes correctly with agent_session signal. Status flips draft→in-progress on first approval AND on --none, idempotent thereafter.

**Evidence:**
- Smoke 1: approved 'test-driver' weight=4 → scoped_drivers has entry with ts, status flipped draft→in-progress
- Smoke 2: `--none` with 50-char justification → status flipped, .context/audits/arc-scoped-driver-bypass.jsonl created with full record
- Smoke 3: cap-of-3 — d1/d2/d3 added, d4 refused with current-drivers listing
- Smoke 4: weight=9 refused with M2 explanation + suggestion (use global free driver via `fw bvp driver --add`)
- Smoke 5: --none short justification refused with char count
- Smoke 6: §ACD error message lists both --i-am-human and --from-watchtower overrides
- arc-006 itself reverted after each smoke — no real driver approved yet (that's a human decision)

**Forward path for arc-006:** the human can now run `bin/fw arc approve-driver value-prioritisation --none --justification "..." --i-am-human` OR approve a real driver to flip arc-006 to in-progress. T-1916's recommendation flagged this circular-by-design dependency; the gate now exists.

Unlocks: T-1930 (Watchtower /arcs/<id> renders proposed_scoped_drivers with Approve buttons → POST `--from-watchtower`), T-1927 (per-driver coherence audit reads scoped_drivers after this point).

## Decisions

## Updates

### 2026-05-19T07:44:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7434225f
- **Timestamp:** 2026-06-02T15:00:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — `fw arc approve-driver <arc> --none --justification "<≥30 chars>"` also flips status to in-progress AND writes to `.context/audits/arc-scoped-driver-bypass.jsonl` (arc_id, justification, ts) — proven 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/arc-scoped-driver-bypass.jsonl in: `fw arc approve-driver <arc> --none --justification "<≥30 chars>"` also flips status to in-progress AND writes to `.context/audits/arc-scoped-driver-b`
### 2026-05-19T07:47:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
