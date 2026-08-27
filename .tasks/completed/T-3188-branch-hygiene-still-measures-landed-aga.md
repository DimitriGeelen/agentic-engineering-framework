---
id: T-3188
name: "Branch hygiene still measures 'landed' against master, which now lags by design"
description: >
  lib/branch-hygiene.sh resolves target=origin/master and derives merged-undeleted
  / behind-threshold / remote-contained from it. Under T-3185's release train master
  deliberately lags bleeding-edge between releases, so a branch already merged into
  bleeding-edge is no longer reported as merged-undeleted and lingers uncollected.
  'Landed' now means 'in the dev branch', not 'in master'. Not fixed in T-3187 because
  changing target semantics has blast radius across every finding class and deserves
  its own test pass.

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [lib/branch-hygiene.sh, tests/unit/t3187_branch_identity_guard.bats]
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
created: 2026-08-26T22:42:00Z
last_update: 2026-08-27T08:04:41Z
date_finished: 2026-08-27T08:04:41Z
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
  - ts: '2026-08-26T22:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:refactor); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T22:45:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3188: Branch hygiene still measures 'landed' against master, which now lags by design

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw_branch_hygiene` judges "landed" against the dev branch (`origin/bleeding-edge`, then local) when one exists, falling back to master for repos that have no dev branch
- [x] `fw_branch_divergence` measures the checkout against the dev branch, and is SILENT on the dev branch itself — the handover must stay neutral on a correct checkout
- [x] The dev branch is never itself reported as unlanded or stale; it is the trunk, not a feature branch
- [x] `master` lagging the dev branch between releases produces NO finding — that lag is the release train's product, not drift
- [x] CONTROL LEG: a genuinely unlanded feature branch still fires, over the same fixture, so "quiet about master" is not "quiet about everything"
- [x] Fallback preserved: a repo with no dev branch behaves exactly as before (master-only consumers are unaffected)
- [x] `FW_DEV_BRANCH` overrides the dev branch name here too, matching the T-3187 guard rather than inventing a second knob
- [x] Tests in `tests/unit/t3188_hygiene_release_train.bats`, every silent assertion paired with a firing one
- [x] Mutation-tested: reverting the target back to master reddens only the release-train tests, not the fallback ones
- [x] No `! cmd` assertions in dead position — `tools/bats-dead-negation-lint.py` reports clean (L-651)

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

## Scope fence and the blocked leg

**In scope, and done:** the measurement target in `lib/branch-hygiene.sh`.
`fw_branch_hygiene` and `fw_branch_divergence` now judge against the dev branch
(`origin/bleeding-edge` -> local -> master fallback), the dev branch is excluded
from the unlanded scan, and `FW_DEV_BRANCH` is the single knob shared with the
T-3187 identity guard.

**Deliberately NOT in scope - the remediation TEXT.** The findings are now
measured correctly, but the advice printed alongside them still says
`git merge origin/master`:

- `bin/fw:3527` - doctor's FORK mitigation line
- `agents/audit/audit.sh:2470-2473` - audit's fork mitigation
- `agents/handover/handover.sh:446-450` - the handover MERGEBACK_NUDGE

Under the release train that advice is actively wrong: merging `origin/master`
into a live branch between releases pulls an OLDER tree. It should name the dev
branch.

**Why it is not fixed here:** `bin/fw` and `agents/audit/audit.sh` are both held
dirty by another session's uncommitted T-3127 work. Editing them would either
commit that session's half-finished changes or force a conflict. Same blocker as
T-3186. Filed as T-3194.

**Also deferred:** `lib/branch-hygiene.sh` go-live routing (T-100196) still frames
go-live as merging master into a branch. Under the release train the direction
inverts. That is a design question in the T-3186 family, not a string fix.

## Verification

bats tests/unit/t3188_hygiene_release_train.bats > /tmp/.t3188-bats 2>&1 && grep -q "^ok 11" /tmp/.t3188-bats
bats tests/unit/t3187_branch_identity_guard.bats > /tmp/.t3188-b2 2>&1 && grep -q "^ok 10" /tmp/.t3188-b2
bats tests/unit/t100143_branch_hygiene.bats > /tmp/.t3188-b3 2>&1 && grep -q "^ok 21" /tmp/.t3188-b3
bash -n lib/branch-hygiene.sh
grep -q "FW_DEV_BRANCH" lib/branch-hygiene.sh
python3 tools/bats-dead-negation-lint.py tests/unit/t3188_hygiene_release_train.bats > /tmp/.t3188-lint 2>&1 && grep -q "dead 0" /tmp/.t3188-lint

## Reviewer Verdict (v1.5)

- **Scan ID:** R-521c773e
- **Timestamp:** 2026-08-27T08:04:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-27T08:04:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
