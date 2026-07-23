---
id: T-2613
name: "aef-audit-cron warn/fail connector unwired — corpus sweep for unlinked handoff-intent
  nodes"
description: >
  aef-audit-cron warn/fail connector unwired — corpus sweep for unlinked handoff-intent
  nodes

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-23T07:38:47Z
last_update: 2026-07-23T08:58:07Z
date_finished: 2026-07-23T08:58:07Z
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
  - ts: '2026-07-23T07:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-23T07:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2613: aef-audit-cron warn/fail connector unwired — corpus sweep for unlinked handoff-intent nodes

## Context

Operator (2026-07-23, right after the T-2612 fix): "many connectors work, still some
don't — example: on aef-audit-cron, 'warn/fail findings present' doesn't work, isn't
linked." Distinct defect class from T-2612: aef-audit-cron carries NO aef:link
elements at all — the element is handoff-INTENT authored without handoff WIRING, so
there is nothing for the editor (or the T-2612 dual-form fix) to bind. This task:
identify the unwired node(s) on aef-audit-cron, wire them to their intended target
workflows, sweep the rest of the corpus for the same class, and live-verify the
jumps.

## Acceptance Criteria

### Agent
- [x] The "warn/fail findings present" element on aef-audit-cron is identified and
      its intended semantics determined: `agt_6_warn` (uid ac_err_findings) is a
      BARE intermediateCatchEvent — no aef:link AND no aef:eventDef — so the
      editor offered the link-catch UI with an empty target ("isn't linked").
      Semantically it is a mid-branch severity condition (exit 1/2 → emission),
      NOT a cross-workflow handoff: its flow continues agt_6_warn → agt_7_emit →
      operator triage. Two-part fix: (a) type it `aef:eventDef kind="error"`
      (editor vocabulary: error/timer/message) → typed rendering, no dead jump
      affordance; (b) the genuinely missing cross-workflow link on this map is
      emitted-findings-tasks → aef-task-lifecycle — added as NEW terminal
      handoff throw `agt_8_handoff_lifecycle` "Handoff → task lifecycle" (uid
      ac_handoff_lifecycle) branching from agt_7_emit, mirroring the
      dispatch-loop return-leg convention.
- [x] aef-audit-cron regenerated with the handoff wired, saved as v3
      (non-destructive; uuid preserved). NOTE: link is uuid-ONLY, not dual-form —
      the AC's "dual-form per T-2612" was authored against the 0.3.1 pin; the
      T-2615 re-pin (0.3.2, resolves_workflow_ref=true) landed first, so emit is
      canonical uuid-only by design (see Evolution).
- [x] Corpus-wide sweep (programmatic: bare catch/throw without link/eventDef +
      handoff-vocabulary names without aef:link) — 5 candidates, each dispositioned:
      1. aef-audit-cron agt_6_warn — FIXED (kind=error + new handoff, above).
      2. aef-session-lifecycle agt_8_wrapper "wrapper cancel window" — same
         bare-catch dead-UI class; uid `sl_tmr_restart` shows original timer
         intent → FIXED as `kind="timer"`, saved v3; renders eventTimer, no
         Target-workflow UI.
      3. aef-session-lifecycle agt_4_session — "→" is prose ("uncaptured work →
         tasks"), an in-map transformation; NOT-A-HANDOFF.
      4. aef-task-lifecycle agt_4_heal — "→" is prose ("issues → diagnose →
         resolve"), internal healing loop; NOT-A-HANDOFF.
      5. t2529-verify — no bpmn:process element (T-2529 API-verify fixture, not
         a workflow map); SKIPPED.
- [x] Live e2e on served bytes (Playwright, operator path): audit-cron v3
      renders all 19 elements incl. ac_handoff_lifecycle + edge ac_e9; handoff
      binds "aef-task-lifecycle ↳ auto-resolved from workflow ref (uuid)", jump
      enabled, jump lands in task-lifecycle (25 tl_* elements). agt_6_warn
      selected → panel shows `eventError`, NO Target-workflow UI. session-
      lifecycle v3 sl_tmr_restart → `eventTimer`, no Target-workflow UI.
- [x] Corpus lint at the pinned 2-finding baseline (kind=error/timer carry no
      binding → emitterless rule silent; new throw is terminal single-target →
      handoff-wiring silent); suites 24/24 green; no baseline change needed.

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

out=$(grep -c 'aef:link workflowRef="1f9b5f0c' .context/designer/projects/aef-audit-cron/v3.bpmn); test "$out" = "1"
grep -q 'aef:eventDef kind="error"' .context/designer/projects/aef-audit-cron/v3.bpmn
grep -q 'aef:eventDef kind="timer"' .context/designer/projects/aef-session-lifecycle/v3.bpmn
python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_lint.py -q
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "2 finding(s)"

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

**Symptom:** clicking "warn/fail findings present" on the served aef-audit-cron
showed the link-catch UI with an empty target and a dead jump — operator read it
as an unlinked connector.

**Root cause:** the node was authored as a BARE intermediateCatchEvent — neither
aef:link (handoff) nor aef:eventDef (typed event). The editor's default catch
rendering is the link-catch shape, so an untyped catch always presents a jump
affordance that can never bind. Two distinct authoring gaps: the condition node
was never typed, and the map's real cross-workflow seam (emitted tasks →
task lifecycle) was never drawn at all.

**Why structurally allowed:** corpus lint had no rule for the untyped-event
class — legacy-ref/ghost-ref/editor-unbindable all key off an EXISTING aef:link;
a node with no link at all matched nothing. Handoff-intent that was simply
missing (no element) is invisible to any per-element scan.

**Prevention:** the T-2613 sweep classifier (bare catch/throw without
link/eventDef + handoff-vocabulary names without aef:link) ran corpus-wide and
dispositioned all 5 candidates; every catch/throw in the corpus now carries
either aef:link or aef:eventDef. A future `untyped-event` lint rule would make
this structural — deferred: the operator-facing rendering question (should a
bare catch offer the link UI at all?) belongs to 832's editor; raised as a
possible upstream refinement in the rail verdict rather than pinned locally.

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

### 2026-07-23 — dual-form AC superseded by the 0.3.2 re-pin landing first
- **What changed:** the AC "wire dual-form per T-2612" was authored while the
  pin was 0.3.1; T-2615 (0.3.2 re-pin, resolves_workflow_ref=true, aliases
  dropped corpus-wide) completed before this task's wiring step.
- **Plan impact:** the new handoff is emitted canonical uuid-ONLY — emit_map is
  now capability-conditional, so hand-authoring a dual-form link would have
  reintroduced the exact alias the re-pin just dropped.
- **Triggered:** no new task; AC2 annotated in place.

### 2026-07-23 — sweep widened the fix beyond the reported map
- **What changed:** the operator's example (audit-cron) was one of TWO
  bare-catch dead-UI instances; session-lifecycle's "wrapper cancel window"
  had the same class (uid sl_tmr_restart — author intended a timer).
- **Plan impact:** both fixed in one pass; the two "→"-named service tasks are
  prose, not handoffs — recorded as not-a-handoff rather than over-wiring.
- **Triggered:** possible upstream question for 832 (should a bare catch offer
  the link UI?) — raised on the rail, not filed locally.

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

### 2026-07-23T07:38:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2613-aef-audit-cron-warnfail-connector-unwire.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-899e5045
- **Timestamp:** 2026-07-23T08:58:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_lint.py -q`

### 2026-07-23T08:58:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
