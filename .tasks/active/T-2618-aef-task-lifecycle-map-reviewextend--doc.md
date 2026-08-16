---
id: T-2618
name: "aef-task-lifecycle map review+extend — document the full task workflow"
description: >
  aef-task-lifecycle map review+extend — document the full task workflow

status: work-completed
workflow_type: build
owner: human
horizon: now
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
created: 2026-07-23T20:51:51Z
last_update: '2026-08-16T22:24:10Z'
date_finished: 2026-07-23T20:57:44Z
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
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2618: aef-task-lifecycle map review+extend — document the full task workflow

## Context

Operator asked to "document the task workflow" and selected the task-lifecycle
interpretation: review the existing `aef-task-lifecycle` corpus map (served in
the designer gallery) against the ACTUAL task workflow (CLAUDE.md §Task System:
Captured → Started Work ↔ Issues → Work Completed, plus the structural gates
G-020/P-010/P-011, the Agent/Human AC split with partial-complete + `fw task
review` handoff, healing on `issues`, episodic generation at completion) and
extend the map to close the documentation gaps. Spec-driven pipeline per T-2602
GO: derive spec from stored BPMN (single representation, T-2608) → edit spec →
`fw corpus generate` (new version, uids preserved) → lint → live e2e.

## Acceptance Criteria

### Agent
- [x] Current latest version of `aef-task-lifecycle` derived (`fw corpus derive`) and reviewed against CLAUDE.md §Task System; gap list recorded in this task's body (what the map shows vs the actual workflow)
- [x] Spec extended to close the recorded gaps; regenerated via `fw corpus generate` as a NEW stored version with ALL pre-existing node/flow uids preserved (rewires/moves limited to the intended changes recorded in the gap list; operator corrections flow through the Human AC / pair-draft loop)
- [x] Corpus lint stays at the 2-finding baseline; corpus suites (test_corpus_spec_roundtrip.py + test_corpus_lint.py) fully green
- [x] Extended map live-verified in the served designer: loads without console errors (favicon 404 excepted), every node renders, new nodes/flows visible and correctly laned

### Human
- [ ] [REVIEW] The extended map reads as accurate, complete documentation of the task workflow
  **Steps:**
  1. Open the designer gallery and load `aef-task-lifecycle` (latest version): http://192.168.10.107:3001/designer
  2. Walk the map against how you actually run tasks: capture → start → work → gates → complete / issues → healing / human-AC review handoff
  **Expected:** every state and gate you recognise from real sessions is present, correctly laned (agent initiative vs human sovereignty), and nothing important is missing or wrong
  **If not:** note the missing/wrong element(s) in chat or on /review/T-2618 — a follow-up version bump closes them

## Gap List (review of v3 vs actual workflow)

1. **Gate-failure path undrawn (structural, closes as new nodes/flows):** `tl_verify`
   flows unconditionally into the human-AC gateway, but P-010/P-011 REFUSE completion
   on unchecked ACs / non-zero Verification — the real flow loops back to work.
   Fix: new gateway `tl_gw_gates` ("gates pass?") after verify; "blocked" back-edge to
   `tl_work`; rewire `tl_e8` verify→gw_gates (uid kept).
2. **Horizon/backlog undrawn (structural):** captured tasks park at `horizon: next/later`
   and are promoted later; map jumps create→start. Fix: new gateway `tl_gw_ready`
   ("ready to start now?") + parked node `tl_parked` (backlog wait, service-typed to stay
   off the contested T-213 kind= surface); rewire `tl_e2` create→gw_ready (uid kept).
3. **Healing escalation absent (meta-only):** enrich `tl_heal` note with the Error
   Escalation Ladder A–D and unresolvable→operator escalation.
4. **Completion-gate variants absent (meta-only):** enrich `tl_verify` note with the
   RCA gate (T-1550 bug-class), render-review gate (P-013), and reviewer auto-tick
   ([REVIEWER] ACs, T-1985).
5. **Review handoff URL class (meta-only):** enrich `tl_human_review` note: handoff via
   `fw task review` → class-correct Watchtower URL (T-2125/T-2129).

Intended layout moves (gap 1 insertion): `tl_gw_human` 1080→1200, `tl_human_review`
x1220→1340, `tl_archive` 1380→1520, `tl_done` 1520→1660. All uids unchanged.

## Recommendation

- **Recommendation:** GO — tick the Human AC and close
- **Rationale:** v4 closes the two structural documentation gaps (the completion-gate
  refusal loop and the horizon backlog — both core mechanics the map previously
  omitted) plus three meta-note enrichments, with every v3 uid preserved and the
  pair-draft loop available for any correction you spot in the UI.
- **Evidence:**
  - uid audit: all 25 v3 uids present in re-derived v4; additions exactly the 8 intended (`tl_gw_gates`, `tl_gw_ready`, `tl_parked`, `tl_e14`–`tl_e18`)
  - corpus lint: 2-finding baseline unchanged; suites 24/24 green
  - live e2e on served bytes: 15/15 nodes + 18/18 edges render, 0 console errors
  - stored as v4 with note "T-2618: document task workflow …" (meta.json latest=4)

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

out=$(cat .context/designer/projects/aef-task-lifecycle/meta.json); echo "$out" | grep -q '"latest": 4'
out=$(python3 tools/corpus_spec.py derive aef-task-lifecycle --out /dev/stdout 2>/dev/null); echo "$out" | grep -q "tl_gw_gates" && echo "$out" | grep -q "tl_parked" && echo "$out" | grep -q "tl_e18"
test "$(python3 tools/corpus_lint.py 2>&1 | grep -c '^  \[')" = "2"
python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_lint.py -q
out=$(curl -sf "$(bin/fw watchtower url)/api/version?id=aef-task-lifecycle&v=4"); echo "$out" | grep -q "tl_gw_gates"

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-23T20:51:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2618-aef-task-lifecycle-map-reviewextend--doc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9afc98f6
- **Timestamp:** 2026-07-23T20:57:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-23T20:57:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
