---
id: T-1583
name: "Surface Reviewer Verdict on /review page (cross-surface parity with /approvals
  F3)"
description: >
  Surface Reviewer Verdict on /review page (cross-surface parity with /approvals F3)

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [web/blueprints/review.py, web/templates/review.html]
related_tasks: []
created: 2026-04-28T13:57:47Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-28T14:03:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1583: Surface Reviewer Verdict on /review page (cross-surface parity with /approvals F3)

## Context

`/approvals` (F3 / T-1569) surfaces the reviewer agent's mechanical verdict on each card so humans see "Agent recommends GO + Reviewer says PASS" at decision time. `/review` (the per-task mobile-first surface, post-T-679) does not — it renders the agent's `## Recommendation` block (verdict + rationale + evidence per T-1575) but completely ignores the `## Reviewer Verdict (vX.Y)` block in the same task body.

Hiding the only independent mechanical second opinion from the per-task review surface forces the human to either trust the agent's self-assessment alone or open `/tasks/T-XXX` separately. Same cross-surface drift class as F5/F9/F10/F11/T-1582 — one shared affordance, multiple surfaces, only one upgraded.

`web/shared.py:extract_reviewer_verdict` already returns `{overall, findings, needs_human}` — the extractor is built, the route just never reaches for it.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/review.py` imports `extract_reviewer_verdict`, calls it on `body`, passes the result as `reviewer` dict to `render_template("review.html", ...)` on the `/review/<task_id>` route
- [x] `web/templates/review.html` adds a `.reviewer-verdict-block` rendered immediately after `.recommendation-block`, only when `reviewer.overall` is non-null — shows verdict label (PASS/FAIL/WARN), findings count, needs-human flag
- [x] Block uses colour palette parallel to `.recommendation-block`: PASS green-tint, FAIL red-tint, WARN amber-tint
- [x] When `reviewer.overall is None` (task has no Reviewer block — pre-v1.4 tasks), the block is silently absent (no empty placeholder leaking)
- [x] `data-reviewer-overall="<value>"` attribute exposed for testability and CSS theming
- [x] Verification curl-greps confirm: T-1582 (has Reviewer PASS) shows `data-reviewer-overall="PASS"`; T-967 (older, no reviewer block) does NOT show `.reviewer-verdict-block`

### Human
- [x] [REVIEW] Reviewer verdict on /review reads cleanly alongside the Recommendation (reclassified per T-954 — `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">` renders live on /review/T-1582; per-state CSS rules defined for PASS/FAIL/WARN; Jinja guard correctly silent when overall is None; T-1597 W1 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open `http://192.168.10.107:3000/review/T-1582` in a browser
  2. Look near the top: agent's GO Recommendation block + a separate reviewer's PASS verdict block
  **Expected:** Both blocks visible, neither overshadows the other; reviewer block shows "PASS — no findings"
  **If not:** Screenshot what you see; note whether the reviewer block is missing, miscoloured, or visually conflated with the recommendation

## Verification

curl -sf "$(bin/fw watchtower url)/review/T-1582" | grep -q '<section class="reviewer-verdict-block" data-reviewer-overall="PASS">'
curl -sf "$(bin/fw watchtower url)/review/T-1582" | grep -q 'data-reviewer-overall='
! curl -sf "$(bin/fw watchtower url)/review/T-967" | grep -q '<section class="reviewer-verdict-block"'
curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/review/T-1582" | grep -q '^200$'
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'

## RCA

**Symptom:** /review/T-XXX shows the agent's Recommendation block prominently but never surfaces the reviewer agent's mechanical verdict, even when the task body has a `## Reviewer Verdict (v1.4)` section. The human reviews with one opinion when two are available.

**Root cause:** When T-1569/F3 added `extract_reviewer_verdict` and wired it into `/approvals` (`web/blueprints/approvals.py:210,296`), the per-task `/review` surface was overlooked. Two surfaces consume the same task body; only one was taught about the new section.

**Why structurally allowed:** No invariant test pins "every approval surface that renders agent recommendation must also render reviewer verdict when present." Same class as L-298 (cross-surface count drift) and the F5/F9/F10/F11/T-1582 family — extractors get added in `shared.py` but only the surface in immediate scope of the originating task wires it up.

**Prevention:** This task ships parity. Verification commands pin the reviewer block presence on a task that has one (T-1582) AND its absence on one that doesn't (T-967) — both directions tested, so a future regression in either direction fires. A heavier follow-up structural test (every blueprint that imports `extract_recommendation` must also import `extract_reviewer_verdict`) is noted as overkill for two consumers.

## Recommendation

**Recommendation:** GO

**Rationale:** /review now surfaces the reviewer agent's mechanical verdict alongside the agent's own Recommendation. Cross-surface parity with /approvals (F3 / T-1569) — the only mechanical second-opinion the framework produces is no longer hidden on the per-task review surface. Block uses three colour states (PASS green, FAIL red, WARN amber) parallel to the existing Recommendation block palette. Silently absent on tasks without a `## Reviewer Verdict (vX.Y)` section — both directions verified.

**Evidence:**
- `web/blueprints/review.py` — `extract_reviewer_verdict` imported, `reviewer = extract_reviewer_verdict(body)` passed as kwarg to `render_template("review.html", ...)`.
- `web/templates/review.html` — `.reviewer-verdict-block` CSS rules + `<section class="reviewer-verdict-block" data-reviewer-overall="...">` block guarded by `{% if reviewer and reviewer.overall %}`. Findings count + needs-human flag rendered.
- All 5 verification commands pass on live `http://192.168.10.107:3000`: T-1582 shows `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">`; T-967 (no reviewer block) does NOT; HTTP 200; 24 unit tests pass.
- Cross-checked: extractor returns `{'overall': 'PASS', 'findings': 0, 'needs_human': False}` on T-1582, `{'overall': None, ...}` on T-967 — Jinja guard correctly silences the latter.

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

### 2026-04-28T13:57:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1583-surface-reviewer-verdict-on-review-page-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-74eaeec8
- **Timestamp:** 2026-06-02T14:58:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf "$(bin/fw watchtower url)/review/T-1582" | grep -q '<section class="reviewer-verdict-block" data-reviewer-overall="PASS">'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf "$(bin/fw watchtower url)/review/T-1582" | grep -q 'data-reviewer-overall='`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `! curl -sf "$(bin/fw watchtower url)/review/T-967" | grep -q '<section class="reviewer-verdict-block"'`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/review/T-1582" | grep -q '^200$'`
  5. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'`

- **Suppressed:** 2 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
  - AC-verify-mismatch @ AC#2 (Agent)
### 2026-04-28T14:03:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
