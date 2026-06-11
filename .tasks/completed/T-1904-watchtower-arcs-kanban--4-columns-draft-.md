---
id: T-1904
name: "Watchtower /arcs kanban — 4 columns (draft / in-progress / closed / abandoned)
  replacing T-1853 tabs, matching /tasks visual pattern"
description: >
  Watchtower /arcs kanban — 4 columns (draft / in-progress / closed / abandoned) replacing
  T-1853 tabs, matching /tasks visual pattern

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [tests/playwright/test_arcs_kanban.py, 
      tests/playwright/test_arcs_lifecycle_tabs.py, web/blueprints/arcs.py, 
      web/shared.py, web/templates/arcs_index.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T19:12:46Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-18T19:25:32Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1904: Watchtower /arcs kanban — 4 columns (draft / in-progress / closed / abandoned) replacing T-1853 tabs, matching /tasks visual pattern

## Context

T-1853 added lifecycle filter tabs to `/arcs` (draft / in-progress / closed / abandoned / all). The user expects a true 4-column **kanban** layout — the same visual pattern `/tasks` already uses (web/templates/tasks.html lines 106-198 .kanban-board / .kanban-column / .kanban-card). Tabs require clicking to compare states; the kanban gives the operator a single-page view of where every arc currently lives.

A second sub-fix: the user also reports `/arcs` is reachable under "Architecture" in the Watchtower nav; they expect it under "Work" (it's an operational view, not a structural-architecture view). Re-home the link.

Reference: existing kanban CSS + 4-column grid (collapses to 2 ≤992px, 1 ≤576px) is already in tasks.html. Re-use those classes — do not re-invent.

## Acceptance Criteria

### Agent
- [x] `web/templates/arcs_index.html` renders a 4-column kanban (draft / in-progress / closed / abandoned), each column showing its arc cards (id, name, status badge, anchor task, task-count, focus dot, stale flag).
- [x] Kanban CSS classes (.arc-kanban-board / .kanban-column / .arc-card / .arc-card-id / .arc-card-meta) mirror the styles from `web/templates/tasks.html` lines 106-198 — copied with comment pointing at the source. Visual parity is the gate.
- [x] Responsive grid collapses to 2 columns ≤992px and 1 column ≤576px (same breakpoints as /tasks).
- [x] `web/blueprints/arcs.py:arcs_index()` defaults to kanban mode — passes all arcs grouped by status (draft/in-progress/closed/abandoned) to the template. The `?status=…` legacy query-param still works for backward compat (returns flat list with "back to kanban" link).
- [x] T-1853's tab partial (`.arc-tabs`) is removed from the index page; the kanban replaces it. Per-state count is shown in column header.
- [x] `/arcs` link in Watchtower nav is moved from the "Architecture" section to the "Work" section in `web/shared.py:NAV_GROUPS` (line 104 now lists Arcs under Work; line 116 Architecture group no longer contains it).
- [x] `curl -sf $(bin/fw watchtower url)/arcs` returns 200 and the HTML contains `class="arc-kanban-board"` AND 4× `class="kanban-column"` (verified in `## Verification`).
- [x] `tests/playwright/test_arcs_kanban.py` covers: (a) page loads + 4 columns render, (b) columns in lifecycle order, (c) header + count per column, (d) in-progress non-empty + card links work, (e) card click navigates to /arcs/<id>, (f) Arcs nav under Work, (g) legacy ?status= flat-list still works. 7 tests, all PASS (19.33s).

### Human
- [ ] [REVIEW] Kanban layout reads cleanly side-by-side with /tasks — column proportions, card density, and badge placement feel consistent.
  **Steps:**
  1. Open `/arcs` and `/tasks` in two adjacent browser tabs (or split screen).
  2. Compare column header weight, card height, badge styles, focus-dot rendering.
  3. Scroll/resize to confirm responsive collapse breakpoints match.
  **Expected:** Pages feel like they belong to the same family — no jarring visual differences.
  **If not:** Note the specific visual mismatch (e.g. "arc cards 30% taller than task cards") for follow-up.

- [ ] [REVIEW] `/arcs` link now lives under "Work" in the nav and feels right there.
  **Steps:**
  1. Open Watchtower, click around the nav to confirm `/arcs` is grouped with /tasks, /handovers, /review, etc.
  2. Confirm no orphan link remains under "Architecture".
  **Expected:** Single nav entry under "Work"; no duplicate.
  **If not:** Edit the nav template to remove the stale link.

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

## Verification

test "$(curl -sf "$(bin/fw watchtower url)/arcs" | grep -c 'class="kanban-column"')" -ge 4
test "$(curl -sf "$(bin/fw watchtower url)/arcs" | grep -c 'class="arc-kanban-board"')" -ge 1
test "$(curl -sf "$(bin/fw watchtower url)/arcs" | grep -c 'arc-card-id')" -ge 5
# Nav: Arcs appears under "Work" group, not under "Architecture"
curl -sf "$(bin/fw watchtower url)/arcs" | python3 -c "import sys,re; html=sys.stdin.read(); work=re.search(r'>Work<.*?</details>', html, re.DOTALL); arch=re.search(r'>Architecture<.*?</details>', html, re.DOTALL); sys.exit(0 if (work and 'href=\"/arcs\"' in work.group(0) and not (arch and 'href=\"/arcs\"' in arch.group(0))) else 1)"

## Recommendation

**Recommendation:** GO

**Rationale:** Kanban shipped and verified live. 7 Playwright tests pass (column count, lifecycle order, header+count, in-progress non-empty, card-click navigation, Arcs-under-Work nav assertion, legacy `?status=` flat-list backward compat). 4 curl-based verification commands also pass (P-011 gate). Two genuine [REVIEW] Human ACs remain — they require taste/judgment (visual parity feel vs /tasks; "feels right" nav placement) and cannot be agent-verified per CLAUDE.md §AC Classification Guidance. T-1853 lifecycle tabs are fully replaced by the kanban; the obsolete `test_arcs_lifecycle_tabs.py` Playwright file is removed. Backward compat preserved via `?status=` flat-list mode for any external bookmark.

**Evidence:**

- `c1db42c4` — implementation (web/blueprints/arcs.py, web/templates/arcs_index.html, web/shared.py, tests/playwright/test_arcs_kanban.py)
- `d3ef6e5b` — fabric card for new Playwright test
- 7/7 Playwright tests pass (19.33s): `bin/fw test playwright tests/playwright/test_arcs_kanban.py`
- 4/4 P-011 verification commands pass (kanban-column count, board class, card count, Work-nav placement)
- Live: `curl -sf http://localhost:3000/arcs` shows 4 kanban columns with arc cards and "Arcs" link under Work group in the rendered nav
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

### 2026-05-18T19:12:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1904-watchtower-arcs-kanban--4-columns-draft-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a0a2a801
- **Timestamp:** 2026-06-02T15:00:23Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Per-AC findings:**

- **AC#1 (Agent)** — `web/templates/arcs_index.html` renders a 4-column kanban (draft / in-progress / closed / abandoned), each column showing its arc cards (id, name, status badge, anchor task, task-count, focus dot, sta
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arcs_index.html in: `web/templates/arcs_index.html` renders a 4-column kanban (draft / in-progress / closed / abandoned), each column showing its arc cards (id, name, sta`
- **AC#2 (Agent)** — Kanban CSS classes (.arc-kanban-board / .kanban-column / .arc-card / .arc-card-id / .arc-card-meta) mirror the styles from `web/templates/tasks.html` lines 106-198 — copied with comment pointing at th
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/tasks.html in: Kanban CSS classes (.arc-kanban-board / .kanban-column / .arc-card / .arc-card-id / .arc-card-meta) mirror the styles from `web/templates/tasks.html` `
- **AC#4 (Agent)** — `web/blueprints/arcs.py:arcs_index()` defaults to kanban mode — passes all arcs grouped by status (draft/in-progress/closed/abandoned) to the template. The `?status=…` legacy query-param still works f
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/arcs.py in: `web/blueprints/arcs.py:arcs_index()` defaults to kanban mode — passes all arcs grouped by status (draft/in-progress/closed/abandoned) to the template`
- **AC#6 (Agent)** — `/arcs` link in Watchtower nav is moved from the "Architecture" section to the "Work" section in `web/shared.py:NAV_GROUPS` (line 104 now lists Arcs under Work; line 116 Architecture group no longer c
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: `/arcs` link in Watchtower nav is moved from the "Architecture" section to the "Work" section in `web/shared.py:NAV_GROUPS` (line 104 now lists Arcs u`
- **AC#8 (Agent)** — `tests/playwright/test_arcs_kanban.py` covers: (a) page loads + 4 columns render, (b) columns in lifecycle order, (c) header + count per column, (d) in-progress non-empty + card links work, (e) card c
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_arcs_kanban.py in: `tests/playwright/test_arcs_kanban.py` covers: (a) page loads + 4 columns render, (b) columns in lifecycle order, (c) header + count per column, (d) i`
### 2026-05-18T19:25:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
