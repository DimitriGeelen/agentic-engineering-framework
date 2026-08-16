---
id: T-1463
name: "T-1459 follow-on: brand 5 dead Claude Code hooks as REFERENCE ONLY in script
  headers"
description: >
  T-1459 follow-on: brand 5 dead Claude Code hooks as REFERENCE ONLY in script headers

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T15:26:25Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T15:27:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1463: T-1459 follow-on: brand 5 dead Claude Code hooks as REFERENCE ONLY in script headers

## Context

T-1459 inception (DEFER recorded last session) found 5 scripts in `agents/context/` that were authored as Claude Code hooks but were never registered in `.claude/settings.json` — they exist on disk, look like live hooks, and would mislead anyone reading the codebase. Until/unless they are wired up, they need an unmissable banner saying so. Files: `session-end.sh`, `stop-guard.sh`, `subagent-stop.sh`, `pl007-scanner.sh`, `session-silent-scanner.sh`.

## Acceptance Criteria

### Agent
- [x] All 5 scripts contain a `# REFERENCE ONLY — not registered in .claude/settings.json (see T-1459)` banner directly under the shebang
- [x] grep confirms 5 matches across the 5 files (one banner per file, no duplicates)
- [x] No script has its banner inside a sub-block (banner must be on a top-level comment line, not inside a function)
- [x] `bash -n` syntax-check passes for all 5 scripts after edit

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

# Banner present in all 5 dead hook scripts
test "$(grep -l 'REFERENCE ONLY.*T-1459' agents/context/session-end.sh agents/context/stop-guard.sh agents/context/subagent-stop.sh agents/context/pl007-scanner.sh agents/context/session-silent-scanner.sh | wc -l)" -eq 5
# Syntax still valid
bash -n agents/context/session-end.sh
bash -n agents/context/stop-guard.sh
bash -n agents/context/subagent-stop.sh
bash -n agents/context/pl007-scanner.sh
bash -n agents/context/session-silent-scanner.sh
# None of the 5 are accidentally registered
test "$(grep -c 'session-end\.sh\|stop-guard\.sh\|subagent-stop\.sh\|pl007-scanner\.sh\|session-silent-scanner\.sh' .claude/settings.json)" -eq 0

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

### 2026-04-25T15:26:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1463-t-1459-follow-on-brand-5-dead-claude-cod.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e8fbfa6
- **Timestamp:** 2026-06-02T14:57:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T15:27:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** 5 dead hooks branded with REFERENCE ONLY banner; all ACs pass
