---
id: T-2361
name: "BVP estimator dedicated handlers final batch — arc-005 feedback-loop-completeness
  + arc-006 estimator-fidelity (already approved)"
description: >
  BVP estimator dedicated handlers final batch — arc-005 feedback-loop-completeness
  + arc-006 estimator-fidelity (already approved)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, estimator, arc-005, arc-006, latent, final-batch]
components: [agents/termlink/bvp-estimator/estimator.py, 
      tests/unit/test_bvp_estimator.py]
related_tasks: [T-2356, T-2357, T-2358, T-2359, T-2360]
arc_id: parallel-execution-aef
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
created: 2026-06-12T23:58:25Z
last_update: '2026-08-16T22:25:03Z'
date_finished: 2026-06-13T00:03:07Z
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
  - ts: '2026-06-13T00:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-13T00:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 4
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-ORCH=4 
      (body:rubric-routable); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2361: BVP estimator dedicated handlers final batch — arc-005 feedback-loop-completeness + arc-006 estimator-fidelity (already approved)

## Context

Final batch in BVP driver implementation sequence this session. Two more handlers:

- **feedback-loop-completeness** (arc-005 inception-review-loop) — operator intent surviving the agent-handoff round-trip, chat-to-file gap closure. Distinct from D2 (Reliability) which covers framework-internal observability (no silent failures); this scores how much a task closes the gap between operator intent expressed in chat and that intent landing back in the next session. Antifragile arc-008 sibling shape.
- **estimator-fidelity** (arc-006 value-prioritisation) — **already APPROVED since 2026-05-21**. Currently activates via `score_free_driver` keyword fallback per T-2358. This task swaps that for a dedicated rubric-anchored handler. Distinct from D2 by measuring estimator-vs-human-confirmed agreement (v2-delta M3 semantic).

Same shape as T-2356 / T-2359 / T-2360 — handlers ship LATENT (or activate immediately for estimator-fidelity since arc-006 already has it approved).

## Acceptance Criteria

