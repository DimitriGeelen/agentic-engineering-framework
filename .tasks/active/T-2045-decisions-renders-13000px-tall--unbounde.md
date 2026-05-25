---
id: T-2045
name: "/decisions renders 13000px tall — unbounded table+list (T-2038 class)"
description: >
  /decisions renders 13,418px (mixed: {% for d in decisions %} table rows AND a second
  loop of article cards). 8th instance of the unbounded-page class (T-2042 probe).
  Fix: scroll-container for the table + collapse the article overflow.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-007, perf, watchtower, decisions, ui, render-surface]
components: []
related_tasks: [T-2042, T-2044, T-2039]
arc_id: watchtower-redesign
created: 2026-05-25T14:52:59Z
last_update: 2026-05-25T15:23:14Z
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
---

# T-2045: /decisions renders 13000px tall — unbounded table+list (T-2038 class)

## Context

8th instance of the unbounded-page class ([[project_unbounded_watchtower_pages]], T-2042 exhaustive probe). `/decisions` renders ~13,418px because the main `<table>` loops `{% for d in decisions %}` over a growing collection with no height bound. The second loop (rationale article-cards) is already inside a **collapsed** `<details>` (no `open`), so it does NOT contribute to default scrollHeight — the table is the sole driver. Fix mirrors T-2044 (/learnings) and T-2039 (/fabric): wrap the table in a `max-height` scroll container with a sticky header (`<details>` can't legally wrap `<tr>`). All rows stay in the DOM, reached by scrolling the internal container.

## Acceptance Criteria

### Agent
- [x] `/decisions` rendered `scrollHeight` < 8000px (TALL_PAGE_CAP_PX) measured via Playwright after restart — **13,418px → 1,169px**
- [x] All decision rows remain in the DOM (count unchanged) inside a bounded `.decisions-table-scroll` container that scrolls (clientHeight < scrollHeight when rows > 30) — **198 rows retained, container scrolls**
- [x] Sticky `thead` so column headers stay visible while scrolling the container — `position: sticky; top: 0; z-index: 2`
- [x] `tests/playwright/test_decisions_height.py` added and passing (height bound + rows-in-scroll-container guards) — **2 passed**

### Human
- [ ] [REVIEW] /decisions reads clean and is comfortable to scan
  **Steps:**
  1. Open http://192.168.10.107:3000/decisions in a browser
  2. Scroll the decisions table — confirm the column header row stays pinned (sticky thead) and the internal scrollbar feels natural, not cramped
  3. Confirm the page itself is short (no endless page-level scroll) and the "Decision Rationale Details" disclosure still expands
  **Expected:** Table scrolls within a bounded container with sticky headers; page height is screen-sized, not 13k px; rationale details still work
  **If not:** Screenshot the issue and note whether the container is too short/tall or headers don't stick

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
python3 -c "import ast,re,sys; s=open('web/templates/decisions.html').read(); assert 'decisions-table-scroll' in s, 'scroll container class missing'; assert 'position: sticky' in s or 'position:sticky' in s, 'sticky thead missing'; print('decisions.html scroll-container + sticky present')"
cd tests/playwright && python3 -m pytest test_decisions_height.py -q 2>&1 | tail -3; cd "$OLDPWD"

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

**Symptom:** `/decisions` rendered 13,418px tall (198 rows) — endless page-level scroll for humans, and wedges the ux-review `full_page` screenshot.

**Root cause:** The decisions `<table>` looped `{% for d in decisions %}` over a growing collection with no height bound. 8th confirmed instance of the unbounded-page class ([[project_unbounded_watchtower_pages]]).

**Why structurally allowed:** The ux-review height detector only swept 5 hard-coded pages, so /decisions (and 4 siblings) grew undetected. **This root is already closed** — T-2042 made the detector exhaustive (`discover_get_routes()` over `app.url_map`, 47 routes), which is what surfaced this very instance.

**Prevention:** `tests/playwright/test_decisions_height.py` (height-bound + rows-in-scroll-container guards) catches a regression of *this* page; the T-2042 exhaustive sweep catches the *next new* page automatically.

## Evolution

### 2026-05-25 — task description over-estimated the shape
- **What changed:** The task was filed as "mixed: table rows AND a second loop of article cards → scroll-container for the table + collapse the article overflow." Inspection showed the article-card loop (rationale details) is already inside a **collapsed** `<details>` (no `open`), so it contributes 0 to default scrollHeight. The table was the sole driver.
- **Plan impact:** Dropped the "collapse the article overflow" half of the plan — unnecessary. Fix reduced to the single table-scroll-container (identical to T-2044 /learnings).
- **Triggered:** No new sub-task; simpler than filed.

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

### 2026-05-25 — scroll-container vs collapse
- **Chose:** Wrap the table in a `max-height` scroll container with sticky `thead`.
- **Why:** `<details>` cannot legally wrap `<tr>` (invalid HTML), so the card-list collapse pattern doesn't apply to a table. The scroll-container keeps all 198 rows in the DOM, reachable by internal scroll, with column headers pinned. Same fix proven on /learnings (T-2044) and /fabric (T-2039).
- **Rejected:** Server-side pagination — adds a request round-trip and state; out of proportion for a static knowledge table. Capping the row count — would hide decisions, violating the "every item reachable" invariant.

## Recommendation

**Recommendation:** GO

**Rationale:** The unbounded height is fixed by the same proven pattern as two prior siblings, with a regression test guarding it. The only open item is the `[REVIEW]` human-taste check (does the bounded table feel comfortable to scan) — agent-side everything passes.

**Evidence:**
- Height: 13,418px → **1,169px** (Playwright, post-restart) — well under the 8000px cap
- Rows: **198 retained** inside `.decisions-table-scroll`; container scrolls (clientHeight < scrollHeight)
- Sticky `thead` (`position: sticky; top: 0; z-index: 2`)
- `tests/playwright/test_decisions_height.py` — **2 passed**
- Eyes-on screenshot: http://192.168.10.107:3000/static/ux-review/T-2045-decisions-bounded.png

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T14:52:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2045-decisions-renders-13000px-tall--unbounde.md
- **Context:** Initial task creation

### 2026-05-25T15:23:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
