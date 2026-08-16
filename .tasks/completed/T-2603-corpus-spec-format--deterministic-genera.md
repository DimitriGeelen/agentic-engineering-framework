---
id: T-2603
name: "Corpus spec format + deterministic generator (S1): derive specs from served
  maps, emit contract-conformant BPMN via /api/save"
description: >
  T-2602 GO child 1/3. Derive declarative specs from served aef-dispatch-loop + aef-task-lifecycle;
  generator emits contract-v0 BPMN (workflowRef uuid enforced, aef:eventDef vocabulary,
  wiring invariants) through /api/save. Answers IW-2 (bundle round-trip fidelity)
  en route. IW-1 (spec vs canvas authority) needs operator answer at design time.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, tools/corpus_spec.py]
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
created: 2026-07-22T10:48:38Z
last_update: '2026-08-16T22:25:11Z'
date_finished: 2026-07-22T19:20:44Z
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
  - ts: '2026-07-22T10:52:39Z'
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
  - ts: '2026-08-16T22:25:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-22T11:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2603: Corpus spec format + deterministic generator (S1): derive specs from served maps, emit contract-conformant BPMN via /api/save

## Context

T-2602 GO child 1/3 (operator decision 2026-07-22T10:47Z). Design basis:
`docs/reports/T-2602-spec-driven-corpus-authoring.md` (design sketch items 1-2, spike S1,
assumptions A1/A2). Served source maps: `aef-dispatch-loop` v3 (uuid e32a518c…, currently
the intentionally-served defective version — spec derivation captures it AS-IS; the
corrected map ships via T-2605 recreate) and `aef-task-lifecycle` v2. Contract v0 per
T-2571 rail ratification (offsets 107-113): cross-workflow refs use `workflowRef` uuid
form; bare `targetWorkflow` name-form is legacy; `aef:eventDef` is the typed-event
vocabulary (T-204/832). IW-1 (spec-authoritative vs canvas-authoritative + reverse
export) is an OPEN operator question — S1 reverse-derivation is valid under either
answer; generator authority semantics are held until it's answered.

## Acceptance Criteria

### Agent
- [x] Spec schema documented (format doc + annotated example) covering everything the two served maps express: lanes, node types (task kinds, typed events with `kind=`/`binding=`, handoff throw/catch), flows, display labels, positions/layout, notes — `docs/reports/T-2603-corpus-spec-format.md`
- [x] S1 reverse-derivation complete: specs derived from served `aef-dispatch-loop` v3 and `aef-task-lifecycle` v2 with a per-element inventory showing zero unrepresented semantic elements — inventory table in the report (one gap, `pool_name`, found and closed during S1 itself). *T-2608 retrofit: specs are NOT persisted — `fw corpus derive` emits them on demand (single stored representation; the two tracked files originally shipped here were removed under the T-2608 GO)*
- [x] Generator emits BPMN from a spec; regenerated `aef-task-lifecycle` is semantically equivalent to served v2 under the canonical comparator (modulo server-stamped fields) — `fw corpus diff` → IDENTICAL on both maps; mutation negative-test exits 1 (comparator not vacuous)
- [x] Generator enforces contract v0: emits `workflowRef` uuid form only (resolved against the store registry at generate time; unresolvable target → hard refusal unless explicit `ghost_intent: true`) and `aef:eventDef` vocabulary for typed events — regenerated task-lifecycle carries `workflowRef="e32a518c-…"` where served v2 has legacy `targetWorkflow` slug, and the two still compare IDENTICAL (ref normalization)
- [x] Generator writes through `/api/save` only (no direct store writes); generate-save cycle under probe id `t2603-roundtrip` → `{ok:true,v:1}`, ghost registry unchanged (only pre-existing 398f4752), served probe canonically IDENTICAL to original; probe deleted via `/api/delete scope:map`, registry clean after
- [x] IW-1 operator answer recorded in `## Decisions` and the generator's authority semantics (who wins: spec or canvas) match the recorded answer — resolved by T-2608 GO (operator, via Watchtower): the question DISSOLVED — single stored representation, no second artifact to win or lose

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

