# T-835: Watchtower Stale Task Dashboard — Inception Research

## Problem

54+ tasks in `work-completed` status with unchecked Human ACs. This backlog:
- Obscures project progress (tasks appear "active" when agent work is done)
- Creates governance noise (stale task warnings in every audit)
- Requires manual human effort to review each task individually

## Questions

1. What categories of Human ACs exist across the 54 tasks? (RUBBER-STAMP vs REVIEW)
2. How many could be auto-verified with evidence the agent already collected?
3. What UI/notification improvements would help the human clear the backlog?
4. Should we build a "batch review" feature in Watchtower?

## Research Plan

### Agent A — Backlog Analysis
Analyze all 54+ work-completed tasks: categorize Human ACs, assess verifiability, identify patterns.

### Agent B — Existing Tooling Audit
Review `fw verify-acs`, `/approvals` page, task completion buttons — what works, what's missing.

### Agent C — Design Options
Sketch 3 design options for stale task resolution (notification, batch review, auto-close).

## Findings

(To be filled by TermLink workers)
