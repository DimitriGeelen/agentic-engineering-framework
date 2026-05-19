---
id: T-1935
name: "BVP T-NEW-7c: bvp-cost-estimator — propose cost_estimate (blast_radius / tier
  / effort) per task"
description: >
  Companion to T-1922 bvp-estimator. Where T-1922 proposes BVP scores per directive,
  T-1935 proposes cost_estimate per task (the F8 x-axis). Without it, T-1934 dots
  cluster at default-medium. v1 heuristic: blast_radius from fw fabric blast-radius
  (only when source file is touched, else 0), tier from tags+workflow_type lookup,
  effort from content-length heuristic (AC count + body line count). Sovereignty:
  writes only to cost_estimate_proposed: (advisory). Human confirms via fw bvp confirm-cost.
  Deterministic R3 contract. Q4 SLA: 10s synchronous cap. Same TermLink worker harness
  as T-1922.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-7c, termlink, cost, arc-006]
components: [agents/termlink/bvp-estimator/, web/blueprints/bvp.py, lib/bvp.sh]
related_tasks: [T-1915, T-1916, T-1922, T-1923, T-1934]
arc_id: value-prioritisation
created: 2026-05-19T19:01:40Z
last_update: '2026-05-19T19:08:39Z'
date_finished:
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
  - ts: '2026-05-19T19:05:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T19:08:39Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1935: BVP T-NEW-7c — bvp-cost-estimator (propose cost_estimate per task)

## Context

T-1922 proposes BVP scores per directive. T-1934 ships the proposed-mode
scatter. But 60+ tasks today carry `bvp_scores_proposed:` and zero
carry `cost_estimate:` — so without an estimator, T-1934 falls back to
`default-medium` (x=4) for every point and the scatter clusters at a
single x-coordinate.

T-1935 closes the F8 cost-axis gap with the same harness pattern as
T-1922: deterministic heuristic engine, advisory-only writes,
sovereignty-preserving, R3-bit-deterministic.

**Source:** arc-006 (value-prioritisation) §F8; T-1934 §Limitations.

**Engine choice:** v1-heuristic (same rationale as T-1922 — bit-deterministic
satisfies R3; ~10ms latency; zero token cost; auditable). v2-LLM is a
clean follow-up.

**Heuristic per component:**
- `blast_radius` — from `fw fabric blast-radius HEAD` only when the
  task body cites changed files. Else 0 (no work touches source) or
  fallback to T-shirt size if author specified one.
- `tier` — table lookup: `tags ∩ {tier-0, tier-1, ...}` → integer; else
  workflow_type heuristic (build=2, refactor=3, test=1, inception=4
  while exploring).
- `effort` — `min(8, max(1, body_line_count / 50 + ac_count))`. Capped
  at 8 to stay within T-shirt-XL bound.

## Acceptance Criteria

