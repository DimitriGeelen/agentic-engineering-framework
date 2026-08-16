---
id: T-2532
name: "Child-2 slice 2: BPMN sequence-flow to AEF horizon + related_tasks (flow-order
  scheduling)"
description: >
  Child-2 slice 2: BPMN sequence-flow to AEF horizon + related_tasks (flow-order scheduling)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tools/bpmn_to_tasks.py]
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
created: 2026-07-12T13:06:20Z
last_update: '2026-08-16T22:25:09Z'
date_finished: 2026-07-12T13:11:09Z
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
  - ts: '2026-08-16T22:25:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2532: Child-2 slice 2: BPMN sequence-flow to AEF horizon + related_tasks (flow-order scheduling)

## Context

Slice 2 of the Child-2 forward compiler (`tools/bpmn_to_tasks.py`, shipped in T-2531). Slice 1 emits
isolated task skeletons; this slice turns them into an **ordered** task set by reading BPMN
`sequenceFlow` edges and mapping flow-order onto AEF's real scheduling primitive:

- **`horizon` from flow-order** — a task's tier = the minimum number of task-nodes on any path from a
  start event to it (task-hops; gateways/events transited, weight 0). Tier 1 → `horizon: now`, tier 2 →
  `next`, tier ≥3 → `later`. This maps the diagram's execution order onto AEF's now/next/later, rather
  than inventing a foreign DAG field.
- **`related_tasks` from nearest task-predecessor** — for each task, its immediate upstream task(s)
  along sequence flow, transiting non-task nodes (gateways, events). Emitted as a list of `aef:uid`s.

Pure standard BPMN (`sequenceFlow` sourceRef/targetRef) — **no aef-specific serialization, so zero
contract risk** and not blocked on 832's pending corpus fixture drop. Gateway *semantics* (G-3
inception mapping) are a later slice; this slice only *transits* gateways when computing task adjacency.

Design of record: `docs/reports/T-2522-bpmn-aef-mapping-contract.md`. Builds on T-2531.

## Acceptance Criteria

### Agent
- [x] Compiler parses `bpmn:sequenceFlow` (sourceRef/targetRef) into a flow graph — verified by unit test
- [x] Each emitted skeleton carries `horizon` mapped from flow-order tier (tier1→`now`, tier2→`next`,
      tier≥3→`later`; unreachable/no-flow → `now`) — verified by unit test on a multi-tier fixture
- [x] Each emitted skeleton carries `related_tasks: [<upstream aef:uid>...]` = nearest task
      predecessor(s) along sequence flow, transiting gateways/events — verified by unit test
      (a task whose predecessor is reached through an exclusiveGateway resolves to that predecessor's uid)
- [x] Output remains parseable YAML frontmatter with the new `horizon`/`related_tasks` fields —
      verified by yaml round-trip of the compiler output
- [x] No regression: existing `tests/unit/test_bpmn_to_tasks.py` slice-1 tests stay green; new slice-2
      tests pass against a checked-in fixture `tests/fixtures/bpmn/flow-order-sample.bpmn`

<!-- No ### Human section: CLI tooling, no render surface — all criteria agent-verifiable. -->

## Verification
python3 -c "import ast; ast.parse(open('tools/bpmn_to_tasks.py').read())"
python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q
python3 -c "import yaml,subprocess; out=subprocess.check_output(['python3','tools/bpmn_to_tasks.py','tests/fixtures/bpmn/flow-order-sample.bpmn']).decode(); docs=[yaml.safe_load(b) for b in out.split('---') if b.strip()]; assert all('horizon' in d for d in docs), 'missing horizon'"

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

### 2026-07-12T13:06:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2532-child-2-slice-2-bpmn-sequence-flow-to-ae.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23f8b887
- **Timestamp:** 2026-07-12T13:11:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-12T13:11:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
