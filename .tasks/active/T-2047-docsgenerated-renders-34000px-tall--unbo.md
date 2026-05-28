---
id: T-2047
name: "/docs/generated renders 34000px tall — unbounded list (T-2038 class)"
description: >
  /docs/generated renders 34,671px. Instance of the unbounded-page class (T-2042 probe).
  Shape TBC — inspect web/templates for the docs-generated index loop; fix by shape
  (cap+collapse or scroll-container).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc-007, perf, watchtower, docs, ui, render-surface]
components: [agents/docgen/generate_component.py, 
      agents/docgen/generate-component.sh, 
      tests/playwright/test_docs_generated_height.py, 
      web/templates/docs_index.html]
related_tasks: [T-2042, T-2045, T-2043]
arc_id: watchtower-redesign
created: 2026-05-25T14:53:15Z
last_update: '2026-05-28T22:54:12Z'
date_finished: 2026-05-26T06:57:03Z
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
  - ts: '2026-05-28T22:54:12Z'
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

# T-2047: /docs/generated renders 34000px tall — unbounded list (T-2038 class)

## Context

9th instance of the unbounded-page class ([[project_unbounded_watchtower_pages]], T-2042 exhaustive probe). `/docs/generated` renders ~34,671px because it loops `{% for subsystem %}` over **31 subsystems**, each an **`<details open>`** wrapping a per-subsystem `<table>` (765 component rows total). All-expanded-by-default = the whole 35k px renders at once. Distinct shape from the single-table pages: a *list of collapsible sections*. The largest subsystem alone is 246 rows (~9,840px) — over the 8000px cap — so collapsing the sections by default is necessary AND each section's table needs a scroll container so an expanded giant section stays bounded.

## Acceptance Criteria

### Agent
- [x] `/docs/generated` default rendered `scrollHeight` < 8000px (TALL_PAGE_CAP_PX) measured via Playwright after restart — **34,671px → 1,281px**
- [x] All 31 subsystem `<details>` are collapsed by default (no `open`); every subsystem + its component rows remain in the DOM (765 rows), reachable by expanding the section — **31 sections, 765 rows retained in DOM**
- [x] Each subsystem table is wrapped in a `.docs-subsystem-scroll` max-height container with sticky `thead`, so even the largest expanded section (246 rows) stays bounded — **largest: 246 rows, container clientHeight 628px < scrollHeight 10,129px → scrolls**
- [x] `tests/playwright/test_docs_generated_height.py` added and passing (default-height bound + all-rows-present + scroll-container guards) — **3 passed**

### Human
- [ ] [REVIEW] Collapse-by-default is the right UX trade for the docs index
  **Steps:**
  1. Open http://192.168.10.107:3000/docs/generated in a browser
  2. Note the page now shows 31 collapsed subsystem rows (each with its component count) instead of one 35k px wall of expanded tables
  3. Expand a subsystem (click) — confirm its component table appears and, for a large subsystem, scrolls within its own container with a pinned header
  **Expected:** A compact, scannable index; expanding a section reveals its components; no endless page-level scroll. The trade is: you now click to expand a subsystem rather than seeing everything at once.
  **If not:** If you'd prefer the first subsystem (or all) open by default, say so — that's a one-line `open` toggle. Screenshot anything that looks off.

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
python3 -c "s=open('web/templates/docs_index.html').read(); assert 'docs-subsystem-scroll' in s, 'scroll container class missing'; assert 'details open' not in s and '<details open>' not in s, 'subsystems still open by default'; assert 'position: sticky' in s or 'position:sticky' in s, 'sticky thead missing'; print('docs_index.html collapsed-default + scroll-container + sticky present')"
cd tests/playwright && python3 -m pytest test_docs_generated_height.py -q 2>&1 | tail -3; cd "$OLDPWD"

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

**Symptom:** `/docs/generated` rendered 34,671px tall — 31 subsystems each `<details open>` with a full component table (765 rows), all expanded at once.

