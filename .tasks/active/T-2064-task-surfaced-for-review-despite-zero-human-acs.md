---
id: T-2064
name: "Task surfaced for human review despite zero Human ACs — review-queue filter gap"
description: >
  T-2056 is in `.tasks/completed/` with 4 Agent ACs ticked and zero Human ACs
  (### Human heading present but body empty — only template comments). User
  sees it surfaced in human-facing UI (HTTP 200 on /review/T-2056), asks
  "non an human ac, why surface to human ??". The review/approvals surface
  filters on owner or status but doesn't filter on "actually has Human ACs > 0".
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [bug, watchtower, review-queue, filter-gap, sovereignty]
components: [web/blueprints/review.py, web/blueprints/approvals.py, bin/fw, agents/task-create/update-task.sh]
related_tasks: [T-2056, T-2061, T-679, T-372, T-373]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: 2026-05-28T14:30:00Z
date_finished: null
---

# T-2064: Task surfaced for human review despite zero Human ACs

## Context

User: "2056 non an human ac, why surface to human ??". Verified:
- T-2056 is in `.tasks/completed/` (closed in this session via T-2061's predicate fix)
- T-2056's `### Human` AC section contains ONLY the template guidance comment — no actual `- [ ] [REVIEW] ...` lines
- `curl /review/T-2056` returns HTTP 200 (not 404 like T-2061 / T-2059 which is its own bug, T-2062)
- T-2056 has Agent ACs only (4 of them, all ticked)

The review surface is showing T-2056 to the human anyway. Why:
- The 404 path triggers on `completed_dir` glob (T-2062's concern)
- But T-2056 hits a different code path that returns 200 — likely because of how its frontmatter or AC structure parses
- OR the review-queue / approvals surface filters by "task in some specific state" without checking "has unchecked Human ACs > 0"

Cross-reference: `fw review-queue` lists 118 tasks awaiting Human AC verification. If T-2056 (zero Human ACs) appears in that count, the filter is broken.

## Acceptance Criteria

### Agent
- [ ] Identify the exact route serving T-2056 with HTTP 200 (`/review/T-2056` or its render path) and confirm why it differs from T-2061's 404 behaviour. Hypothesis: T-2056 had a `## Recommendation` block AND was not glob-matched as completed (race? cache? wrong file location?) — or the route logic differs from the curl-tested path.
- [ ] Audit `fw review-queue` (CLI) AND the `/approvals` page logic — verify both filter on "unchecked Human ACs > 0", not just "owner=human OR has [REVIEW]".
- [ ] Decide GO/NO-GO/DEFER on remediation candidates:
  - (a) Filter at render-time: pre-render check counts unchecked Human ACs; skip task if 0
  - (b) Filter at queue-build: `fw review-queue` excludes zero-Human-AC tasks; review.py / approvals.py inherit
  - (c) Auto-tick zero-Human-AC tasks at completion (close the loop at the closure boundary)
- [ ] If GO on any candidate, file a build task.

### Human
- [ ] [REVIEW] After remediation, the human review queue and `/review/T-XXX` paths surface ONLY tasks with at least one unchecked Human AC.

## Verification

# Confirm current symptom:
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.10.107:3000/review/T-2056
# T-2056 is in completed/ with zero Human ACs but route returns 200

## RCA

**Symptom:** A completed task with no Human ACs (only Agent ACs) appears in the human-facing review surface. User cannot tell why — the task has nothing for them to verify.

**Root cause hypothesis:** Either (a) the route/page logic filters on `[REVIEW]` prefix presence or `Recommendation` block existence without checking "unchecked Human AC count > 0", OR (b) the route logic has different branches for `/review/T-XXX` (one returns 404 for completed/, one returns 200; T-2056 hits the 200 path for a reason this RCA needs to identify). The two-symptom dichotomy with T-2061/T-2059 (both completed/, both 404) vs T-2056 (completed/, 200) points at a content-driven branch in review.py, not a status-driven one.

**Why structurally allowed:** Human ownership of tasks was added (T-372/T-373) with sound rules around "evidence required to close human-owned task". But the filter logic that decides "should this human be looking at this task" doesn't itself check whether there's anything for the human to do. The classification rule "Make it a Human AC if..." (CLAUDE.md §AC Classification Guidance) is a guidance to authors; the surface logic doesn't enforce that zero-Human-AC tasks shouldn't be surfaced.

**Prevention:** Add a "has unchecked Human ACs" predicate to the review-surface filter chain (CLI + web). Pin with a bats/pytest case asserting "a completed task with zero Human ACs is NOT in `fw review-queue` output and returns 404/redirect on /review/T-XXX". Verify the same predicate also gates `/approvals` rendering of the task.

## Evolution

## Decisions

## Decision

<!-- Filled by `fw inception decide T-2064 go|no-go|defer --rationale "..."` -->

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct .tasks/active/ Write (Bash blocked at 98% budget).
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2064-task-surfaced-for-review-despite-zero-human-acs.md
- **Context:** User reported 4 bugs (T-2062..T-2065 batch). T-2056 is the canonical case.
