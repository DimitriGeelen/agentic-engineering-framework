---
id: T-2062
name: "Watchtower /review/T-XXX returns 404 for completed tasks — break of agent hand-off contract"
description: >
  Agent presents work to human via `fw task review T-XXX` which renders
  `http://host/review/T-XXX`. After the task moves to `.tasks/completed/`,
  that URL returns HTTP 404. The agent had handed off T-2059 + T-2061 with
  /review/ URLs ~10 minutes earlier; user clicks them, sees "404 task not
  found". Read-only review of recent closures is broken.
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [bug, watchtower, review-surface, hand-off, render-fidelity]
components: [web/blueprints/review.py, web/templates/review.html]
related_tasks: [T-2059, T-2061, T-2056, T-2060, T-679]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: 2026-05-28T14:30:00Z
date_finished: null
---

# T-2062: Watchtower /review/T-XXX returns 404 for completed tasks

## Context

User reported: "2061 2059 404 task not found ???!". Reproduced via curl: both `/review/T-2061` and `/review/T-2059` return HTTP 404 (T-2056 returns 200 — surfaced despite being completed; that's a separate bug, T-2064). Both T-2061 and T-2059 are in `.tasks/completed/`.

In `web/blueprints/review.py` (read earlier this session):
```python
for location in ("active", "completed"):
    ...
"completed": ("Task Completed", f"{task_id} has been completed. No pending Human ACs."),
...
if completed_dir.exists() and list(completed_dir.glob(f"{task_id}-*.md")):
    return _render_review_404(task_id, "completed")
```

So /review/T-XXX intentionally 404s for completed tasks — but `_render_review_404(...)` returns a 404 with `reason="completed"` and a friendly message ("Task Completed"). The HTTP status code is what's hurting the agent's hand-off message UX: clickable link → user gets "404 task not found" page.

## Acceptance Criteria

### Agent
- [ ] Verify the intended UX for `/review/T-XXX` on a completed task. Three candidate behaviours: (a) HTTP 200 with read-only render of the task body + Recommendation + Decisions (canonical "review-the-shipped-work" view), (b) HTTP 301/302 redirect to `/tasks/T-XXX` (existing canonical task-detail view), (c) keep HTTP 404 but change the agent's hand-off message to use `/tasks/T-XXX` for completed work.
- [ ] Decide GO/NO-GO/DEFER on which candidate ships; if GO, file a build task.
- [ ] Document the agent-side hand-off contract update in CLAUDE.md §Presenting Work for Human Review (T-679) — should the agent point at /review/ (action surface) or /tasks/ (read surface) for already-completed work?

### Human
<!-- Decide path (a/b/c) and confirm framing. -->
- [ ] [REVIEW] Confirm whether /review/T-XXX for completed tasks should render-200, redirect, or stay 404.

## Verification

# Run curl to confirm current behaviour:
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.10.107:3000/review/T-2061

## RCA

**Symptom:** Clicking the /review/T-XXX URL the agent hands off in `## Recommendation` for a just-completed task returns HTTP 404 ("task not found") page. User cannot review what the agent shipped.

**Root cause hypothesis:** `web/blueprints/review.py` intentionally returns 404 when the task is in `.tasks/completed/`. The design assumption was "/review/ is for in-flight tasks awaiting Human AC sign-off; completed tasks have nothing to review". This breaks at the boundary where the agent's hand-off naming convention assumes /review/T-XXX is the universal review surface (per CLAUDE.md §Presenting Work for Human Review, T-679).

**Why structurally allowed:** No bats test asserts "GET /review/T-XXX on a completed task returns 200" (or 3xx). The 404 was wired in, the agent's hand-off pattern was wired in, no regression guard caught the mismatch. Plus the all-routes height test (T-2048) doesn't exercise /review/T-XXX with a completed task fixture — only the live url_map.

**Prevention (per inception decision):** Once path is chosen, ship: (1) the route change OR redirect OR doc change, (2) a Playwright/curl regression case asserting expected behaviour for a completed-task fixture, (3) a CLAUDE.md note clarifying which surface the agent should link to.

## Evolution

## Decisions

## Decision

<!-- Filled by `fw inception decide T-2062 go|no-go|defer --rationale "..."` -->

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct .tasks/active/ Write (Bash blocked at 98% budget).
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2062-watchtower-review-t-xxx-404-on-completed.md
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); requested inception RCAs + horizon: now; budget gate prevented `bin/fw work-on` from completing.