### Agent
- [x] `score_feedback_loop_completeness(fm, body, tags) -> tuple[int, list[str]]` added with full 6-level rubric: L5 new round-trip-fidelity primitive class (e.g. automated handover-completeness audit), L4 framework-level handover/session capture gate (e.g. PreCompact handover always emits, completion-percentage audit), L3 component-level handover content-quality test (e.g. handover Suggested First Action filled / Next Step populated test), L2 single handover-section fix with rationale, L1 incidental handover/feedback mention, L0 no signal
- [x] `score_estimator_fidelity(fm, body, tags) -> tuple[int, list[str]]` added with full 6-level rubric: L5 new estimator-fidelity primitive class (e.g. v2-delta auto-needs-split mechanism, structural drift detection), L4 framework-level estimator-fidelity audit (e.g. proposed-vs-confirmed delta audit gate at framework level), L3 component-level fidelity test or rubric refinement (e.g. new score_* handler + dedicated tests, this session's T-2356/T-2359/T-2360 pattern), L2 single rubric tweak with rationale, L1 incidental estimator/fidelity mention, L0 no signal
- [x] Both handlers registered in the `handlers` dict with canonical name-form keys: `"feedback-loop-completeness"`, `"estimator-fidelity"`
- [x] Each handler's docstring references T-2361 + the originating arc YAML rationale + states the LATENT-until-X invariant (or "already active for arc-006" for estimator-fidelity)
- [x] Test coverage: 6 per-level tests × 2 handlers = 12 + 2 dispatch + 2 non-registration = ≥ 16 new tests. All PASS, existing test suite green
- [x] bvp_estimator file ≥ 189 tests (was 173), wider BVP regression ≥ 271 (was 255)
- [x] Reviewer PASS on T-2361

### Human-omitted
<!-- All ACs agent-verifiable. -->

### Human-template
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

python3 -m pytest tests/unit/test_bvp_estimator.py -q > /tmp/.t2361-pytest.out 2>&1; grep -q "passed" /tmp/.t2361-pytest.out && ! grep -qE "failed|error" /tmp/.t2361-pytest.out
grep -q "def score_feedback_loop_completeness" agents/termlink/bvp-estimator/estimator.py
grep -q "def score_estimator_fidelity" agents/termlink/bvp-estimator/estimator.py
grep -q '"feedback-loop-completeness": score_feedback_loop_completeness' agents/termlink/bvp-estimator/estimator.py
grep -q '"estimator-fidelity": score_estimator_fidelity' agents/termlink/bvp-estimator/estimator.py
out=$(bin/fw reviewer T-2361 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-12 — L4 estimator-fidelity body tripped L5 due to "structural" keyword overlap

- **What changed:** My first L4 test body "Proposed-vs-confirmed delta audit gate at framework level ships; structural needs-split signal lands." matched L5 `structural (needs[- ]split|drift detection)` because the body contains "structural needs-split signal" — exactly the L5 phrase. Adjusted test body to use L4-only phrasing ("v2-delta audit gate fires on score divergence" — no "structural" qualifier). Rubric itself is correct: the L5 phrasing IS structural class-changing, the test body was inadvertently L5-tier.
- **Plan impact:** None — the L5 pattern is right; the test should match what L5 means in plain English. Sibling lesson to T-2360 evolution: when writing test bodies for L4, deliberately avoid L5 vocabulary.
- **Triggered:** None.

## Recommendation

**Recommendation:** GO

**Rationale:** Final batch closes the BVP dedicated-handler matrix this session. 7/7 Agent ACs verified: 2 dedicated handlers (feedback-loop-completeness arc-005 + estimator-fidelity arc-006) implemented with 6-level rubrics; both registered in handlers dict with canonical name-form keys; docstrings reference T-2361 + originating arc YAML + LATENT/already-approved invariant; 16 new tests (6 per-level × 2 + 2 dispatch + 2 latency); bvp_estimator file 189/189 (+16 over T-2360 baseline of 173); wider BVP regression net 271/271 (+16); reviewer R-21c5850a PASS, 0 findings.

**Notable:** `estimator-fidelity` is the ONLY dedicated handler this session that activates IMMEDIATELY — arc-006 already approved this scoped driver on 2026-05-21. Pre-T-2361 arc-006 member tasks scoring against estimator-fidelity fell through to `score_free_driver` keyword fallback. Post-T-2361 they get rubric-anchored 0-5 scoring. The other 9 dedicated handlers shipped this session (D-DISJOINT, D-WIRE-EVIDENCE, uncertainty-recognition, severity-likelihood-calibration, sovereignty-preservation, aesthetic-cohesion, render-fidelity, theme-portability, feedback-loop-completeness) remain LATENT until their respective arcs' proposed_scoped_drivers get operator approval.

**Evidence:**
- `agents/termlink/bvp-estimator/estimator.py` — two new score_* functions + handlers dict registration with T-2361 comment
- `tests/unit/test_bvp_estimator.py` — 16 new tests
- Reviewer verdict: R-21c5850a PASS, 0 findings
- Regression net: 271/271 BVP-related tests PASS

**Cumulative this session:** **10 dedicated arc-scoped handlers** (T-2356 × 2 + T-2359 × 3 + T-2360 × 3 + T-2361 × 2) + **1 dispatch wiring slice (T-2357)** + **1 name-form parity fix (T-2358)** = 12 BVP commits landing 271 regression tests + 6 reviewer PASS verdicts.

## Activation paths for the operator (single-click each on Watchtower)

| Arc | Driver(s) ready to activate | URL |
|-----|----------------------------|-----|
| arc-001 dispatch-safety | uncertainty-recognition, severity-likelihood-calibration | `/arcs/dispatch-safety` |
| arc-005 inception-review-loop | feedback-loop-completeness | `/arcs/inception-review-loop` |
| arc-006 value-prioritisation | sovereignty-preservation (estimator-fidelity already approved) | `/arcs/value-prioritisation` |
| arc-007 watchtower-redesign | aesthetic-cohesion, render-fidelity, theme-portability | `/arcs/watchtower-redesign` |
| arc-011 parallel-execution-aef | D-DISJOINT, D-WIRE-EVIDENCE | `/arcs/parallel-execution-aef` |

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

### 2026-06-12T23:58:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2361-bvp-estimator-dedicated-handlers-final-b.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9a1540a5
- **Timestamp:** 2026-06-13T00:03:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T00:03:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
