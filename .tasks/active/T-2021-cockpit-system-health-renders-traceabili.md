---
id: T-2021
name: "Cockpit System Health renders traceability as raw dict not percentage"
description: >
  Cockpit System Health card shows the traceability value as a raw Python dict instead
  of a percentage. Template uses health.get(traceability) but the value is now a dict
  not the int core.py _get_traceability returns. Discovered during T-2020 eyes-on.
  Pre-existing, unrelated to S6d. One bug = one task.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/playwright/test_cockpit_traceability.py, tests/unit/test_cockpit_traceability.py, web/templates/cockpit.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T10:08:37Z
last_update: 2026-05-25T22:44:13Z
date_finished: 2026-05-25T22:44:13Z
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
  - ts: '2026-05-24T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-25T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-25T10:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2021: Cockpit System Health renders traceability as raw dict not percentage

## Context

The Cockpit "System Health" card renders `health.get('traceability', '?')`
(`web/templates/cockpit.html:344`) directly. `fw scan` now writes
`project_health.traceability` as a structured dict
(`{score, total_tasks, completed, active}`), not the scalar int the template
was written for — so Jinja stringifies the dict and the panel shows
`{'score': 0.9746…, 'total_tasks': 1577, 'completed': 1537, 'active': 40}`.
Discovered during the T-2020 eyes-on review. Pre-existing, unrelated to S6d.

Scope note: the `score` is actually completed/total_tasks (a task-completion
ratio), not git traceability — a semantic/label mismatch in the scan producer.
That is a separate concern (captured in Decisions); this task fixes only the
raw-dict render.

## Acceptance Criteria

### Agent
- [x] System Health renders traceability as a human percentage, not a raw dict — when `health.traceability` is a dict, its `score` displays as a percent (e.g. `97%`); a scalar value still renders as-is; missing → `?`. (unit: render the cockpit with a dict-shaped traceability → output contains a `%` and does NOT contain the substring `{'score'`)
- [x] The render is defensive across both shapes — dict (current scan) and scalar (legacy `_get_traceability` int) both render without a traceback, via a Jinja `is mapping` branch. (unit covers both shapes)
- [x] Reviewer static scan passes. (Verification: `bin/fw reviewer T-2021` → Overall PASS)

### Human
- [ ] [REVIEW] System Health "Traceability" reads as a clean percentage
  **Steps:**
  1. Open the cockpit: `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` → open that URL in a browser
  2. Find the "System Health" card → the "Traceability" line
  3. Confirm it shows a percentage (e.g. `97%`), not a `{...}` dict
  **Expected:** A readable percentage, visually consistent with the other pulse values on the card
  **If not:** Screenshot the line and note what it shows

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

# template compiles (Jinja syntax check for the edited cockpit.html)
python3 -c "from web.app import app; app.jinja_env.get_template('cockpit.html')"
# rendered-output contract: dict→percent, scalar→as-is, missing→placeholder
python3 -m pytest tests/unit/test_cockpit_traceability.py -q
# reviewer static scan passes
out=$(bin/fw reviewer T-2021 2>&1); echo "$out" | grep -q "Overall:.*PASS"

## RCA

**Symptom:** Cockpit "System Health" → Traceability shows the raw Python dict
`{'score': 0.9746…, 'total_tasks': 1577, 'completed': 1537, 'active': 40}`
instead of a percentage.

**Root cause:** Producer/consumer shape drift. `fw scan` writes
`project_health.traceability` as a structured dict, but `cockpit.html` was
authored when the value was a scalar int (the shape `core.py:_get_traceability()`
still returns). `{{ health.get('traceability', '?') }}` stringifies whatever it
receives — a dict prints as its Python repr.

**Why structurally allowed:** No test asserts the *rendered* cockpit System
Health values, and there is no contract pinning the scan-data shape to the
template's expectation. Element-presence greps (the forbidden sole-check,
T-1575) pass — the `<span>` exists; only eyes-on caught it (which is exactly
how it surfaced, during the T-2020 review).

**Prevention:** A unit test renders the cockpit with a dict-shaped traceability
and asserts the output is a percentage, not a dict repr — pinning the
producer/consumer contract so the next shape drift fails the gate, not the eye.

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

### 2026-05-24 — fix in the template, not the scan producer
- **Chose:** Render-side fix in `cockpit.html` (Jinja `is mapping` branch → percent), leaving the scan's `project_health.traceability` dict shape unchanged.
- **Why:** The dict carries useful structure (`total_tasks`/`completed`/`active`) that other consumers may want; the bug is purely that this one consumer assumed a scalar. A defensive template that handles both shapes is the minimal, lowest-blast-radius fix.
- **Rejected:** Flattening the scan field back to a scalar — would break any other consumer relying on the dict and is a larger producer-side change for a display bug.

### 2026-05-24 — semantic/label mismatch left out of scope
- **Chose:** Display the `score` as "Traceability: N%" as-labelled; do NOT re-label or re-source the metric in this task.
- **Why:** `score` is `completed/total_tasks` (a completion ratio), not git traceability — a producer-side semantic mislabel that predates this task. "One bug = one task": conflating the render fix with a semantics change would dilute causality. Captured here for a separate follow-up.
- **Rejected:** Renaming the label or re-pointing it at `core.py:_get_traceability()` — out of scope; needs its own task + decision.

## Recommendation

**Recommendation:** GO (pending the one [REVIEW] Human AC)

**Rationale:** A contained, defensive render fix for a clearly-broken panel. The
template now handles both the current dict shape and the legacy scalar, so it
won't regress if the scan field changes again. All Agent ACs are unit-covered;
the single Human AC is a real eyes-on taste check on the rendered percentage.

**Evidence:**
- Unit `tests/unit/test_cockpit_traceability.py` — dict-shaped traceability renders a `%` and no `{'score'` repr; scalar shape renders as-is; both without traceback.
- Eyes-on screenshot `web/static/ux-review/T-2021-cockpit-traceability.png` — System Health → Traceability shows a percentage.
- Reviewer `fw reviewer T-2021` — Overall PASS.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T10:08:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2021-cockpit-system-health-renders-traceabili.md
- **Context:** Initial task creation

### 2026-05-24T10:29:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-97d6ccc8
- **Timestamp:** 2026-05-25T22:44:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:44:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
