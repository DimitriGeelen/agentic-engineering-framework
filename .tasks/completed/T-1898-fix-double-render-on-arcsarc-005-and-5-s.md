---
id: T-1898
name: "fix double-render on arcs/arc-005 and 2 sibling pages — templates extend base.html but render_page wraps in _wrapper.html (which also extends base.html), producing two full Watchtower headers"
description: >
  fix double-render on arcs/arc-005 and 2 sibling pages — templates extend base.html but render_page wraps in _wrapper.html (which also extends base.html), producing two full Watchtower headers

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/arc_detail.html, web/templates/arcs_index.html, web/templates/orchestrator.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T11:26:56Z
last_update: 2026-05-18T11:42:17Z
date_finished: 2026-05-18T11:42:17Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1898: fix double-render on arcs/arc-005 and 2 sibling pages — templates extend base.html but render_page wraps in _wrapper.html (which also extends base.html), producing two full Watchtower headers

## Context

`web/shared.py:render_page()` is documented to take "pure HTML fragment (no <html>, no extends)" page templates and wraps them in `_wrapper.html`, which itself extends `base.html`. Three page templates rendered via `render_page()` violate the convention by starting with `{% extends "base.html" %}{% block content %}…{% endblock %}` — Jinja then renders base.html twice (once by the wrapper, once by the page template embedded inside the wrapper's `{% include _content_template %}`), producing two full Watchtower nav stacks at the top of every full-page (non-htmx) load. Found while reviewing `/arcs/arc-005`. **Scope:** `arc_detail.html`, `arcs_index.html`, `orchestrator.html` (the three that go through `render_page`). Three other templates also begin with `extends base.html` (`escalation_drift.html`, `reviewer_audit.html`, `reviewer_overrides.html`) but their blueprints use `render_template()` directly — they're rendered correctly and out of scope. The mid-fix attempt to sweep them broke their layout and was reverted in the same iteration.

## Acceptance Criteria

### Agent
- [x] None of the 3 `render_page`-rendered templates (`arc_detail.html`, `arcs_index.html`, `orchestrator.html`) start with `{% extends "base.html" %}` (verified by grep).
- [x] `curl -sf http://localhost:3000/arcs/arc-005` returns HTTP 200 and the response body contains exactly one `<nav` opening tag (proxy for one Watchtower chrome instance — base.html emits `<nav class="site-nav">` for the top bar).
- [x] Same one-`<nav>` assertion holds for `/arcs` and `/orchestrator`.
- [x] htmx fragment behaviour preserved: `curl -sf -H "HX-Request: true" http://localhost:3000/arcs/arc-005` returns the fragment without `<nav` (no chrome on htmx swaps).
- [x] No regression on the 3 `render_template`-rendered routes: `/escalation-drift`, `/reviewer/audit`, `/reviewer/overrides` each return HTTP 200 with exactly one `<nav` (the abortive sweep through these templates was reverted in-iteration).
- [x] RCA section filled in (workflow_type=build + title contains "fix").

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
- [ ] [REVIEW] Layout reads clean — only one Watchtower header at the top, no visible page-in-page
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/arc-005 in browser
  2. Scroll to top; count headers (each contains "Watchtower" + nav links)
  3. Spot-check `/arcs`, `/escalation-drift`, `/reviewer/audit`, `/reviewer/overrides`, `/orchestrator`
  **Expected:** Exactly one Watchtower header per page; the page-title sits directly under it
  **If not:** Note which page still double-renders; agent re-investigates wrapper inheritance

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

# All checks use `test "$(... | grep -c)" -eq N` pattern per L-387/L-393 —
# avoids SIGPIPE/pipefail failures from `grep -q` closing stdin early.

# AC1: none of the 3 render_page templates still extend base.html
test "$(grep -l '{% extends \"base.html\" %}' web/templates/arc_detail.html web/templates/arcs_index.html web/templates/orchestrator.html 2>/dev/null | wc -l)" -eq 0

# AC2: arc-005 page returns 200 with exactly one <nav opening tag
test "$(curl -sf "$(bin/fw watchtower url)/arcs/arc-005" | grep -c '<nav')" -eq 1

# AC3: same one-<nav check across the other 2 render_page routes
for path in /arcs /orchestrator; do test "$(curl -sf "$(bin/fw watchtower url)$path" | grep -c '<nav')" -eq 1 || { echo "FAIL: $path"; exit 1; }; done

# AC4: htmx fragment behaviour preserved — no <nav on HX-Request
test "$(curl -sf -H "HX-Request: true" "$(bin/fw watchtower url)/arcs/arc-005" | grep -c '<nav')" -eq 0

# AC5: regression check on the 3 render_template routes (sweep-revert)
for path in /escalation-drift /reviewer/audit /reviewer/overrides; do test "$(curl -sf "$(bin/fw watchtower url)$path" | grep -c '<nav')" -eq 1 || { echo "FAIL: $path (regression)"; exit 1; }; done

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

**Symptom:** `/arcs/arc-005` and 5 other pages render the full Watchtower top-bar twice — two nav rows, two project switchers, two "Knowledge / Architecture / Quality" group headers — pushing real content below the fold. Pure space waste.

**Root cause:** `web/shared.py:render_page()` is contractually documented to wrap *fragment* templates inside `_wrapper.html` (which extends `base.html`). Three page templates rendered through that path (`arc_detail.html`, `arcs_index.html`, `orchestrator.html`) were authored as full Jinja pages — they begin with `{% extends "base.html" %}{% block content %}…{% endblock %}`. The wrapper's `{% include _content_template %}` then drops a *second* `base.html` chain into the rendered output. Both chains emit the full chrome.

**Why structurally allowed:** The render_page docstring states the convention but nothing enforces it. The template authoring contract lives in a comment in `web/shared.py`, not in any lint, audit, or template-load hook. Sibling templates that follow the convention (inception.html, decisions.html, fabric_explorer.html, tasks.html) became the by-example reference; templates added without checking them drifted. To make matters worse, three *other* templates (`escalation_drift.html`, `reviewer_audit.html`, `reviewer_overrides.html`) also start with `extends base.html` but their blueprints call `render_template()` directly — so for them, the extends is correct. Without inspecting the blueprint, the templates look like sibling instances of the same bug. The mid-fix sweep through all six broke the latter three; reverting them was caught by the Playwright/curl loop in-iteration (small mercy: not committed).

**Prevention:** AC1 verification command (`grep -L '{% extends "base.html" %}' ...` scoped to the 3 render_page-rendered templates) acts as the local guard for this fix. AC5 regression check pins the 3 render_template routes' one-`<nav>` shape so the sweep mistake can't reoccur silently. Broader structural guard — a `render_page()`-side runtime check that refuses to wrap a template whose first non-empty line begins with `{% extends "base.html"`, with an actionable error pointing the dev at the contract — is logged as a follow-up (file T-NEXT after this ships; not in scope here per "one bug = one task").

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

**Rationale:** All 5 Agent ACs PASS. Visual confirmation via Playwright shows a single Watchtower nav at the top of `/arcs/arc-005` with content directly below (arc-005-after.png). Regression check on the 3 `render_template` routes left them at one-`<nav>` each (no breakage from the abortive sweep). RCA filed: structural prevention follow-up logged (render_page-side runtime check) but out of scope per "one bug = one task".

**Evidence:**
- AC1 grep: 0/3 render_page templates still extend base.html
- AC2/AC3: `/arcs/arc-005`, `/arcs`, `/orchestrator` each return exactly one `<nav` (was 2 on /arcs/arc-005 before the fix)
- AC4: HX-Request fragment returns zero `<nav` (chrome stripped on htmx swaps)
- AC5 regression: `/escalation-drift`, `/reviewer/audit`, `/reviewer/overrides` each still return one `<nav` after the in-iteration revert
- Playwright screenshot pair: `arc-005-current.png` (before, two stacked Watchtower bars) vs `arc-005-after.png` (after, one bar, content immediately below)
- Commit `3f4bb4bb`

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

### 2026-05-18T11:26:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1898-fix-double-render-on-arcsarc-005-and-5-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-27bf3d0a
- **Timestamp:** 2026-05-18T11:42:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-18T11:42:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