### Agent
- [x] `agents/termlink/bvp-estimator/estimator.py:estimate_cost(task_path) -> dict` returns `{cost_estimate, evidence, version, rubric_sha, latency_s}` with `cost_estimate` shape `{blast_radius, tier, effort}` integers. — Verified by `test_estimate_cost_returns_required_fields`.
- [x] Sovereignty: estimator writes ONLY to `cost_estimate_proposed:` (advisory list, parallel structure to `bvp_scores_proposed:`). `cost_estimate:` (confirmed) is human-only via `fw bvp confirm-cost`. — Verified by `test_write_proposed_cost_never_touches_confirmed` + `test_cmd_cost_sweep_skips_confirmed`.
- [x] M3 v2-delta semantics: skip writing when proposal is within ±1 on every component vs. confirmed. — Verified by `test_cost_v2_delta_skip_when_within_1` + `_no_skip_when_any_component_delta_2`.
- [x] Determinism R3: 10 consecutive `estimate_cost` calls on the same task yield bit-identical output (latency excluded). — Verified by `test_estimate_cost_deterministic_10_runs` + live `fw bvp estimate-cost determinism T-1922 --runs 10` → `delta=0 (deterministic=True)`.
- [x] CLI verbs added: `fw bvp estimate-cost T-XXX`, `fw bvp estimate-cost all`, `fw bvp estimate-cost sweep --cron`, `fw bvp estimate-cost determinism T-XXX`. — Live-tested in session: `fw bvp estimate-cost T-1935 --json` returns the canonical envelope; `... sweep --cron` runs idempotently.
- [x] Cron entry `bvp-cost-estimator-sweep-15m` added to `.context/cron-registry.yaml` (mirrors T-1923's sweep entry); `fw doctor` reports "Cron registry in sync". — Verified via `fw cron generate && fw cron install` + `fw doctor` "OK Cron registry in sync".
- [x] `web/blueprints/bvp.py:_compute_cost` reads `cost_estimate_proposed:` (latest entry) when `cost_estimate:` is absent and `default_when_absent=True` is set; the default-medium fallback then becomes a last-resort instead of the common case. — Verified by `test_resolve_cost_estimate_reads_proposed_when_proposed_mode` + `_ignores_proposed_when_confirmed_mode` (T-1934 confirmed-strict preserved).
- [x] Unit tests pin: per-component shape contract, determinism (10-run delta=0), M3 v2-delta (skip/no-skip), sovereignty (writes only to proposed), `_compute_cost` reads proposed path. — 13 new tests in `test_bvp_estimator.py` + 5 new tests in `test_bvp_blueprint_cost.py`. 53/53 PASS.
- [x] After full sweep, `curl /bvp` returns >0 task points NOT at x=4 (i.e., the dots spread across the x-axis). — Verified: 57/72 (79%) of task points now render at `three-component-proposed` cost source with composite cost ∈ [0.8, 2.2]. The 15 remaining default-medium points are completed-status tasks the sweep doesn't touch (correct scope per AC#3 in T-1923 carried forward).

### Human
<!-- All ACs above are deterministic/structural — no [REVIEW] Human ACs required.
     If visual blast-radius distribution looks wrong on the scatter, that's
     fed back as a follow-up rather than blocking this slice. -->

## Verification

grep -q "estimate_cost" agents/termlink/bvp-estimator/estimator.py
grep -q "cost_estimate_proposed" agents/termlink/bvp-estimator/estimator.py
grep -q "bvp-cost-estimator-sweep-15m" .context/cron-registry.yaml
out=$(bin/fw doctor 2>&1 || true); [ "$(printf %s "$out" | grep -c 'Cron registry in sync')" -ge 1 ]
out=$(python3 -m pytest tests/unit/test_bvp_estimator.py tests/unit/test_bvp_blueprint_cost.py 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'passed')" -ge 1 ]
out=$(bin/fw bvp estimate-cost determinism T-1922 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'delta=0|deterministic')" -ge 1 ]

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

## Recommendation

**Recommendation:** GO

**Rationale:** Cost-estimator closes the F8 cost-axis gap that T-1934
surfaced. With the heuristic engine populating
`cost_estimate_proposed:` on every active task (start-work / captured
status), 79% of `/bvp` dots now render at their proper cost-composite
position instead of clustering at `default-medium`. Sovereignty is
preserved end-to-end: estimator never writes to confirmed
`cost_estimate:`; T-1934's confirmed-strict semantics carry through
the routing layer (`_resolve_cost_estimate`).

This is a pure-additive slice — no T-1934 regression possible because
the new path only activates in proposed-mode and falls back to the
existing `default-medium` if no proposed cost exists either.

**Evidence:**

- `agents/termlink/bvp-estimator/estimator.py` (+260 LOC) — new
  symbols `score_blast_radius`, `score_tier`, `score_effort`,
  `estimate_cost`, `_cost_v2_delta_should_skip`,
  `_cost_short_rationale`, `write_proposed_cost`,
  `_cost_proposed_is_stale`, `cmd_cost_one`, `cmd_cost_all`,
  `cmd_cost_sweep`, `cmd_cost_determinism`. CLI verbs `cost-one`,
  `cost-all`, `cost-sweep`, `cost-determinism` wired.
- `lib/bvp.sh` — `fw bvp estimate-cost` verb routing added (mirrors
  `fw bvp estimate`). Single-task convenience: `fw bvp estimate-cost
  T-XXX` → `cost-one T-XXX`. Subverb mapping: `sweep`→`cost-sweep`,
  `all`→`cost-all`, `determinism`→`cost-determinism`.
- `web/blueprints/bvp.py` — `_latest_proposed_cost_estimate` +
  `_resolve_cost_estimate` (with `is_proposed` parameter to preserve
  confirmed-strict routing). `_collect_task_points` /
  `_collect_arc_points` extended to surface
  `three-component-proposed` source. (No template changes — the
  proposed cost flows through the existing 4-class d3 selection from
  T-1934.)
- `.context/cron-registry.yaml` — `bvp-cost-estimator-sweep-15m`
  entry; `fw doctor` reports "Cron registry in sync". Cron deployed
  via `fw cron generate && fw cron install` to
  `/etc/cron.d/agentic-audit-999-agentic-engineering-framework`.
- `tests/unit/test_bvp_estimator.py` (+13 tests) + `test_bvp_blueprint_cost.py` (+5 tests) — 53/53 PASS. Coverage: shape, ladder, tag-wins-over-workflow, clamping, R3 determinism (10-run delta=0), v2-delta (3 paths), sovereignty (2 paths), staleness (3 paths), routing precedence.
- **Live page state:** `curl /bvp` →
  `cost_source: {'three-component-proposed': 57, 'default-medium': 15}`
  — 79% of points at their real cost composite, 15 default-medium
  stragglers are completed-status tasks the sweep correctly skips.
- **Determinism:** `fw bvp estimate-cost determinism T-1922 --runs 10` →
  `delta=0 (deterministic=True)`. R3 ship-blocking AC met.

**Limitations / future work:**

- v1 heuristic uses `components:` count as blast_radius proxy. Not
  identical to the `fw fabric blast-radius` graph traversal (which
  would be more accurate but requires resolving each component to a
  fabric ID). v2-LLM or v2-fabric is a clean follow-up.
- Tier heuristic: workflow_type defaults heavily to `build=2`. Tasks
  that should be tier-1 or tier-3 need explicit `tier-N` tags.
- No `fw bvp confirm-cost` verb yet — humans currently set
  `cost_estimate:` directly in frontmatter. Confirm-cost verb is the
  natural sibling to `fw bvp confirm` (T-1924) and can ship as
  T-1937 (separate slice).

**arc-006 status:** 19 build slices feature-complete on the agent
side (17 originals + T-1934 + T-1935). Visual half of T-1928/29/30
reviews now fully populated.

## Decisions

### 2026-05-19 — `components:` field as blast-radius proxy

**Choice:** v1 heuristic counts the `components:` frontmatter list to
estimate blast_radius (0/1/3/5/7/9 ladder by count).

**Why:** `components:` is already authored by hand on most tasks and is
trivially accessible from the frontmatter parser. The full
`fw fabric blast-radius` resolution (graph traversal from changed files
to dependents) is more accurate but requires component-ID resolution
on every task, which (a) costs 10-100× the latency and (b) doesn't run
deterministically without a fabric snapshot at task-write time. v2 can
swap in fabric blast-radius when the cron cost is acceptable.

### 2026-05-19 — Confirmed-strict routing preserved

**Choice:** `_resolve_cost_estimate(fm, is_proposed=...)` only reads
from `cost_estimate_proposed:` when `is_proposed=True` (i.e., the BVP
point itself is in proposed-mode). Confirmed BVP points with no
`cost_estimate:` continue to skip (legacy T-1934 behavior).

**Why:** A confirmed BVP score reflects deliberate human authority
on the y-axis. Borrowing an estimator-proposed cost on the x-axis
would silently mix sovereignty boundaries — the point would render
with "two-bar confidence" (confirmed y, proposed x) but with no visual
indicator. Better to drop the point until the human also confirms
cost, OR sets a confirmed cost_estimate. The cost is honest: missing
data shows as missing.

### 2026-05-19 — `cost_source: "three-component-proposed"` label

**Choice:** When proposed cost flows through `_compute_cost`, the
returned `cost_source` is suffixed with `-proposed` (e.g.,
`"three-component-proposed"` or `"tshirt-proposed"`).

**Why:** Diagnosability (artefact §4 F8 traceability). A reviewer
hovering an outlined dot can see in the tooltip whether the cost came
from a confirmed three-component breakdown, a confirmed T-shirt, or an
estimator's component-count heuristic. This protects against the
class of "where did this number come from?" surprises.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-19T19:01:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1935-bvp-t-new-7c-bvp-cost-estimator--propose.md
- **Context:** Initial task creation

### 2026-05-19T19:05:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
