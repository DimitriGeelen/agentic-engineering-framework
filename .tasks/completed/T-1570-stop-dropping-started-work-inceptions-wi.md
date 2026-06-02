---
id: T-1570
name: "Stop dropping started-work inceptions without Recommendation on /approvals (F4)"
description: >
  Stop dropping started-work inceptions without Recommendation on /approvals (F4)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/approvals.py]
related_tasks: []
created: 2026-04-27T21:35:15Z
last_update: 2026-04-27T21:37:39Z
date_finished: 2026-04-27T21:37:39Z
---

# T-1570: Stop dropping started-work inceptions without Recommendation on /approvals (F4)

## Context

F4 from the T-1565 approval-arc audit. `_load_pending_go_decisions` in
`web/blueprints/approvals.py:128-130` drops every inception whose
`## Recommendation` section is missing or <20 chars. The skip is justified for
captured/unexplored backlog (T-1123) but creates a blind spot for started-work
inceptions where the agent began exploring but forgot to write a recommendation.
The template already has fallback rendering at `_approvals_content.html:127-148`
("No agent recommendation written yet" — T-1214) — the loader just never emits
those cards.

Asymmetric with the partial-complete path where the Recommendation gate (T-1529)
*blocks* completion under the same condition. The completion gate is right; the
display gate is wrong. Aligning them makes the agent's stuck state visible.

## Acceptance Criteria

### Agent
- [x] `_load_pending_go_decisions` includes started-work inceptions without a
      substantive Recommendation section. Captured/unexplored remain dropped.
- [x] Existing template fallback (T-1214 "No agent recommendation written yet")
      renders for these cards — confirmed via curl on live /approvals.
- [x] T-1565 (started-work, audit task with no Recommendation block) now
      appears on /approvals; T-1546 (captured) correctly stays hidden.
- [x] No regression: 2 inceptions with substantive Recommendation still render
      the recommendation summary (T-1119 contract preserved).

## Verification

python3 -c "from web.app import create_app; from web.blueprints.approvals import _load_pending_go_decisions; app=create_app(); ctx=app.app_context(); ctx.push(); rows=_load_pending_go_decisions(); no_rec=[r for r in rows if not r.get('recommendation')]; assert len(rows) > 0 and len(no_rec) > 0; print(f'F4 ok: total={len(rows)} no-rec={len(no_rec)}')"
PORT=$(bin/fw watchtower port 2>/dev/null || echo 3000); curl -sf "http://localhost:$PORT/approvals" >/dev/null && echo approvals-200-ok
bash -c 'PORT=$(bin/fw watchtower port 2>/dev/null || echo 3000); curl -s "http://localhost:$PORT/approvals" | grep -q "No agent recommendation written yet" && echo fallback-rendered'

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

**Rationale:** F4 closed with a 1-line semantic change. The display gate now
aligns with the completion gate (T-1529): both treat "started-work inception
without substantive Recommendation" as a stuck state requiring human visibility,
not as a backlog item to hide. Captured/unexplored backlog (T-1123) remains
correctly hidden.

**Evidence:**
- `web/blueprints/approvals.py:127-134` — branch only drops cards when
  `not rec_substantive AND status != 'started-work'`.
- Live verification: 3 cards now (was 2), with T-1565 surfacing under the
  T-1214 fallback "No agent recommendation written yet" warning.
- T-1546 (status=captured) correctly remains hidden — captured backlog is
  intentionally not surfaced for review.

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

### 2026-04-27T21:35:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1570-stop-dropping-started-work-inceptions-wi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-16ba1c8b
- **Timestamp:** 2026-06-02T14:58:22Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bash -c 'PORT=$(bin/fw watchtower port 2>/dev/null || echo 3000); curl -s "http://localhost:$PORT/approvals" | grep -q "No agent recommendation written yet" && echo fallback-rendered'`
### 2026-04-27T21:37:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** F4 implemented and verified live
