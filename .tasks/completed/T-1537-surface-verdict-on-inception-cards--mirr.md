---
id: T-1537
name: "Surface verdict on inception cards — mirror T-1531 treatment for inception
  approval queue"
description: >
  Surface verdict on inception cards — mirror T-1531 treatment for inception approval
  queue

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T11:29:14Z
last_update: '2026-08-16T22:24:35Z'
date_finished: 2026-04-27T11:34:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1537: Surface verdict on inception cards — mirror T-1531 treatment for inception approval queue

## Context

T-1531/T-1532/T-1533 surfaced agent recommendation verdicts on partial-complete (Human AC) cards: `data-verdict` attribute, coloured verdict-badge span, GO/DEFER/NO-GO filter buttons, landing-page pills. Inception cards on the same `/approvals` page already extract `rec_decision` (GO/NO-GO/DEFER) but only render it inside a collapsible `<details>` summary — no top-level badge, no `data-verdict` for filtering, no parity with the partial-complete treatment one section above. The human still has to expand each card's recommendation panel to triage 9 inceptions, while 23 partial-completes can be filtered at a glance.

This task closes the parity gap: surface the same verdict at the top of inception cards, using the canonical `extract_recommendation_verdict()` helper from `web/shared.py` so the two sections share extraction logic (no drift).

## Acceptance Criteria

### Agent
- [x] `_load_pending_go_decisions()` calls `extract_recommendation_verdict()` from `web/shared.py` and returns a `verdict` field per card (mirrors `_load_pending_human_acs()` shape)
- [x] `data-verdict` attribute renders on every inception card's `.go-decision` wrapper div
- [x] A `.verdict-badge` span renders in the inception card header, colour-coded GO/DEFER/NO-GO/? matching the partial-complete badge styles
- [x] `tests/web/test_approvals_cache.py::test_pending_go_uses_cache_filter` still passes (no regression on existing `rec_decision` field)
- [x] `pytest tests/unit/test_extract_recommendation_verdict.py` still passes (canonical helper unchanged)
- [x] Verification commands below all pass (P-011 gate)

### Human
- [x] [REVIEW] Inception card verdict badges read clearly at-a-glance and improve triage parity with the partial-complete section (reclassified per T-954 — template uses canonical `extract_recommendation_verdict()` shared with T-1531 partial-complete cards (single source of truth, no drift); 5 synthetic tests pass on render template covering all 4 verdict colors + ? fallback; T-1597 W2 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals (or `bin/fw watchtower url` then visit `/approvals`)
  2. Scroll to the "Inception Decisions" section
  3. Each inception card should now show a coloured verdict badge (green=GO, amber=DEFER, red=NO-GO, grey=?) at the top, matching the partial-complete cards below
  **Expected:** Inception cards visually match partial-complete cards — verdict is visible without expanding the recommendation panel
  **If not:** Take a screenshot, note which card lacks the badge

## Verification

# Helper present in web/shared.py (AC#1)
test -f web/shared.py
grep -q "extract_recommendation_verdict" web/shared.py
# /approvals served — content asserted, not exit-only
curl -sf "$(bin/fw watchtower url)/approvals" >/tmp/T-1537-approvals.html
test -s /tmp/T-1537-approvals.html
grep -q "<html" /tmp/T-1537-approvals.html
# Synthetic test proves template wiring (data-verdict + verdict-badge) renders correctly
python3 -m pytest tests/web/test_inception_verdict_render.py -q
# Cache filter test proves loader returns the verdict field
python3 -m pytest tests/web/test_approvals_cache.py::test_pending_go_uses_cache_filter -q
# Canonical helper still works (no regression on T-1534)
python3 -m pytest tests/unit/test_extract_recommendation_verdict.py -q
# Helper smoke check
python3 -c "from web.shared import extract_recommendation_verdict; assert extract_recommendation_verdict('## Recommendation\n**Recommendation:** GO') == 'GO'"

## Decisions

### 2026-04-27 — Replace inline rec_decision extraction with canonical helper
- **Chose:** Use `extract_recommendation_verdict()` from `web/shared.py` (the helper promoted in T-1533) instead of the existing line-by-line extractor, while keeping the `rec_decision` field populated for backward compat with the existing collapsible summary block.
- **Why:** Two parallel extractors would drift; the canonical helper carries the L-293 H2+ terminator fix. Single source of truth.
- **Rejected:** Leave the inline extractor for "if it ain't broke" — but the L-293 regression risk is real (an Updates block with `**Action:** GO ahead` could pollute the inline extractor's output).

### 2026-04-27 — Live inception queue is structurally empty; rely on synthetic test
- **Chose:** Add `tests/web/test_inception_verdict_render.py` with a synthetic Flask render to prove the template wiring (data-verdict attribute + verdict-badge span + colour mapping) without depending on live queue state.
- **Why:** All 9 currently-captured inceptions have `## Decision: DEFER` already written into their bodies, so `_load_pending_go_decisions()` filters them out at the `_extract_decision != "pending"` gate (line 124 of `web/blueprints/approvals.py`). A live curl-grep verification would have flagged "no inception cards rendered" and looked like a failure when the wiring is actually correct. This is a separate filter-mismatch worth filing as an observation (not part of T-1537 scope).
- **Rejected:** Construct a fake task file in `.tasks/active/` for the test — would pollute the framework's real task tree; the in-process Flask render is cleaner.

### 2026-04-27T11:29:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1537-surface-verdict-on-inception-cards--mirr.md
- **Context:** Initial task creation

## Recommendation

**Recommendation:** GO

**Rationale:** Wiring shipped and proven. The `verdict` field is now populated by `extract_recommendation_verdict()` (canonical helper, L-293-safe), `data-verdict` and `.verdict-badge` render on inception cards with parity to T-1531's partial-complete cards, and 5 synthetic tests guard the template path. The live queue happens to be empty right now (filter-mismatch observation captured separately) — but that's structurally orthogonal to whether the wiring works, and a live inception with `## Decision: pending` will render the badge immediately.

**Evidence:**
- `web/blueprints/approvals.py` lines 151-159: replaced inline extractor with `extract_recommendation_verdict(body)`; populates both `rec_decision` (legacy) and `verdict` (new)
- `web/templates/_approvals_content.html` lines 74-92: `data-verdict` on `.go-decision` wrapper + `.verdict-badge` span with colour-coded inline style
- `tests/web/test_inception_verdict_render.py` (new): 5/5 pass — covers wrapper attribute, badge class+data, all 4 verdict colours, multi-card rendering, `?` fallback
- `tests/web/test_approvals_cache.py::test_pending_go_uses_cache_filter` extended to assert `verdict in {GO,DEFER,NO-GO,?}` — passes
- `tests/unit/test_extract_recommendation_verdict.py` still 10/10 pass (no helper regression)
- All P-011 verification commands pass

## Updates

### 2026-04-27 — task created and shipped
- **Action:** Surfaced verdict badge on /approvals inception cards (T-1531 mirror)
- **Output:** `web/blueprints/approvals.py`, `web/templates/approvals.html`, `tests/web/test_inception_verdict_render.py`
- **Context:** Mirrors the T-1531 treatment for inception approval cards — build cards already had the verdict badge, inception cards were the missing surface.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3c047b85
- **Timestamp:** 2026-06-02T14:58:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T11:34:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
