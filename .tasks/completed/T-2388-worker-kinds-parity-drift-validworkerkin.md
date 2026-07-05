---
id: T-2388
name: "Worker-kinds parity drift: VALID_WORKER_KINDS literal in bin/fw vs lib/resolver.py"
description: >
  Bug-hunt unit suite found 2 failures in tests/unit/worker_kinds_parity.bats: #2402
  (VALID_WORKER_KINDS literal not found in bin/fw at expected grep shape) + #2404
  (bin/fw set != resolver.py set, source-of-truth check). Either a real parity drift
  between the two worker-kind definitions or a stale test after a bin/fw refactor.
  Classify drift-vs-stale-test, then fix the source-of-truth or the test.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, governance, parity, dispatch]
components: [bin/fw]
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
created: 2026-06-14T01:02:37Z
last_update: 2026-07-05T00:12:40Z
date_finished: 2026-07-05T00:12:40Z
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
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
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
  - ts: '2026-07-03T14:00:05Z'
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
---

# T-2388: Worker-kinds parity drift: VALID_WORKER_KINDS literal in bin/fw vs lib/resolver.py

## Context

Found by the background bug-hunt unit suite (session 77ac04c8, 2026-06-14). 2 of 2410 tests
failed in `tests/unit/worker_kinds_parity.bats`:
- **#2402** "parity literal exists at expected location in bin/fw" — `grep -E "VALID_WORKER_KINDS\s*=\s*\{" bin/fw` (test line 68) failed → the literal isn't in bin/fw in the expected shape.
- **#2404** "parity literal in both files is identical (source-of-truth check)" — `[ "$fw_set" = "$resolver_set" ]` (test line 91) failed → the worker-kind sets in bin/fw and lib/resolver.py differ.

(#2401 "doctor reports WARN when bin/fw set differs from resolver" and #2403 "literal exists in
lib/resolver.py" PASS — so resolver.py is fine and doctor's drift WARN works; the gap is bin/fw.)

This is a **hypothesis to investigate, not a pre-concluded RCA** (per
feedback_remediation_plans_are_hypotheses): either (a) a real source-of-truth drift between
bin/fw and resolver.py worker-kind sets (dispatch correctness risk), or (b) a stale test after
a bin/fw refactor that moved/reshaped the `VALID_WORKER_KINDS` literal.

## Acceptance Criteria

### Agent
- [x] Classify (a) real drift vs (b) stale test: locate the worker-kind definition in bin/fw, compare its set to lib/resolver.py, and check git history for a bin/fw refactor that reshaped the literal
- [x] If real drift: reconcile to a single source of truth (the set both must share); if stale test: update the test's grep/extraction to match bin/fw's current shape
- [x] `bats tests/unit/worker_kinds_parity.bats` green; `fw doctor` worker-kinds parity line green
- [x] RCA filled; reviewer PASS

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

# Origin-based checks (MAIN's branch lags origin/master where this lands).
git show origin/master:tests/unit/worker_kinds_parity.bats > /tmp/.t2388-bats && grep -q "post-T-1946 shape" /tmp/.t2388-bats
! grep -q "expected location in bin/fw" /tmp/.t2388-bats
python3 lib/worker_kinds_parity.py lib > /tmp/.t2388-parity && grep -q "OK|" /tmp/.t2388-parity
git show origin/master:lib/resolver.py > /tmp/.t2388-resolver && grep -q "VALID_WORKER_KINDS = {" /tmp/.t2388-resolver
git show origin/master:lib/workflow_lint.py > /tmp/.t2388-lint && grep -q "VALID_WORKER_KINDS = {" /tmp/.t2388-lint

## RCA

**Symptom:** 2 of 7 tests in `tests/unit/worker_kinds_parity.bats` failed (background bug-hunt, session 77ac04c8): the grep for a `VALID_WORKER_KINDS = {...}` literal in `bin/fw` found nothing, and the bin/fw-vs-resolver set comparison returned empty-vs-populated.

**Root cause:** classification **(b) stale test** — T-1946 (commit 307aafefd) extracted bin/fw's inline worker-kinds parity heredoc to `lib/worker_kinds_parity.py` per L-332/L-408, removing the literal from bin/fw by design. The real sources are `lib/resolver.py` and `lib/workflow_lint.py` (both `{"Task", "TermLink", "pi", "ollama-loop"}`, parity module reports OK). No dispatch-correctness drift existed.

**Why structurally allowed:** the T-1946 refactor moved the source-of-truth location but did not update the T-1735 pin tests that encoded the OLD location — the test suite was not run as part of that task's Verification (its gate covered the new module, not the sibling pins). Producer/consumer split within the test corpus: the refactor shipped, the pins lagged.

**Prevention:** tests now pin the post-T-1946 shape explicitly (literal in workflow_lint + resolver, bin/fw delegates to the parity module) with a comment naming the refactor, so the next relocation fails with a message pointing at the delegation contract rather than a bare grep miss.

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

### 2026-06-14T01:02:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2388-worker-kinds-parity-drift-validworkerkin.md
- **Context:** Initial task creation

### 2026-07-04T23:58:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-914fbd33
- **Timestamp:** 2026-07-05T00:12:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-05T00:12:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
