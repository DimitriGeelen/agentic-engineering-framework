---
id: T-877
name: "Strengthen install-to-first-session pipeline — auto-fix warnings, guide onboarding,
  fw vs bin/fw resolution"
description: >
  Inception: Strengthen install-to-first-session pipeline — auto-fix warnings, guide
  onboarding, fw vs bin/fw resolution

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-05T06:06:23Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-05T06:14:36Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-877: Strengthen install-to-first-session pipeline — auto-fix warnings, guide onboarding, fw vs bin/fw resolution

## Problem Statement

The install-to-first-session pipeline has 6+ user-facing failure modes discovered from a real user install on 025-WokrshopDesigner. Each mode is individually minor but collectively they create a frustrating onboarding experience:

1. **`Run:` prefix** — Installer prints `Run: /path/fw doctor`, users copy-paste it verbatim → "Run:: command not found" (FIXED in T-875)
2. **`fw` vs `bin/fw` resolution** — Installer links `fw → ~/.local/bin/fw` (global) but consumer projects need `bin/fw` (project-local). Users run `fw init` from wrong context, `fw doctor` resolves wrong install
3. **Git hooks not installed after init** — `fw init` creates directories but doesn't install git hooks. Every consumer project starts with 2 WARN items
4. **Git identity not configured** — `fw doctor` warns but doesn't attempt to inherit from global git config or parent project
5. **No enforcement baseline** — Every fresh project starts without one; `fw doctor` warns but doesn't auto-create
6. **No onboarding guidance** — After install, no mention of starting Claude Code or that init tasks are ready to guide the user
7. **Version mismatch after installer update** — Installer updates `~/.agentic-framework` but doesn't run `fw upgrade` on existing consumer projects
8. **`fw init` from wrong directory** — Installer says "fw init" without specifying to `cd` into the project first. If user runs from `/root/`, they initialize `/root/` as a project

**For whom:** Any user installing or updating the framework on consumer projects.
**Why now:** Real user (the framework author!) hit ALL of these in a single install session. If the author hits them, new users will be completely blocked.

## Assumptions

- A1: `fw init` should auto-install git hooks (currently requires separate `fw git install-hooks`)
- A2: `fw init` should auto-create enforcement baseline (currently requires separate `fw enforcement baseline`)
- A3: Git identity can be inherited from global config (`git config --global user.email`)
- A4: The installer can auto-run `fw upgrade` on discovered consumer projects after updating the framework
- A5: Post-install messaging should include "start Claude Code" guidance and mention onboarding tasks

## Exploration Plan

### Spike 1: Audit the full install → init → first-session flow
1. Map every step from `curl | bash` through first Claude Code session
2. Identify every point where user must do manual work that could be automated
3. Categorize: auto-fixable vs. requires-human-judgment

### Spike 2: Evaluate auto-remediation in fw init
1. Can `fw init` call `fw git install-hooks` automatically?
2. Can `fw init` create enforcement baseline?
3. Can `fw init` inherit git identity from global config?
4. What are the risks of auto-fixing (e.g., overwriting intentional git hook config)?

### Spike 3: Post-install messaging improvements
1. What should the installer say after completing?
2. Should it mention Claude Code specifically? (portability concern — framework is agent-neutral)
3. Should `fw upgrade` be auto-run on consumer projects?

## Technical Constraints

- install.sh must work via `curl | bash` (no interactive prompts)
- Must work on both Linux (bash 5.x) and macOS (bash 3.2)
- Consumer projects may not have git initialized yet
- Global git config may not exist

## Scope Fence

**IN scope:**
- install.sh post-install messaging and auto-remediation
- fw init auto-hook-install and auto-baseline
- fw upgrade auto-consumer-update consideration
- Post-install onboarding guidance

**OUT of scope:**
- Changing the fw CLI resolution mechanism (T-664 already handled this)
- Interactive installer (violates curl|bash constraint)
- Onboarding task content (T-460 already handled this)

## Acceptance Criteria

### Agent
- [x] Problem statement validated with evidence from real install output
- [x] All 3 spikes completed with findings
- [x] Recommendation written with rationale and implementation plan

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-877-install-pipeline.md`
  2. Evaluate whether proposed auto-remediations are safe
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-877 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- At least 4 of the 8 failure modes can be auto-remediated safely
- No auto-remediation risks data loss or overwriting intentional config

**NO-GO if:**
- Auto-remediation introduces more failure modes than it fixes
- The changes would break curl|bash or macOS compatibility

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 6 of 8 failure modes fixable

**Date**: 2026-04-05T06:45:45Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** 6 of 8 failure modes are fixable with low-risk auto-remediation. Real user (framework author) hit all of them in one session. Implementation is ~50 lines across 2 files.
- **Evidence:**
  - Full flow audit in `docs/reports/T-877-install-pipeline.md`
  - F1 already fixed (T-875)
  - F3/F4/F5 auto-remediation is safe (idempotent, no overwrites)
  - F2/F6 are messaging changes only

## Decision

**Decision**: GO

**Rationale**: 6 of 8 failure modes fixable

**Date**: 2026-04-05T06:45:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-05T06:14:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: 6 of 8 failure modes are fixable with low-risk auto-remediation. Real user (framework author) hit all of them in one session. Implementation is ~50 lines across 2 files.
- Evidence:
  - Full flow audit in `docs/reports/T-877-install-pipeline.md`
  - F1 already fixed (T-875)
  - F3/F4/F5 auto-remediation is safe (idempotent, no overwrites)
  - F2/F6 are messaging changes only

### 2026-04-05T06:14:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-05T06:45:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 6 of 8 failure modes fixable

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cae41312
- **Timestamp:** 2026-06-02T15:05:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
