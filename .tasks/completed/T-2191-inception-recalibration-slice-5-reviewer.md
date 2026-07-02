---
id: T-2191
name: "Inception recalibration Slice 5: reviewer-agent disposition completeness +
  extend defer-as-hedge for answered-without-evidence"
description: >
  T-2186 Slice 5. Extend lib/reviewer/static_scan.py with a disposition-completeness
  detector (inceptions only) verifying every declared open question carries answered|deferred|dissolved
  + rationale + evidence citation. Integrate with T-1985 auto-tick v1.5 so [REVIEWER]-prefixed
  dispositions can auto-tick when conjunctive 5-condition gate passes. Extend the
  T-2145 defer-as-hedge detector to also flag 'answered-without-evidence' pattern
  (rationale lacks citation). Bats + unit-test pins. Verification: detector fires
  on synthetic under-disposed inception; auto-tick fires on synthetic well-disposed
  one; defer-as-hedge catches no-evidence answered case.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-2186, T-2188, T-2145]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:04:35Z
last_update: '2026-06-11T22:24:10Z'
date_finished: 2026-06-03T05:39:49Z
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
  - ts: '2026-06-11T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
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

# T-2191: Inception recalibration Slice 5: reviewer-agent disposition completeness + extend defer-as-hedge for answered-without-evidence

## Context

Reviewer static-scan extension for inception `## Open Questions`. Adds a `disposition-incomplete` detector firing on inceptions whose IW-N entries are missing required disposition/rationale, or whose `disposition: answered` cases lack evidence citation (sibling-shape to T-2145 `defer-as-hedge`: decision-without-evidence pattern). Catalogue-registered, override-supported. Builds on T-2190 (template section) and T-2194 (filing-time gate).

## Acceptance Criteria

### Agent
- [x] New `detect_disposition_completeness` function in `lib/reviewer/static_scan.py` fires on `workflow_type: inception` when `## Open Questions` exists; for each `- **IW-N:**` entry, checks disposition value ∈ {answered, deferred, dissolved} AND rationale exists AND `disposition: answered` rationale contains an evidence citation (file:line, `T-NNNN`, `docs/reports/...`, or G-/L-/D-NNN id). Python smoke-test 6/6: well-filed→0, missing-disp→1, answered-no-cite→1, invalid-value→1, build-exempt→0, no-section→0.
- [x] Detector registered in catalogue `policy/anti-patterns.yaml` as `disposition-incomplete` with description, examples_positive/negative, and override guidance (parallels T-2145 entry).
- [x] Detector wired into `scan_task()` orchestrator (after the T-2145 `defer-as-hedge` block) and emits findings with `ac_index=None`, `lie_severity=partial`, `detection_confidence=heuristic`. Reviewer self-scan R-de365602 PASS confirms wiring imports cleanly.
- [x] Bats test `tests/unit/reviewer_disposition_incomplete.bats` pins: well-disposed inception passes, missing-disposition fires, missing-rationale fires, invalid disposition value fires, answered-without-citation fires, non-inception exempt, no-Open-Questions section grandfathered. All tests PASS (9/9; +2 over filed scope: deferred-no-citation-passes, multi-IW-mixed-health). Full reviewer suite: 14/14.
- [x] Reviewer agent self-scan (`bin/fw reviewer T-2191`) returns Overall: PASS (scan R-239920e1, 2026-06-03T05:38:58Z, findings: none).

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

bats tests/unit/reviewer_disposition_incomplete.bats
grep -q "def detect_disposition_completeness" lib/reviewer/static_scan.py
grep -q "disposition-incomplete" policy/anti-patterns.yaml
grep -q "detect_disposition_completeness" lib/reviewer/static_scan.py
out=$(bin/fw reviewer T-2191 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-03 — separated from defer-as-hedge rather than extending it
- **What changed:** Original IW-7 spec said "extend the T-2145 defer-as-hedge detector to also flag answered-without-evidence". On reading T-2145's gates (Recommendation-level: artifact path, candidate matrix, Rationale length) the disposition-completeness rule needed a different gate-shape (per-question, Open Questions section). Cleaner as a sibling detector with a shared family description than as a polymorphic extension.
- **Plan impact:** New detector `detect_disposition_completeness`, new catalogue entry `disposition-incomplete`, wired right after `detect_defer_as_hedge`. Override path identical (TTL'd per-pattern). T-2145 detector unchanged.
- **Triggered:** None — kept slice scoped. Cross-ref in description explicitly names T-2145 as the parent family pattern so future readers see the lineage.

### 2026-06-03 — auto-tick (T-1985) integration via verdict-level findings
- **What changed:** Original spec implied direct auto-tick integration ("[REVIEWER]-prefixed dispositions can auto-tick"). On re-reading the T-1985 5-condition gate, all that matters is the per-AC-index match (`ac_index`); verdict-level findings (`ac_index=None`) are correctly skipped because the gate's clause 2 requires "zero per-AC findings for that AC's index" — None never matches an integer index. So `[REVIEWER]`-style ACs on inceptions referencing this detector get auto-ticked whenever this detector returns 0 findings, exactly the right behaviour with no code change.
- **Plan impact:** Removed an auto-tick-integration AC that would have been a no-op. The five-condition gate already handles this shape correctly.
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

### 2026-06-02T22:04:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2191-inception-recalibration-slice-5-reviewer.md
- **Context:** Initial task creation

### 2026-06-02T23:19:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c31c8ffd
- **Timestamp:** 2026-06-03T05:39:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-03T05:39:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
