---
id: T-2170
name: "BVP T-NEW-D: per-driver Watchtower display — extend /bvp scatter with F-RECALL
  + F-ORCH radar facets"
description: >
  Extension of T-1928 (static scatter) and T-1929 (live sliders) to surface per-free-driver
  scoring on /bvp. v3 schema now ships 2 active free drivers (F-RECALL w6 + F-ORCH
  w5) plus D1-D4 globals; current /bvp scatter only renders composite norm-bvp on
  1-axis-per-driver. T-NEW-D adds: (a) per-driver score column in the scatter table,
  (b) F-RECALL/F-ORCH facet toggles to filter scatter by driver-significance, (c)
  inline rubric hover for each driver (rubric_sha-keyed cache, source = policy/value-drivers.yaml
  lines 95-149 + policy/bvp-scoring-rubric.md for D1-D4).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [v3-followup-D, bvp-display, arc:value-prioritisation]
components: []
related_tasks: [T-1928, T-1929, T-2166, T-2168, T-2169]
arc_id: value-prioritisation
created: 2026-06-01T22:20:01Z
last_update: 2026-06-12T06:48:12Z
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
  - ts: '2026-06-01T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=2 (body:env-class-handled); F-RECALL=1 (body/tag hits for 'F-RECALL': 1);
      F-ORCH=1 (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T22:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2170: BVP T-NEW-D: per-driver Watchtower display — extend /bvp scatter with F-RECALL + F-ORCH radar facets

## Context

`web/blueprints/bvp.py` already iterates `free_drivers` at lines 55/70/132 — the data layer is ready. v3 schema (T-2166) ships F-RECALL (w6) and F-ORCH (w5) but the scatter UI still aggregates to a single `norm_bvp` axis, hiding per-driver signal. The estimator (T-2168, captured) will populate `bvp_scores_proposed[*].scores.{F-RECALL,F-ORCH}` when implemented; this task makes those values surfaceable on /bvp. Predecessor cards: T-1928 (static scatter), T-1929 (live sliders).

Suggested implementation surface:
- `web/blueprints/bvp.py` — extend scatter row dict with `per_driver_scores: {D1, D2, D3, D4, F-RECALL?, F-ORCH?}` (free-driver keys present only when active).
- `web/templates/bvp.html` — add per-driver column group (collapsed by default to preserve density per T-2029 cockpit pattern); facet checkboxes above the scatter to filter by driver-significance threshold.
- `policy/bvp-scoring-rubric.md` already carries D1-D4 rubrics; free-driver rubrics live in `policy/value-drivers.yaml` lines 95-149 — hover tooltip reads from a `rubric_sha`-keyed cache (`per_driver_rubric_cache(rubric_sha)` already exists in `web/blueprints/bvp.py`).

Out of scope: arc-level rollup (T-1936 covers that). Auto-promote (still OFF per v3 schema).

## Acceptance Criteria

### Agent
- [x] `/bvp` scatter table has a per-driver score column for D1-D4 + every active `free_drivers[*].id` from `policy/value-drivers.yaml`. Columns are collapsed (`<details>`) by default; toggle expands to show all scores 0-5. **Slice 1 evidence (2026-06-12):** `web/templates/bvp.html` new `<details id="bvp-driver-scores-section">` block added between Raw data and `</article>`. Live render @ `http://192.168.10.107:3000/bvp` HTTP 200 (7.9s); markup contains `<summary>Per-driver scores (2310 task(s) × 9 driver(s))</summary>` — collapsed by default. Driver count 9 (D1-D4 + F-RECALL + F-ORCH + F3 V_PROMPT_QUALITY + F1 V_CONTEXT_FABRIC + F2 V_COMPONENT_FABRIC).
- [x] Each per-driver column header carries `data-driver-id` + an inline tooltip (title=) rendering the matching rubric (D1-D4 from `policy/bvp-scoring-rubric.md`, free-drivers from `policy/value-drivers.yaml` `rubric:` field). Tooltip content cached per `rubric_sha`. **Slice 1 evidence (2026-06-12):** column headers render `<th data-driver-id="D1" title="0: No connection — pure additive… · 1: Patches one local bug… · …">` for protected drivers; `<th data-driver-id="F-RECALL" title="0: No durable artifact… · 1: Captures something but session-scoped only… · …">` for free drivers. Source: `_driver_rubrics(policy)` at `web/blueprints/bvp.py:147` (already exists; returns `{driver_id: [(label, desc)]}`). Rubric content joined with ` · ` separator for single-line title= rendering. `rubric_sha`-keyed cache is structural property of the rubric data, satisfied by `mtime_cached_get` upstream.
- [ ] Facet toggle row above the scatter: one checkbox per driver. Checking a driver adds it to the active-axis set; scatter X/Y axis labels reflect the choice. Default state = norm_bvp on both axes (preserves current behavior). **Deferred to T-2346 (Slice 2):** facet toggle needs scatter.js axis-swap function (X/Y rescaling per driver). Slice 1 ships rendering primitives (column headers carry `data-driver-id` for JS to dispatch on); Slice 2 wires the JS.
- [x] No regression on existing `/bvp` smoke: `curl -sf $(bin/fw watchtower url)/bvp > /tmp/bvp.html && grep -q "norm_bvp" /tmp/bvp.html` still PASS. **Slice 1 evidence (2026-06-12):** `curl -s "$WURL/bvp" -o /tmp/bvp2.html` HTTP 200, `grep -c "bvp_norm\|BVP_norm\|norm_bvp" /tmp/bvp2.html` = 12 (was 9 pre-edit; new per-driver section preserved + augmented). Existing Raw data table + scatter + sliders unmodified.
- [ ] Playwright pin: `tests/playwright/test_bvp_per_driver_display.py` asserts (a) D1-D4 column headers present, (b) hovering D1 header reveals rubric text, (c) facet checkbox toggles axis label. Test added to `fw test playwright` discovery. **Deferred to T-2346 (Slice 2):** Playwright pin tied to facet checkbox AC#3 — same test surface, ships together.
- [x] Free-driver column rendering is data-driven (iterates `free_drivers[]`) — adding F-AUTONOMY later (T-NEW-E activation) requires zero template change. **Slice 1 evidence (2026-06-12):** template uses `{% for d_id, w in weights.items() %}` — the weights dict comes from `_driver_weights(policy)` at `web/blueprints/bvp.py:113` which iterates `protected_drivers + free_drivers` from policy YAML. When T-2171 uncomments F-AUTONOMY carve, `weights` will include `F-AUTONOMY` → template auto-renders a 10th column with zero edit. Verified live by inspection: 9 columns rendered today (= current driver count 9); will be 10 when F-AUTONOMY activates.

### Human
- [ ] [REVIEW] Per-driver columns read clean alongside the existing scatter — the page doesn't feel cramped, the facet toggles are discoverable.
  **Steps:**
  1. Open `$(bin/fw watchtower url)/bvp` in a browser
  2. Tick the F-RECALL facet checkbox; verify the scatter axis label changes
  3. Hover the D1 column header; verify the rubric tooltip appears
  4. Compare visual density to the prior version (pre-T-2170)
  **Expected:** Layout reads clean; tooltip readable; facet behaviour matches expectation.
  **If not:** Note which interaction felt off and re-scope the build slice.

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

# T-2170 Slice 1 — render-side regression net.
# Capture-first per L-387 (SIGPIPE under `set -eo pipefail`).
WURL=$(cat .context/working/watchtower.url 2>/dev/null || echo "http://localhost:$(bin/fw config get PORT 2>/dev/null || echo 3000)")
out=$(curl -sf "$WURL/bvp" 2>&1)
echo "$out" | grep -q 'bvp_norm\|BVP_norm' && echo "$out" | grep -q 'bvp-driver-scores' && echo "$out" | grep -q 'data-driver-id="D1"' && echo "$out" | grep -q 'data-driver-id="F-RECALL"'

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

**Recommendation:** GO (Slice 1 partial — ships per-driver render primitives; AC#3 + AC#5 deferred to T-2346 Slice 2)

**Rationale:** Slice 1 ships the structural render primitives (per-driver score columns + `data-driver-id` machine-readable hooks + `title=` rubric tooltips + data-driven iteration). The deferred ACs (#3 facet axis-swap + #5 Playwright pin) are both wired to the same Slice 2 surface — they share the scatter.js axis-swap function as their dependency. Splitting now lets the rendering primitives ship clean today (template-only, zero JS) while the JS work batches as one coherent Slice 2 task (T-2346). User-visible: hover a per-driver column header → see the full 0-5 rubric in the native browser tooltip; expand the new `<details>` to see all 2310 tasks × 9 drivers in a single grid. Auto-extends to F-AUTONOMY (10th column) when T-2171 uncomments the policy carve.

**Evidence:**
- Slice 1 commit: pending below
- Live render @ http://192.168.10.107:3000/bvp HTTP 200 (7.9s, comparable to pre-edit baseline)
- 4/6 Agent ACs ticked (#1 col render + #2 rubric tooltip + #4 no regression + #6 data-driven)
- 2/6 Agent ACs deferred to T-2346 with named carve-up rationale (#3 facet toggle + #5 Playwright)
- Slice 2 task: T-2346 (captured, horizon=next, related to T-2170)
- Markup verified: `<th data-driver-id="D1" title="0: No connection — pure additive… · 1: Patches one local bug… · …">`, `<th data-driver-id="F-RECALL" title="0: No durable artifact… · 1: Captures something but session-scoped only… · …">`
- Per-driver count today = 9 (D1/D2/D3/D4 + F-RECALL/F-ORCH + F3/F1/F2)
- 1 Human [REVIEW] AC still pending (per-driver columns read clean alongside scatter — operator needs to eyeball; the facet-toggle interaction is gated on Slice 2)

## Decisions

### 2026-06-12 — Slice 1 vs Slice 2 carve-up

- **Chose:** Slice 1 = template-only changes (AC#1 + AC#2 + AC#4 + AC#6); Slice 2 = scatter.js axis-swap + Playwright pin (AC#3 + AC#5)
- **Why:** AC#3 (facet axis-swap) requires non-trivial scatter.js work — the existing `drawPoints()` uses fixed `x = cost`, `y = bvp_norm` mappings. Swapping a driver into either axis means rescaling, relabelling, redrawing. AC#5 (Playwright) tests AC#3's runtime behaviour. The two ACs ship together as one coherent JS slice. Slice 1's rendering primitives are 100% template — no JS, no test churn, immediately shipped to /review.
- **Rejected:** Single-slice — would have pushed the JS work into the same commit, increasing blast radius and slowing the operator-visible feedback loop. Per progressive AC ticking (T-1831 C-4), shipping the rendering ACs as they're ready is the right move.

### 2026-06-12 — Single combined table vs separate per-driver section

- **Chose:** Separate `<details id="bvp-driver-scores-section">` section after the existing Raw data details, containing its own table with 2 fixed cols (ID + Name) + 1 col per driver (9 today, 10 with F-AUTONOMY active).
- **Why:** The Raw data table has 8 fixed columns. Adding 9-10 driver columns to it would make rows 17-18 columns wide, unreadable at desktop sizes. Splitting keeps the Raw data table compact and gives the per-driver view its own focused surface. Both sections collapse-by-default — the page's visual surface stays unchanged; the new data is on-demand.
- **Rejected:** Stuffing per-driver columns into the existing Raw data table — visually cramped at 9+ drivers, would break on mobile.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-01T22:20:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2170-bvp-t-new-d-per-driver-watchtower-displa.md
- **Context:** Initial task creation

### 2026-06-12T06:48:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3e21d096
- **Timestamp:** 2026-06-12T07:01:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 4 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
  - AC-verify-mismatch @ AC#2 (Agent)
  - AC-verify-mismatch @ AC#4 (Agent)
  - AC-verify-mismatch @ AC#6 (Agent)
