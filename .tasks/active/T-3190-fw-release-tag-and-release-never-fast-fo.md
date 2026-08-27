---
id: T-3190
name: "fw release tag-and-release never fast-forwards master — the release train has
  no engine"
description: >
  fw release tag-and-release never fast-forwards master — the release train has no
  engine

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-08-27T07:26:00Z
last_update: '2026-08-27T07:30:17Z'
date_finished:
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
  - ts: '2026-08-27T07:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=210,acs=12)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T07:30:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3190: fw release tag-and-release never fast-forwards master — the release train has no engine

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] G-096 registered in `.context/project/concerns.yaml` before the fix lands, with `follow_up_task: T-3190`
- [x] `release_tag_and_release` fast-forwards `master` to the dev branch as part of a release
- [x] The fast-forward is checked for cleanliness BEFORE the tag is pushed — a release that cannot advance master must not leave a published tag behind
- [x] A non-clean fast-forward (master ahead, or diverged) REFUSES the release with a named reason, rather than tagging and reporting success
- [x] `--dry-run` reports the master fast-forward it would perform, and mutates nothing
- [x] The release path does not weaken, scope, or bypass the T-2394 master-guard — it uses the fast-forward transition the guard already permits
- [x] Test suite `tests/unit/t3190_release_master_ff.bats` covers: happy-path FF, refusal on divergence, refusal on master-ahead, no-tag-on-refusal, and dry-run purity
- [x] Every silent-pass assertion is paired with a firing control leg over the same fixture (the T-3187 discipline — silence is not evidence)
- [x] Mutation-tested: removing the FF leg, and removing the pre-tag ordering guard, each redden only their intended tests
- [x] A local advance that reaches NO remote rolls back both the branch and the tag — the local ref moving is not the release
- [x] CLAUDE.md §Release-Train Branch Model's release claim matches what the code actually does

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

bats tests/unit/t3190_release_master_ff.bats > /tmp/.t3190-bats 2>&1 && grep -q "^ok 18" /tmp/.t3190-bats
bash -n lib/release.sh
grep -q "release_ff_state" lib/release.sh
grep -q "REFUSING to release" lib/release.sh
grep -q "reached no remote" lib/release.sh
python3 tools/bats-dead-negation-lint.py tests/unit/t3190_release_master_ff.bats > /tmp/.t3190-lint 2>&1 && grep -q "dead 0" /tmp/.t3190-lint
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/concerns.yaml'))['concerns']; assert any(g.get('id')=='G-096' and g.get('follow_up_task')=='T-3190' for g in d)"
grep -q "fast-forwards \`master\` and cuts the tag" CLAUDE.md
bin/fw release tag-and-release --dry-run > /tmp/.t3190-dry 2>&1 && grep -q "would fast-forward master" /tmp/.t3190-dry
