---
id: T-2359
name: "BVP estimator dedicated handlers batch — arc-001 uncertainty-recognition +
  severity-likelihood-calibration + arc-006 sovereignty-preservation (3 latent handlers)"
description: >
  BVP estimator dedicated handlers batch — arc-001 uncertainty-recognition + severity-likelihood-calibration
  + arc-006 sovereignty-preservation (3 latent handlers)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, estimator, arc-001, arc-006, latent, batch]
components: [agents/termlink/bvp-estimator/estimator.py, 
      tests/unit/test_bvp_estimator.py]
related_tasks: [T-2328, T-2356, T-2357, T-2358]
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
created: 2026-06-12T23:39:10Z
last_update: 2026-06-12T23:45:39Z
date_finished: 2026-06-12T23:45:39Z
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
  - ts: '2026-06-12T23:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-12T23:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 4
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=4 (body:rubric-routable); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2359: BVP estimator dedicated handlers batch — arc-001 uncertainty-recognition + severity-likelihood-calibration + arc-006 sovereignty-preservation (3 latent handlers)

## Context

Batch sibling of T-2328 V_* trio + T-2356 D-* pair. Three dedicated handlers for arc-001 (dispatch-safety) + arc-006 (value-prioritisation) proposed scoped drivers. All LATENT — activate when (a) operator approves the respective arc's `proposed_scoped_drivers` via Watchtower AND (b) tasks tagged with that arc dispatch through the merge path shipped in T-2357.

| Handler | Source arc | Driver name | Weight | Rationale anchor |
|---------|------------|-------------|--------|-----------------|
| `score_uncertainty_recognition` | arc-001 | uncertainty-recognition | 5 | dispatch-safety.yaml proposed_scoped_drivers — pause_requested / self-assessment / risk-policy preamble; worker-DECISION level distinct from D1/D2 framework level |
| `score_severity_likelihood_calibration` | arc-001 | severity-likelihood-calibration | 4 | dispatch-safety.yaml proposed_scoped_drivers — pause-trigger threshold calibration; false-positive vs false-negative rate; live audit vs retrospective "should-have-paused" classification |
| `score_sovereignty_preservation` | arc-006 | sovereignty-preservation | 5 | value-prioritisation.yaml proposed_scoped_drivers — §ACD-gate strengthening; fw bvp confirm robustness; Watchtower-only Sovereign verbs; --i-am-human / --from-watchtower bypass mechanism completeness (per L-399 / T-1890) |

Each handler ships with a full 6-level rubric (L0 no signal → L5 class-changing structural mechanism). All registered in the `handlers` dict alongside D1-D4 / F-RECALL / F-ORCH / V_* / F-AUTONOMY / D-DISJOINT / D-WIRE-EVIDENCE. Keys match exactly the canonical-name shape per T-2358 (lib/arc.sh:1258 writes `name:`).

## Acceptance Criteria

### Agent
- [x] `score_uncertainty_recognition(fm, body, tags) -> tuple[int, list[str]]` added to `agents/termlink/bvp-estimator/estimator.py` with full 6-level rubric: L5 new pause-detection class/mechanism (e.g. self-assessment scoring becomes a fw verb), L4 framework-level pause/risk gate (new hook or audit check), L3 component-level pause-detection helper/test, L2 single risk-policy preamble addition / threshold tweak, L1 incidental uncertainty mention, L0 no signal
- [x] `score_severity_likelihood_calibration(fm, body, tags) -> tuple[int, list[str]]` added with rubric: L5 new calibration mechanism class (e.g. live false-positive/negative auto-audit), L4 framework-level pause-rate audit / live calibration loop, L3 component-level threshold-tuning test / audit script, L2 single threshold adjustment with rationale, L1 incidental calibration mention, L0 no signal
- [x] `score_sovereignty_preservation(fm, body, tags) -> tuple[int, list[str]]` added with rubric: L5 new §ACD-gate primitive class (e.g. new Sovereign verb routing pattern), L4 framework-level §ACD gate / bypass-parity hook, L3 component-level Sovereign-verb test / bypass log assertion, L2 single --i-am-human / --from-watchtower wiring fix, L1 incidental sovereignty mention, L0 no signal
- [x] All three handlers registered in the `handlers` dict in `estimate_task()` with keys `"uncertainty-recognition"`, `"severity-likelihood-calibration"`, `"sovereignty-preservation"` (canonical name-form per T-2358)
- [x] Each handler's docstring references T-2359 + the originating arc YAML + the rationale anchor + states the LATENT-until-X invariant explicitly (mirrors T-2329 / T-2356 phrasing)
- [x] Test coverage: per-level test (0/1/2/3/4/5 for each handler = 18 per-level tests minimum) + dispatch-via-arc-scope test (3 dispatches showing each handler fires when its driver is in the arc's scoped_drivers and the task carries the arc's arc_id) + non-registration test (3 tests showing drivers absent when no arc context). Total ≥ 24 new tests
- [x] All new tests PASS; existing test suite green (bvp_estimator file ≥ 149, wider BVP regression ≥ 231)
- [x] Reviewer PASS on T-2359: `bin/fw reviewer T-2359 2>&1` returns `Overall: PASS` or `CONCERN`, no FAIL

