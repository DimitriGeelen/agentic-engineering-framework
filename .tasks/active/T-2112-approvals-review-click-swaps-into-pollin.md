---
id: T-2112
name: "/approvals 'Review' click swaps into polling div + bounces back after 10s —
  hx-target inheritance bug"
description: >
  USER report: clicking Review on /approvals Arc-Closure card briefly shows the /arcs/<slug>/review
  page, then 'jumps back' after a few seconds. Root cause: #approvals-content has
  hx-target='this' for its own 10s polling. htmx hx-target attribute INHERITS to descendant
  elements. The Review button (an <a> inside #approvals-content) gets the inherited
  target. Clicking it swaps the new content INTO #approvals-content (NOT #content)
  — leaving the old breadcrumb+heading above it. 10s later, the polling hx-trigger='every
  10s' fires and replaces #approvals-content with /approvals/content — i.e. the original
  approvals page. That's the 'bounce back'. Fix: add explicit hx-target=#content hx-swap=innerHTML
  hx-push-url=true on the Review and Approve/Override buttons (and the T-XXX anchor
  link) inside the arc-closure cards. Sibling polling containers exist on /review/T-XXX
  and /cockpit — they likely have the same bug class but are 'one bug = one task'.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, approvals, htmx, ui-bug, arc-007]
components: [web/templates/_approvals_content.html]
related_tasks: [T-669, T-2060, T-2110, T-2111]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T15:41:12Z
last_update: '2026-05-30T15:45:03Z'
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
  - ts: '2026-05-30T15:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-30T15:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2112: /approvals 'Review' click swaps into polling div + bounces back after 10s — hx-target inheritance bug

## Context

**User report 2026-05-30:** clicking "Review" on the `/approvals` Arc-Closure card briefly shows the destination page (`/arcs/<slug>/review`), then "jumps back" to `/approvals` after a few seconds. The user described this as "larger screen disappears after no to much time".

**Forensic capture (Playwright):**

```
Before click:  breadcrumbs in DOM = 1  (Govern › Approvals)
After click:   breadcrumbs in DOM = 2  (Govern › Approvals  +  Work › Arcs › review)
              URL = /arcs/arc-grooming/review
              title = "Approvals (142 pending) ..." (stale)
              h1[0] in #content  = "Approvals (142 pending)"  (old, stale)
              h1[1] in #content  = "Review arc: Arc grooming"  (new, nested in #approvals-content)
              parent of new content = DIV#approvals-content (inside MAIN#content)
```

The new content lands inside `#approvals-content`, NOT replacing `#content`. The old shell stays visible above. Then the 10-second polling on `#approvals-content` fires and overwrites it with the original `/approvals/content` → "bounce back".

**Trail to root cause:**

