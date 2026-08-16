---
id: T-1253
name: "Pre-push hook VERSION-stamping breaks version.json-based consumer projects
  (T-106 blocker, T-648 regression)"
description: >
  Inception: Pre-push hook VERSION-stamping breaks version.json-based consumer projects
  (T-106 blocker, T-648 regression)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-14T07:02:41Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-04-18T22:42:38Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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
  - ts: '2026-08-16T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1253: Pre-push hook VERSION-stamping breaks version.json-based consumer projects (T-106 blocker, T-648 regression)

## Problem Statement

The framework's `pre-push` hook contains a VERSION-stamping block (introduced in T-648)
that writes `git describe --tags --match 'v[0-9]*'` output to `VERSION` and
`.agentic-framework/VERSION` on every push. This assumes tag-based versioning.

Consumer projects that use `version.json`/`version_prod.json`-based versioning
(e.g., T-106 blocker) have their version silently overwritten on every push,
reverting manual bumps to whatever the latest matching git tag is.

Reported by .109 cross-agent: "VERSION gets rewritten to 3.1.alpha every push
even after we bump version.json to 3.2.9-alpha."

## Assumptions

- A1: The VERSION-stamping block in pre-push is the root cause (not some other hook)
- A2: Consumer projects legitimately use non-git-tag versioning (version.json)
- A3: Stripping the block locally is safe for version.json-based projects
- A4: A version.json-aware stamping block can detect which scheme the project uses
- A5: `fw upgrade` alone does not fix this because the template itself is wrong

## Exploration Plan

1. **Spike A (15min):** Read `agents/git/lib/hooks.sh` pre-push section; confirm
   the stamping block exists and is unconditional.
2. **Spike B (15min):** Check if `version.json` presence is detectable at hook-time.
3. **Spike C (30min):** Evaluate 3 fix paths against portability + usability directives:
   - Path 1: Make stamping block opt-in (flag in .framework.yaml)
   - Path 2: Auto-detect version.json and skip stamping when present
   - Path 3: Remove the stamping block entirely (make it manual)

## Technical Constraints

- Hook runs in every consumer's git repo; must work without additional deps
- version.json is a convention in some projects, not a framework standard
- The pre-push hook must remain fast (<100ms) — no heavy parsing
- Must not break projects that DO use git-tag versioning

## Scope Fence

**IN:** Diagnose the stamping block, choose a fix path, produce a build proposal
**OUT:** Actually implementing the fix (becomes a separate build task after GO)
**OUT:** Addressing T-106 AC#2 directly (needs Tier 2 authorization for global framework)

## Acceptance Criteria

### Agent
- [x] Spike A complete: stamping block located in pre-push template, block documented
- [x] Spike B complete: detection method for version.json-based projects identified
- [x] Spike C complete: 3 fix paths evaluated against directives (Antifragility/Reliability/Usability/Portability)
- [x] Research artifact written to docs/reports/T-1253-pre-push-version-stamping.md
- [x] Recommendation written with rationale and GO/NO-GO/DEFER

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Path 2 (auto-detect version.json / package.json / pyproject.toml)
scores best on Usability and Portability with no regression for git-tag users.
The fix is bounded (modify the stamping block in `agents/git/lib/hooks.sh` plus
the installed copy in `.git/hooks/pre-push`), testable, and reversible.

**Evidence:**
- Stamping block isolated to ~20 lines (agents/git/lib/hooks.sh:385-403)
- Real consumer bug demonstrated: /opt/050-email-archive has version.json=0.17.3 but VERSION=0.12.1055 (5 versions behind)
- Detection signals are mechanical (file existence + grep for version key)
- See full research artifact: docs/reports/T-1253-pre-push-version-stamping.md

**Next step if GO:** Create `T-1254-build: implement version-scheme detection in pre-push stamping block`

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Path 2 (auto-detect version.json / package.json / pyproject.toml)
scores best on Usability and Portability with no regression for git-tag users.
The fix is bounded (modify the stamping block in `agents/git/lib/hooks.sh` plus
the installed copy in `.git/hooks/pre-push`), testable, and reversible.

Evidence:
- Stamping block isolated to ~20 lines (agents/git/lib/hooks.sh:385-403)
- Real consumer bug demonstrated: /opt/050-email-archive has version.json=0.17.3 but VERSION=0.12.1055 (5 versions behind)
- Detection signals are mechanical (file existence + grep for version key)
- See full research artifact: docs/reports/T-1253-pre-push-version-stamping.md

Next step if GO: Create `T-1254-build: implement version-scheme detection in pre-push stamping block`

**Date**: 2026-04-18T22:42:37Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-14T07:06:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T22:42:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Path 2 (auto-detect version.json / package.json / pyproject.toml)
scores best on Usability and Portability with no regression for git-tag users.
The fix is bounded (modify the stamping block in `agents/git/lib/hooks.sh` plus
the installed copy in `.git/hooks/pre-push`), testable, and reversible.

Evidence:
- Stamping block isolated to ~20 lines (agents/git/lib/hooks.sh:385-403)
- Real consumer bug demonstrated: /opt/050-email-archive has version.json=0.17.3 but VERSION=0.12.1055 (5 versions behind)
- Detection signals are mechanical (file existence + grep for version key)
- See full research artifact: docs/reports/T-1253-pre-push-version-stamping.md

Next step if GO: Create `T-1254-build: implement version-scheme detection in pre-push stamping block`

### 2026-04-18T22:42:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ebb2b315
- **Timestamp:** 2026-06-02T14:56:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
