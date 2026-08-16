---
id: T-497
name: "fw vendor command — copy framework into project .agentic-framework/"
description: >
  Create fw vendor subcommand that copies the complete framework (~7MB: bin, lib,
  agents, web, docs, seeds, templates, FRAMEWORK.md, metrics.sh) into project/.agentic-framework/.
  Excludes .git, .context, .tasks/active, .tasks/completed, .fabric. Creates VERSION
  file. Plain copy, no git-in-git. From T-482 GO.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [portability, isolation, P0]
components: [bin/fw]
related_tasks: []
created: 2026-03-15T14:00:51Z
last_update: '2026-08-16T22:25:32Z'
date_finished: 2026-03-15T14:07:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:23Z'
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
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-497: fw vendor command — copy framework into project .agentic-framework/

## Context

From T-482 GO. See `docs/reports/T-482-install-model-inception.md`.

## Acceptance Criteria

### Agent
- [x] `fw vendor` subcommand exists in bin/fw and shows in `fw help`
- [x] `fw vendor` copies bin/, lib/, agents/, web/, docs/, .tasks/templates/, FRAMEWORK.md, metrics.sh to PROJECT_ROOT/.agentic-framework/
- [x] `fw vendor` excludes .git/, .context/, .tasks/active/, .tasks/completed/, .fabric/, install.sh
- [x] `fw vendor` creates VERSION file with current FW_VERSION
- [x] `fw vendor` is idempotent (re-running overwrites cleanly, 7.0MB both times)
- [x] `fw vendor --dry-run` shows what would be copied without copying
- [x] Vendored .agentic-framework/bin/fw is executable and resolves FRAMEWORK_ROOT from its own location

### Human
- [x] [RUBBER-STAMP] Run `fw vendor` in a test project and verify .agentic-framework/ contents
  **Steps:**
  1. Create temp dir: `mkdir /tmp/test-vendor && cd /tmp/test-vendor && git init`
  2. Run `fw vendor`
  3. Check: `ls .agentic-framework/bin/fw` exists and is executable
  4. Check: `du -sh .agentic-framework/` is ~7MB
  **Expected:** Complete framework in .agentic-framework/, no .git or .context from framework
  **If not:** Note what's missing or extra

## Verification

# fw vendor subcommand exists
grep -q "vendor)" bin/fw
# fw help shows vendor
grep -q "vendor" bin/fw

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

### 2026-03-15T14:00:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-497-fw-vendor-command--copy-framework-into-p.md
- **Context:** Initial task creation

### 2026-03-15T14:07:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a631373d
- **Timestamp:** 2026-06-02T15:03:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