### Human-omitted
<!-- All ACs agent-verifiable (backend Python, no UI / no operator judgment). Same shape as T-2328 / T-2356 sibling batches. -->

### Human-template
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
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

python3 -m pytest tests/unit/test_bvp_estimator.py -q > /tmp/.t2359-pytest.out 2>&1; grep -q "passed" /tmp/.t2359-pytest.out && ! grep -qE "failed|error" /tmp/.t2359-pytest.out
python3 -m pytest tests/unit/ -q -k "bvp or estimator" > /tmp/.t2359-wider.out 2>&1; grep -q "passed" /tmp/.t2359-wider.out && ! grep -qE "failed|error" /tmp/.t2359-wider.out
grep -q "def score_uncertainty_recognition" agents/termlink/bvp-estimator/estimator.py
grep -q "def score_severity_likelihood_calibration" agents/termlink/bvp-estimator/estimator.py
grep -q "def score_sovereignty_preservation" agents/termlink/bvp-estimator/estimator.py
grep -q '"uncertainty-recognition": score_uncertainty_recognition' agents/termlink/bvp-estimator/estimator.py
out=$(bin/fw reviewer T-2359 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-12 — calibration gate too strict on proximity requirement

- **What changed:** First test run had 4 failures in the calibration handler (single-adjustment, framework-audit-four, new-class-five, dispatch-via-arc-scope). Root cause: my `calibration_body` gate required `\bcalibrat\b.{0,30}(pause|threshold|risk-policy)` — proximity within 30 chars. Real test bodies (and likely real-world task bodies) have "calibration mechanism class — live false-positive auto-audit" where "calibration" and "threshold" are >30 chars apart. Same shape as T-2356 L2 narrative+command bound being too tight. Widened: standalone `\bcalibrat\b` mention is enough to enter the rubric; per-level patterns then sort it to L1-L5.
- **Plan impact:** Filing rubric was rigorous on what L2-L5 looked like but understated the L1-entry threshold. Sibling lesson to T-2356 evolution entries — when in doubt, gate liberally and let the per-level patterns do the heavy work.
- **Triggered:** No follow-on; fix folded into slice.

### 2026-06-12 — three handlers, one batch, T-2328-pattern preserved

- **What changed:** Originally considered shipping each handler as its own slice. T-2328 V_* trio set the precedent for batching when handlers share infrastructure (handlers dict registration, test fixture style, dispatch-merge invariant). All three landed in one task without test-isolation problems — each handler's per-level tests are independent (no shared global state).
- **Plan impact:** Confirms the batch-shape is durable. Likely will reuse for arc-007 watchtower-redesign trio (aesthetic-cohesion / render-fidelity + 1) and the remaining arcs.
- **Triggered:** No follow-on.

## Recommendation

**Recommendation:** GO

**Rationale:** Batch sibling of T-2328 / T-2356 shipped cleanly. 8/8 Agent ACs verified: 3 dedicated handlers implemented with full 6-level rubrics anchored to each arc's `proposed_scoped_drivers` rationale; all registered in handlers dict with canonical name-form keys (per T-2358); docstrings reference T-2359 + originating arc YAML + LATENT-until-X invariant; 24 new tests (6 per-level × 3 + 3 dispatch + 3 non-registration) all PASS; bvp_estimator file 149/149 (+24 over T-2358 baseline of 125); wider BVP regression net 231/231 (+24); reviewer R-06bd5e54 PASS, 0 findings. All three handlers latent — fire when operator approves the respective arc's proposed_scoped_drivers via Watchtower.

**Evidence:**
- `agents/termlink/bvp-estimator/estimator.py` — `score_uncertainty_recognition` + `score_severity_likelihood_calibration` + `score_sovereignty_preservation` (3 handlers, 6 levels each)
- handlers dict registration with T-2359 comment block
- `tests/unit/test_bvp_estimator.py` — 24 new tests (6 per-level for each handler + 3 dispatch + 3 latency)
- Reviewer verdict: R-06bd5e54 PASS, 0 findings
- Regression net: 231/231 BVP-related tests PASS

**Activation paths:**
1. arc-001 uncertainty-recognition + severity-likelihood-calibration: `http://192.168.10.107:3000/arcs/dispatch-safety` → Approve buttons on proposed_scoped_drivers table
2. arc-006 sovereignty-preservation: `http://192.168.10.107:3000/arcs/value-prioritisation` → same

After approval, member tasks of each arc dispatch through the T-2357 merge path and these handlers fire with rubric-scored 0-5 values.

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

### 2026-06-12T23:39:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2359-bvp-estimator-dedicated-handlers-batch--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0ec6ccbd
- **Timestamp:** 2026-06-12T23:45:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-12T23:45:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
