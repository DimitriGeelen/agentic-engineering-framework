---
id: T-294
name: "Framework onboarding: portable project bootstrap"
description: >
  Discover, identify, and define what onboarding steps and scripts are needed
  to make the framework production-ready with a polished portable bootstrap
  experience. Covers: approaches (shared vs vendored), content separation,
  step sequence, post-startup, OS dependencies, and missing tooling.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: [lib/init.sh, lib/setup.sh, bin/fw, lib/templates/claude-project.md]
related_tasks: [T-124, T-108, T-125, T-126, T-127, T-295, T-296, T-297, T-298, 
      T-299, T-300, T-301, T-302, T-303, T-304, T-305, T-306, T-307, T-308, 
      T-309, T-310, T-311, T-312]
created: 2026-03-04T14:23:26Z
last_update: '2026-06-11T22:24:18Z'
date_finished: 2026-03-08T20:49:19Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:18Z'
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

# T-294: Framework onboarding: portable project bootstrap

## Problem Statement

The framework works well internally (290+ completed tasks, validated via T-124 on sprechloop), but onboarding a new project still requires tribal knowledge. There's no dependency checker, no pre-flight validation, no first-run experience, and the CLAUDE.md template can drift from the framework source. For the framework to be truly portable (D4), a new user should go from zero to working framework in under 5 minutes with clear error messages when something is wrong.

**For whom:** Any developer adopting the framework for a new project.
**Why now:** Three external-facing tasks (T-285 self-audit prompt, T-286 standalone script, T-289 CI/CD pipeline) are pushing toward external use — onboarding is the bottleneck.

## Assumptions

- A-1: Shared tooling model (Approach A) remains the primary deployment model
- A-2: Python 3 + PyYAML are acceptable minimum dependencies
- A-3: A pre-flight check would prevent most first-run failures
- A-4: `fw setup` guided wizard is sufficient for first-time users (no GUI needed)
- A-5: Template drift is a real problem that will cause agent misbehavior

## Exploration Plan

1. **Spike: Dependency audit** (30 min) — Map every external dependency, classify required vs optional
2. **Spike: Pre-flight script** (30 min) — Prototype `fw preflight` that checks all deps
3. **Spike: First-run experience** (45 min) — Design the "first 5 minutes" flow
4. **Spike: Template drift detection** (30 min) — How to detect and remediate stale CLAUDE.md
5. **Dialogue: User feedback** (ongoing) — Present findings, get direction on priorities

## Technical Constraints

- Must work on Linux (primary), macOS (secondary), WSL2 (tertiary)
- No root access required (except optional symlink to /usr/local/bin)
- Framework repo must remain a git repository (hooks depend on .git/)
- Python 3.8+ is minimum (Ubuntu 20.04 baseline)
- No network access required after initial clone (air-gap friendly)

## Scope Fence

**IN scope:**
- Discovering and cataloging all onboarding gaps
- Designing the step sequence and scripts needed
- Identifying OS dependencies and platform constraints
- Defining what "production-ready onboarding" means
- Go/no-go on building the identified scripts

**OUT of scope:**
- Actually building the scripts (post-GO build tasks)
- Vendored/embedded mode (Approach B — separate inception if needed)
- Package manager distribution (Approach C — future)
- Watchtower onboarding (separate concern)

## Acceptance Criteria

- [x] Problem statement validated
- [x] All 6 areas explored with findings documented
- [x] Assumptions tested against real framework state
- [x] Prioritized list of build tasks identified
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- At least 3 actionable build tasks identified with clear scope
- No fundamental blockers to the shared tooling model
- User agrees the identified work is worth building

**NO-GO if:**
- Framework architecture requires fundamental redesign for portability
- Dependencies are too heavy or platform-specific for general use
- Effort exceeds value (onboarding is "good enough" as-is)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Simulation found 9 real issues (4 P1, 5 P2). 13 build tasks identified across 3 phases. fw work-on is the only working path. Bugs in doctor, context init, task create need fixing. Missing README, preflight, audit grace period. Evidence: docs/reports/T-294-framework-onboarding-portable-bootstrap.md

**Date**: 2026-03-04T14:52:28Z
## Decision

**Decision**: GO

**Rationale**: Simulation found 9 real issues (4 P1, 5 P2). 13 build tasks identified across 3 phases. fw work-on is the only working path. Bugs in doctor, context init, task create need fixing. Missing README, preflight, audit grace period. Evidence: docs/reports/T-294-framework-onboarding-portable-bootstrap.md

**Date**: 2026-03-04T14:52:28Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-04T14:52:28Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Simulation found 9 real issues (4 P1, 5 P2). 13 build tasks identified across 3 phases. fw work-on is the only working path. Bugs in doctor, context init, task create need fixing. Missing README, preflight, audit grace period. Evidence: docs/reports/T-294-framework-onboarding-portable-bootstrap.md

### 2026-03-04T16:41:27Z — status-update [task-update-agent]
- **Change:** tags: +parent

### 2026-03-08T20:49:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-92d439c6
- **Timestamp:** 2026-06-02T15:01:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
