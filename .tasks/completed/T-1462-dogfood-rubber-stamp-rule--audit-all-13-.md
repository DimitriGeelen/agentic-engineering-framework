---
id: T-1462
name: "Dogfood RUBBER-STAMP rule — audit all 13 [RUBBER-STAMP] ACs in active tasks,
  convert deterministic ones to Agent ACs with verification commands, fill missing
  instructions"
description: >
  Dogfood RUBBER-STAMP rule — audit all 13 [RUBBER-STAMP] ACs in active tasks, convert
  deterministic ones to Agent ACs with verification commands, fill missing instructions

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T14:06:13Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T14:15:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1462: Dogfood RUBBER-STAMP rule — audit all 13 [RUBBER-STAMP] ACs in active tasks, convert deterministic ones to Agent ACs with verification commands, fill missing instructions

## Context

User feedback 2026-04-25: "the rubber stamps have no instruction, furthermore we said we would dogfood the process we are building and evaluate if the rubber stamps really need a human." This task applies CLAUDE.md's RUBBER-STAMP conversion rule — *if a Human AC has `[RUBBER-STAMP]` prefix and its Steps section contains only deterministic shell commands with clear expected output, it SHOULD be an Agent AC with verification commands instead* — to all active tasks.

## Audit findings

13 active tasks carried `[RUBBER-STAMP]` Human ACs. Categorized:

**Converted (5):** moved to Agent AC + verification command, all closed in this session.

| Task | What the human was asked | Mechanical replacement |
|---|---|---|
| T-1240 | Open /tasks?sort=id; T-1239 below T-999 | curl + parse ID order |
| T-1241 | Open /cron; ≤1 "no data" | curl + count "no data" (threshold updated 11→16 jobs) |
| T-594 | 6 identical tool calls in Claude → loop warning | mechanical: pipe 6 hook payloads to dist JS in tmp PROJECT_ROOT |
| T-880 | fw init test dir; check messaging | tmp `fw init`; assert hooks + enforcement-baseline files present |
| T-663 | Fresh Claude session; tool counter increments | structural: settings.json no bare-fw + tool-counter > 0 in this session |

**Kept as Human ACs (8):** environment-bound — genuinely need a human's host or device. Each already had Steps/Expected/If-not filled in and no conversion is safe.

| Task | Why human-bound |
|---|---|
| T-464 | Needs interactive Claude Code session (`/capture` skill) |
| T-481 | macOS-only filesystem (filemode quirk) |
| T-518 | macOS bash 3.2 (Linux ships bash 5+) |
| T-544 | `gh auth login` requires human credentials |
| T-612 | Live Tier 0 block flow needs Claude Code session |
| T-613 | `brew upgrade` requires macOS host |
| T-708 | Phone receives ntfy push (remote endpoint) |
| T-710 | Same — phone push receipt |

## Pattern observed

The 5 converted ACs all matched the rule's exact shape: deterministic CLI/HTTP steps with binary expected outcomes. None of the 5 conversions required novel test design — each translated to ≤2 lines of shell. The 8 kept ACs all involve a host or device the agent can't reach (macOS, phone, gh credentials, interactive Claude Code). The split — *5 mechanical, 8 environment-bound* — suggests the rule's threshold is well-placed: when verification is reachable, mechanical wins; when it crosses a host boundary, humans are unavoidable.

The implicit win: 5 tasks that were "shipped, just waiting on a checkbox" are now actually shipped. That's pure pipeline-clearing — work was already done; rubber-stamps were just sand in the gears.



## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] All 13 active-task `[RUBBER-STAMP]` Human ACs categorized: 5 converted, 8 kept-as-human
- [x] 5 conversion candidates have verification commands added to their `## Verification` sections (T-1240, T-1241, T-594, T-880, T-663)
- [x] All 8 "keep" rubber-stamps already have Steps/Expected/If-not filled in (no edits needed)
- [x] No remaining `[RUBBER-STAMP]` AC violates the CLAUDE.md conversion rule (all 8 are environment-bound)
- [x] Findings + table captured in this task body

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
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-25T14:06:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1462-dogfood-rubber-stamp-rule--audit-all-13-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f09b5d9f
- **Timestamp:** 2026-06-02T14:57:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T14:15:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
