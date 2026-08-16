---
id: T-2189
name: "Inception recalibration Slice 3: estimator workflow_type=inception branch +
  040 scoring exception"
description: >
  T-2186 Slice 3. Modify agents/termlink/bvp-estimator/estimator.py to detect workflow_type:
  build inception and compute the VoI composite (reach + uncertainty + cost_of_wrong)
  instead of D1-D4+F-* mechanism rubrics. Add inception-scoring-exception section
  to policy/value-drivers.yaml (v3+) documenting the override. The composite weights
  live in 040 (single source of truth per IW-6). Verification: estimator branch present,
  value-drivers.yaml carries the new section, fw bvp rank emits inception-flagged
  rows, unit test pins composite math, existing build-task scoring unchanged (regression
  guard).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [inception, estimator, bvp, T-2186-slice, value-drivers]
components: []
related_tasks: [T-2186, T-2187]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:04:03Z
last_update: '2026-08-16T22:24:56Z'
date_finished: 2026-06-03T05:52:27Z
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
bvp_scores_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-03T05:48:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:56Z'
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
cost_estimate_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2189: Inception recalibration Slice 3: estimator workflow_type=inception branch + 040 scoring exception

## Context

The estimator's D1-D4 + F-* mechanism rubrics fit build-shaped work but evaluate inceptions incorrectly: an inception's `components:` is empty by definition (the build doesn't exist yet), so blast_radius is always 0 and cost looks artificially cheap. T-2188 shipped `target_blast_radius` (int 0..9) and `voi_score` (float 0..1) on inception frontmatter; T-2189 wires the estimator to use them. Cost side: `score_blast_radius` prefers `target_blast_radius` when `workflow_type: inception`. Value side: a single VoI-derived score replaces D1-D4 per-driver scoring for inceptions (the operator's `voi_score` IS the composite). Build/refactor/test/decommission scoring is unchanged.

## Acceptance Criteria

### Agent
- [x] `score_blast_radius()` in `agents/termlink/bvp-estimator/estimator.py` checks `workflow_type: inception` and prefers `target_blast_radius` (int 0..9, clamped) over `components` count. Falls back to the existing component-count logic when the field is missing/malformed (grandfathered). Smoke: inception tbr=7 → 7; inception no-tbr → 0 fallback; build 3-components → 3 unchanged.
- [x] New helper `_score_inception_voi()` returns `(score, evidence)` derived from `voi_score` (0..1 → 0..5 scaled, round). Missing or malformed `voi_score` returns neutral mid-score (2) with evidence string naming the fallback reason. Smoke: 0.9→4, 0.1→0, missing→2, malformed→2, 1.5 clamped→5.
- [x] `estimate_task()` branches on `workflow_type: inception`: instead of routing each driver to its D-handler, it routes ALL driver IDs (D1-D4 + free drivers) through `_score_inception_voi`. Build/refactor/test/etc. paths are unchanged (regression guard).
- [x] `policy/value-drivers.yaml` carries a new `inception_scoring_exception:` top-level section documenting (1) the cost substitution (target_blast_radius), (2) the value substitution (voi-derived for all drivers), (3) source-of-truth pointer to 050-Inceptions.md §Scoring Exception. YAML parses cleanly; keys: enabled, cost_substitution, value_substitution, source_of_truth, estimator_ref.
- [x] Unit test `tests/unit/test_estimator_inception.py` pins: inception with voi=0.9 ranks higher than inception with voi=0.1 on the same drivers; target_blast_radius substitution applies; missing fields fall back gracefully; build-task scoring path is byte-identical pre/post (regression). 13/13 PASS. Regression: existing `test_bvp_estimator.py` 43/43 PASS unchanged.
- [x] Reviewer agent self-scan (`bin/fw reviewer T-2189`) returns Overall: PASS (scan R-ad932262, 2026-06-03T05:51:38Z, findings: none).

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_estimator_inception.py -q
grep -q "_score_inception_voi" agents/termlink/bvp-estimator/estimator.py
grep -q "target_blast_radius" agents/termlink/bvp-estimator/estimator.py
grep -q "inception_scoring_exception" policy/value-drivers.yaml
out=$(bin/fw reviewer T-2189 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-03 — voi_score IS the composite (no reach/uncertainty/cost_of_wrong split)
- **What changed:** Original spec called for a VoI composite of `reach + uncertainty + cost_of_wrong`. Re-reading T-2188 (the schema slice that shipped), `voi_score` is already declared as the operator-synthesised composite (0..1) — the three components are conceptual sub-axes, not separate fields. Decomposing them at the estimator layer would either (a) require the operator to enter three numbers (more frontmatter, more cognitive load) or (b) require the estimator to invent values for them from body-grepping (sub-axis hallucination). Simpler and more honest: use voi_score as filed.
- **Plan impact:** Single helper `_score_inception_voi` rather than three. Policy section names the composite without enforcing its decomposition.
- **Triggered:** None — kept slice scoped. Sub-axis decomposition is a future refinement if VoI calibration becomes the bottleneck.

### 2026-06-03 — same voi-derived score for ALL drivers (uniform routing)
- **What changed:** Initial sketch had `_score_inception_voi` only replace D1-D4; free drivers would still flow through their own handlers. That would mean an inception with high voi could score 4 on D1-D4 but 0 on F-CUSTOM if the body lacked custom-driver signals. The mixed shape misrepresents inception rank — the value of resolving the question is the same regardless of which driver lens reads it.
- **Plan impact:** `estimate_task` branches at the top: if `is_inception`, every driver_id (D1-D4 AND free drivers) routes through `_score_inception_voi`. Build/refactor/etc. unchanged.
- **Triggered:** None.

<!-- Evolution closed.
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

### 2026-06-02T22:04:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2189-inception-recalibration-slice-3-estimato.md
- **Context:** Initial task creation

### 2026-06-03T05:47:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5b4ef802
- **Timestamp:** 2026-06-03T05:52:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-03T05:52:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
