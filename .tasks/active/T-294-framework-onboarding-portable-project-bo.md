---
id: T-294
name: "Framework onboarding: portable project bootstrap"
description: >
  Discover, identify, and define what onboarding steps and scripts are needed
  to make the framework production-ready with a polished portable bootstrap
  experience. Covers: approaches (shared vs vendored), content separation,
  step sequence, post-startup, OS dependencies, and missing tooling.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [portability, onboarding, dx]
components: [lib/init.sh, lib/setup.sh, bin/fw, lib/templates/claude-project.md]
related_tasks: [T-124, T-108, T-125, T-126, T-127]
created: 2026-03-04T14:23:26Z
last_update: 2026-03-04T14:23:26Z
date_finished: null
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
- [ ] All 6 areas explored with findings documented
- [ ] Assumptions tested against real framework state
- [ ] Prioritized list of build tasks identified
- [ ] Go/No-Go decision made

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
