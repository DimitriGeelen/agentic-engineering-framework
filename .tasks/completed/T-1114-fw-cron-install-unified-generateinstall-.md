---
id: T-1114
name: "fw cron install: unified generate+install command + fw doctor drift check (T-1112
  build)"
description: >
  fw cron install: unified generate+install command + fw doctor drift check (T-1112
  build)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, tests/integration/cron_install.bats]
related_tasks: []
created: 2026-04-11T22:15:35Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-11T22:40:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1114: fw cron install: unified generate+install command + fw doctor drift check (T-1112 build)

## Context

Build task implementing T-1112 GO decision (inception RCA captured in
`docs/reports/T-1112-cron-divergence-rca.md`). The cron registry system
(T-604) and the legacy schedule-install system (T-184/T-196) both write
to `.context/cron/agentic-audit.crontab` with different content: the
legacy path has a hardcoded template (10 audit jobs) while the registry
has 11 jobs including `pickup-process`. Running `fw audit schedule
install` after `fw cron generate` silently clobbers the registry-sourced
crontab, leaving `pickup-process` uninstalled. This task adds a unified
`fw cron install` command that is the single chokepoint for installing
from the registry, plus a `fw doctor` drift check that catches the
problem retroactively.

## Acceptance Criteria

### Agent
- [x] `fw cron install` subcommand added to `bin/fw` cron case that:
      (a) regenerates the registry-sourced crontab via the existing
      `fw cron generate` logic, (b) computes a diff against the system
      cron file (`/etc/cron.d/agentic-audit-<slug>` by default,
      overridable via `FW_CRON_INSTALL_DIR` for tests), (c) installs
      atomically using `install -m 0644` with sudo degradation.
- [x] `fw cron install --dry-run` shows the pending diff without making
      changes and exits 0. Exit code is non-zero when source/registry is
      missing.
- [x] `fw cron install` honors `FW_CRON_INSTALL_DIR` so integration
      tests can target a temp directory instead of `/etc/cron.d/`.
- [x] `fw doctor` adds a cron drift check: when the registry-generated
      crontab differs from the installed file (or when the registry has
      jobs but nothing is installed), it emits a WARN with the remediation
      command `fw cron install`.
- [x] `fw cron help` documents the new `install` subcommand.
- [x] Unit/integration bats test `tests/integration/cron_install.bats`
      passes: exercises dry-run + clean install + drift detection using
      `FW_CRON_INSTALL_DIR` + `FW_CRON_REGISTRY` overrides.
- [x] `bin/fw test integration tests/integration/cron_install.bats` green.
- [x] Existing `tests/unit/lib_*.bats` regression-free.

## Verification

grep -q '^            install)' bin/fw
grep -q 'FW_CRON_INSTALL_DIR' bin/fw
bin/fw cron help 2>&1 | grep -q 'install'
bats tests/integration/cron_install.bats

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

### 2026-04-11T22:15:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1114-fw-cron-install-unified-generateinstall-.md
- **Context:** Initial task creation

### 2026-04-11T22:40:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dfcbf70e
- **Timestamp:** 2026-06-02T14:55:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bin/fw cron help 2>&1 | grep -q 'install'`