1. `web/templates/base.html:506` — `<body hx-boost="true" hx-target="#content" hx-swap="innerHTML">` (correct shell-wide default).
2. `web/templates/approvals.html:237-243` — `<div id="approvals-content" hx-trigger="every 10s" hx-target="this" hx-swap="innerHTML">` (T-669 polling container). The `hx-target="this"` override is necessary for the polling itself (so the polling response doesn't blow away the page shell — T-2060).
3. **htmx inheritance**: `hx-target` is inherited by descendant elements unless they override. The Review and Approve/Override buttons live INSIDE `#approvals-content` (rendered via `_approvals_content.html` `{% include %}`). They inherit `hx-target="this"` from the polling container — NOT `hx-target="#content"` from body.
4. Click → boost fetches `/arcs/<slug>/review`, extracts `#content` from the response, but swaps innerHTML into the LOCAL inherited target (`#approvals-content`).
5. After 10s the polling fires and reverts.

**Fix shape:** Explicit `hx-target="#content" hx-swap="innerHTML" hx-push-url="true"` on every clickable navigation link inside `_approvals_content.html` that should navigate to a non-/approvals destination. The polling target inheritance is fine for elements that genuinely act on the polling div (T-669 / T-2060 intent); it's the cross-page navigation that needs the override.

## Acceptance Criteria

### Agent
- [ ] `_approvals_content.html` Review buttons (`href="/arcs/.../review"`) carry `hx-target="#content" hx-swap="innerHTML" hx-push-url="true"` so they swap into the shell, not the polling div.
- [ ] `_approvals_content.html` Approve/Override buttons (`href="/arcs/.../close"`) carry the same triplet.
- [ ] `_approvals_content.html` anchor-task links (`href="/tasks/T-XXX"`) carry the same triplet (otherwise reviewer clicks T-XXX → same bounce-back from polling overwrite).
- [ ] Forensic comment in `_approvals_content.html` near the first override names T-2112 and explains why the triplet is needed (so the next maintainer doesn't strip them as redundant).
- [ ] Playwright regression: after clicking Review and waiting >10s, the page URL stays at `/arcs/<slug>/review`, only one `nav.wt-breadcrumb` is in the DOM (not two), and the polling-div's content is NOT the old approvals content.

## Pickup-Ready Patch (for next session — budget hit ~97% mid-fix)

Apply this diff to `web/templates/_approvals_content.html` (lines 219-232 of the current file). Forensic comment + 4 anchor edits:

```diff
-            <a href="/arcs/{{ a.slug }}"><strong>{{ a.name }}</strong></a>
+            {# T-2112: explicit hx-target="#content" on every cross-page navigation link
+               inside this template. The wrapping #approvals-content div sets
+               hx-target="this" for its own 10s polling (T-669 / T-2060); htmx INHERITS
+               that to descendant anchors. Without these overrides, clicking Review or
+               an anchor-task link swaps the destination INTO the polling div (so the
+               old approvals shell breadcrumb/heading stays above it) and the next
+               polling cycle (≤10s) overwrites the swapped content with /approvals/content
+               — i.e. "bounces back". Triplet here = target + swap + push-url so the
+               browser URL also updates correctly. #}
+            <a href="/arcs/{{ a.slug }}"
+               hx-target="#content" hx-swap="innerHTML" hx-push-url="true"><strong>{{ a.name }}</strong></a>
             <span style="font-size:0.8rem; color:var(--pico-muted-color);">
                 {{ a.completed }}/{{ a.total }} — {{ "%.0f%%" % (a.completion_ratio * 100) }}
             </span>
             {% if a.anchor %}
             <span style="font-size:0.78rem; color:var(--pico-muted-color);">
-                · anchor <a href="/tasks/{{ a.anchor }}">{{ a.anchor }}</a>
+                · anchor <a href="/tasks/{{ a.anchor }}"
+                            hx-target="#content" hx-swap="innerHTML" hx-push-url="true">{{ a.anchor }}</a>
             </span>
             {% endif %}
         </div>
         <div style="display:flex; gap:0.4rem;">
-            <a href="/arcs/{{ a.slug }}/review" role="button" class="secondary outline" style="margin:0; font-size:0.78rem;">Review</a>
-            <a href="/arcs/{{ a.slug }}/close" role="button" style="margin:0; font-size:0.78rem;">Approve / Override</a>
+            <a href="/arcs/{{ a.slug }}/review" role="button" class="secondary outline"
+               hx-target="#content" hx-swap="innerHTML" hx-push-url="true"
+               style="margin:0; font-size:0.78rem;">Review</a>
+            <a href="/arcs/{{ a.slug }}/close" role="button"
+               hx-target="#content" hx-swap="innerHTML" hx-push-url="true"
+               style="margin:0; font-size:0.78rem;">Approve / Override</a>
         </div>
```

After applying:
1. Restart Watchtower (`bin/fw watchtower restart`)
2. Add Playwright test `tests/playwright/test_approvals_arc_review_navigation.py`:
   - goto `/approvals`, click Review on first arc-closure card
   - wait 12s (>polling interval)
   - assert `pg.url` still matches `/arcs/<slug>/review`
   - assert `document.querySelectorAll('nav.wt-breadcrumb').length == 1`
   - assert `document.querySelectorAll('h1').length == 1` (only the review heading, not the approvals one)
3. Run the 5 Verification commands above
4. Tick all 5 Agent ACs; add a `[REVIEW]` Human AC for visual confirmation
5. Write `## Recommendation` block + `## Evolution` entry
6. `bin/fw task update T-2112 --status work-completed`

## Sibling concern (NOT filed yet)

Other pages with the same `hx-target="this"` polling pattern likely have the same bug class:
- `web/templates/review.html:595` — `/review/T-XXX` polling container
- `web/templates/cockpit.html:282` — cockpit activity polling

After T-2112 ships, audit those for any boosted anchor links inside the polling container; file siblings if they bounce-back too. One bug = one task.

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

grep -q 'hx-target="#content".*hx-push-url="true"' web/templates/_approvals_content.html
grep -c 'hx-target="#content"' web/templates/_approvals_content.html > /tmp/.t2112-count && test "$(cat /tmp/.t2112-count)" -ge 3
grep -q 'T-2112' web/templates/_approvals_content.html
curl -sf "$(bin/fw watchtower url)/approvals" > /tmp/.t2112-page.html && grep -q 'hx-target="#content"' /tmp/.t2112-page.html
python3 -m pytest tests/playwright/test_approvals_arc_review_navigation.py -q --no-header > /tmp/.t2112-test.log 2>&1 && tail -1 /tmp/.t2112-test.log | grep -q "passed"

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

### 2026-05-30T15:41:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2112-approvals-review-click-swaps-into-pollin.md
- **Context:** Initial task creation
