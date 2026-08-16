---
id: T-2409
name: "T-1820 v2 — investigate why user-facing CLI doesn't fire inbox.queued on no-consumer
  deposit"
description: >
  Spin-out from T-1820 AC #3 partial-ship. T-1636 build landed: integration test mirror_inbox_deposit_with()
  calls aggregator().inject() correctly and fires inbox.queued; both unit tests pass.
  But two user-facing CLI trigger attempts (file send to offline target, channel post
  with kill-9'd member) did NOT fire inbox.queued, despite the framework subscriber
  polling cleanly. Scope: (a) trace which user-facing CLI paths call mirror_inbox_deposit_with()
  vs an alternative deposit path that bypasses the new emit; (b) reproduce a CLI flow
  that DOES fire the event; (c) extend integration test to cover the CLI surface,
  not just the inner crate function. Substrate ships; this closes the demo loop for
  arc-003.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-15T17:52:53Z
last_update: '2026-08-16T22:25:05Z'
date_finished: 2026-07-05T09:59:07Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-07-02T13:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-02T13:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-03T14:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2409: T-1820 v2 — investigate why user-facing CLI doesn't fire inbox.queued on no-consumer deposit

## Context

Investigation of a TermLink-crate behavior gap (T-1820 AC#3 partial-ship): the
inner function `mirror_inbox_deposit_with()` fires `inbox.queued` (proven by
unit + integration tests), but two user-facing CLI flows (file send to offline
target, channel post with kill-9'd member) did not fire the event. The code
under investigation lives in `/opt/termlink` — outside this project's boundary
(T-559), and the fix homes there (§Gap Homing, T-1333). This task therefore
coordinates: dispatch the investigation into a worker rooted at /opt/termlink,
collect findings, and ensure follow-up is filed where the fix lives.

## Acceptance Criteria

### Agent
- [x] Investigation dispatched to /opt/termlink (TermLink worker in the target
      project's own context, per T-559 boundary rule); findings collected via
      fw bus or a report file in this repo under docs/reports/T-2409-*.md
- [x] Findings answer scope (a): which user-facing CLI deposit paths call
      mirror_inbox_deposit_with() and which take a bypass path that skips the
      inbox.queued emit (file:line references into the termlink crates)
- [x] Findings answer scope (b): a CLI flow that DOES fire inbox.queued is
      reproduced, OR the gap is confirmed with a stated root cause
- [x] Follow-up homed where the fix lives: termlink-side task/pickup reference
      recorded in this task's Updates (scope (c) integration-test extension is
      termlink-repo work, not AEF work)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

grep -q "remote.rs:1750" docs/reports/T-2409-inbox-queued-cli-gap-summary.md
grep -q "T-2363" docs/reports/T-2409-inbox-queued-cli-gap-summary.md
grep -q "channel.rs:748" docs/reports/T-2409-inbox-queued-cli-gap-summary.md

## RCA

- **Symptom:** framework subscriber long-polling inbox.queued saw nothing on two user-facing CLI "no-consumer deposit" flows (T-1820 AC#3 partial-ship).
- **Root cause:** (1) termlink `remote send-file` legacy fallback calls RPC `event.emit` (no hub handler) instead of `event.emit_to` → SESSION_NOT_FOUND without deposit (remote.rs:1750); (2) channel-post-to-killed-member expectation was a design mismatch — the hub has no membership registry.
- **Why structurally allowed:** T-1636's integration test covered the inner crate function, not the CLI surface; two independent emit sites (T-1636 legacy, T-1637 inline) evolved separately so a CLI path could miss both untested.
- **Prevention:** termlink T-2363 (fix + CLI-surface integration test on two-node hub harness); topology documented in docs/reports/T-2409-inbox-queued-cli-gap-summary.md + /opt/termlink/docs/reports/T-2409-inbox-queued-cli-gap.md.


## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-15T17:52:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2409-t-1820-v2--investigate-why-user-facing-c.md
- **Context:** Initial task creation

### 2026-07-05T00:12:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-05T10:20:00Z — investigation-complete [worker t2409-inbox-gap]
- **Findings:** summary at docs/reports/T-2409-inbox-queued-cli-gap-summary.md; full report in /opt/termlink/docs/reports/ (T-2362 there)
- **Follow-up:** termlink T-2363 (remote send-file fallback wrong RPC fix + integration test) — fix homed per §Gap Homing

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4b5dd62d
- **Timestamp:** 2026-07-05T09:59:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-05T09:59:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
