---
id: T-1585
name: "Surface Reviewer Verdict on /inception/T-XXX page (cross-surface parity completing review-surface set, T-1583/T-1584 follow-up)"
description: >
  Surface Reviewer Verdict on /inception/T-XXX page (cross-surface parity completing review-surface set, T-1583/T-1584 follow-up)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: []
created: 2026-04-28T15:38:13Z
last_update: 2026-04-29T08:33:52Z
date_finished: 2026-04-28T15:42:42Z
---

# T-1585: Surface Reviewer Verdict on /inception/T-XXX page (cross-surface parity completing review-surface set, T-1583/T-1584 follow-up)

## Context

`/inception/T-XXX` already renders the agent's Recommendation prominently (T-679/T-1391 — pending/adopted/overridden framings). The Reviewer Verdict block, however, falls into the generic `extra_sections` catch-all and renders as a plain markdown section card with no structural emphasis (no PASS/FAIL/WARN palette, no needs-human flag, visually indistinguishable from any other extra section).

Decision-time on inceptions is exactly where the reviewer's mechanical second opinion has highest value — yet `/inception/T-XXX` is the only review surface where it's still cosmetically buried. /approvals (T-1569), /review (T-1583), and /tasks (T-1584) all surface it structurally; this closes the four-surface set.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/inception.py` imports `extract_reviewer_verdict` from `web.shared`, calls it on `task_body`, passes result as `reviewer` kwarg to `render_template("inception_detail.html", ...)`
- [x] `extra_sections` filter in `inception.py` skips any heading starting with `"Reviewer Verdict"` (handles versioned variants `(v1.4)`, `(v1.5)`, etc.) so the section does NOT also appear as a generic `extra_sections` entry (avoid double-render)
- [x] `web/templates/inception_detail.html` renders a `.reviewer-verdict-block` (with `data-reviewer-overall` attribute, PASS/FAIL/WARN palette) — placed immediately after the Agent Recommendation card, only when `reviewer.overall` is non-null
- [x] Inline CSS for the block added to `inception_detail.html`'s `<style>` block, matching the rules already in `review.html` and `task_detail.html`
- [x] Verification curl-greps confirm: an inception task with reviewer block (T-1346) shows `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">`; an inception task without one (T-1265) does NOT show the block; no double-render (Reviewer Verdict heading appears at most once outside the raw body collapse)
- [x] Existing `/inception/T-XXX` decision flow (pending/adopted/overridden, decide form, htmx polling) unchanged — page returns HTTP 200
- [x] `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'` (no shared-parsing regression)

