---
id: T-1086
name: "Fix hooks.sh bypass messages — commit-msg task-ref, inception gate, pre-push
  (T-1084 primary fix)"
description: >
  Fix hooks.sh bypass messages — commit-msg task-ref, inception gate, pre-push (T-1084
  primary fix)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T09:19:10Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-11T09:21:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1086: Fix hooks.sh bypass messages — commit-msg task-ref, inception gate, pre-push (T-1084 primary fix)

## Context

Primary fix from T-1084 (GO decided 2026-04-11). Three git-hook gates in `agents/git/lib/hooks.sh` all print the same misleading bypass recipe:
```
Emergency bypass (human only):
  fw tier0 approve
  git commit --no-verify
```
This is wrong in both contexts: human terminals have no Tier 0 pending file (`fw tier0 approve` errors out), and agent contexts never hit the git hook because Tier 0 fires at the Bash tool level first.

Replace with a clean message that distinguishes contexts. The research-artifact gate (line 169) already gets it right.

Research artifact: `docs/reports/T-1084-gate-bypass-discoverability.md`

## Acceptance Criteria

### Agent
- [x] commit-msg task-ref gate (hooks.sh:72-81) — replaced with clean bypass
- [x] Inception commit-msg gate (hooks.sh:124-132) — replaced with clean bypass
- [x] Pre-push audit gate (hooks.sh:372-381) — replaced with clean bypass
- [x] Hook VERSION bumped 1.5 → 1.6 (both templates + git.sh)
- [x] Mirrored to `.agentic-framework/` consumer copy
- [x] Consumer propagation verified: 11/11 projects FIXED via TermLink `install-hooks --force`

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
! grep -q 'Emergency bypass (human only)' agents/git/lib/hooks.sh
! grep -q 'Emergency bypass (human only)' .agentic-framework/agents/git/lib/hooks.sh
grep -c 'git commit --no-verify' agents/git/lib/hooks.sh | grep -qE '^[3-9]'

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

### 2026-04-11T09:19:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1086-fix-hookssh-bypass-messages--commit-msg-.md
- **Context:** Initial task creation

### 2026-04-11T09:21:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-50ddc8c6
- **Timestamp:** 2026-06-02T14:55:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `grep -c 'git commit --no-verify' agents/git/lib/hooks.sh | grep -qE '^[3-9]'`
