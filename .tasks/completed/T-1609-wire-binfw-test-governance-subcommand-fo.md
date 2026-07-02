---
id: T-1609
name: "Wire bin/fw test governance subcommand for red-team harness"
description: >
  Wire bin/fw test governance subcommand for red-team harness

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-04-29T21:47:53Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T22:08:56Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1609: Wire bin/fw test governance subcommand for red-team harness

## Context

T-1601 inception design called for `bin/fw test governance` subcommand + audit cron integration. Phases 1-3 (T-1606/T-1607/T-1608) shipped the harness as `tests/governance/*.bats` (25 tests). Without a discoverable subcommand, the suite is invisible to operators and CI — only someone who already knows where to look will find it.

This task adds:
- `fw test governance` → runs `bats tests/governance/`
- `fw test all` → includes governance suite alongside unit/integration/web/playwright
- `fw test` usage line lists `governance` as an option

Audit cron integration is intentionally out of scope here — the suite is fast enough (<5s) to live in `fw test all` without needing its own scheduler entry. If governance regressions become a recurring class, a future task can wire it into pre-push or audit cron.

## Acceptance Criteria

### Agent
- [x] `fw test governance` exists and runs the 3 .bats files in tests/governance/
- [x] `fw test all` invokes the governance suite as a step
- [x] `fw test` (with no args, or invalid arg) usage line lists `governance`
- [x] `bats tests/governance/*.bats` passes 25/25 via the new subcommand
- [x] Existing `fw test unit`, `fw test all` paths still work (no regression — `bash -n bin/fw` clean, only added new case branch)

## Recommendation

- **Recommendation:** GO
- **Rationale:** Final wiring step of the T-1601 inception arc. The 25-test red-team harness is now discoverable via `fw test governance` and runs as part of `fw test all`. No new logic — just a case-branch addition matching the existing unit/integration shape.
- **Evidence:**
  - `fw test governance` → 25/25 pass
  - `fw test invalidarg` → usage line lists `governance` option
  - `bash -n bin/fw` → syntax clean
  - Edit pattern: 3 case-branch additions (governance subcommand, governance step in `all`, usage line entry)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification
bats tests/governance/
bin/fw test invalidarg 2>&1 | grep -q governance
bash -n bin/fw

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

### 2026-04-29T21:47:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1609-wire-binfw-test-governance-subcommand-fo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed7f79b9
- **Timestamp:** 2026-06-02T14:58:38Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw test invalidarg 2>&1 | grep -q governance`
### 2026-04-29T22:08:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
