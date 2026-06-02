---
id: T-974
name: "Inception recommendation gate — require ## Recommendation before fw inception decide"
description: >
  Inception recommendation gate — require ## Recommendation before fw inception decide

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T19:58:57Z
last_update: 2026-04-06T20:01:25Z
date_finished: 2026-04-06T20:01:25Z
---

# T-974: Inception recommendation gate — require ## Recommendation before fw inception decide

## Context

Agent in WorkshopDesigner completed inception research but never wrote `## Recommendation` into the task file. Watchtower rendered blank. CLAUDE.md §Presenting Work for Human Review requires it but nothing enforces it. Also: inception template lacks `## Recommendation` section, so agents don't know to write it. Two fixes: (1) add `## Recommendation` to inception template, (2) gate `fw inception decide` on non-empty recommendation. Related: T-973 (review-before-decide gate), T-679.

## Acceptance Criteria

### Agent
- [x] Inception template (`inception.md`) includes `## Recommendation` section with placeholder guidance
- [x] `inception.sh` `do_inception_decide()` checks for `## Recommendation` with actual content (not just placeholder)
- [x] Blocks with helpful message telling agent to write recommendation first
- [x] Both `.agentic-framework/lib/` and `lib/` copies updated
- [x] Human AC Steps updated to use `fw task review` instead of raw CLI command
- [x] Verification commands pass

## Verification

grep -q '## Recommendation' .tasks/templates/inception.md
grep -q 'Recommendation' lib/inception.sh
grep -q 'Recommendation' .agentic-framework/lib/inception.sh
grep -q 'fw task review' .tasks/templates/inception.md

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

### 2026-04-06T19:58:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-974-inception-recommendation-gate--require--.md
- **Context:** Initial task creation

### 2026-04-06T20:01:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Recommendation gate implemented and tested

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b3e5025f
- **Timestamp:** 2026-06-02T15:05:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
