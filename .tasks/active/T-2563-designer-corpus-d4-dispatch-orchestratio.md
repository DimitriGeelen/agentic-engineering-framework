---
id: T-2563
name: "designer-corpus D4: dispatch-orchestration loop process diagram (resolver dispatch
  → worker → outcome backprop)"
description: >
  designer-corpus D4: dispatch-orchestration loop process diagram (resolver dispatch
  → worker → outcome backprop)

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
created: 2026-07-19T20:53:32Z
last_update: '2026-08-16T22:24:10Z'
date_finished: 2026-07-19T21:00:25Z
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
  - ts: '2026-07-19T21:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-19T21:00:09Z'
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
  - ts: '2026-08-16T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2563: designer-corpus D4: dispatch-orchestration loop process diagram (resolver dispatch → worker → outcome backprop)

## Context

arc-014 corpus diagram D4 of 5 (T-2553 GO, telemetry pick #4: dispatch 992/1240 events). The v1 dispatch-orchestration loop as actually operated: `fw resolver dispatch` (workflow → assemble envelope → telemetry to dispatches.jsonl) → TermLink worker executes → `fw outcome evaluate/backprop` (outcome rows joined to dispatch rows) — plus the paused-dispatch chain (worker pause_requested → operator `fw pause resolve` → retry envelope linked via retry_of_dispatch_id). Message flavor: worker↔orchestrator coupling via bus/inbox is the honest `kind=message` typed event. Same D1-D3 pattern: canonical dialect, live POST /api/save, compile, verbatim log, gaps to arc-014.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Diagram `aef-dispatch-loop` drafted in 832's canonical dialect covering resolver dispatch → worker execution → outcome evaluate/backprop, including the paused-dispatch sovereignty step (operator `fw pause resolve`) and the honest `kind=message` typed event (worker result on bus, binding=bus:task-channel)
- [x] Saved through the LIVE designer gallery API (`POST /api/save`, id=aef-dispatch-loop) — meta.json + v2.bpmn exist under `.context/designer/projects/aef-dispatch-loop/` (v1 was malformed — see Evolution + T-2564)
- [x] `fw bpmn compile` on the saved v2.bpmn exits 0; every expected WARN class accounted for (1× message T-2551, 1× gateway T-2557) in the verbatim compile log at `docs/reports/T-2563-d4-compile-log.md`; the NEW gap class (save accepts malformed XML) filed as T-2564, not fixed mid-flight
- [x] Owner derivation correct: sovereignty-lane userTask dl_pause_resolve → owner human; all initiative-lane serviceTasks → owner agent

### Human
- [ ] [REVIEW] D4 dispatch-loop diagram reads as a faithful picture of the v1 orchestration substrate
  **Steps:**
  1. Open http://192.168.10.107:3001/designer and load project `aef-dispatch-loop` (v2)
  2. Check the flow: dispatch selected → resolver envelope → spawn worker → message event (result on bus) → "worker paused?" → your `fw pause resolve` step → retry envelope loops back to spawn; completed path → outcome evaluate/backprop → end
  3. Correct anything directly in the designer UI (pair-draft: your edits become v3)
  **Expected:** The pause chain's sovereignty placement and the retry loop match how dispatch-safety slice 5 actually behaves
  **If not:** Edit in the designer or note the correction — the diff drives the next corpus iteration

## Verification

test -f .context/designer/projects/aef-dispatch-loop/v2.bpmn
test -f .context/designer/projects/aef-dispatch-loop/meta.json
out=$(bin/fw bpmn compile .context/designer/projects/aef-dispatch-loop/v2.bpmn 2>&1); test "$(echo "$out" | grep -c "typed-event annotation")" = "1" && test "$(echo "$out" | grep -c "T-2557")" = "1"
out=$(bin/fw bpmn compile .context/designer/projects/aef-dispatch-loop/v2.bpmn 2>&1); echo "$out" | grep -q "id: dl_pause_resolve" && echo "$out" | grep -A2 "id: dl_pause_resolve" | grep -q "owner: human"
test -f docs/reports/T-2563-d4-compile-log.md

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

### 2026-07-19 — the corpus stresses the SAVE surface, not just the compiler
- **What changed:** v1 shipped a raw angle-bracket token inside an attribute (authoring slip) — and the gallery API happily persisted the malformed XML ({"ok":true,"v":1}); only fw bpmn compile caught it (ParseError line/col, exit 1). Until D4, every corpus finding was compiler-side; this is the first store-side gap: /api/save has no well-formedness check, so a broken save surfaces at the WRONG layer (compile-time or designer-load-time instead of save-time).
- **Plan impact:** none for D5 drafting; escape discipline noted for meta notes containing CLI placeholder syntax.
- **Triggered:** T-2564 (save-side XML parse → HTTP 400 with line/column; captured/later, arc-014).

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

**Recommendation:** GO — accept D4 into the corpus
**Rationale:** Fourth corpus diagram through the full pipeline; first kind=message validation, pause-chain sovereignty step derives owner:human correctly, distinct-node retry loop confirms T-2562 is specific to self-loops — and the v1 authoring slip surfaced the first store-side gap (T-2564), exactly the accumulator behavior the grill scoped.
**Evidence:**
- `.context/designer/projects/aef-dispatch-loop/v2.bpmn` saved via live API ({"ok":true,"v":2})
- Compile exit 0: 5 skeletons, dl_pause_resolve owner:human, 1 message WARN + 1 gateway WARN (verbatim in docs/reports/T-2563-d4-compile-log.md)
- T-2564 filed with real ACs (captured/later, arc:designer-corpus)
- Review companion: `docs/reports/T-2572-drafting-instincts-diff.md` — D4 (substrate-level) vs 832's pair-draft #2 (protocol-level) side-by-side; the open steer it surfaces: Framework-lane governance nodes vs hook-delegation convention for corpus diagrams

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

### 2026-07-19T20:53:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2563-designer-corpus-d4-dispatch-orchestratio.md
- **Context:** Initial task creation

### 2026-07-19T20:54:52Z — status-update [task-update-agent]
- **Change:** tags: +arc:designer-corpus

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19c06556
- **Timestamp:** 2026-07-19T21:00:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-19T21:00:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
