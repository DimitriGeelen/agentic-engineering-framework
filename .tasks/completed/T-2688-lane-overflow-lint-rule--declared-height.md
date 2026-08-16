---
id: T-2688
name: "lane-overflow lint rule — declared height cannot contain lane members"
description: >
  lane-overflow lint rule — declared height cannot contain lane members

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/test_corpus_lint_lane_overflow.py, tools/corpus_lint.py]
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
created: 2026-07-29T22:29:42Z
last_update: '2026-08-16T22:25:14Z'
date_finished: 2026-07-29T22:39:11Z
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
  - ts: '2026-08-16T22:25:14Z'
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
---

# T-2688: lane-overflow lint rule — declared height cannot contain lane members

## Context

Build slice authorised by the **T-2687 GO** (operator, 2026-07-30). Artifact:
`docs/reports/T-2687-band-feasibility-lint.md`.

The shipped `lane-geometry` rule (T-2684) compares lanes *against each other*, so it is
structurally blind to a lane whose **own members span more than its declared height** —
ordering is correct, nothing crosses, and yet the band cannot contain its content, so the
render overflows. T-2687 proved the blindness on a synthetic map (lane spanning 190px inside
`height=100`: ordering CLEAN, capacity INFEASIBLE) and found a live instance:
`draft-knowledge-leveling`'s agent lane spans **513px inside `height=260`**, a 253px
overflow on the v8 promotion candidate that the ordering rule never named.

**Threshold is derived, not chosen.** With half-open bands (`[O, O+h)`, the semantics T-2687
established after the closed-interval boundary bug in F1), containing a lane's members
requires `O ≤ min_y` and `max_y < O + h`, which is satisfiable exactly when
`span < height`. So the overflow condition is **`span >= height`**, not `span > height`.
The boundary case is a real overflow: a node whose top sits exactly on the band's bottom
edge is already outside a half-open band.

**What this slice deliberately does NOT do.** Every measurement here is on node **top-y**,
so it *understates* overflow by the node box height `H`: full-box containment needs
`span + H < height`, i.e. overflow at `span >= height - H`. `H` is a renderer constant we do
not read (T-559 boundary), asked of 832 at rail 338 and **not yet answered**. The
conservative `span >= height` form needs no constant and cannot false-positive — node height
only ever makes overflow worse, never better — so it ships now; the `H`-dependent tight-lane
detection stays out until 832 answers. That is the difference between a conservative subset
and a guess (T-2684's band model was the guess).

Known tight lanes awaiting `H`, recorded so the follow-up has its data: knowledge-leveling
framework 18px headroom, session-lifecycle agent 60, task-lifecycle agent 70, inception-flow
agent 80.

## Acceptance Criteria

### Agent
- [x] `lane-overflow` rule in `tools/corpus_lint.py` fires when a lane's member y-span is
      `>= ` its declared `aef:laneMeta height`, evaluated per-lane
- [x] Threshold correctness pinned both ways: `span == height` fires (half-open boundary is
      an overflow), `span == height - 1` is silent
- [x] Finding names the lane, the span, the declared height, the shortfall in pixels, and
      the two extremal member nodes bounding the span — so an author can act without
      opening the map
- [x] Message names **both** fix options (raise the declared height / compress node
      placement) and prescribes neither — per T-2687 IW-4, the rule can localise the defect
      but cannot decide the authoring call
- [x] Skips per-lane (not per-map) when that lane is unpopulated or has an unpositioned
      member; an unevaluable lane must SKIP, never silently pass
- [x] Fires on `draft-knowledge-leveling` naming its agent lane and the 253px shortfall;
      silent on the other 10 store maps
- [x] Live default-scan baseline unchanged at exactly 3 findings (drafts are skipped by the
      default scan, so the new finding surfaces only when the draft is named explicitly)
- [x] Rule documented in the module docstring rule catalogue with its T-2687 origin, and the
      deferred `H`-dependent leg named there so the next reader knows it is a conservative
      subset rather than the whole class
- [x] 5/5 conformance rails still PASS and the corpus suites stay green

### Human

<!-- Removed deliberately (T-2143 audience axis). Every criterion here is deterministic,
     and the one judgment-shaped question — does the finding message read clearly? — has
     an AGENT audience: lint output is read by agents running `fw corpus lint`, not by the
     operator. Routing it to a Human prefix would be the single-axis routing error T-2143
     documents (subjective + agent-audience routes wrong every time). The message quality
     is pinned instead by Agent ACs asserting it names the span, the height, the pixel
     excess, both extremal nodes, and both fix options. -->

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

# 1. Rule pinned both ways incl. the derived span>=height boundary, per-lane skip,
#    the orthogonality proof vs lane-geometry, and the live 253px instance.
python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py -q
# 2. No regression in the sibling geometry rule, explain staging, or the T-2686 guard.
python3 -m pytest tests/unit/test_corpus_lint.py tests/unit/test_corpus_lint_lane_geometry.py tests/unit/test_corpus_explain.py tests/unit/test_t2686_laneset_order.py -q
# 3. Default-scan baseline unmoved at exactly 3 (drafts skipped, so the new finding
#    must NOT leak into the pinned baseline).
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "^3 finding(s)"
# 4. The live instance is reachable when the draft is named, and reports the agent lane.
out=$(bin/fw corpus lint draft-knowledge-leveling 2>&1); echo "$out" | grep -q "lane-overflow"
# 5. All five conformance rails still green.
python3 tools/corpus_conformance.py --all

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

### 2026-07-29T22:29:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2688-lane-overflow-lint-rule--declared-height.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-63c199d5
- **Timestamp:** 2026-07-29T22:39:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `lane-overflow` rule in `tools/corpus_lint.py` fires when a lane's member y-span is
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tools/corpus_lint.py in: `lane-overflow` rule in `tools/corpus_lint.py` fires when a lane's member y-span is`

### 2026-07-29T22:39:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
