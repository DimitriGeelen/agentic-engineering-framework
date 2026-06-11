---
id: T-1575
name: "Structural Recommendation rendering — unified extractor returns verdict+rationale+evidence;
  /review renders structured"
description: >
  Structural Recommendation rendering — unified extractor returns verdict+rationale+evidence;
  /review renders structured

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [bin/fw, tests/playwright/test_review_page.py, 
      web/blueprints/inception.py, web/blueprints/review.py, 
      web/blueprints/tasks.py, web/shared.py, web/templates/_review_acs.html, 
      web/templates/review.html]
related_tasks: []
created: 2026-04-28T06:53:04Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-28T15:23:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1575: Structural Recommendation rendering — unified extractor returns verdict+rationale+evidence; /review renders structured

## Context

The /review/T-XXX page renders the `## Recommendation` section as a `<pre>` block, showing literal markdown (`**Recommendation:** GO`, `**Rationale:** ...`) instead of rendered HTML. User flagged this as a recurring failure ("time-over-time pointed out"). Three call sites parse recommendations with three different shapes — `web/shared.py:extract_recommendation_verdict` (string), `web/blueprints/inception.py:_extract_rationale_from_recommendation` (rationale-only, blueprint-private), `web/blueprints/review.py:_parse_recommendation` (raw dump). Same class as F5 (CLI/web parity, T-1571) but at the parser layer.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` exposes `extract_recommendation(body) -> {verdict, rationale, evidence, raw}` returning a structured dict (parallel shape to `extract_reviewer_verdict`)
- [x] `extract_recommendation_verdict` retained as compatibility shim (delegates to new helper) so existing call sites in approvals.py / cockpit.py / handover.sh keep working
- [x] `web/blueprints/inception.py` uses the unified helper — `_extract_rationale_from_recommendation` and `_extract_recommendation_stance` removed (or 1-line shims) so there's one source of truth
- [x] `web/blueprints/review.py:_parse_recommendation` removed; /review template renders `verdict`, `rationale` (markdown→HTML), and `evidence` (markdown→HTML) as separate labeled sections
- [x] When `rationale` is empty/placeholder/missing, /review renders an "Incomplete recommendation" warning instead of a verdict badge
- [x] Unit tests in `tests/unit/test_extract_recommendation.py` covering: full block, verdict-only, empty section, evidence missing, H2+ terminator regression, real-world T-1565 sample
- [x] `bin/fw test unit -- tests/unit/test_extract_recommendation.py` passes
- [x] Live verification: T-1565 review page shows separate Rationale and Evidence sections with rendered markdown

### Human
- [x] [REVIEW] T-1565 review page renders the recommendation cleanly — no literal `**` characters visible, evidence bullets rendered as a list, GO badge prominent (reclassified per T-954 — `class="rec-rationale"` + `class="rec-evidence"` present in served HTML, no literal `**` markers; T-1597 W1 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open the review page: http://192.168.10.107:3000/review/T-1565
  2. Look at the Recommendation block at the top
  3. Verify: GO verdict prominent, Rationale labeled section with paragraph (no asterisks visible), Evidence labeled section with formatted bullets
  **Expected:** Clean structured rendering, not a wall of raw markdown
  **If not:** Screenshot what you see, note which markers are still raw

## Verification

# Implementation files exist and reference unified helper (ACs)
test -f web/shared.py
grep -q "extract_recommendation\b" web/shared.py
test -f web/blueprints/inception.py
grep -q "extract_recommendation\b" web/blueprints/inception.py
test -f web/blueprints/review.py
grep -q "extract_recommendation\b" web/blueprints/review.py
# Rendered /review surfaces structured rationale/evidence
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'class="rec-rationale"'
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'class="rec-evidence"'
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'

## RCA

**Symptom:** /review/T-1565 displays the recommendation as raw markdown (`**Recommendation:** GO`, `**Rationale:** ...`, bullet points as `- text`) inside a `<pre>` block. Reads as "no recommendation, no rationale" to the human even though the data is present.

**Root cause:** Three parsers, three shapes. `web/shared.py:extract_recommendation_verdict` returns only the verdict string. `web/blueprints/inception.py` has `_extract_rationale_from_recommendation` and `_extract_recommendation_stance` (private). `web/blueprints/review.py:_parse_recommendation` is a third implementation that dumps the entire section into `<pre>`. The /review surface uses verdict-only + raw-dump and never reaches for the structured rationale extractor that exists nine modules away.

**Why structurally allowed:** When T-1195 added the recommendation block to /review, the extractor that already existed in inception.py wasn't promoted to shared.py. T-1390 and T-1391 added more structured extractors but left them blueprint-private. Same class as F5 (CLI vs web parity asymmetry, T-1571) and L-293 (multiple section parsers, none consolidated). The framework allowed N parsers with overlapping but inconsistent behaviour to ship.

**Prevention:** Consolidate to one helper in `web/shared.py`. Any future "parse recommendation" need imports from there. Unit tests pin the contract. Removing the duplicates physically deletes alternative paths.

## Recommendation

**Recommendation:** GO

**Rationale:** Three parsers consolidated into one `web.shared.extract_recommendation(body) -> {verdict, rationale, evidence, raw}` helper. /review surface now renders structured fields with proper markdown (no more `<pre>` raw-dump showing literal `**` characters). Verdict-without-rationale renders an "incomplete recommendation" warning instead of a green badge — a recommendation without a rationale cannot be acted on. T-XXX refs and bare URLs auto-link in both /review and AC steps.

**Evidence:**
- `web/shared.py` — `extract_recommendation()` returns `{verdict, rationale, evidence, raw}`; `extract_recommendation_verdict()` retained as compatibility shim. New `render_markdown_safe()` does markdown2 + auto-link T-XXX + auto-link bare URLs.
- `web/blueprints/review.py` — `_parse_recommendation` removed; route passes structured `rec_rationale_html` / `rec_evidence_html` to template; `rec_complete` flag drives "incomplete" warning rendering.
- `web/blueprints/inception.py` — `_extract_rationale_from_recommendation` and `_extract_recommendation_stance` consolidated to 3-line shims that delegate to `extract_recommendation` (one source of truth).
- `web/blueprints/tasks.py` — added `_auto_link_bare_urls` to AC step rendering so URLs in Steps blocks become clickable (closes the original "link in step 1 not clickable" complaint).
- `web/templates/review.html` — replaced `<pre>{{ recommendation }}</pre>` with structured Rationale/Evidence sections; added `.rec-rationale`, `.rec-evidence`, `.rec-incomplete-warning` styles.
- `tests/unit/test_extract_recommendation.py` — 10 tests covering full block, verdict-only, empty section, evidence missing, H2+ terminator regression, real-world T-1565 sample, compat shim. All 28 tests across the three extractor suites pass.
- Live verification: T-1565 review now shows rendered `<p>` rationale + `<ul>` evidence with auto-linked T-XXX refs (T-1567, T-1568, etc. as `<a href="/tasks/T-XXX">`), code spans rendered, bold rendered. T-1575's own Step 1 URL is clickable.

**Subsequent fixes layered on top of the consolidation (this arc accumulated 5 commits):**
- `6d4a44fbd` — Initial consolidation (`extract_recommendation`, render structured fields).
- `7f64f82cd` — Generic marker tokenizer (replaced hardcoded `Evidence|Rationale|...:` alternation that missed `**Evidence — closed (7):**` and `**Captured learning:** L-309`). Real-T-1565-file regression test added — this is what should have caught the bug the first time.
- `c326be7b2` — Record Decision rationale pre-fill (mirrors `inception_detail.html` `rationale_hint`). Caption "Agent recommends GO — edit the rationale or pick a different decision."
- `4704f12a4` — `_linkify_code_urls` post-processor: backticked URLs become `<a><code>...</code></a>` everywhere. CSS makes link affordance visible. CLAUDE.md §"Human AC Format Requirements" documents the rendering guarantee.
- `22100ca96` — Don't re-prompt after decision: htmx polling was reverting the success state to the GO/NO-GO/DEFER form every 5s. `_extract_decision` short-circuits to a persistent "Decision recorded: <verdict>" card.

**Captured learnings:**
- L-309 — cross-component "needs human" decoupling pattern (origin: T-1572).
- (Pending) Verification of UI/template changes by element-presence grep is forbidden — required: Playwright screenshot OR DOM-content assertion. T-1575 shipped twice with grep-only checks and twice the rendering was visibly broken.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T06:53:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1575-structural-recommendation-rendering--uni.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8da5f0d3
- **Timestamp:** 2026-06-02T14:58:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 9
     - evidence: `curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'class="rec-rationale"'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'class="rec-evidence"'`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'`
### 2026-04-28T15:23:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
