---
id: T-2531
name: "Child-2 forward compiler: BPMN diagram to AEF task skeletons (first slice)"
description: >
  Child-2 forward compiler: BPMN diagram to AEF task skeletons (first slice)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-11T21:39:29Z
last_update: 2026-07-11T21:50:57Z
date_finished: 2026-07-11T21:50:57Z
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
  - ts: '2026-07-11T21:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-11T21:45:09Z'
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

# T-2531: Child-2 forward compiler: BPMN diagram to AEF task skeletons (first slice)

## Context

**This is the Child-2 build slice authorized by the operator's "GO Child-2" decision** (2026-07-11),
made across the T-2522/T-2523 inception dialogue. Child-2 is the **forward bridge**: a compiler that
turns a BPMN process diagram into AEF task skeletons — the primary value path of the workflow-designer
integration (AEF-led; 832 owns the reverse/editor seam).

Design inputs are **settled** (do not re-litigate here):
- **IW-1 keystone (ratified):** `aef:uid` lives in `<bpmn:extensionElements><aef:uid>…</aef:uid>` on
  each node — the stable task identity. 832 proved the seam round-trips both ways (T-187 editor fixed
  point, T-188 bridge↔editor across 24 workflows / 620+ uids).
- **IW-7 (ratified):** Lane = authority-of-record for who-performs. `owner: human` ⇔ human/user lane;
  `owner: agent` ⇔ agent/service lane.
- **IW-9 (832-sharpened, pending operator ratify — do NOT depend on it this slice):** keep
  `workflow_type` (orthogonal what-kind axis); collapse node-level `owner` override into the lane.
  This slice reads owner **from the lane only**, which is forward-compatible with the sharpening.
- **Ratified rulings:** gateway is constitutive (a gateway node is a real control-flow construct, not a
  marker); **tier default = 1**; **AC-seeding = skeleton, not placeholder** (emit a real skeleton
  frontmatter, never a `[First criterion]` stub).
- **Contract of record:** `docs/reports/T-2522-bpmn-aef-mapping-contract.md`.
- **Corpus:** 832 ships 24 rendered maps as a vendored fixture (`examples/aef-processes/rendered/<id>.bpmn`);
  delivery method still open on the rail. This slice does NOT require the full corpus — a single checked-in
  fixture BPMN suffices.

**Slice scope (bounded):** parse ONE `.bpmn`, extract task nodes + `aef:uid` + lane, emit valid AEF
task-skeleton frontmatter to stdout. No CLI route, no Watchtower page, no round-trip write-back — those
are later Child-2 slices. Reverse direction (tasks→diagram) is out of scope (832 owns it).

## Acceptance Criteria

### Agent
- [x] `tools/bpmn_to_tasks.py` (new) parses a BPMN 2.0 `.bpmn` file and extracts each task node
      (`bpmn:userTask` / `bpmn:serviceTask` / `bpmn:scriptTask`) together with its `aef:uid` read from
      `<bpmn:extensionElements>` (IW-1 keystone) — verified by unit test against a checked-in fixture
- [x] Lane→owner mapping (IW-7): a task node in a human/user lane emits `owner: human`; a task node in
      an agent/service lane emits `owner: agent`. Owner is derived from the **lane only** (no node-level
      override), forward-compatible with the IW-9 sharpening — verified by unit test covering both lanes
- [x] Emitted skeleton is a **real skeleton, not a placeholder** (AC-seeding ruling): frontmatter carries
      `id` (from `aef:uid`), `name` (from node name), `owner` (from lane), `workflow_type` (default
      `build`, `tier: 1` default per ruling) — no template-stub AC text in the emitted skeleton
- [x] Compiler output is parseable YAML frontmatter — verified `python3 -c "import yaml; yaml.safe_load(...)"`
      round-trips each emitted skeleton
- [x] Unit test `tests/unit/test_bpmn_to_tasks.py` passes against a checked-in fixture BPMN
      (`tests/fixtures/bpmn/two-lane-sample.bpmn`) with ≥2 task nodes spanning both lanes

<!-- No ### Human section: this is CLI tooling with no render surface — all criteria are
     agent-verifiable (parser correctness + fixture-driven unit test). The render-surface gate
     (P-013) does not apply (no web/templates|static|blueprints touched). -->

## Verification
python3 -c "import ast; ast.parse(open('tools/bpmn_to_tasks.py').read())"
python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q
python3 -c "import yaml,subprocess; out=subprocess.check_output(['python3','tools/bpmn_to_tasks.py','tests/fixtures/bpmn/two-lane-sample.bpmn']).decode(); [yaml.safe_load(b) for b in out.split('---') if b.strip()]"

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

### 2026-07-11T21:39:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2531-child-2-forward-compiler-bpmn-diagram-to.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c78f7999
- **Timestamp:** 2026-07-11T21:50:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-11T21:50:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
