---
id: T-1569
name: "Surface Reviewer Verdict on Watchtower approvals cards (F3 from T-1565 audit)"
description: >
  Surface Reviewer Verdict on Watchtower approvals cards (F3 from T-1565 audit)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/approvals.py, web/shared.py, 
      web/templates/_approvals_content.html]
related_tasks: []
created: 2026-04-27T21:24:55Z
last_update: '2026-08-16T22:24:37Z'
date_finished: 2026-04-27T21:34:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1569: Surface Reviewer Verdict on Watchtower approvals cards (F3 from T-1565 audit)

## Context

F3 from the T-1565 approval-arc audit (`docs/reports/T-1565-approval-arc-gaps-audit.md`):
the reviewer agent (`lib/reviewer/static_scan.py`) writes a `## Reviewer Verdict (vX.Y)`
block into the task body containing `Overall`, `Needs Human`, and `Findings` count, but
neither the inception cards (`_load_pending_go_decisions`) nor the Human-AC cards
(`_load_pending_human_acs`) extract or render it. At the moment of human decision the
agent's self-assessment is visible; the structural-scan's findings — the only mechanical
advisor in the arc — are not. This task closes that gap with a small badge.

## Acceptance Criteria

### Agent
- [x] `extract_reviewer_verdict(body)` helper exists in `web/shared.py`, returning
      `{"overall": str|None, "findings": int, "needs_human": bool|None}` from the
      `## Reviewer Verdict (vX.Y)` block. Returns `{"overall": None, ...}` when missing.
- [x] `_load_pending_go_decisions` populates `reviewer` field on each result.
- [x] `_load_pending_human_acs` populates `reviewer` field on each result.
- [x] `_approvals_content.html` renders a small badge next to the existing verdict
      badge on both card types: green when PASS+no findings; red when FAIL/WARN, has
      findings, or needs_human. Hidden when `reviewer.overall is None`.
- [x] Unit test `tests/unit/test_extract_reviewer_verdict.py` (8 cases) pins the
      shapes: pass+none, warn+findings+needs_human, fail+many, absent, empty,
      H3-terminator, unrelated-overall, real-world sample.
- [x] `/approvals` page returns HTTP 200 and 9 reviewer badges render against
      live corpus.

python3 -c "from web.shared import extract_reviewer_verdict; r=extract_reviewer_verdict(open('.tasks/active/T-1448-t-1443-v13-reviewer-agent-per-ac-granula.md').read()); assert r['overall']=='PASS', r; assert r['findings']==0, r; assert r['needs_human'] is False, r; print('helper ok:', r)"
python3 -c "from web.shared import extract_reviewer_verdict; r=extract_reviewer_verdict('# no verdict here'); assert r['overall'] is None, r; print('absent ok:', r)"
PORT=$(bin/fw watchtower port 2>/dev/null || echo 3000); curl -sf "http://localhost:$PORT/approvals" >/dev/null && echo "approvals 200 ok"
PORT=$(bin/fw watchtower port 2>/dev/null || echo 3000); curl -s "http://localhost:$PORT/approvals" | grep -q 'reviewer-badge' && echo "badge rendered"

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

## Recommendation

**Recommendation:** GO

**Rationale:** F3 closed with the minimal viable surface. The reviewer agent's
mechanical verdict is now visible at the exact moment a human is making a
decision (inception GO/NO-GO + Human-AC verification), addressing the audit's
core point: "the only mechanical advisor in the arc was wired to write but
nothing surfaced its findings."

**Evidence:**
- `web/shared.py` — new `extract_reviewer_verdict()` helper, parallel shape to
  `extract_recommendation_verdict()` (L-293 H2+ terminator preserved).
- `web/blueprints/approvals.py` — both loaders populate `reviewer` field.
- `web/templates/_approvals_content.html` — badge renders next to existing
  recommendation verdict on both inception cards (Section B) and Human-AC cards
  (Section C). Green for PASS+no-findings; red for FAIL/WARN/findings/needs_human.
- `tests/unit/test_extract_reviewer_verdict.py` — 8/8 passing including L-293
  terminator regression and real-world shape.
- Live corpus: 9 reviewer badges rendered on /approvals (HTTP 200).

**Follow-ups (out of scope here, see T-1565 audit):**
- F4 — silent inception drop on /approvals (split filter for Recommendation-less)
- F5 — `fw review-queue` excludes pending inception decisions (CLI parity)
- F6 — Recommendation gate decoupled from reviewer.needs_human

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

### 2026-04-27T21:24:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1569-surface-reviewer-verdict-on-watchtower-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f8e59b7d
- **Timestamp:** 2026-06-02T14:58:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T21:34:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** F3 implemented, tested, verified live
