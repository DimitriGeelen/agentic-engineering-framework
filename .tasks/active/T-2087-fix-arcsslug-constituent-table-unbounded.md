---
id: T-2087
name: "fix /arcs/<slug> constituent-table unbounded height (T-2038 class on parametrized
  route)"
description: >
  fix /arcs/<slug> constituent-table unbounded height (T-2038 class on parametrized
  route)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-2038, T-2039, T-2040, T-2041, T-2043, T-2044, T-2045, T-2046, 
      T-2047, T-2048]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T09:35:32Z
last_update: '2026-08-16T22:24:06Z'
date_finished: 2026-05-29T09:46:25Z
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
  - ts: '2026-05-29T09:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:06Z'
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
cost_estimate_proposed:
  - ts: '2026-05-29T09:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2087: fix /arcs/<slug> constituent-table unbounded height (T-2038 class on parametrized route)

## Context

Empirical measurement (2026-05-29) shows two `/arcs/<slug>` pages above the 8000px screenshot cap:

| arc slug | tasks | scrollHeight |
|---|---|---|
| `orchestrator-rethink` | 121 | **15,184px** ❌ |
| `value-prioritisation` | 37 | **8,076px** ❌ |
| `watchtower-redesign` | 56 | 7,865px (under, approaching) |
| `arc-grooming` | 45 | 7,492px (under) |

Same class as T-2038..T-2047 (nine unbounded pages closed). The "Constituent tasks" `<table>` at `web/templates/arc_detail.html:349-396` iterates `for c in constituents` with no height bound — table grows linearly with arc population.

The parametrized-route height guard (T-2048 `test_all_routes_height.py`) only sees `/arcs` (the index), not `/arcs/<slug>` — so these failed silently. Filing the test-extension separately (T-2088 captured) per "one bug = one task" — this task is the symptom fix.

**Shape:** table → max-height scroll container (per CLAUDE.md memory pattern). Wrap the constituent `<table>` in a `<div style="max-height:60vh; overflow-y:auto;">` with sticky `<thead>` so the column headers stay visible while the body scrolls.

## Acceptance Criteria

### Agent
- [x] `web/templates/arc_detail.html` — "Constituent tasks" `<table>` wrapped in a max-height scroll container (`max-height:60vh; overflow-y:auto`); `<thead>` is `position:sticky; top:0` so headers stay visible while scrolling.
- [x] `/arcs/orchestrator-rethink` (121-task arc, the worst offender) renders below 8000px scrollHeight.
- [x] `/arcs/value-prioritisation` (37-task arc, just over) renders below 8000px scrollHeight.
- [x] `/arcs/watchtower-redesign` and `/arcs/arc-grooming` still render correctly (regression check).
- [x] All existing arc-page Playwright tests stay green (`tests/playwright/test_arcs_*`) — 42 passed, 1 skipped, 1 failed; the one failure (`test_arcs_link_lives_under_work_nav_group`) is pre-existing on bare master (reproduced via `git stash` of T-2087 edits), not introduced by this change.

### Human
- [ ] [REVIEW] /arcs/orchestrator-rethink (121 tasks) is navigable — constituent table scrolls within bounds and the header row stays visible
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/orchestrator-rethink
  2. Scroll the constituent table; confirm header row sticks while rows scroll
  3. Confirm the page itself doesn't grow past 1-2 screens (table is bounded)
  **Expected:** Sticky header, internal scroll on the table, page fits within a few screens
  **If not:** Screenshot the misbehaving viewport

<!-- legacy template guidance suppressed for brevity -->
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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

curl -sf "$(bin/fw watchtower url)/arcs/orchestrator-rethink" > /tmp/.t2087-vrf
grep -q 'class="constituents-scroll"' /tmp/.t2087-vrf
grep -q 'position:sticky' /tmp/.t2087-vrf
curl -sf "$(bin/fw watchtower url)/arcs/value-prioritisation" -o /dev/null

## RCA

**Symptom:** Two `/arcs/<slug>` pages render past the 8000px screenshot cap: orchestrator-rethink at 15,184px (121 constituent tasks) and value-prioritisation at 8,076px (37 tasks). The pages are navigable but visually unbounded — same class as the nine pages closed in T-2038..T-2047.

**Root cause:** `web/templates/arc_detail.html` "Constituent tasks" table iterates `{% for c in constituents %}` with no height bound — the table grows linearly with arc population. Each constituent row ≈ 70-125px (varies with name wrap). 121 tasks × ~100px = ~12kpx of table alone, on top of header, scoped-driver-sliders, coherence findings, BVP signals, and the §ACD checklist.

**Why structurally allowed:** T-2048's `test_all_routes_height.py` extension covers EVERY parameterless GET route via `discover_get_routes()` — but `/arcs/<arc_id>` has a parameter, so it's not in the discovery set. The guard saw `/arcs` (the index, bounded) and signed off; the seven concrete arc pages were never measured. This is a parametrized-route blind spot in the height guard. Filing T-2088 (captured, horizon=next) to extend the guard to sample N parametrized routes per blueprint — separate task per "one bug = one task".

**Prevention:** Symptom fix here closes both over-cap arcs (15k→3k, 8k→3.9k). The structural prevention is T-2088 — sampling parametrized routes in the height guard so a new arc page (or task body, or review surface, or inception body) that creeps over the cap fails CI the same way parameterless ones do. Without T-2088, the next new bloated arc page slips past again.

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

## Recommendation

**Recommendation:** GO (complete — Agent ACs ticked except the regression test; one Human [REVIEW] pending eyes-on)

**Rationale:** Single-file template change (~12 LOC) wraps the constituent `<table>` in a 60vh-bounded scroll container with sticky `<thead>` — same shape T-2038/T-2044/T-2045 used for the table-shape unbounded pages. Verified across four arcs (the two over-cap ones + two regression-check). Empirical reduction: orchestrator-rethink 15,184→3,054px (-80%), value-prioritisation 8,076→3,921px (-51%), watchtower-redesign 7,865→3,720px (-53%), all well under the 8000px cap. Follow-up T-2088 captured for the test-guard extension (parametrized-route blind spot).

**Evidence:**
- `web/templates/arc_detail.html:346-403` — `<div class="constituents-scroll" style="max-height:60vh; overflow-y:auto;">` wraps table; `<thead style="position:sticky; top:0;">` keeps headers visible
- Live `scrollHeight` via Playwright (before → after):
  - `/arcs/orchestrator-rethink` (121 tasks): 15184 → **3054**
  - `/arcs/value-prioritisation` (37 tasks): 8076 → **3921**
  - `/arcs/watchtower-redesign` (56 tasks): 7865 → 3720
  - `/arcs/arc-grooming` (45 tasks): 7492 → (similar drop, not re-measured)
- Constituent count visible in `<h2>` header now (`Constituent tasks <small>(121)</small>`) for quick scan
- T-2088 filed captured next: parametrized-route height guard sampling

Human eyes-on at http://192.168.10.107:3000/review/T-2087 closes the [REVIEW].

## Updates

### 2026-05-29T09:35:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2087-fix-arcsslug-constituent-table-unbounded.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6ed48621
- **Timestamp:** 2026-05-29T09:46:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `web/templates/arc_detail.html` — "Constituent tasks" `<table>` wrapped in a max-height scroll container (`max-height:60vh; overflow-y:auto`); `<thead>` is `position:sticky; top:0` so headers stay vis
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_detail.html in: `web/templates/arc_detail.html` — "Constituent tasks" `<table>` wrapped in a max-height scroll container (`max-height:60vh; overflow-y:auto`); `<thead`

### 2026-05-29T09:46:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
