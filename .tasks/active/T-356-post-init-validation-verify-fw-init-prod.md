---
id: T-356
name: "Post-init validation: verify fw init produced correct and complete output"
description: >
  Inception: Post-init validation: verify fw init produced correct and complete output

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-08T17:36:15Z
last_update: 2026-03-08T17:36:15Z
date_finished: null
---

# T-356: Post-init validation: verify fw init produced correct and complete output

## Problem Statement

`fw init` creates ~15 files/directories, generates provider-specific configs, installs git hooks, and writes settings with resolved paths. When any of these steps silently fails (T-352: `_sed_i` undefined, T-355: Cellar path hardcoding), the user gets no feedback — hooks break silently, enforcement disappears, and the first sign is a mysterious failure hours later.

**For whom:** Any new user running `fw init` (especially Homebrew installs on macOS).
**Why now:** T-352 and T-355 both caused silent init failures discovered only through manual testing. We need a structural check, not user vigilance.

## Assumptions

A1. `fw doctor` already checks some post-init state (hooks, settings.json) but not completeness.
A2. A post-init validation step could run automatically at the end of `fw init`.
A3. The validation should be fast (<2s) and not require network access.
A4. Different providers (claude, cursor, generic) produce different outputs — validation must be provider-aware.

## Exploration Plan

1. **Inventory:** Map everything `fw init` creates (files, dirs, hooks, configs) — 30 min
2. **Gap analysis:** Compare inventory against what `fw doctor` currently checks — 15 min
3. **Design options:** (a) extend `fw doctor` with init-specific checks, (b) new `fw init --verify` flag, (c) automatic post-init validation built into `fw init` itself — 30 min
4. **Prototype:** Spike the chosen approach on a temp directory — 30 min

## Technical Constraints

- Must work on macOS (Homebrew) and Linux (git clone)
- Must handle both `--provider claude` and `--provider generic` (different outputs)
- Cannot assume Python is available (some checks must be pure bash)
- Hook paths differ by install method (Cellar/opt/direct clone)

## Scope Fence

**IN:** Validating that `fw init` output is correct and complete (files exist, paths resolve, hooks executable, JSON valid).
**OUT:** Runtime validation during agent sessions (that's `fw doctor`'s job). Test harness for CI. Cross-project init testing.

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Clear inventory of what `fw init` produces (>10 checkable items)
- At least one design option is implementable in <1 hour
- Would have caught T-352 or T-355 failures automatically

**NO-GO if:**
- `fw doctor` already covers 90%+ of the checks (just needs minor extension)
- Validation logic would be fragile / tightly coupled to init internals
- Overhead of validation > 5 seconds (users won't wait)

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
