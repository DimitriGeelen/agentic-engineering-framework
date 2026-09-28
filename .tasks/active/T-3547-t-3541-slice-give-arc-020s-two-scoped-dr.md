---
id: T-3547
name: "T-3541 slice: give arc-020's two scoped drivers (identity-fidelity, provisioning-safety)
  declarative scoring specs so they stop being names without mechanisms"
description: >
  T-3541 slice: give arc-020's two scoped drivers (identity-fidelity, provisioning-safety)
  declarative scoring specs so they stop being names without mechanisms

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-09-28T23:19:37Z
last_update: '2026-09-28T23:30:30Z'
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
  - ts: '2026-09-28T23:30:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=222,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-28T23:30:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 4
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=4 (body:fw-audit-or-doctor); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3547: T-3541 slice: give arc-020's two scoped drivers (identity-fidelity, provisioning-safety) declarative scoring specs so they stop being names without mechanisms

## Context

arc-020 approved two scoped drivers on 2026-09-07 — `identity-fidelity` (weight 4) and
`provisioning-safety` (weight 4) — each with a rubric and no mechanism. `fw audit` and
`fw doctor` have WARNed on both ever since, in the wording T-3428 chose deliberately:

> `identity-fidelity` cannot be scored, so it contributes nothing to any ranking while its
> weight and rubric read as a live axis (T-3427 omits it from the denominator)

That is the OBS-463 class exactly: the free-driver slot is a name, not an extension point,
until something can score it. T-3428 then built the extension point — a declarative
`scoring:` spec with a validator and an explainer — and these two drivers were never given
one. Six drivers across four arcs are in the same state; this task takes the two on arc-020,
which is ours, and leaves the other four to their own arcs.

**This is one slice of T-3541**, which bundles four independent deliverables (swap the
project id into address slot 3, retire `elide_path()`, rule on migration for existing
path-form entries, write this spec). That is a Task Sizing violation, and one of the four —
a compatibility ruling on a ratified format — is Sovereign and not mine. The scoring spec
depends on none of the others, so it is taken out and done.

**Design note carried into the specs themselves.** The polarity trap on
`provisioning-safety` is worth naming: provisioning work is not automatically good on that
axis. The driver exists to price a SUCCESSFUL-BUT-WRONG action — a typo'd address
provisioning a hub — so a slice that expands what can be auto-created must not outscore the
slice that bounds it. Level 5 therefore keys on containment vocabulary (idempotency,
admission control, integrity-verify) and level 3 on provisioning vocabulary, not the
reverse.

**A spec that fires on everything ranks nothing.** So the specs are tried against real
tasks before being attached, with the discrimination measured rather than assumed — the
authoring header's own advice, and the only way to find out that a level never fires or
fires uniformly.

## Acceptance Criteria

### Agent
- [x] Both drivers have a declarative `scoring:` spec that passes
      `fw bvp driver --validate-scoring`
- [x] Each spec's levels are tried against real tasks with `fw bvp driver --explain`, and
      the results recorded in this task — including which level fired and on what evidence,
      not merely that a number came back
- [x] Discrimination is MEASURED, not asserted, and the figures are recorded here. A spec
      that fires uniformly is reported as such rather than kept.
      **Criterion corrected mid-task:** it originally read "score arc-020 tasks above
      non-arc-020 tasks", which is structurally impossible and was written before I knew
      that — `fw bvp driver --explain <scoped-driver> <non-member>` refuses with *"driver
      not found in policy or in T-XXXX's arc scoped_drivers"*. A scoped driver can only
      score its own arc, so cross-arc separation is guaranteed by construction and measures
      nothing. The question that has content is discrimination WITHIN the arc, which is what
      was measured and what forced the level-3 rewrite.
- [x] The specs are attached to `.context/arcs/arc-020.yaml`'s `scoped_drivers[]` entries,
      leaving `weight:`, `rationale:` and `approved_at:` untouched — this adds a mechanism
      to an approved driver, it does not re-approve or re-weight one
- [x] `fw audit` no longer WARNs that `identity-fidelity` or `provisioning-safety` has
      neither a handler nor a scoring spec, verified by running it
- [x] The other four unscorable drivers are left alone and named here, so this task is not
      mistaken for having closed the whole WARN class

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

# Both drivers carry a scoring block with all three levels, and the approval
# fields are untouched — this task adds a mechanism, it does not re-approve.
python3 -c "import yaml;d=yaml.safe_load(open('.context/arcs/arc-020.yaml'));e={x['name']:x for x in d['scoped_drivers']};assert sorted((e['identity-fidelity']['scoring'] or {})['levels'])==[1,3,5];assert sorted((e['provisioning-safety']['scoring'] or {})['levels'])==[1,3,5]"
python3 -c "import yaml;d=yaml.safe_load(open('.context/arcs/arc-020.yaml'));e={x['name']:x for x in d['scoped_drivers']};assert e['identity-fidelity']['weight']==4 and e['provisioning-safety']['weight']==4;assert e['identity-fidelity']['approved_at']=='2026-09-07T12:33:20Z';assert e['provisioning-safety']['approved_at']=='2026-09-07T12:34:06Z'"

