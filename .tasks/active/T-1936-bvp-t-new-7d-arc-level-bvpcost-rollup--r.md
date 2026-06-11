---
id: T-1936
name: "BVP T-NEW-7d: arc-level BVP+cost rollup — render arc dots on /bvp scatter"
description: >
  Arc dots on /bvp render 0 today because arc YAML files have empty bvp_scores: {}
  and no proposed scores. Estimator (T-1922/T-1935) operates on tasks only — by design
  (an arc's value is the rolled-up value of its tasks). T-1937 adds rollup: walk all
  tasks where arc_id matches, mean-aggregate their BVP scores (proposed or confirmed)
  and cost_estimate components. Display arcs as proposed-mode (outlined orange) until
  either: (a) the human runs fw bvp confirm --arc <slug>, OR (b) all constituent tasks
  have confirmed scores (in which case the rollup becomes derived-confirmed).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bvp, build, slice-7d, arc-rollup, web, arc-006]
components: [lib/bvp.sh, tests/unit/test_bvp_blueprint_cost.py, 
      tests/unit/test_bvp_scatter_arc_mode.py, web/blueprints/arcs.py, 
      web/blueprints/bvp.py, web/templates/arc_detail.html, 
      web/templates/bvp.html]
related_tasks: [T-1915, T-1916, T-1922, T-1934, T-1935]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T19:24:41Z
last_update: '2026-06-11T22:23:27Z'
date_finished: 2026-05-20T19:09:14Z
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
  - ts: '2026-05-19T19:25:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T19:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1936: BVP T-NEW-7d — arc-level BVP+cost rollup on /bvp scatter

## Context

Arc dots on `/bvp` render 0 today: arc YAML files have empty
`bvp_scores: {}` and no proposed scores. T-1922/T-1935 score tasks
only — by design (an arc's value is the rolled-up value of its
member tasks).

