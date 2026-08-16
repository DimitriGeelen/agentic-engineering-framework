---
id: T-1718
name: "Evolution-gate + vertical-slice discipline for inception → build transitions"
description: >
  Structural mechanism that makes spec-vs-build drift visible during build. Surfaced
  from T-1717 Phase 3 grill (Q4) — 'understanding of what we need and want evolves
  with the process of materialisation'. Adds (a) mandatory ## Evolution section in
  build tasks populated at slice boundaries; (b) update-task.sh gate refusing slice-progress
  with empty Evolution log (same shape as T-1550 RCA gate); (c) vertical-slice discipline
  — smallest end-to-end deliverable before parallel streams; (d) fw inception revise
  affordance for mid-build pivots without abandoning the task. Prerequisite for T-1717
  GO if approved. Sibling structural fix surfaced from T-1717 grill, not part of T-1717
  scope.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [structural-gate, T-1716-family, dogfood-prerequisite, §ACD-prevention]
components: [agents/task-create/update-task.sh, lib/evolution_log.sh, 
      tests/unit/evolution_log_gate.bats]
related_tasks: [T-1717, T-1550, T-1716, T-1671, T-1259, T-1260, G-062, G-066]
arc_id: embeddings-strategy
created: 2026-05-04T14:50:48Z
last_update: '2026-08-16T22:23:59Z'
date_finished: 2026-05-27T05:11:05Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 1
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=1 
      (body:error-msg-improved); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 1
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=1 
      (body:error-msg-improved); D4=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 1
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=1 
      (body:error-msg-improved); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 1
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=1 
      (body:error-msg-improved); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1718: Evolution-gate + vertical-slice discipline for inception → build transitions

## Context

Surfaced from T-1717 Phase 3 grill (Q4) — *"the understanding of what we
need and want, evolves with the process of materialisation"*. This task
ships the structural counter-pattern: build tasks must capture the
**evolution of understanding** during build (not just at end), making
spec-vs-build drift visible rather than silent. Same shape as T-1550
RCA gate (advisory CLAUDE.md text → structural enforcement).

**Slice 1 (this scope):** smallest end-to-end vertical that proves the
loop. Adds `## Evolution` section to default build template (opt-in
backward-compat), implements detection helper, wires gate into
`update-task.sh` for `--status work-completed` on tasks that already
have the section. `--skip-evolution` Tier-2 bypass exists.

**Slices 2+ (future):** mandatory mid-build entries at slice boundaries,
`fw inception revise` affordance, mandatory population on tasks that
declare `slices: N` in frontmatter.

See T-1717 grill artifact `docs/reports/T-1717-embeddings-strategy-grill.md`
§ "Q4 — *how to get adaptive guidance without rigidity*".

## Acceptance Criteria

### Agent (Slice 1)
- [x] **A1** `lib/evolution_log.sh` exists with `has_real_evolution_log()`
  + `find_arc_tasks_without_evolution_log()` (mirror of
  `lib/inception_recommendation.sh` from T-1716).
- [x] **A2** `## Evolution` section added to `.tasks/templates/default.md`
  build template with format hint comment block.
- [x] **A3** `agents/task-create/update-task.sh` extended with
  `check_evolution_log()` function. Fires on `--status work-completed`
  when task body already contains `## Evolution` heading. Refuses with
  actionable error if section is empty / template-only.
  `--skip-evolution` flag bypasses with logged Tier-2 entry.
- [x] **A4** Bats coverage in `tests/unit/evolution_log_gate.bats`:
  17/17 passing (helper unit tests + arc-task discovery + backward-compat
  no-op + non-arc / non-build skip).
- [x] **A5** Self-application: this task (T-1718) carries a populated
  `## Evolution` section. Eats own dogfood from day 1.
- [x] **A6** `lib/evolution_log.sh` registered in fabric
  (`.fabric/components/lib-evolution_log.yaml`).

### Human (Slice 1)
- [ ] [REVIEW] Confirm gate UX on a synthetic task is actionable, not
  punitive. Symmetric to T-1716 review.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1718`
  2. Observe gate fires on a synthetic build task with empty Evolution log
  3. Verify error message names the section, suggests fix, references T-1718
  **Expected:** Error message points to `## Evolution`, includes example
  format (a slice-boundary entry), references `--skip-evolution` bypass.
  **If not:** flag missing/confusing element; agent reworks.

## Verification

bats tests/unit/evolution_log_gate.bats
test -f lib/evolution_log.sh
grep -q "^## Evolution" .tasks/templates/default.md
grep -q "check_evolution_log" agents/task-create/update-task.sh
grep -q "T-1718" lib/evolution_log.sh

## Recommendation

**Recommendation:** GO — slice 1 (opt-in backward-compatible Evolution-log gate) shipped and self-applies on this task.

**Rationale:**
The gate makes spec-mutation visible rather than silent: any arc-tagged build task that mutates the inception's intended scope must record the delta in a `## Evolution` section before `--status work-completed` accepts close. T-1718 itself carries an Evolution log (A5 — self-application), proving the gate runs and doesn't deadlock its own closure. Backward-compatibility (gate fires only on tasks that already contain `## Evolution`) means the 38 in-flight tasks at slice ship-time were not retroactively blocked — the gate ratchets up as new tasks adopt the section.

**Evidence:**
- `lib/evolution_log.sh:has_real_evolution_log()` exists and is registered in fabric (A1, A6).
- `## Evolution` section landed in `.tasks/templates/default.md` (A2).
- `agents/task-create/update-task.sh` wired with `check_evolution_log` invocation (A3).
- `tests/unit/evolution_log_gate.bats` covers detect/refuse/accept paths (A4).
- This task's own `## Evolution` block (lines 113-127) records slice 1 kickoff — self-application proof (A5).

## Evolution

### 2026-05-04 — Slice 1 kickoff
- **Slice scope:** opt-in backward-compatible gate (fires only on tasks
  whose body already contains `## Evolution`). Avoids retroactively
  blocking 38 in-flight tasks.
- **Insight from T-1717 grill Q4:** rigidity ≠ structural enforcement.
  Structural enforcement of *recording the evolution* is the opposite
  of rigid — it forces the spec-mutation to be **visible** rather than
  silent.
- **Pattern source:** T-1716 (`lib/inception_recommendation.sh` +
  `update-task.sh` gate) is direct precedent. Mirror the exact shape:
  detection helper extracted to lib/, gate function in update-task.sh,
  bypass flag with logged Tier-2 entry, bats tests.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-05-04T14:50:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1718-evolution-gate--vertical-slice-disciplin.md
- **Context:** Initial task creation

### 2026-05-04T15:03:14Z — status-update [task-update-agent]
- **Change:** tags: +arc:embeddings-strategy

### 2026-05-04T15:19:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-09642f8c
- **Timestamp:** 2026-06-11T11:49:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-27T05:11:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
