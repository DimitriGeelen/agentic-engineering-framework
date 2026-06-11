---
id: T-1419
name: "CLAUDE.md trim — Quick Reference → fw help (T-1355 GO)"
description: >
  CLAUDE.md trim — Quick Reference → fw help (T-1355 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T09:42:06Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-24T09:50:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1419: CLAUDE.md trim — Quick Reference → fw help (T-1355 GO)

## Context

T-1355 GO (decided 2026-04-24): trim CLAUDE.md from 74,708 bytes toward <=55,000 bytes (~25% reduction) while preserving every governance anchor. Primary lever: collapse the Quick Reference table (lines 1010-1154, ~144 lines of `fw X` / direct-invocation pairs) into a short essentials list pointing at `fw help`. The full command catalogue is already discoverable via `fw help`, so the table is duplicate knowledge. Governance-critical verbs (work-on, task create/update, inception decide, context focus, handover, termlink) stay inline so the agent never has to query a tool to find the core governance workflow.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md size <= 60,000 bytes (start: 74,708; final: 59,832 — saved 14,876 bytes / 19.9%)
- [x] Quick Reference section retained but compressed — grouped by workflow (starting work / inceptions / context / commits / handovers / fabric / dispatch / tier0 / scheduling / knowledge / setup)
- [x] `fw help` mentioned in trimmed Quick Reference as the canonical full catalogue
- [x] All H2 governance anchors preserved: Four Constitutional Directives, Authority Model, Instruction Precedence, Task System, Task Sizing Rules, Enforcement Tiers, Working with Tasks, Error Escalation Ladder, Agent Behavioral Rules, Plan Mode Prohibition, Built-in Task Tool Ban, Session Start Protocol, Session End Protocol (all 12 present, 1017 lines → 927)
- [x] Markdown parses cleanly (24 fences balanced, no orphan table separators)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
test $(wc -c < CLAUDE.md) -le 60000
grep -q '^## Four Constitutional Directives' CLAUDE.md
grep -q '^## Authority Model' CLAUDE.md
grep -q '^## Instruction Precedence' CLAUDE.md
grep -q '^## Task System' CLAUDE.md
grep -q '^## Task Sizing Rules' CLAUDE.md
grep -q '^## Enforcement Tiers' CLAUDE.md
grep -q '^## Agent Behavioral Rules' CLAUDE.md
grep -q '^## Plan Mode Prohibition' CLAUDE.md
grep -q '^## Built-in Task Tool Ban' CLAUDE.md
grep -q '^## Session Start Protocol' CLAUDE.md
grep -q '^## Session End Protocol' CLAUDE.md
grep -q '^## Quick Reference' CLAUDE.md
grep -q 'fw help' CLAUDE.md

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

### 2026-04-24T09:42:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1419-claudemd-trim--quick-reference--fw-help-.md
- **Context:** Initial task creation

### 2026-04-24T09:50:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9679dee3
- **Timestamp:** 2026-06-02T14:57:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
