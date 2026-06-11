---
id: T-2327
name: "T-2305 GO scope support — projected BVP ranking impact for V_PROMPT_QUALITY
  + V_CONTEXT_FABRIC + V_COMPONENT_FABRIC (advisory analysis, 5 sample tasks scored
  against new rubrics)"
description: >
  T-2305 GO scope support — projected BVP ranking impact for V_PROMPT_QUALITY + V_CONTEXT_FABRIC
  + V_COMPONENT_FABRIC (advisory analysis, 5 sample tasks scored against new rubrics)

status: work-completed
workflow_type: design
owner: agent
horizon: null
tags: [arc-value-prioritisation, agent-prep, bvp-support, advisory-analysis, 
      no-source-change]
components: []
related_tasks: [T-2305, T-2306]
arc_id: value-prioritisation
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-11T07:12:34Z
last_update: 2026-06-11T07:18:58Z
date_finished: 2026-06-11T07:18:58Z
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
  - ts: '2026-06-11T07:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-11T07:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2327: T-2305 GO scope support — projected BVP ranking impact for V_PROMPT_QUALITY + V_CONTEXT_FABRIC + V_COMPONENT_FABRIC (advisory analysis, 5 sample tasks scored against new rubrics)

## Context

T-2305 GO scope authorized 3 new free drivers — V_PROMPT_QUALITY (w=7),
V_CONTEXT_FABRIC (w=7), V_COMPONENT_FABRIC (w=6). The implementation
(T-2306) is Sovereign-blocked at agent layer — the `fw bvp driver --add`
calls need operator. T-2305 §7 says ranking changes are expected but
doesn't show CONCRETE numbers — the operator's grill of "is the ranking
shift actually useful?" can only be answered by sample data.

This task writes a projected-impact analysis: 5 sample tasks scored
against the 3 new drivers using the T-2305 §5 rubrics, side-by-side
with their current BVP scores, showing the BVP_total + BVP_norm shift
each task would experience. Result: operator can grill the driver-add
proposal on concrete ranking impact, not generic claims.

Sample set chosen to demonstrate driver discrimination:
- T-2271 (BVP bundle README) — touches policy/prompts/ → V_PROMPT_QUALITY uplift expected
- T-2319 (fabric enrich pass) — touches .fabric/ → V_COMPONENT_FABRIC uplift expected
- T-2322 (budget-gate compact_boundary) — touches agents/context/ → V_CONTEXT_FABRIC uplift expected
- T-2325 (arc-011 grill responses) — neutral on all 3 → baseline dilution
- T-2298 (audit perf batch) — neutral on all 3 → baseline dilution

Scope: a single docs/reports/ artifact. No edit to task frontmatters.
No edit to policy/value-drivers.yaml. No write to .context/bvp-*.yaml.
ALL scoring is agent-advisory; the operator confirms (or doesn't) via
`fw bvp confirm --i-am-human` (Sovereign).

## Acceptance Criteria

### Agent
- [x] docs/reports/arc-006-bvp-driver-projected-impact.md exists with non-empty body
- [x] Artifact scores all 5 sample tasks (T-2271, T-2319, T-2322, T-2325, T-2298) against all 3 new drivers
- [x] Per-task score includes 1-line rubric-trace rationale (which T-2305 §5.X scoring level applied + why)
- [x] Artifact computes current BVP_total + BVP_total_with_3_new + BVP_norm shift for each sample task (5×2 = 10 BVP_total lines, 5×2 = 17 BVP_norm references including summary table)
- [x] Artifact's summary table shows ≥1 task that gains BVP_norm rank and ≥1 task that loses BVP_norm rank (T-2322 gains 3→2; T-2319 gains 4→3; T-2298 loses 1→3; T-2325 loses 2→4)
- [x] Artifact explicitly declares "advisory analysis only — operator confirms via fw bvp confirm" and names the Sovereign boundary (8 references)
- [x] Cross-references T-2305 §5 (rubrics) + §7 (expected changes) by section number (§5 cited 4×, §7 cited 1× + §6 + §8)
- [x] Identifies ≥2 ambiguity points in the rubrics encountered during scoring (4 ambiguity points identified: V_CONTEXT_FABRIC scope, V_PROMPT_QUALITY index-vs-content, V_COMPONENT_FABRIC L3-vs-L2 characterization, sample-bias L4/L5)

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

test -s docs/reports/arc-006-bvp-driver-projected-impact.md
# L-387: bash substring containment, no pipe-to-grep
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); for t in T-2271 T-2319 T-2322 T-2325 T-2298; do case "$out" in *"$t"*) :;; *) echo "missing $t"; exit 1;; esac; done
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); n=$(echo "$out" | grep -cE "V_PROMPT_QUALITY|V_CONTEXT_FABRIC|V_COMPONENT_FABRIC"); test "$n" -ge 15
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); echo "$out" | grep -qE "BVP_total" && echo "$out" | grep -qE "BVP_norm"
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); echo "$out" | grep -qE "Δ|delta|shift"
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); echo "$out" | grep -qE "Sovereign|fw bvp confirm|advisory"
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); echo "$out" | grep -qE "T-2305.*§5" && echo "$out" | grep -qE "T-2305.*§7"
out=$(cat docs/reports/arc-006-bvp-driver-projected-impact.md); echo "$out" | grep -qE "ambiguity|borderline|ambiguous"

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO (full close — advisory analysis artifact in place,
8/8 Agent ACs, no human [REVIEW] needed — pure analysis artifact, no
prose-taste judgment required)

