---
id: T-2360
name: "BVP estimator dedicated handlers batch 2 — arc-007 watchtower-redesign trio (aesthetic-cohesion + render-fidelity + theme-portability)"
description: >
  BVP estimator dedicated handlers batch 2 — arc-007 watchtower-redesign trio (aesthetic-cohesion + render-fidelity + theme-portability)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, estimator, arc-007, latent, batch]
components: [agents/termlink/bvp-estimator/estimator.py, tests/unit/test_bvp_estimator.py]
related_tasks: [T-2356, T-2357, T-2358, T-2359, T-2328]
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
created: 2026-06-12T23:48:31Z
last_update: 2026-06-12T23:55:45Z
date_finished: 2026-06-12T23:55:45Z
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
---

# T-2360: BVP estimator dedicated handlers batch 2 — arc-007 watchtower-redesign trio (aesthetic-cohesion + render-fidelity + theme-portability)

## Context

Third batch in BVP driver implementation sequence (T-2356 D-* pair → T-2359 arc-001/006 trio → T-2360 arc-007 trio). All 3 arc-007 (watchtower-redesign) `proposed_scoped_drivers` per `.context/arcs/watchtower-redesign.yaml`:

| Handler | Driver name | Weight | Rationale anchor |
|---------|-------------|--------|-----------------|
| `score_aesthetic_cohesion` | aesthetic-cohesion | 5 | watchtower-redesign.yaml — visual rhythm, typography spacing, palette contrast harmony, restraint; distinct from D3 Usability which rewards joy-to-use/extend/debug/defaults/errors |
| `score_render_fidelity` | render-fidelity | 5 | watchtower-redesign.yaml — visual failures that pass functional D2 (accent at 3.83:1 WCAG fail T-2006, Pico bleed T-2003, unbounded page height T-2038…T-2047); distinct from D2 which catches functional failures |
| `score_theme_portability` | theme-portability | 4 | watchtower-redesign.yaml — preset applies uniformly across Cockpit/Tasks/Approvals/Fabric/Arcs/Settings (headline_mechanic acid test); distinct from D4 Portability which is about provider/lang/env boundaries |

All LATENT until operator approves arc-007 proposed_scoped_drivers via Watchtower. T-2357 dispatch wiring + T-2358 name-form widening land activation immediately on approval.

## Acceptance Criteria

### Agent
- [x] `score_aesthetic_cohesion(fm, body, tags) -> tuple[int, list[str]]` added with full 6-level rubric: L5 new aesthetic primitive class (e.g. new design-token system / palette-contrast lint as structural mechanism), L4 framework-level aesthetic check (typography/density picker axes / palette-contrast lint), L3 component-level palette/typography/spacing tests (e.g. T-2004 / T-2029 sibling shape), L2 single palette/density tweak with rationale, L1 incidental aesthetic mention, L0 no signal
- [x] `score_render_fidelity(fm, body, tags) -> tuple[int, list[str]]` added with full 6-level rubric: L5 new render-fidelity primitive class (e.g. automated visual-regression / Playwright contrast check baseline), L4 framework-level render check (audit FAIL on contrast / unbounded height / Pico bleed), L3 component-level fix to a single render-fidelity defect (e.g. WCAG contrast fix on one accent), L2 single render-bug-fix without prevention, L1 incidental render mention, L0 no signal
- [x] `score_theme_portability(fm, body, tags) -> tuple[int, list[str]]` added with full 6-level rubric: L5 new theme-portability primitive class (e.g. design-token-substrate that auto-propagates across all surfaces), L4 framework-level theme apply-sweep (multi-page sweep / token-substrate adoption / dark-mode toggle), L3 component-level theme fix on 1-2 surfaces, L2 single missed-surface fix with rationale, L1 incidental theme mention, L0 no signal
- [x] All three handlers registered in the `handlers` dict with canonical name-form keys: `"aesthetic-cohesion"`, `"render-fidelity"`, `"theme-portability"`
- [x] Each handler's docstring references T-2360 + the originating arc YAML rationale + states the LATENT-until-X invariant
- [x] Test coverage: 6 per-level tests × 3 handlers = 18 + 3 dispatch + 3 non-registration = ≥ 24 new tests. All PASS, existing test suite green
- [x] bvp_estimator file ≥ 173 tests (was 149), wider BVP regression ≥ 255 (was 231)
- [x] Reviewer PASS on T-2360

### Human-omitted
<!-- All ACs agent-verifiable; pure backend Python. -->

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

