---
id: T-2134
name: "ac-check form hx-target=this (T-2133 GO slice A+B — surgical fix + test pin)"
description: >
  ac-check form hx-target=this (T-2133 GO slice A+B — surgical fix + test pin)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [bug, regression, htmx, review-surface, fix, T-2133-implementation]
components: [web/templates/_review_acs.html]
related_tasks: [T-2133, T-2131, T-2114]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T07:16:22Z
last_update: 2026-05-31T19:52:09Z
date_finished: 2026-05-31T07:22:33Z
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
---

# T-2134: ac-check form hx-target=this (T-2133 GO slice A+B — surgical fix + test pin)

## Recommendation

**Recommendation:** GO (build complete, agent ACs verified, awaiting human real-browser confirmation)

**Rationale:** T-2133 RCA identified the regression conclusively (htmx:targetError on inherited hx-target=#content). The fix is one HTML attribute on the ac-check form — `hx-target="this"` resolves to the form element itself and overrides the inherited #content lookup. Verified end-to-end: rendered HTML carries the attribute (curl), Playwright test pin passes (44.90s), live browser_evaluate confirms htmx:configRequest fires with CSRF header and zero targetError. Sovereignty preserved throughout (the aborted XHR + post-click grep both confirm T-2131's Human AC remained `[ ]`).

**Evidence:**
- Fix commit: `web/templates/_review_acs.html` ac-check form now has `hx-target="this"` between hx-vals and hx-swap
- Playwright pin: `tests/playwright/test_review_interaction.py::TestACCheckboxClickFlow::test_ac_checkbox_click_posts_to_toggle_endpoint` PASSED (1 passed in 44.90s)
- Live browser: htmx:configRequest with `path=/api/task/T-2131/toggle-ac`, `verb=post`, X-CSRF-Token present; no htmx:targetError fired (was the smoking gun pre-fix)
- T-2131 unmodified: grep of AC lines + watchtower.log POST count both confirm sovereignty preserved
- RCA detail: `docs/reports/T-2133-review-checkbox-htmx-target-error-rca.md`

## Context

Build slice A+B of T-2133 (GO recorded). Surgical fix for the `/review` checkbox regression: the `<form class="ac-check">` in `web/templates/_review_acs.html:35` is missing an explicit `hx-target`, so it inherits `hx-target="#content"` from the T-2114 wrapper-reset div. Standalone `review.html` has no `#content` element, htmx fires `htmx:targetError`, and the POST is aborted before any network call. Fix: add `hx-target="this"` to the form (hx-swap="none" makes the target irrelevant for the response, but htmx still requires it to resolve to a real element).

See `docs/reports/T-2133-review-checkbox-htmx-target-error-rca.md` for full RCA evidence.

## Acceptance Criteria

### Agent
- [x] `web/templates/_review_acs.html` `<form class="ac-check">` declares explicit `hx-target="this"` (the form element itself — always resolves, makes the inherited #content moot)
- [x] `curl -s "$URL/review/T-2131" | grep -c 'class="ac-check"'` shows the rendered form still present (sanity: didn't accidentally delete the form) — returned 1
- [x] Rendered HTML contains `hx-target="this"` on the ac-check form (multi-line aware — attribute is on a separate line from the class): `curl -s "$URL/review/T-2131" | grep -A3 'class="ac-check"' | grep -q 'hx-target="this"'` — PASS
- [x] Playwright pin: `tests/playwright/test_review_interaction.py::TestACCheckboxClickFlow::test_ac_checkbox_click_posts_to_toggle_endpoint` passes against running watchtower (the test route-intercepts the POST, asserting the click reaches the endpoint — the exact contract this fix restores) — PASSED in 44.90s

**Live browser verification (Playwright browser_evaluate, sovereignty-preserved by aborting XHR in htmx:beforeRequest):**
- `htmx:configRequest` fires with `path: /api/task/T-2131/toggle-ac`, `verb: post`, `X-CSRF-Token` header **present**
- `htmx:targetError` does **not** fire (was the smoking gun before the fix)
- T-2131 Human AC remained `[ ]` after click (verified by `grep "^- \[" .tasks/active/T-2131-*.md` + zero POST entries in `watchtower.log`)

### Human
- [x] [REVIEW] Real-browser click verification — the regression is gone
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2131 in your actual browser (the one you used when you reported the bug)
  2. Click the checkbox next to "Pasting an inception URL `/review/T-2123` lands on the correct inception decide form"
  3. Observe: the checkbox should TICK and STAY ticked (not bounce back after 5 seconds)
  4. The AC list above should re-render with the AC marked ✅ and the "Human ACs: 1/1" counter incrementing
  **Expected:** Click persists; counter increments; no console errors (htmx:targetError should be gone)
  **If not:** Open browser DevTools → Console; look for `htmx:targetError` or any 4xx/5xx network call on `/api/task/T-2131/toggle-ac`. Report what you see; the fix may need an additional sibling form override.

<!-- Note: this [REVIEW] is genuinely human — curl/Playwright can verify the wire, but only the human can confirm the bug they reported is gone in their own browser. Render-surface gate (P-013) also requires at least one [REVIEW] on web/templates/ edits. -->

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

# T-2134 verification — running watchtower URL, sanity + contract checks.
# Multi-line aware: ac-check form's hx-target attribute is on a separate line
# from the class declaration (template formats one attribute per line).
url=$(bin/fw watchtower url); out=$(curl -s "$url/review/T-2131"); echo "$out" | grep -c 'class="ac-check"' | grep -qE '^[1-9]'
url=$(bin/fw watchtower url); out=$(curl -s "$url/review/T-2131"); echo "$out" | grep -A3 'class="ac-check"' | grep -q 'hx-target="this"'

## RCA

**Symptom:** User reports clicking a Human AC checkbox on `/review/T-2131` does nothing — checkbox toggles visually but reverts after 5s; server file never changes.

**Root cause:** `<form class="ac-check">` in `_review_acs.html:35` has no explicit `hx-target`. It inherits `hx-target="#content"` from the T-2114 outer wrapper-reset div (`_review_acs.html:21`). Standalone `review.html` has no `#content` element (intentional T-667 mobile-first — doesn't extend base.html). htmx 2.0.4 fires `htmx:targetError` and aborts the request *before* any of `htmx:configRequest`, `htmx:beforeRequest`, `htmx:beforeSend` — so CSRF interception (which fires on configRequest) never runs and no network call is made.

**Why structurally allowed:** T-2114 introduced the wrapper-reset to fix a different bug (anchor bounce-back on hx-boosted links inside AC body). The wrapper's safety-rail — every descendant form must declare its own `hx-target` — was documented at `_review_acs.html:3-20` but never enforced. Two of the three sibling forms (inception decide, build complete) happened to set their own target; the ac-check form did not. The Playwright test `tests/playwright/test_review_interaction.py::test_ac_checkbox_click_posts_to_toggle_endpoint` would have caught it but doesn't run on every watchtower change.

**Prevention:**
1. This fix adds `hx-target="this"` on the ac-check form (idempotent — `this` always resolves regardless of wrapper).
2. T-NEW-C (separate task) sweeps every other form inside `<div hx-target="#content">` wrappers for the same missing-override class.
3. Optional follow-up: a template-lint rule that flags forms-without-hx-target inside wrappers-with-hx-target (cheap static check, future task).

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

### 2026-05-31T07:16:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2134-ac-check-form-hx-targetthis-t-2133-go-sl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e5b8779d
- **Timestamp:** 2026-05-31T07:22:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Per-AC findings:**

- **AC#1 (Agent)** — `web/templates/_review_acs.html` `<form class="ac-check">` declares explicit `hx-target="this"` (the form element itself — always resolves, makes the inherited #content moot)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/_review_acs.html in: `web/templates/_review_acs.html` `<form class="ac-check">` declares explicit `hx-target="this"` (the form element itself — always resolves, makes the `
- **AC#4 (Agent)** — Playwright pin: `tests/playwright/test_review_interaction.py::TestACCheckboxClickFlow::test_ac_checkbox_click_posts_to_toggle_endpoint` passes against running watchtower (the test route-intercepts the
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_review_interaction.py in: Playwright pin: `tests/playwright/test_review_interaction.py::TestACCheckboxClickFlow::test_ac_checkbox_click_posts_to_toggle_endpoint` passes against`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: `url=$(bin/fw watchtower url); out=$(curl -s "$url/review/T-2131"); echo "$out" | grep -c 'class="ac-check"' | grep -qE '^[1-9]'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 36
     - evidence: `url=$(bin/fw watchtower url); out=$(curl -s "$url/review/T-2131"); echo "$out" | grep -A3 'class="ac-check"' | grep -q 'hx-target="this"'`

### 2026-05-31T07:22:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