# Round-trip identity on both S1 source maps — specs derived ON DEMAND (T-2608
# single stored representation: no persisted spec files; dispatch-loop is v1
# post-T-2605 recreate)
python3 tools/corpus_spec.py derive aef-task-lifecycle --v 2 --out /tmp/.t2603-tl.yaml >/dev/null && python3 tools/corpus_spec.py generate /tmp/.t2603-tl.yaml --out /tmp/.t2603-tl.bpmn >/dev/null && python3 tools/corpus_spec.py diff .context/designer/projects/aef-task-lifecycle/v2.bpmn /tmp/.t2603-tl.bpmn
python3 tools/corpus_spec.py derive aef-dispatch-loop --out /tmp/.t2603-dl.yaml >/dev/null && python3 tools/corpus_spec.py generate /tmp/.t2603-dl.yaml --out /tmp/.t2603-dl.bpmn >/dev/null && python3 tools/corpus_spec.py diff "$(ls .context/designer/projects/aef-dispatch-loop/v*.bpmn | sort -V | tail -1)" /tmp/.t2603-dl.bpmn
# Contract v0: generated XML carries uuid workflowRef form, never legacy targetWorkflow
out=$(python3 tools/corpus_spec.py generate /tmp/.t2603-tl.yaml); echo "$out" | grep -q 'workflowRef=' && ! echo "$out" | grep -q 'targetWorkflow='
# fw corpus verb routes
out=$(bin/fw corpus canon aef-task-lifecycle); echo "$out" | grep -q '"pool_name"'

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

### 2026-07-22 — IW-1 (spec vs canvas authority) — dissolved by T-2608 GO

- **Chose:** neither option 1 (spec-authoritative) nor option 2
  (canvas-authoritative + persisted reverse export). Operator's question *"why are
  these two not combined in one file?"* → T-2608 inception → GO recorded via
  Watchtower: **single stored representation** — the canvas BPMN XML in the
  designer store is the only persisted truth; the spec YAML is an on-demand lens
  (`fw corpus derive`) and a transient authoring input, never stored.
- **Why:** the spec is a lossless derived view (this task's own round-trip proof)
  — persisting it stores zero new information and buys the derived-artifact drift
  class the framework already gates 3× over (cron registry→generated,
  tool-set→manifest, source→vendored). With one stored artifact there is no
  "who wins."
- **Rejected:** both original IW-1 options presumed two persisted artifacts;
  full alternatives analysis in `docs/reports/T-2608-single-stored-representation.md`.
  The two spec files this task originally tracked were removed under the GO;
  Verification retrofitted to derive-on-the-fly.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-22T10:48:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2603-corpus-spec-format--deterministic-genera.md
- **Context:** Initial task creation

### 2026-07-22T10:52:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-22T18:20Z — S1 shipped: derive/generate/canon/diff + fw corpus verb [agent]
- **Action:** `tools/corpus_spec.py` (fabric-registered) + `bin/fw corpus` route; specs for both source maps landed at `.context/designer/specs/`; report `docs/reports/T-2603-corpus-spec-format.md`
- **Evidence:** round-trip IDENTICAL both maps; mutation negative-test exit 1; save-leg probe `t2603-roundtrip` → `{ok:true,v:1}` → served twin IDENTICAL → deleted, ghost registry unchanged throughout (398f4752 fixture only)
- **Insight (Evolution-grade):** the one derivation gap S1 caught — participant `pool_name` ≠ workflowMeta `title` — was invisible to the comparator until parse_map captured it; lesson for T-2604 lint: every spec field must be in the canonical form or drift in it is silent. AC6 (IW-1 authority model) remains open awaiting operator answer.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cfd437c1
- **Timestamp:** 2026-07-22T19:20:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-22T19:20:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