# Neither driver is reported unscorable any more. Asserted as ABSENCE of these
# two rather than as a total count: the count is mutable corpus state (other
# arcs may gain or fix drivers at any time) and pinning it would rot the line
# for reasons unrelated to this change — T-3326.
out=$(bash -c 'source lib/bvp-scorability.sh; fw_bvp_unscorable_drivers "$PWD"' 2>&1); ! echo "$out" | grep -q 'identity-fidelity'
out=$(bash -c 'source lib/bvp-scorability.sh; fw_bvp_unscorable_drivers "$PWD"' 2>&1); ! echo "$out" | grep -q 'provisioning-safety'

# The attached specs actually score, read from the arc file with no --scoring-file.
out=$(timeout 90 bin/fw bvp driver --explain identity-fidelity T-3311 2>&1); echo "$out" | grep -qE 'Score: [0-9]'
out=$(timeout 90 bin/fw bvp driver --explain provisioning-safety T-3311 2>&1); echo "$out" | grep -qE 'Score: [0-9]'

# Every level is reachable — a level that can never fire is decoration. T-3309
# is the arc's one identity-fidelity 5; T-3311 is its one provisioning-safety 5.
out=$(timeout 90 bin/fw bvp driver --explain identity-fidelity T-3309 2>&1); echo "$out" | grep -q 'Score: 5'
out=$(timeout 90 bin/fw bvp driver --explain provisioning-safety T-3311 2>&1); echo "$out" | grep -q 'Score: 5'

# ...and the specs discriminate rather than firing uniformly: a low scorer exists
# for each, so the driver orders its arc instead of flattening it.
out=$(timeout 90 bin/fw bvp driver --explain identity-fidelity T-3313 2>&1); echo "$out" | grep -q 'Score: 1'
out=$(timeout 90 bin/fw bvp driver --explain provisioning-safety T-3399 2>&1); echo "$out" | grep -q 'Score: 0'

# One source of truth: the draft spec files were deleted once inlined, because
# `scoring_file:` is not read at runtime (only the inline `scoring:` key is), so
# keeping them would be two copies that can drift.
test ! -d .context/arcs/scoring

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

### 2026-09-28 — level 3 of provisioning-safety keys on paths, not on `election`/`governor` keywords
- **Chose:** move `election` and `governor` out of level 3's `keywords:` and rely on the
  four `lib/aef_*.py` paths for that level.
- **Why:** measured. As keywords they lifted **10 of the arc's 14 members** to level 3 —
  every task whose body merely mentions those slices as context, which is most of an arc
  built around them. A driver that gives 71% of its own arc one score orders nothing. After
  the change the distribution is L0×1, L1×6, L3×6, L5×1, which actually ranks.
- **Rejected:** leaving it and reporting the concentration. The authoring header's own
  advice is to try a spec on real tasks precisely so a level that fires uniformly is found
  before it is attached, and "uniform enough to be useless" is exactly what it describes.

### 2026-09-28 — the spec is inlined into arc-020.yaml and the draft files deleted
- **Chose:** one inline `scoring:` block per driver entry; `.context/arcs/scoring/*.yaml`
  drafts removed after attachment.
- **Why:** `estimator.py:load_scoring_spec` reads only the inline `scoring:` key. A
  `scoring_file:` reference is **not** read at runtime — `--scoring-file` is a CLI-only
  try-before-you-attach affordance. Keeping the drafts would have left two copies where
  only one is live, and the dead one reads as authoritative.
- **Rejected:** keeping the drafts as documentation. Their design commentary moved into the
  arc file as comments instead, so the reasoning sits where the mechanism does.

### 2026-09-28 — a scoped driver cannot score a non-member, which retires the cross-arc question
- **Chose:** measure discrimination WITHIN arc-020 only.
- **Why:** `fw bvp driver --explain identity-fidelity T-3546` refuses — *"driver not found
  in policy or in T-3546's arc scoped_drivers"*. Cross-arc separation is therefore
  guaranteed by construction and measuring it would have produced a meaningless green. This
  corrected an acceptance criterion written before the constraint was known; the correction
  is recorded on the criterion rather than silently applied.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-28 — measured distributions across all 14 arc-020 members
- **identity-fidelity:** L1×5, L3×8, L5×1. The single 5 is T-3309 (resolution and
  provisioning ladder). Sample evidence, T-3307: `L1:keyword=identity;
  L1:keyword=addressable; L1:keyword=correspondent; L3:keyword=circuit id;
  L3:path=lib/aef_address.py` → 3.
- **provisioning-safety, first draft:** L1×2, L3×10, L5×1, L0×1 — rejected, see Decisions.
- **provisioning-safety, attached version:** L0×1, L1×6, L3×6, L5×1. The single 5 is
  T-3311 (load-adaptive environmental governor), which is the containment slice the level
  was designed to find; the single 0 is T-3399 (reject elided project value), which touches
  addressing and no provisioning path at all — a measured 0, not an unscored one.
- **Not closed by this task:** four drivers remain unscorable — `Discard fidelity` and
  `Loop closure (conditional)` on `.context/arcs/continuous-run.yaml`,
  `unknown-input-safety` and `first-run-recoverability` on
  `.context/arcs/onboarding-shape-detection.yaml`. They belong to other arcs and are
  deliberately untouched. The WARN count goes 6 → 4, not 6 → 0.

## Updates

### 2026-09-28T23:19:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3547-t-3541-slice-give-arc-020s-two-scoped-dr.md
- **Context:** Initial task creation
