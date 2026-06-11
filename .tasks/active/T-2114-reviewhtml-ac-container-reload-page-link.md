---
id: T-2114
name: "review.html #ac-container Reload-page link + markdown-rendered URLs bounce-back
  — htmx hx-target inheritance, third sibling of T-2112"
description: >
  review.html #ac-container Reload-page link + markdown-rendered URLs bounce-back
  — htmx hx-target inheritance, third sibling of T-2112

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, review, htmx, ui-bug, arc-007]
components: [web/templates/_review_acs.html]
related_tasks: [T-2112, T-2113, T-2060, T-667, T-1575]
arc_id: watchtower-redesign
created: 2026-05-30T16:32:35Z
last_update: '2026-06-11T22:23:32Z'
date_finished: 2026-05-30T16:40:31Z
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2114: review.html #ac-container Reload-page link + markdown-rendered URLs bounce-back — htmx hx-target inheritance, third sibling of T-2112

## Context

Third sibling of T-2112 (arc-007). `review.html:592-598` declares `<div id="ac-container" hx-target="this" hx-trigger="every 5s">` for the per-task polling fragment (T-667). Descendants inside `_review_acs.html` inherit `hx-target="this"`:

1. The explicit "Reload page" link (`<a href="/review/{task_id}">`) at line 83 — clicking it swaps the full review page response INTO the small `#ac-container` div.
2. **All markdown-rendered URLs** inside AC `Steps`/`Expected`/`If not` text (e.g. `<a href="/tasks/T-XXX">T-XXX</a>` produced by `render_markdown_safe`) — same bounce-back class. Anyone clicking a task ID in an AC instruction gets the destination swapped into the polling div, then 5s later the polling overwrites it.

Higher anchor density than T-2112/T-2113 because every AC body's user-text gets URL-linkified.

**Chosen fix shape (cleaner than the per-anchor triplet used for T-2112/T-2113):** wrap the body of `_review_acs.html` in a single `<div hx-target="#content" hx-swap="innerHTML" hx-push-url="true">` that resets the inheritance for all descendants. The polling DIV's `hx-target="this"` still resolves correctly on the polling DIV itself (the resolver checks the element initiating the request, not its descendants). One reset > 4+ overrides on each rendered anchor — and it covers markdown-rendered URLs automatically.

## Acceptance Criteria

### Agent
- [x] `_review_acs.html` content is wrapped in a `<div hx-target="#content" hx-swap="innerHTML" hx-push-url="true">` (or equivalent) so descendants inherit the page-shell target, breaking the polling-div inheritance.
- [x] The polling cycle on `#ac-container` still functions: `GET /review/T-XXX/acs` swaps into `#ac-container` itself (NOT `#content`) — verified by the playwright test asserting URL stability + wrapper persistence after 7 s (one polling cycle + safety).
- [x] Forensic comment in `_review_acs.html` names T-2114 and references T-2112 + T-2113.
- [x] Playwright regression: navigates to `/review/T-2112`, asserts the wrapper is present, then waits 7 s past the 5-s polling interval and asserts URL stable + wrapper still present.
- [x] Manual curl: rendered `/review/T-2112/acs` fragment shows the wrapping div with `hx-target="#content"` at the top.

### Human
- [ ] [REVIEW] Open `/review/T-XXX` for any task with Human ACs that contain URLs. Click a URL inside the AC Steps/Expected/If-not text. The URL must open as a full page swap, not a swap into the small AC fragment.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2112
  2. Locate an AC whose Steps or Expected text contains a clickable URL (e.g. a `/tasks/T-XXX` reference)
  3. Click that URL
  4. Wait at least 7 seconds
  **Expected:** The destination page replaces the entire content area, NOT just the AC fragment. URL bar updates. No stale review-page heading visible above.
  **If not:** Reopen T-2114 with a screenshot of the stacked layout.

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

grep -q 'T-2114' web/templates/_review_acs.html
grep -q 'hx-target="#content"' web/templates/_review_acs.html
curl -sf "$(bin/fw watchtower url)/review/T-2112/acs" > /tmp/.t2114-frag.html && grep -q 'hx-target="#content"' /tmp/.t2114-frag.html
python3 -m pytest tests/playwright/test_review_acs_navigation.py -q --no-header > /tmp/.t2114-test.log 2>&1 && tail -1 /tmp/.t2114-test.log | grep -q "passed"

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

## RCA

**Symptom:** Clicking any URL inside an AC's Steps/Expected/If-not text on `/review/T-XXX` — OR the explicit "Reload page" link after task completion — swaps the destination INTO `#ac-container`. The review page shell stays visible above; 5 s later the AC-polling cycle overwrites the swap with the original AC fragment → "bounce back to /review". Not yet user-reported (predicted from T-2112+T-2113 sweep).

