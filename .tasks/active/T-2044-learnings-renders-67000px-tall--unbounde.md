---
id: T-2044
name: "/learnings renders 67000px tall — unbounded table (T-2038 class)"
description: >
  /learnings renders 67,890px (table-dominant: {% for l in learnings %} rows in a
  details/open + practices articles). 7th instance of the unbounded-page class (T-2042
  probe). Fix: wrap table in max-height scroll container with sticky thead, like T-2039
  /fabric.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-007, perf, watchtower, learnings, ui, render-surface]
components: [tests/playwright/test_decisions_height.py, 
      tests/playwright/test_graduation_height.py, 
      tests/playwright/test_learnings_height.py, web/templates/decisions.html, 
      web/templates/graduation.html, C-006]
related_tasks: [T-2039, T-2042, T-2043]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T14:52:48Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-26T06:55:33Z
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
  - ts: '2026-05-25T15:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T15:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
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
---

# T-2044: /learnings renders 67000px tall — unbounded table (T-2038 class)

## Context

7th instance of the unbounded-page class (T-2042 probe). `/learnings` renders the learnings
`<table>` inside a `<details open>` — open by default, so all rows count toward height → the
table grows unbounded as learnings accumulate → 67,890px. Table shape (`<details>` can't wrap
`<tr>`) → same fix as T-2039 /fabric: wrap the table in a `max-height` scroll container with a
sticky `thead`. All rows stay in the DOM, reached by scrolling the internal container.
(Practices + received-learnings sections are already collapsed `<details>` — not the driver.)
See [[project_unbounded_watchtower_pages]].

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] /learnings rendered scrollHeight drops below the 8000px `_safe_shot` cap (from 67,890px), verified by a live playwright probe — measured **67,890px → 1,173px**
- [x] All learning rows stay in the DOM inside a `.learnings-table-scroll` container (container clientHeight < table scrollHeight when rows are many); `thead` sticky — **462 rows**, container 618px over 67,465px content, `thead` position=sticky
- [x] `tests/playwright/test_learnings_height.py` added (height-bounded + rows-in-scroll-container), both pass — **2 passed**
- [x] New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_learnings_height.yaml`

### Human
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
- [ ] [REVIEW] /learnings reads cleanly after the height fix
  **Steps:**
  1. Open http://192.168.10.107:3000/learnings
  2. Confirm the learnings table scrolls internally (sticky header stays visible) and the page no longer endless-scrolls
  3. Scroll the table to the bottom and confirm the oldest learnings are reachable
  **Expected:** The table is a fixed-height scroll region with a sticky header; the page itself is short; every learning is reachable by scrolling the table
  **If not:** Note whether the scroll region height feels right and whether the sticky header reads clearly

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

curl -sf "$(bin/fw watchtower url)/learnings" >/dev/null
python3 -m pytest tests/playwright/test_learnings_height.py -q 2>&1 | tail -3
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

**Symptom:** `/learnings` rendered 67,890px tall (462 learning rows in one table).

**Root cause:** The learnings table sits inside a `<details open>` — `open` means its rows
always render and count toward page height. With no scroll bound, the table grows one row
per learning forever (learnings are append-only). Same data-growth class as T-2038..T-2043.

**Why structurally allowed:** /learnings was never in the ux-review sweep's hard-coded
5-page list — invisible to tooling until T-2042 made the detector exhaustive (7th of 9
instances that fix surfaced).

**Prevention:** (1) `tests/playwright/test_learnings_height.py` pins scrollHeight < 8000 and
rows-in-scroll-container — guards this page forever. (2) The exhaustive detector (T-2042)
now has /learnings in scope, so a future regression surfaces in `--all-routes` Capture
automatically.

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

### 2026-05-25 — table shape → scroll container, not collapse

- **What changed:** Confirmed the 67k px is the single learnings table (462 rows), not the
  practices/received sections (already collapsed `<details>`). So this is the /fabric table
  shape, not the /inception card-list shape.
- **Plan impact:** Used the T-2039 scroll-container fix (max-height + sticky thead) rather
  than the cap+collapse pattern — `<details>` can't legally wrap `<tr>`.
- **Triggered:** None — one of the 5 instances T-2042 surfaced; others filed T-2045..T-2047.

## Decisions

### 2026-05-25 — scroll-container vs. cap+collapse for a table

- **Chose:** Wrap the learnings table in `.learnings-table-scroll` (max-height scroll
  container + sticky thead), keeping the `<details open>` open.
- **Why:** It's a table. `<details>` cannot legally wrap `<tr>` rows, so the cap+collapse
  card pattern doesn't apply; the scroll container bounds height while keeping every row
  reachable and the header visible. Mirrors the proven T-2039 /fabric fix exactly.
- **Rejected:** Collapsing the whole table behind a `<details>` — would hide all learnings
  by default (worse than the scroll). Paginating server-side — heavier change, and the
  scroll container is sufficient at this scale.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** 7th instance of the unbounded-page class fixed with the established T-2039
table pattern. /learnings drops from 67,890px to 1,173px while keeping all 462 learning rows
in the DOM inside a sticky-header scroll container. A playwright regression test pins height
and the scroll-container invariant and is registered in the fabric. Only the scroll-height
feel remains for human taste.

**Evidence:**
- scrollHeight: **67,890px → 1,173px** (live playwright probe, `< 8000px` cap)
- Rows: **462** in DOM; container clientHeight 618px < table scrollHeight 67,465px; `thead` position=sticky
- `tests/playwright/test_learnings_height.py`: **2 passed**
- Eyes-on screenshot: http://192.168.10.107:3000/static/ux-review/T-2044-learnings-bounded.png
- Template: `web/templates/learnings.html` — `.learnings-table-scroll` wrapper (max-height + sticky thead)

## Updates

### 2026-05-25T14:52:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2044-learnings-renders-67000px-tall--unbounde.md
- **Context:** Initial task creation

### 2026-05-25T15:00:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1738c1df
- **Timestamp:** 2026-05-26T06:55:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#4 (Agent)** — New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_learnings_height.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/tests-playwright-test_learnings_height.yaml in: New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_learnings_height.yaml``

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 19
     - evidence: `curl -sf "$(bin/fw watchtower url)/learnings" >/dev/null`

### 2026-05-26T06:55:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
