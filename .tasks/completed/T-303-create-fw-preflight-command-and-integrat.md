---
id: T-303
name: "Create fw preflight command and integrate into fw init"
description: >
  New lib/preflight.sh that validates all OS dependencies before init.
  Two modes: (1) fw preflight — standalone check, (2) fw init calls it as first step.
  Check: python3 >= 3.8, PyYAML, git >= 2.0, bash >= 4.0, write perms, git identity.
  Classifies deps as required vs recommended. Shows exact install commands with
  why each dep is needed. Interactive install-with-consent: asks user before running
  any install commands (required [Y/n], recommended [y/N]). Follows sovereignty
  principle — detect silently, act only with consent. Same pattern as Tier 0.
  In non-interactive mode (CI/piped): print commands only, never auto-install.
  Source: T-294 simulation O-002, DX comparison (Terraform pattern).

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [bin/fw, lib/init.sh]
related_tasks: [T-294]
created: 2026-03-04T16:21:42Z
last_update: '2026-08-16T22:25:26Z'
date_finished: 2026-03-04T18:40:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
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
  - ts: '2026-08-16T22:25:26Z'
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

# T-303: Create fw preflight command and integrate into fw init

## Context

Sovereignty principle: framework detects gaps and proposes actions, human decides.
Same pattern as Tier 0 (detect, inform, ask, execute with approval).
See T-294 research artifact: `docs/reports/T-294-framework-onboarding-portable-bootstrap.md`

## Acceptance Criteria

### Agent
- [x] `fw preflight` checks: python3 version, PyYAML, git version, bash version, write perms, git identity
- [x] Each dep classified as required or recommended with explanation of why it's needed
- [x] Platform detection (apt/brew/pip) for install commands
- [x] Interactive mode: prompts user before installing (required [Y/n], recommended [y/N])
- [x] Non-interactive mode: prints commands only, exits with pass/fail code
- [x] `fw init` calls preflight as first step, stops if required deps missing
- [x] `fw preflight --check-only` skips install prompts (alias for non-interactive)

### Human
- [x] Output is clear and actionable for someone who has never seen the framework

## Verification

fw preflight --check-only
test -f /opt/999-Agentic-Engineering-Framework/lib/preflight.sh
grep -q "do_preflight" /opt/999-Agentic-Engineering-Framework/lib/init.sh

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

### 2026-03-04T16:21:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-303-create-fw-preflight-command-and-integrat.md
- **Context:** Initial task creation

### 2026-03-04T18:36:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T18:40:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cafbcf19
- **Timestamp:** 2026-06-02T18:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - skip-as-pass @ Verification:line 1
