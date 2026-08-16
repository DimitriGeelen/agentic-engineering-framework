---
id: T-2561
name: "designer-corpus D3: session-lifecycle process diagram (init → work → handover
  → push)"
description: >
  designer-corpus D3: session-lifecycle process diagram (init → work → handover →
  push)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:designer-corpus]
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
created: 2026-07-19T20:45:40Z
last_update: '2026-08-16T22:24:10Z'
date_finished: 2026-07-19T20:52:59Z
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
  - ts: '2026-08-16T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2561: designer-corpus D3: session-lifecycle process diagram (init → work → handover → push)

## Context

arc-014 corpus diagram D3 of 5 (T-2553 GO, telemetry pick #3: handover ran 1387×). The AEF session lifecycle as actually operated: Session Start Protocol (context init → read LATEST.md → focus) → work loop (task gate, commit cadence P-009, budget escalation ladder) → Session End Protocol (session capture → `fw handover --commit` → push verify T-1277). Timer flavor: the budget thresholds and the auto-restart wrapper give this process its typed-event (timer) character — encoded via `aef:eventDef kind=timer` where honest. Same D1/D2 pattern: draft in 832's canonical dialect, save via live POST /api/save, compile, capture verbatim log, file gaps to arc-014.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Diagram `aef-session-lifecycle` drafted in 832's canonical dialect (aef:workflowMeta schemaVersion=2, laneMeta authority=, uid attribute form, aef:position) covering init → work loop → budget escalation → handover → push-verify, with the honest typed timer event (T-179 wrapper cancel window, `kind=timer binding=PT3S`) and the commit-cadence loop edge
- [x] Saved through the LIVE designer gallery API (`POST /api/save`, id=aef-session-lifecycle → `{"ok":true,"v":1}`) — meta.json + v1.bpmn exist under `.context/designer/projects/aef-session-lifecycle/`
- [x] `fw bpmn compile` on the saved v1.bpmn exits 0; every expected WARN class accounted for (1× typed-event T-2551, 2× gateway T-2557 with branch labels) in the verbatim compile log at `docs/reports/T-2561-d3-compile-log.md`; the one NEW gap class (self-referential related_tasks on the commit-cadence self-loop) filed as T-2562, not fixed mid-flight
- [x] Owner derivation correct: sovereignty-lane userTask sl_review → owner human; all initiative-lane serviceTasks → owner agent

### Human
- [ ] [REVIEW] D3 session-lifecycle diagram reads as a faithful picture of how sessions actually run
  **Steps:**
  1. Open http://192.168.10.107:3001/designer and load project `aef-session-lifecycle`
  2. Check the flow: operator launch → init → work loop with "budget critical?" gateway looping back (commit cadence) → capture → handover → push-verify → "restart requested?" → timer (3s cancel window) → restart, or clean end via your review-queue step
  3. Correct anything directly in the designer UI (pair-draft: your edits become v2)
  **Expected:** The two decision points (budget wrap-up, auto-restart) and the sovereignty placement of the review-queue step match your mental model of a session
  **If not:** Edit in the designer (creates v2) or note the correction — the diff drives the next corpus iteration
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

test -f .context/designer/projects/aef-session-lifecycle/v1.bpmn
test -f .context/designer/projects/aef-session-lifecycle/meta.json
out=$(bin/fw bpmn compile .context/designer/projects/aef-session-lifecycle/v1.bpmn 2>&1); test "$(echo "$out" | grep -c "typed-event annotation")" = "1" && test "$(echo "$out" | grep -c "T-2557")" = "2"
out=$(bin/fw bpmn compile .context/designer/projects/aef-session-lifecycle/v1.bpmn 2>&1); echo "$out" | grep -q "id: sl_review" && echo "$out" | grep -A2 "id: sl_review" | grep -q "owner: human"
test -f docs/reports/T-2561-d3-compile-log.md

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

### 2026-07-19 — self-loops are a distinct fidelity class from distinct-node loops
- **What changed:** D1 proved the flow-walk survives loops, but its back-edge came from a distinct node (tl_heal → tl_work). D3's commit-cadence loop routes through a gateway straight back to the SAME task — and the nearest-task-predecessor walk faithfully records the task as its own predecessor (`related_tasks: [sl_init, sl_work]`). The corpus exercise is doing exactly what the grill scoped it for: each real process shape stresses a compiler path the fixtures didn't.
- **Plan impact:** none for D4/D5 drafting; promote of D3's skeletons should wait for the T-2562 fix or hand-strip the self-ref.
- **Triggered:** T-2562 (skip self-references in Pass-2 accumulation; captured/later, arc-014).

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

**Recommendation:** GO — accept D3 into the corpus
**Rationale:** Third corpus diagram through the full pipeline; both detector classes (T-2551 typed-event, T-2557 gateway) fired exactly as designed, owner/horizon derivation correct, and the exercise surfaced one genuinely new minor gap (self-referential related_tasks, T-2562) — the accumulator arc working as intended.
**Evidence:**
- `.context/designer/projects/aef-session-lifecycle/v1.bpmn` saved via live API (`{"ok":true,"v":1}`)
- Compile exit 0: 6 skeletons, sl_review owner:human, 1 timer WARN + 2 gateway WARNs (verbatim in docs/reports/T-2561-d3-compile-log.md)
- T-2562 filed with real ACs (captured/later, arc:designer-corpus)

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

### 2026-07-19T20:45:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2561-designer-corpus-d3-session-lifecycle-pro.md
- **Context:** Initial task creation

### 2026-07-19T20:46:51Z — status-update [task-update-agent]
- **Change:** tags: +arc:designer-corpus

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d29a92bc
- **Timestamp:** 2026-07-19T20:53:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-19T20:52:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
