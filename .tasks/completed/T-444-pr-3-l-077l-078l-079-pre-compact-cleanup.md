---
id: T-444
name: "PR #3: L-077/L-078/L-079: Pre-compact cleanup learnings + complete hook set in fw init"
description: |
  OneDev PR #3 (branch: learning/precompact-cleanup)

  Summary:
  - L-077: PROJECT_ROOT must resolve from git toplevel (budget-gate.sh fix included)
  - L-078: Delete redundant project artifacts when framework catches up (pre-compact-workflow cleanup)
  - L-079: Token monitoring needs both structural enforcement (hook) AND behavioral guidance (skill)

  Changes to fw init / fw setup: the generated .claude/settings.json now includes the complete hook set — PreCompact hook (auto-runs fw handover before /compact), SessionStart hooks.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [onedev, pr]
components: []
related_tasks: []
created: 2026-03-11T23:58:20Z
last_update: 2026-03-11T23:58:20Z
date_finished: 2026-03-12T13:00:47Z
---

# T-444: PR #3: L-077/L-078/L-079: Pre-compact cleanup learnings + complete hook set in fw init

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] L-077 fix applied: PROJECT_ROOT resolves from git toplevel in budget-gate.sh
- [x] L-078/L-079 pre-compact cleanup applied and `fw init` generated `.claude/settings.json` includes the complete hook set (PreCompact, SessionStart hooks)
- [x] PR #3 branch `learning/precompact-cleanup` merged on OneDev

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-11T23:58:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-444-pr-3-l-077l-078l-079-pre-compact-cleanup.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-39f4e691
- **Timestamp:** 2026-06-02T15:02:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — L-078/L-079 pre-compact cleanup applied and `fw init` generated `.claude/settings.json` includes the complete hook set (PreCompact, SessionStart hooks)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: L-078/L-079 pre-compact cleanup applied and `fw init` generated `.claude/settings.json` includes the complete hook set (PreCompact, SessionStart hooks`
