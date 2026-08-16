---
id: T-1963
name: "/arcs/<slug>/review route — read-only review surface (separate from /close)"
description: >
  T-1959 build child D: same template as review.html. Linked from /approvals (T-1961)
  and from fw arc review (T-1962). /close becomes the submit handler; /review is the
  consume-the-recommendation surface. Closes the asymmetry with inception-decide flow
  (/inception/T-XXX vs /review/T-XXX is the canonical pattern).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [approval-ux, watchtower, arc, T-1959-followup, arc:arc-grooming]
components: [tests/playwright/test_arc_review_route.py, web/blueprints/arcs.py, 
      web/templates/_approvals_content.html, web/templates/arc_review.html]
related_tasks: [T-1959, T-1960, T-1961, T-1962, T-1911]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T17:57:15Z
last_update: '2026-08-16T22:24:01Z'
date_finished: 2026-05-21T17:51:33Z
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
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
      F2: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=1 (body/tag hits for 'F2':
      1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:27Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1963: /arcs/<slug>/review route — read-only review surface (separate from /close)

## Context

T-1959 child D. T-1960 + T-1961 wired the rec onto the anchor and surfaced close-ready arcs on /approvals — but the "Review" CTA on each row currently points to `/arcs/<slug>` (the generic detail page) because the dedicated read-only review surface didn't exist. That breaks parity with the inception flow (`/inception/T-XXX` vs `/review/T-XXX`) and forces the human to dig through tabs to find the rec.

T-1963 adds a thin GET-only `/arcs/<slug>/review` route that renders the anchor-task Recommendation, headline mechanic, completion stats, and a single "Approve / Override" CTA to `/arcs/<slug>/close`. T-1961's Review CTA gets re-pointed to it.

## Acceptance Criteria

### Agent
- [x] New GET-only route `/arcs/<arc_id>/review` in `web/blueprints/arcs.py` resolves the arc (404 on miss), calls `_anchor_recommendation`, renders `arc_review.html` — no POST handler (read-only); closed/abandoned arcs still render (vs `/close` which redirects)
- [x] New `web/templates/arc_review.html` renders: arc header (name, slug, status), headline mechanic (when present), completion stats, the Agent Recommendation panel from T-1960 (verdict badge + rationale_html + evidence_html + suggested demo), an "Approve / Override" CTA linking to `/arcs/<arc_slug>/close`, and a back link to `/arcs/<arc_slug>`
- [x] When the arc has no anchor task OR no `## Recommendation` block, the page still renders (with an empty-state message instead of the rec panel)
- [x] `_approvals_content.html` ARC CLOSURE section "Review" CTA hrefs swap from `/arcs/{{ a.slug }}` to `/arcs/{{ a.slug }}/review`
- [x] Playwright test `tests/playwright/test_arc_review_route.py` asserts the page renders for arc-006 (value-prioritisation, anchor T-1915 with rec) and arc-005 (dispatch-safety, closed but still readable) — DOM-content per T-1575
- [x] `python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"` succeeds
- [x] Watchtower restart + `curl /arcs/value-prioritisation/review` returns 200 with recommendation panel; `curl /arcs/dispatch-safety/review` returns 200 (does NOT 302-redirect, unlike `/close`)

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

- [ ] [REVIEW] /arcs/<slug>/review reads cleanly as a "decide from a brief" surface — header + headline mechanic + completion stats + rec panel + single Approve/Override CTA; no clutter, no editable fields, no §ACD prompt (that lives on /close)
  **Steps:**
  1. Open http://192.168.10.107:3000/arcs/value-prioritisation/review
  2. Read the page top-to-bottom — confirm there are no editable form fields
  **Expected:** Page reads as a brief. Layout: arc name + status + headline mechanic, then "X/Y constituent tasks completed", then the Agent Recommendation panel, then a prominent "Approve / Override" button that navigates to `/close`. No form, no §ACD prompt, no inputs. Back link returns to `/arcs/<slug>`.
  **If not:** Note what feels editable/clutter (a stray input field, the §ACD prompt leaking through, missing back link).

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

python3 -c "import ast; ast.parse(open('web/blueprints/arcs.py').read())"
FW_TEST_PORT=3000 python3 -m pytest tests/playwright/test_arc_review_route.py -q
WT=$(bin/fw watchtower url); out=$(curl -s -o /dev/null -w "%{http_code}" "$WT/arcs/value-prioritisation/review"); [[ "$out" == "200" ]]
WT=$(bin/fw watchtower url); out=$(curl -s -o /dev/null -w "%{http_code}" "$WT/arcs/dispatch-safety/review"); [[ "$out" == "200" ]]
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

### 2026-05-21 — closed-arc behaviour: render instead of redirect
- **What changed:** `/close` 302-redirects when the arc is closed/abandoned (sensible — the form is no longer actionable). For `/review`, the rec should remain *readable* after closure, so the human can audit later what was decided. Made `/review` render in all states; only the "Approve / Override → Close form" CTA is suppressed when status ∈ (closed, abandoned), replaced with a muted notice.
- **Plan impact:** AC says "closed/abandoned arcs still render" — captured directly in the template branch (`_closed` flag).
- **Triggered:** Playwright test pins this: `test_arc_review_renders_for_closed_arc_without_redirect` asserts 200 (not 302) for dispatch-safety.

### 2026-05-21 — empty-rec absence-rendering (no anchor or no block)
- **What changed:** When the arc has no `anchor_task` OR the anchor's body lacks a `## Recommendation` block, the page must still render usefully — the human came here to *find* the rec. Added a `.empty-rec` dashed-border block with explicit "open the anchor task and write one" guidance instead of failing silent.
- **Plan impact:** Template needs both presence and absence branches; helper already returns `present: False` in those cases (from T-1960 work).
- **Triggered:** None — both branches landed in the same commit.

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

**Recommendation:** GO

**Rationale:** Closes the T-1959 trilogy (T-1960 wired the rec onto the anchor, T-1961 listed close-ready arcs on /approvals, T-1963 gives them a dedicated read-only review surface). Now /approvals Review CTA points at `/arcs/<slug>/review` — a brief-style read of the rec with one CTA to act. Matches the inception flow's `/inception/T-XXX` vs `/review/T-XXX` split. Closed arcs stay readable for audit; absence-rendering keeps the page useful even when no rec is written yet. All ACs ticked, 6/6 Playwright green, live smoke confirms 200/200/404 for in-progress/closed/nonexistent.

**Evidence:**
- `web/blueprints/arcs.py`: new GET-only route `arc_review_surface` — reuses `_read_arc`, `_resolve_constituents`, `_completion_stats`, `_anchor_recommendation`, `_arc_reports`; renders `arc_review.html`
- `web/templates/arc_review.html`: arc header + headline mechanic + completion stats + rec panel (present/absent branch) + Approve/Override CTA (suppressed when arc is closed/abandoned) + back link to detail
- `web/templates/_approvals_content.html`: Review CTA href swapped from `/arcs/{{ a.slug }}` → `/arcs/{{ a.slug }}/review`
- Playwright `tests/playwright/test_arc_review_route.py` (6 tests, PASS) — header visible, panel visible, anchor link, /close CTA href, no editable form fields (read-only contract), closed-arc 200 (no 302), nonexistent 404
- Live smoke: `/arcs/value-prioritisation/review` returns 200 with verdict-GO panel; `/arcs/dispatch-safety/review` returns 200 with closed-state notice (no redirect); `/arcs/nonexistent-arc/review` returns 404

**Review on Watchtower:** http://192.168.10.107:3000/review/T-1963

## Updates

### 2026-05-20T17:57:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1963-arcsslugreview-route--read-only-review-s.md
- **Context:** Initial task creation

### 2026-05-21T17:46:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-75d4bf22
- **Timestamp:** 2026-05-21T17:51:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — New `web/templates/arc_review.html` renders: arc header (name, slug, status), headline mechanic (when present), completion stats, the Agent Recommendation panel from T-1960 (verdict badge + rationale_
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_review.html in: New `web/templates/arc_review.html` renders: arc header (name, slug, status), headline mechanic (when present), completion stats, the Agent Recommenda`

### 2026-05-21T17:51:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