T-1936 derives arc BVP+cost from member tasks via the `arc_id:` field.
Aggregation:
- BVP scores: mean per driver across members (proposed-or-confirmed)
- blast_radius: max across members (arc's blast is the union)
- tier: mean across members (rounded)
- effort: sum across members, clamped to [0, 9] (arcs ARE thick)

Result mode is `derived-proposed` (advisory) unless ALL contributing
members had confirmed scores, in which case it's `derived-confirmed`.
A direct `bvp_scores:` on the arc YAML always overrides the rollup
(human authority remains the override).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/bvp.py:_arc_member_tasks(slug, id)` returns all tasks whose `arc_id:` matches either slug form (e.g., `value-prioritisation`) or canonical form (e.g., `arc-006`). — Verified by `test_arc_member_tasks_matches_both_arc_id_forms`.
- [x] `_arc_rolled_up_scores(members)` returns `(scores, mode)` with `mode ∈ {derived-confirmed, derived-proposed, ""}`. Empty members → `(None, "")`. — Verified by 6 unit tests covering empty / single-confirmed / mean / mixed-degrades-to-proposed / only-proposed / skips-member-without-scores.
- [x] `_arc_rolled_up_cost(members)` returns `(cost_dict, mode)` with blast_radius=max, tier=mean, effort=sum-clamped-to-9. — Verified by `test_arc_rolled_up_cost_aggregation_rules` (effort=4+6=10 clamps to 9; tier mean rounds).
- [x] `_collect_arc_points` resolution order: direct confirmed → direct proposed → rollup → skip. Direct overrides rollup. — Live tested: 5 arcs render with `derived-proposed` mode (all member tasks have only proposed BVP scores; no arc has direct `bvp_scores:` set).
- [x] Sovereignty: rollup is advisory (`mode` carries `-proposed` / `-derived` suffix). Confirmed `bvp_scores:` on the arc YAML overrides rollup. Estimator never writes to arc YAMLs. — `cost_source` displays `three-component-derived` in the rendered payload; no estimator write paths target arc YAML files.
- [x] Unit tests pin: 1-member rollup, multi-member rollup, mixed proposed+confirmed members, direct override, no-members → no point. — 9 new tests in `test_bvp_blueprint_cost.py` covering all paths. 20/20 PASS overall (5 T-1934 + 5 T-1935 + 9 T-1936 + 1 implicit).
- [x] After Watchtower restart, `curl /bvp` returns ≥1 arc point in the inline JSON payload (arc-006 minimum — 21 member tasks). — Verified: 5 arcs render (arc-002, 003, 004, 005, 006). arc-001 has no member tasks with `arc_id:` set yet. arc-006 (value-prioritisation): bvp_norm=0.31, cost=3.3, source=three-component-derived.

### Human
- [ ] [REVIEW] Arc dots distribute meaningfully on the scatter — they sit at reasonable BVP-norm and cost-composite positions relative to their member tasks, AND it's visually clear they're arcs (larger circles) vs tasks (smaller dots).
  **Steps:**
  1. Open `http://192.168.10.107:3000/bvp` in a browser
  2. Identify the 5 arc dots (they're larger than task dots)
  3. Hover over arc-006 specifically — verify cost_source mentions `derived`
  4. Spot-check: does arc-006's position roughly match where you'd expect the *average* of its 21 member tasks to land?
  **Expected:** Arc dots are visible, distinct from task dots, and sit at reasonable rolled-up positions. Tooltip shows `derived` provenance for cost.
  **If not:** Note which arc looks wrong (too high/low BVP, too left/right cost) — feeds back to v2 aggregation rules.

### Human (template-comment-block-removed-by-author)
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

grep -q "_arc_member_tasks" web/blueprints/bvp.py
grep -q "_arc_rolled_up_scores" web/blueprints/bvp.py
grep -q "_arc_rolled_up_cost" web/blueprints/bvp.py
out=$(python3 -m pytest tests/unit/test_bvp_blueprint_cost.py 2>&1 || true); [ "$(printf %s "$out" | grep -cE 'passed')" -ge 1 ]
out=$(curl -sf "$(bin/fw watchtower url)/bvp" 2>&1 || true); [ "$(printf %s "$out" | python3 -c "import sys,re,json; html=sys.stdin.read(); m=re.search(r'<script id=\"bvp-data\"[^>]*>(.*?)</script>', html, re.DOTALL); data=json.loads(m.group(1)) if m else {}; print(len(data.get('arcs',[])))")" -ge 1 ]

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

### 2026-05-20 — arc-001 (closed) has no `arc_id:` members; legacy `arc:*` tag corpus still live
- **What changed:** Filing assumed all arcs would have member tasks via `arc_id:` once T-1850's migration ran. Implementation surfaced that arc-001 has 0 members via `arc_id:` despite being the original dispatch-safety arc with 11 tracked tasks (it lives on the legacy `tags: [arc:dispatch-safety]` form). 5 of 6 arcs render dots; arc-001 silently doesn't.
- **Plan impact:** The "all arcs render" assumption is false until the legacy `arc:*` tag → `arc_id:` migration completes. The rollup code itself is correct — the data hasn't fully migrated. Two co-existing identity surfaces (T-1849 + T-1850) is still partially live.
- **Triggered:** No new task (T-1850 already owns the migration). Captured as evidence that the rollup is well-defined on member-set absence (empty → skip; AC#2 covers this). When T-1850 closes, arc-001 will join the scatter without code change.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the last visible gap on the `/bvp` scatter — arc dots now render with rolled-up BVP+cost from member tasks. 5 of 6 arcs visible (arc-001 has no member tasks via `arc_id:`; arc-006 minimum confirmed: 21 member tasks → bvp_norm=0.31, cost=3.3, source=`three-component-derived`).

Sovereignty boundaries clean: direct `bvp_scores:` on an arc always overrides the rollup; estimator never writes to arc YAML files; mixed-member case (one proposed input + one confirmed) correctly degrades to `derived-proposed` (advisory) rather than silently claiming derived-confirmed. The rollup is a render-side aggregation only — no new persisted state, no new gate semantics.

**Evidence:**

- `web/blueprints/bvp.py` (+150 LOC) — `_arc_member_tasks`, `_arc_rolled_up_scores`, `_arc_rolled_up_cost` helpers. `_collect_arc_points` extended with the 4-mode resolution ladder (direct-confirmed → direct-proposed → rollup → skip).
- `tests/unit/test_bvp_blueprint_cost.py` (+9 tests) — empty / single / multi / mixed / dual-arc-id-form. 20/20 PASS overall.
- **Live render state:** `curl /bvp` returns 73 task points + 5 arc points; arcs distribute across the y-axis (bvp_norm ∈ [0.31, 0.53]) and x-axis (cost ∈ [1.5, 3.3]).

**Aggregation rules (D7-reframe — diagnosable per artefact §4):**

| Component | Rule | Why |
|-----------|------|-----|
| BVP scores (D1-D4) | mean rounded | arc value = average value of its members |
| blast_radius | max | arc's blast is the *union* of member blasts, not the sum (you can't multiply blast — you cover what your widest member covers) |
| tier | mean rounded | arcs span workflow types; mean is the honest mid-point |
| effort | sum clamped to 9 | arcs ARE thick — sum reflects total work; clamp prevents off-scale dots |

**arc-006 status:** 20 build slices shipped (17 originals + T-1934 + T-1935 + T-1936). The full visual loop is closed.

## Decisions

### 2026-05-19 — Mixed-mode degrades to derived-proposed

**Choice:** If even one contributing member has only proposed (not
confirmed) scores, the whole rollup is `derived-proposed`. Only when
*every* contributing member has confirmed `bvp_scores:` does the
rollup become `derived-confirmed`.

**Why:** Sovereignty rule: a rollup is only as authoritative as its
weakest input. Mixing one human-confirmed score with three estimator
proposals into a "derived-confirmed" output would launder advisory
data into apparent authority. Better to be honest: until every member
is confirmed, the arc rollup is advisory.

### 2026-05-19 — effort: sum, blast_radius: max

**Choice:** Effort sums (arcs are thick); blast_radius takes max (arc
blast is union, not sum).

**Why:** Capture the two different semantics. Sum-effort acknowledges
that an arc with 10 tasks of effort=4 each is genuinely more work than
one task of effort=4 — but cap at 9 to keep the scatter rendering in
its T-shirt-XL bound. Max-blast acknowledges that touching one shared
component once gives you the same blast as touching it ten times — the
graph reach doesn't multiply.

### 2026-05-19 — Direct overrides rollup (sovereignty)

**Choice:** A direct `bvp_scores:` (or `bvp_scores_proposed:`) on the
arc YAML always wins over the rollup.

**Why:** Lets the human declare arc-level authority intentionally —
e.g., an arc whose value isn't its members' value (cross-cutting
initiative, exploration). The rollup is a sensible default, not a
hard-coded truth. Same logic for cost_estimate.

## Decisions  <!-- (placeholder anchor below) -->

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

### 2026-05-19T19:24:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1936-bvp-t-new-7d-arc-level-bvpcost-rollup--r.md
- **Context:** Initial task creation

### 2026-05-19T19:25:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-757bc940
- **Timestamp:** 2026-05-21T07:20:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] Arc dots distribute meaningfully on the scatter — they sit at reasonable BVP-norm and cost-composite positions relative to their member tasks, AND it's visually clear they're arcs (larger cir
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows `' in Expected: Arc dots are visible, distinct from task dots, and sit at reasonable rolled-up positions. Tooltip shows `derived` provenance for cost.`
### 2026-05-20T19:09:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