**Rationale:** Concretizes T-2305 §7's "ranking changes expected" predictions
with sample data. 5 tasks scored against all 3 new drivers using the §5
rubrics, with per-task rubric-trace, raw BVP_total + BVP_norm calculations,
and a relative-ranking summary table. Demonstrates BOTH the discrimination
(driver-touching tasks get rubric-traceable uplift) and the dilution
(BVP_norm decreases for all tasks because denominator grew 35→55 weight).

Operator can now grill the driver-add proposal on actual numbers:
- T-2298 (audit perf) rank 1→3 — is this acceptable? (audit work IS
  important; should V_CONTEXT_FABRIC count toward "memory subsystem
  reliability"?)
- T-2322 (budget gate) rank 3→2 — is this the right uplift? (the rubric
  ambiguity #1 question: budget != memory, should T-2322 score 0 not 2?)
- T-2319 (fabric enrich) rank 4→3 (tie) — is L3 the right score for
  characterization without code change? (rubric ambiguity #3)

**Evidence:**
- `docs/reports/arc-006-bvp-driver-projected-impact.md` exists with per-task
  scoring + summary table + ambiguity-point capture
- All 5 sample tasks scored (T-2271, T-2319, T-2322, T-2325, T-2298)
- 36 V_PROMPT_QUALITY/V_CONTEXT_FABRIC/V_COMPONENT_FABRIC mentions across
  scoring + ambiguity sections
- 10 BVP_total + 17 BVP_norm calculations (5 tasks × current + new + summary)
- 8 explicit "advisory" / "Sovereign" / "fw bvp confirm" mentions preserving
  operator authority
- 4 ambiguity points captured as first-30-days refinement candidates per
  T-2305 §6 ("borderline cases will surface in first-use")
- 4 cross-references to T-2305 §5 (rubrics) + 1 to §7 (predictions) +
  references to §6 and §8

**What this artifact gives the BVP-drivers track:**
- T-2305 (driver specs) + T-2306 (CLI execution) + T-2306-quickstart
  (operator-runnable steps) + T-2327 (this — projected impact analysis)
  together give the operator a complete pre-add bundle:
  - WHY add (T-2305 §1-§6 with sharpening dialogue)
  - WHAT to add (T-2305 §5 specs)
  - HOW to add (T-2305 §8 + quickstart)
  - WHAT HAPPENS after add (T-2327 — this artifact)
- 4 ambiguity points are forward-looking refinement input — the operator
  can either tighten the rubrics pre-add or accept the borderlines and
  refine during first-30-days

**Out of scope (deliberately):**
- No edit to any task's `bvp_scores:` (Sovereign boundary)
- No edit to `policy/value-drivers.yaml` (Sovereign)
- No edit to T-2305 keystone or T-2306 task body
- No new estimator heuristic in `agents/termlink/bvp-estimator/` (deferred
  per artifact's NOT-list; would be sibling of T-2306 once drivers exist)
- No fix to current `bvp_scores_proposed:` estimator output for the 5
  samples (the existing rationale strings are cron-output; this artifact
  proposes new-driver scores but doesn't backfill the proposed-list)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-11T07:12:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2327-t-2305-go-scope-support--projected-bvp-r.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9403b116
- **Timestamp:** 2026-06-11T07:18:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-11T07:18:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