**Root cause:** Every subsystem section defaulted to `open`, so the whole corpus rendered on load with no height bound. 9th confirmed instance of the unbounded-page class ([[project_unbounded_watchtower_pages]]) — and a distinct *list-of-collapsible-sections* shape, not a single table.

**Why structurally allowed:** The ux-review height detector swept only 5 hard-coded pages, so /docs/generated grew undetected. **This root is already closed** by T-2042 (exhaustive `discover_get_routes()` over `app.url_map`), which is what surfaced this instance.

**Prevention:** `tests/playwright/test_docs_generated_height.py` (default-height bound + all-rows-present + collapsed-with-scroll guards) catches a regression of this page; the T-2042 exhaustive sweep catches the next new page automatically.

## Evolution

### 2026-05-25 — distinct shape required a two-part fix
- **What changed:** Unlike the single-table siblings (T-2044/T-2045) and card-list siblings (T-2043), this page is a *list of 31 collapsible sections*. Collapse-by-default alone bounds the default render, BUT the largest subsystem is 246 rows (~10,129px) — over the 8000px cap — so an expanded section would itself be unbounded.
- **Plan impact:** Applied BOTH fixes: (1) remove `open` so sections collapse by default, (2) wrap each table in a `.docs-subsystem-scroll` max-height container so even a fully-expanded giant section scrolls internally.
- **Triggered:** Collapse-by-default is a deliberate UX change (all-expanded → click-to-expand) — flagged as a `[REVIEW]` AC so the human can confirm the trade or ask for first-section-open.

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

### 2026-05-25 — collapse-by-default + per-section scroll container
- **Chose:** Remove `open` from the subsystem `<details>` (collapse by default) AND wrap each table in a `max-height: 70vh` scroll container with sticky `thead`.
- **Why:** With 31 sections, keeping them all open and only adding scroll containers still sums to >8000px (31 × min-height). Collapsing bounds the default state to a 31-row index; the scroll container handles the one oversized section (246 rows) when a user expands it. Together they keep all 765 rows reachable while bounding both the default and any single expanded section.
- **Rejected:** Collapse-only (no scroll container) — leaves the 246-row section unbounded once expanded (10,129px). Keep-open + scroll-only — 31 min-height containers still overflow the page. Pagination — adds round-trips/state, overkill for a static index. Keeping first section open — slightly friendlier first impression, but inconsistent and the largest section happens to be `framework-core` (130) / `context-fabric` (45); left as a one-line toggle the human can request via the [REVIEW] AC.

## Recommendation

**Recommendation:** GO

**Rationale:** The unbounded height is fixed; all rows stay reachable; the largest expandable section is now bounded by its own scroll container. The one judgment call — collapse-by-default changes the index from all-expanded to click-to-expand — is surfaced as a `[REVIEW]` AC with a one-line revert offered. Agent-side everything passes.

**Evidence:**
- Default height: 34,671px → **1,281px** (Playwright, post-restart) — well under the 8000px cap
- 31 subsystems, **765 rows retained** in the DOM (collapsed, not dropped)
- Largest expanded section bounded: 246 rows, container clientHeight **628px** < scrollHeight **10,129px** → scrolls internally
- `tests/playwright/test_docs_generated_height.py` — **3 passed**
- Eyes-on screenshot (collapsed index): http://192.168.10.107:3000/static/ux-review/T-2047-docsgen-collapsed.png

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-25T14:53:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2047-docsgenerated-renders-34000px-tall--unbo.md
- **Context:** Initial task creation

### 2026-05-25T15:30:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b999a2d8
- **Timestamp:** 2026-05-26T06:57:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — `tests/playwright/test_docs_generated_height.py` added and passing (default-height bound + all-rows-present + scroll-container guards) — **3 passed**
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_docs_generated_height.py in: `tests/playwright/test_docs_generated_height.py` added and passing (default-height bound + all-rows-present + scroll-container guards) — **3 passed**`

### 2026-05-26T06:57:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