**Root cause:** Same htmx `hx-target` inheritance class as T-2112 and T-2113. `review.html:592` wraps the AC area in `<div id="ac-container" hx-target="this" hx-trigger="every 5s">` (T-667). Every descendant `<a>` inherits `hx-target="this"`. Two flavours of descendant anchor were affected:
1. **Explicit anchors** in `_review_acs.html` (the "Reload page" link at line 83).
2. **Markdown-rendered anchors** emitted by `render_markdown_safe` from AC user-text (`Steps:` blocks, `Expected:`, `If not:`). Higher anchor density than T-2112/T-2113 because *every* URL inside an AC body becomes a candidate.

**Why structurally allowed:** Same L-438 gap as T-2112/T-2113. The per-anchor triplet fix worked for the previous two but does not extend to dynamically-rendered URLs — `render_markdown_safe` would need patching at the rendering layer, which is broader blast radius than this single template.

**Prevention:**
1. **Wrapper-reset pattern (chosen):** A single `<div hx-target="#content" hx-swap="innerHTML" hx-push-url="true">` at the top of `_review_acs.html`. The polling DIV's `hx-target="this"` still resolves on the polling DIV itself (htmx resolves hx-target on the element issuing the request, not on its descendants). The reset wrapper rewires the inheritance for all descendants — including markdown-rendered URLs. One reset > N per-anchor overrides + covers anchors we'd never enumerate.
2. **Playwright regression** (`tests/playwright/test_review_acs_navigation.py`) — pins the wrapper presence + URL stability over a polling cycle.
3. **Broader prevention candidate (L-438 extension):** with three instances now (T-2112 ascending-anchor, T-2113 ascending-anchor, T-2114 ascending-anchor + markdown-density), the case for a template-shape lint is strong. Out of scope for this single-bug task; should be filed as a separate inception (`detector-for-hx-target-inheritance-bounce-back`) following arc-007's "one bug = one task" cadence.

## Evolution

### 2026-05-30 — wrapper-reset > per-anchor triplet when anchor population is dynamic

- **What changed:** T-2112 and T-2113 used a per-anchor triplet on each cross-page link. That works for templates with a small, enumerable set of anchors. `_review_acs.html` contains user-text passed through `render_markdown_safe` — every URL in AC text becomes an anchor at render time. We'd need to either patch the renderer (broad blast radius) or wrap the whole fragment in a target-reset div. The wrapper is cleaner; the polling cycle still functions because hx-target resolves on the polling DIV itself, not its descendants.
- **Plan impact:** The fix shape SHOULD have been wrapper-reset from T-2112 onwards. But three independent instances were the trigger to learn this — the pattern is now established. Future polling-container surfaces should default to wrapper-reset.
- **Triggered:** L-438 extension candidate documented in RCA. A class-detector inception is appropriate after this third instance; out of scope here.

## Recommendation

**Recommendation:** GO

**Rationale:** Wrapper-reset pattern lands cleanly on the highest-anchor-density polling surface. Polling cycle preserved (verified by 7-s wait + wrapper-still-present assertion). Single forensic-commented div covers all current and future descendant anchors — including markdown-rendered URLs that would have required render-layer patching otherwise. Third instance of the class confirms the fix shape and justifies a separate detector inception (not in this task).

**Evidence:**
- Patch: `web/templates/_review_acs.html` — one wrapper-reset div at the top, closing div at end, multi-line forensic comment block naming T-2114 + cross-referencing T-2112, T-2113, and the bounce-back RCA.
- Rendered fragment carries the wrapper: `curl /review/T-2112/acs | grep hx-target='#content'` returns 1 occurrence (the wrapper) — body anchors inherit silently.
- Playwright passes (2 tests, 7.7 s combined): wrapper-presence + URL-stability-after-polling-cycle.
- All 4 Verification commands return OK.

**Follow-up candidate (NOT in this task):** file an inception for "htmx hx-target-inheritance-bounce-back detector" — three instances justify it; arc-007's "one bug = one task" cadence keeps that distinct from this fix.

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

### 2026-05-30T16:32:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2114-reviewhtml-ac-container-reload-page-link.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d58288ab
- **Timestamp:** 2026-05-30T16:41:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `python3 -m pytest tests/playwright/test_review_acs_navigation.py -q --no-header > /tmp/.t2114-test.log 2>&1 && tail -1 /tmp/.t2114-test.log | grep -q "passed"`

### 2026-05-30T16:40:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
