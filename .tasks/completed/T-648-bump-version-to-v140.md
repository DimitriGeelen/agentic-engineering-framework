---
id: T-648
name: "Git-derived versioning — auto-increment patch from commit count since tag"
description: >
  Replace hardcoded FW_VERSION with git-derived semver. Major.minor = human tags,
  patch = auto from commits since tag.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-27T14:10:08Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-27T17:28:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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
  - ts: '2026-08-16T22:25:36Z'
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

# T-648: Bump version to v1.4.0

## Context

71 commits since v1.3.0 with no version change. Hardcoded FW_VERSION breaks by design — nobody remembers to bump it. Git-derived versioning: major.minor from human tags, patch auto-derived from commit count since tag.

## Acceptance Criteria

### Agent
- [x] `bin/fw` derives version from `git describe` — no hardcoded FW_VERSION
- [x] Falls back to `VERSION` file when not in git repo (consumer installs)
- [x] `fw version` shows `1.4.X` where X = commits since v1.4.0 tag
- [x] Pre-push hook stamps `VERSION` file from git describe
- [x] Tag v1.4.0 created
- [x] Upstream copies synced (.agentic-framework/bin/fw, VERSION)

### Human
- [x] [RUBBER-STAMP] Verify `fw version` shows correct auto-derived version
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw version`
  2. Make a test commit, run `bin/fw version` again
  **Expected:** Patch number increments by 1
  **If not:** Check `git describe --tags`

## Verification

bin/fw version | grep -qE 'fw v1\.4\.'
grep -q 'git describe' bin/fw
test -f VERSION

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

### 2026-03-27T14:10:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-648-bump-version-to-v140.md
- **Context:** Initial task creation

### 2026-03-27T17:28:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-27T18:07:59Z — status-update [task-update-agent]
- **Change:** owner: agent → human

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-97baea45
- **Timestamp:** 2026-06-02T15:04:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw version | grep -qE 'fw v1\.4\.'`
