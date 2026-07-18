---
id: T-2540
name: "BPMN O-3 VETO: name-only Human lane must raise not warn (832 offset 49 conformance) + PL-035 early-return audit"
description: >
  BPMN O-3 VETO: name-only Human lane must raise not warn (832 offset 49 conformance) + PL-035 early-return audit

status: started-work
workflow_type: build
owner: agent
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
created: 2026-07-18T07:37:42Z
last_update: 2026-07-18T07:37:42Z
date_finished: null
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

# T-2540: BPMN O-3 VETO: name-only Human lane must raise not warn (832 offset 49 conformance) + PL-035 early-return audit

## Context

832 workflow-designer VETOed (DM rail offset 49, cid t2399-auto-063412) the name-only-"Human"-lane
leniency shipped in T-2537. Per mapping-v1 §3 (IW-9, v1.1) `aef:laneMeta authority` is the SOLE
authority-of-record — a lane *name* ("Human") is not an authority carrier. So the ONLY shape that
satisfies O-3 (inception go/no-go MUST be sovereignty-laned) is `authority="sovereignty"`;
name-only-Human, laneMeta-without-@authority, non-sovereignty authority, and no-lane all fail §7
identically. This is a conformance fix to an already-frozen v1.1 fence (832 confirmed: "reading out
a frozen fence, not a new graduation — needs no sovereign GO"), closing a cross-implementation split
(my compiler ACCEPTs+warns what 832's reference validator REJECTs).

Offset 50 flagged PL-035 (their own no-laneSet early-`return` skipping O-3) and asked me to audit my
fail-fast path for the same shape. Audit result: my inception check is inline in the main node loop
(no early return/continue before it), so PL-035 does NOT lurk here — but I add a regression-lock test.

## Acceptance Criteria

### Agent
- [x] `is_inception` branch raises `MalformedInceptionError` unless `authority == "sovereignty"` (name heuristic no longer satisfies O-3); the pre-laneMeta compat WARN branch is deleted
- [x] `tests/fixtures/bpmn/inception-nameonly-lane-sample.bpmn` moves from the warn set to the raises set (fixture unchanged; test assertion flipped)
- [x] New regression-lock test proves a no-laneSet inception raises (PL-035 existence-rule lock)
- [x] AGENT.md + vendored `.agentic-framework/agents/bpmn/AGENT.md` roadmap updated to reflect the VETO tightening (O-3 = sovereignty-only, no name-only accept)
- [x] Full bpmn test suite green: `python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q`

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable. -->

All criteria are agent-verifiable (deterministic conformance behaviour + tests). No Human AC.

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

python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q
# name-only Human lane must now exit non-zero (raises) — was accept+warn before
out=$(python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/inception-nameonly-lane-sample.bpmn 2>&1); rc=$?; [ "$rc" -ne 0 ] && echo "$out" | grep -q "sovereignty"
# valid sovereignty inception still compiles (owner: human, exit 0)
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/inception-gonogo-sample.bpmn | grep -q "owner: human"

## RCA

**Symptom:** AEF's `bpmn_to_tasks.py` compiler ACCEPTED a name-only "Human" lane on an inception
subProcess (emitting `owner: human` + a "pre-laneMeta compat" WARN), while 832's reference validator
REJECTED the same diagram with `E-INCEPTION-NOT-SOVEREIGN`. Two conformant implementations disagreed
on the same v1.1 MUST — a diagram's fate depended on which tool it met (832 rail offset 49).

**Root cause:** T-2537 offered an antifragile "accept-with-warning" ramp for pre-laneMeta legacy
diagrams whose lane was human-*named* but carried no `laneMeta@authority`. That ramp treated a lane
NAME as a (weak) authority signal. But mapping-v1 §3 makes `laneMeta@authority` the SOLE
authority-of-record; a name is a string a human typed, not a governance assertion. The compat case
provably cannot arise (832: 80/80 corpus lanes carry explicit authority; editor serializer emits it
unconditionally; importer defaults missing→'none', never name-derived). The ramp was a compat bridge
to nowhere that silently forked conformance.

**Why structurally allowed:** the O-3 check keyed off the *derived* `lane_owner` (which folds in the
name heuristic via `_lane_owner`) instead of the *authority-of-record* directly. Folding the name
heuristic into the same variable that gates a sovereignty MUST let a presentational signal (name)
satisfy a structural requirement (authority). Cross-implementation divergence had no test because
each side only tested its own fixtures — neither corpus contained the name-only shape (it can't be
produced by a conformant editor), so the split was invisible until 832 read out the frozen fence.

**Prevention:** (1) the O-3 gate now keys off `authority == "sovereignty"` directly — the name
heuristic is structurally excluded from inception owner resolution; (2) fixture
`inception-nameonly-lane-sample.bpmn` is pinned in the RAISES set (regression-locks the exact shape);
(3) a no-laneSet inception test pins the PL-035 existence-rule (absence == violation, fail hardest);
(4) roadmap + this RCA capture the O-1(comparison, no-op on absence) vs O-3(existence, fire on
absence) asymmetry 832 flagged as PL-035 — a lane-lookup that resolves lanes before the existence
check would re-introduce it. Audit confirms my inception check is inline in the node loop with no
early return, so PL-035 does not currently lurk.

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

### 2026-07-18T07:37:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2540-bpmn-o-3-veto-name-only-human-lane-must-.md
- **Context:** Initial task creation
