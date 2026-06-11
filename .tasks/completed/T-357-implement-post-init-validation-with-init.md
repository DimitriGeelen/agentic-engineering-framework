---
id: T-357
name: "Implement post-init validation with #@init: tags"
description: >
  Implement the T-356 GO decision: (1) Add #@init: tags to lib/init.sh for all 31
  creation units, (2) Create lib/validate-init.sh that parses tags and validates each
  unit, (3) Call validate-init from end of fw init, (4) Register both components in
  Fabric with dependency edge, (5) Add cron audit check for tag-count drift. See docs/reports/T-356-post-init-validation.md
  for full design.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [bin/fw, lib/init.sh, lib/validate-init.sh]
related_tasks: [T-356]
created: 2026-03-08T18:17:48Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-08T19:14:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-357: Implement post-init validation with #@init: tags

## Context

T-356 inception GO decision. Design: `docs/reports/T-356-post-init-validation.md`. Independent `validate-init.sh` driven by `#@init:` tags embedded in `init.sh`. Three-layer assurance: blast-radius nudge, cron audit for drift.

## Acceptance Criteria

### Agent
- [x] All creation units in `lib/init.sh` have `#@init: <type>-<key> <path> [args]` tags (30 units)
- [x] Each `#@init:` tag has a human-readable comment on the next line
- [x] `lib/validate-init.sh` exists and parses `#@init:` tags from `init.sh`
- [x] `validate-init.sh` checks: dir exists, file exists, yaml valid + keys, json valid + keys, exec + contains, hookpaths
- [x] `fw init` calls `validate-init.sh` at the end and shows pass/fail per unit
- [x] `fw validate-init [target-dir]` works as standalone command
- [x] Both components registered in Fabric with `init.sh → validate-init.sh` dependency edge

### Human
- [x] [RUBBER-STAMP] Run `fw init --provider claude --force` in a temp dir and verify validation output
  **Steps:**
  1. `mkdir /tmp/test-validate && cd /tmp/test-validate && git init`
  2. `fw init --provider claude --force`
  3. Observe validation output at end of init
  **Expected:** All items show `✓ <type>-<key> <description>`, zero failures
  **If not:** Note which `✗` items failed and check if the tag or check is wrong

## Verification

# validate-init.sh exists and is executable
test -x lib/validate-init.sh
# All init units have tags
test "$(grep -c '#@init:' lib/init.sh)" -ge 25
# validate-init.sh can parse tags
grep -q '#@init:' lib/init.sh
# fw subcommand registered
grep -q 'validate-init' bin/fw

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

### 2026-03-08T18:17:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-357-implement-post-init-validation-with-init.md
- **Context:** Initial task creation

### 2026-03-08T19:14:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ffba9146
- **Timestamp:** 2026-06-02T15:02:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