python3 -m pytest tests/unit/test_bvp_estimator.py -q > /tmp/.t2360-pytest.out 2>&1; grep -q "passed" /tmp/.t2360-pytest.out && ! grep -qE "failed|error" /tmp/.t2360-pytest.out
grep -q "def score_aesthetic_cohesion" agents/termlink/bvp-estimator/estimator.py
grep -q "def score_render_fidelity" agents/termlink/bvp-estimator/estimator.py
grep -q "def score_theme_portability" agents/termlink/bvp-estimator/estimator.py
grep -q '"aesthetic-cohesion": score_aesthetic_cohesion' agents/termlink/bvp-estimator/estimator.py
out=$(bin/fw reviewer T-2360 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-12 — gating-vs-leveling: L1-entry too narrow, L4-trigger too greedy

- **What changed:** First test run had 6 failures across all three handlers, splitting into two classes: (a) L1-entry gating was too narrow (test bodies that *should* enter the rubric returned 0 because the gate keyword wasn't in body — same lesson as T-2359 calibration evolution); (b) L4 theme-portability trigger fired on "Theme sweep on two pages — Cockpit and Tasks" because my regex `Cockpit[/, ].{0,40}Cockpit|Tasks|...` matched " and " between surfaces. Two surfaces ≠ all surfaces. Fixed by requiring 3+ surfaces with `[/,]` separators OR explicit "all/every/across" qualifier.
- **Plan impact:** Sibling of T-2359's "gate liberally, level precisely" lesson — but with the OPPOSITE warning for L4: when distinguishing "some surfaces" from "all surfaces", the regex must capture the totality semantics, not just the existence of a single surface name. "and" connecting two surfaces is L3, not L4.
- **Triggered:** None.

### 2026-06-12 — L2 single-fix pattern needed "fixes one X" support

- **What changed:** Original L2 single_fix regex was `fix(es|ed)? (a |the )?(render|...) (bug|defect|issue)` — required "a" or "the" between fix and the noun. Real-world bug-fix bodies say "fixes one render bug" — the "one" article wasn't accepted. Added `( one)?` between the fix verb and the article.
- **Plan impact:** The rubric had a coverage gap for canonical bug-fix phrasing. Future scoped-driver handler design should explicitly enumerate the determiner classes (a / the / one / single) in L2 fix-class patterns.
- **Triggered:** None.

## Recommendation

**Recommendation:** GO

**Rationale:** Third batch in BVP driver implementation sequence. 8/8 Agent ACs verified: 3 dedicated handlers (aesthetic-cohesion + render-fidelity + theme-portability) implemented with 6-level rubrics anchored to arc-007 `proposed_scoped_drivers` rationale; all registered in handlers dict with canonical name-form keys; docstrings reference T-2360 + originating arc YAML + LATENT-until-X invariant; 24 new tests (6 per-level × 3 + 3 dispatch + 3 latency); bvp_estimator file 173/173 (+24 over T-2359 baseline); wider BVP regression net 255/255 (+24); reviewer R-de1a8683 PASS, 0 findings.

**Evidence:**
- `agents/termlink/bvp-estimator/estimator.py` — three new score_* functions + handlers dict registration with T-2360 comment
- `tests/unit/test_bvp_estimator.py` — 24 new tests
- Reviewer verdict: R-de1a8683 PASS, 0 findings
- Regression net: 255/255 BVP-related tests PASS

**Activation path:**
- `http://192.168.10.107:3000/arcs/watchtower-redesign` → Approve buttons on proposed_scoped_drivers (aesthetic-cohesion / render-fidelity / theme-portability)

After approval, member tasks of arc-007 dispatch through the T-2357 merge path and these three handlers fire with rubric-scored 0-5 values.

## Cumulative — BVP driver implementation prong status

8 dedicated arc-scoped handlers shipped this session across 4 commits (T-2356 D-* pair + T-2359 arc-001/006 trio + T-2360 arc-007 trio = 8 handlers). Plus 1 dispatch wiring slice (T-2357) and 1 name-form parity fix (T-2358). All LATENT until operator approves the respective arcs' `proposed_scoped_drivers` via Watchtower.

Remaining proposed_scoped_drivers without dedicated handlers (would fall through to score_free_driver fallback if approved):
- arc-005 inception-review-loop: 1 driver (feedback-loop-completeness) — single driver, could be a quick follow-on
- arc-006 sovereignty-preservation already shipped via T-2359
- arc-006 estimator-fidelity (APPROVED since 2026-05-21) — already activates via T-2358 fix → score_free_driver keyword fallback; could ship dedicated handler for richer rubric

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

### 2026-06-12T23:48:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2360-bvp-estimator-dedicated-handlers-batch-2.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f1b28f29
- **Timestamp:** 2026-06-12T23:55:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-12T23:55:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
