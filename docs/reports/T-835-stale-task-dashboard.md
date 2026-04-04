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

### Agent A — Backlog Analysis (144 lines, `T-835-agent-a-backlog-analysis.md`)
- **77 work-completed tasks** with 79 unchecked Human ACs
- **28 RUBBER-STAMP** (36%) — auto-close candidates (9 CLI-verifiable, 14 browser, 5 macOS-only)
- **48 REVIEW** (62%) — genuine human judgment needed (34 inception GO/NO-GO)
- Only 23% have Recommendation sections — most force human to dig through details
- Backlog accelerating: ~7 tasks/day entering, ~0 reviewed/day
- Oldest: T-436 at 25 days

### Agent B — Tooling Audit (207 lines, `T-835-agent-b-tooling-audit.md`)
- 7 review tools exist but ALL are single-task-oriented
- No batch/triage workflow, no queue navigation, no filtering
- `fw verify-acs` is read-only — identifies passing ACs but can't auto-check
- P1 quick wins: `verify-acs --auto-check` flag + "Complete all ready" button

### Agent C — Design Options (205 lines, `T-835-agent-c-design-options.md`)
- **Option A — Batch Approval Page** (M, 3-4h): Multi-select, grouped view, pre-flight evidence
- **Option B — Auto-Close RUBBER-STAMP** (S, 1-2h): `verify-acs --auto-close`, clears ~31 tasks
- **Option C — Daily Digest** (S, 1-2h): ntfy push summary, prevents re-accumulation

## Recommendation

**GO — Build Option B first (auto-close RUBBER-STAMP), then Option A (batch UI).**

Rationale:
1. Option B is S-sized, would clear 31 tasks immediately, requires no UI changes
2. Option A addresses the remaining 48 REVIEW tasks with batch workflow
3. Combined: B+A covers 100% of the backlog with total effort M (4-6h)
4. Option C is nice-to-have for ongoing prevention but doesn't clear existing backlog