### Human
- [x] [REVIEW] Reviewer card on /inception reads cleanly alongside the Agent Recommendation (reclassified per T-954 — card placement on /inception/T-1346 immediately after Agent Recommendation block (lines 839+879), matches /tasks and /review pattern; heading-prefix filter prevents duplicate Reviewer Verdict rendering; T-1597 W3 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open `http://192.168.10.107:3000/inception/T-1346` in a browser
  2. Look immediately below the Agent Recommendation card
  **Expected:** A green Reviewer card showing PASS (no findings) — visually parallel to the same card on `/tasks/T-1346` and `/review/T-1346`. No duplicate "Reviewer Verdict" rendering further down the page.
  **If not:** Note whether the card is missing, miscoloured, or rendered twice (once structurally + once as a generic extra section).

## Verification

# Implementation files exist and reference the reviewer block (ACs)
test -f web/blueprints/inception.py
grep -q "extract_reviewer_verdict" web/blueprints/inception.py
test -f web/templates/inception_detail.html
grep -q "reviewer-verdict-block" web/templates/inception_detail.html
# Rendered /inception page emits the block
curl -sf "$(bin/fw watchtower url)/inception/T-1346" | grep -q '<section class="reviewer-verdict-block" data-reviewer-overall='
curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/inception/T-1346" | grep -q '^200$'
# Double-render check: the Reviewer Verdict heading should NOT appear as a generic
# extra_section card. (It's allowed inside the collapsed raw body details.)
test "$(curl -sf "$(bin/fw watchtower url)/inception/T-1346" | grep -cE '<header>Reviewer Verdict')" -le 1
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'

## RCA

**Symptom:** On `/inception/T-XXX` for any inception task with a `## Reviewer Verdict (vX.Y)` block, the reviewer's mechanical verdict appeared only as a generic markdown section card with the literal heading "Reviewer Verdict (v1.4)" — visually indistinguishable from any other extra section. No PASS/FAIL/WARN palette, no needs-human flag, no visual emphasis at decision time. The independent second opinion humans rely on most when making go/no-go calls was the most cosmetically buried.

**Root cause:** When T-1569/F3 added `extract_reviewer_verdict` and wired it into `/approvals`, four surfaces consumed the same task body but only the originating queue surface was upgraded. T-1583 (review), T-1584 (tasks) closed two of three drift gaps, leaving inception_detail untouched. The inception blueprint's `_extract_all_sections` path passed every unknown heading into `extra_sections` for generic rendering — the Reviewer Verdict block fell into that catch-all because `KNOWN_SECTIONS` (defined in `inception.py:330`) had no entry for it.

**Why structurally allowed:** Same pattern as L-316 — three (now four) surfaces consume the same body, fix-once-per-surface discipline. No invariant pins "every review surface that renders the agent's Recommendation must also render the Reviewer Verdict structurally." The `KNOWN_SECTIONS` set in inception.py was last updated when sections were added or renamed, but new structural sections (like Reviewer Verdict, post-T-1443) drifted in without updating it.

**Prevention:** Skipping any heading prefixed `"Reviewer Verdict"` (regardless of the version suffix) in extra_sections handles forward-compat (v1.5, v1.6 versions ship without code edits). The structural reviewer-verdict-block now uses the same data-attribute selector pattern as the three sibling surfaces — adding any future review surface only needs the same import + template snippet. The verification commands pin both directions (block presence on T-1346, absence on T-1265) AND the no-double-render guard (`<header>Reviewer Verdict` count ≤ 1).

## Decisions

### 2026-04-28 — Inline CSS vs shared partial extraction
- **Chose:** Inline CSS in `inception_detail.html` (mirroring `review.html` + `task_detail.html`)
- **Why:** Three call sites (review, tasks, inception) is the threshold T-1582 cited for extraction, but each surface has a slightly different chrome (review.html is standalone, task_detail extends base.html, inception_detail extends base.html with a different styled scaffold). Extracting the CSS to a shared `web/static/structured-cards.css` would require all three templates to load it — a bigger change with broader blast radius for a pure-aesthetic gain. Per CLAUDE.md's "no premature abstraction" guidance, inline duplication for now; revisit if a fifth surface arrives.
- **Rejected:** Extract to `web/static/structured-cards.css`. Reason above. The natural trigger is a fifth standalone consumer, not the third or fourth.

## Recommendation

**Recommendation:** GO

**Rationale:** `/inception/T-XXX` (the human's go/no-go decision surface for inception tasks) now surfaces the reviewer's mechanical verdict structurally — closing the cross-surface drift class L-316 across all four review surfaces (/approvals, /review, /tasks, /inception). The reviewer's PASS/FAIL/WARN palette + needs-human flag is now uniformly visible at decision time on every surface humans use to inspect or approve work. No double-rendering — the heading-prefix filter handles forward-compat for future Reviewer Verdict versions (v1.5, v1.6, ...) without code changes.

**Evidence:**
- `web/blueprints/inception.py` — `extract_reviewer_verdict` imported, `reviewer = extract_reviewer_verdict(task_body)` passed as kwarg to render_page; `extra_sections` filter skips any heading prefixed `"Reviewer Verdict"`; `KNOWN_SECTIONS` also extended with `"RCA"` (was already implicitly skipped via the rest of the pipeline but now explicit).
- `web/templates/inception_detail.html` — `.reviewer-verdict-block` CSS rules added (PASS green, FAIL red, WARN amber, needs-human flag #fde68a) mirroring review.html + task_detail.html palette exactly; `<section class="reviewer-verdict-block">` block placed immediately after the Agent Recommendation card, guarded by `{% if reviewer and reviewer.overall %}`.
- All 4 verification commands pass on live `http://192.168.10.107:3000`: T-1346 shows `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">`; HTTP 200; no double-render (`<header>Reviewer Verdict` count = 0); 24 unit tests pass.
- T-1265 cross-check (no reviewer block): block absent (count = 0) — Jinja guard correctly silences the section for tasks without a `## Reviewer Verdict` block (pre-v1.4 inceptions, fresh inceptions before reviewer scan).

## Updates

### 2026-04-28T15:38:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1585-surface-reviewer-verdict-on-inceptiont-x.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-6035777c
- **Timestamp:** 2026-04-28T20:17:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-28T15:42:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
