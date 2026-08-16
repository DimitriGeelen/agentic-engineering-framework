---
id: T-2552
name: "fw bpmn compile: surface silently-dropped typed-event aef:eventDef annotations
  as WARN"
description: >
  fw bpmn compile: surface silently-dropped typed-event aef:eventDef annotations as
  WARN

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-07-19T18:35:58Z
last_update: '2026-08-16T22:25:10Z'
date_finished: 2026-07-19T18:41:54Z
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
  - ts: '2026-08-16T22:25:10Z'
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

# T-2552: fw bpmn compile: surface silently-dropped typed-event aef:eventDef annotations as WARN

## Context

832's typed BPMN events (their T-204 Slice 1) encode error/timer/message as
`<aef:eventDef kind= binding=>` on a neutral `intermediateCatchEvent`. AEF's compiler
(`tools/bpmn_to_tasks.py`) *transits* these events in the T-2532 flow-walk (they contribute to
`related_tasks` edges) but **silently drops** the `aef:eventDef` annotation — no skeleton, no
signal. This task adds a compile **WARN** so a typed-event annotation is never silently lost —
the reliability leg committed to 832 on rail dm offset 80. Consumption *semantics* (whether AEF
should DO anything with the event) is separately scoped in **T-2551** (inception); this task is
WARN-only and does not consume.

## Acceptance Criteria

### Agent
- [x] `parse_bpmn` emits a WARN for each `intermediateCatchEvent` carrying an `aef:eventDef`,
  naming the node id, the event `kind`, and stating the annotation is not consumed by AEF (T-2551)
  — verified live via `fw bpmn compile` (3 WARNs, kind+binding each, exit 0); impl `bpmn_to_tasks.py`
  `_event_def` + Pass-3 warn loop
- [x] the WARN does NOT fire for diagrams without typed events — no false positives on existing
  fixtures (`two-lane-sample.bpmn`, `inception-gonogo-sample.bpmn`) — pinned by
  `test_no_typed_event_warn_on_plain_fixtures`
- [x] a synthetic typed-event fixture is added under `tests/fixtures/bpmn/` matching 832's
  documented encoding (`kind`/`binding` on `intermediateCatchEvent`, NO native
  `bpmn:*EventDefinition`) — `tests/fixtures/bpmn/typed-event-sample.bpmn` (error/timer/message)
- [x] a unit test pins: WARN present + correctly shaped for the typed-event fixture, absent for a
  no-typed-event fixture; existing compile behavior stays green — 34/34 pass
  (`test_bpmn_to_tasks.py`, 3 new + 31 existing)

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
python3 -c "import ast; ast.parse(open('tools/bpmn_to_tasks.py').read())"
python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q -k "typed_event or compile"

## RCA

**Symptom:** a workflow diagram carrying 832's typed events (error/timer/message via
`aef:eventDef`) compiles with zero indication the event semantics were dropped — the annotation
vanishes silently.

**Root cause:** `parse_bpmn` only emits skeletons for `TASK_TAGS`
(`{userTask, serviceTask, scriptTask}`). `intermediateCatchEvent` is transited by the flow-walk
(`_nearest_task_preds`, line 279) for `related_tasks` purposes but its `aef:eventDef` extension is
never read — no code path touches `eventDef`, so its `kind`/`binding` are lost with no warning.

**Why structurally allowed:** the compiler predates typed events (832 shipped them in T-204 this
session). The namespace-agnostic parse tolerates unknown tags *by design* (correct for
forward-compat), but that same tolerance means a NEW *meaningful* annotation is indistinguishable
from noise — there is no "I saw an extension I don't consume" signal. Forward-compat silence and
data-loss silence look identical.

**Prevention:** this WARN is the structural signal that a typed-event annotation was seen but not
consumed; the unit test pins it so a typed-event diagram can never again compile silently. The
*decision* of whether to consume the event (vs. only warn) is separately scoped in T-2551.

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

### 2026-07-19T18:35:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2552-fw-bpmn-compile-surface-silently-dropped.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7f2ac777
- **Timestamp:** 2026-07-19T18:41:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-19T18:41:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
