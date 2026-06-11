---
id: T-1255
name: "Release tagging + tag-push gap — GitHub stuck at v1.0.0"
description: >
  Inception: Release tagging + tag-push gap — GitHub stuck at v1.0.0

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-14T20:32:43Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-14T20:39:20Z
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
---

# T-1255: Release tagging + tag-push gap — GitHub stuck at v1.0.0

## Problem Statement

GitHub (`DimitriGeelen/agentic-engineering-framework`) appears stuck at v1.0.0 as the
"Latest release" while framework development has reached VERSION `1.5.614`. Three
layered issues found on investigation:

1. **Tags not pushed:** Local tags go up to `v1.5.742`, but GitHub/OneDev only have
   `v1.0.0` … `v1.4.0`. `handover.sh:759` uses `git push HEAD` (not `--follow-tags`),
   so annotated tags never travel with commit pushes.
2. **No bump cadence:** Only one `v1.5.x` tag exists locally (`v1.5.742`, 2026-04-06).
   `VERSION` file reads `1.5.614` but that's synthesised by the pre-push stamper
   (T-648) as `1.5 + 614 commits past v1.5.742` — not a real tag anyone can fetch.
3. **No GitHub Releases:** Tags ≠ Releases. GitHub's "Latest release" widget shows
   whatever has a formal `gh release` attached. If only v1.0.0 was ever published
   as a Release, that's what shows — regardless of tag state.

## Assumptions

- A1: User wants GitHub public face to reflect actual framework maturity
- A2: Tag push absence is systemic (never pushed), not a one-time oversight
- A3: Automated tag creation + tag push + Release creation is the sustainable fix
- A4: `--follow-tags` on handover push won't cause unwanted tag leakage (all tags local are intentional)

## Exploration Plan

- **Spike A (15min):** Inventory current state — local tags, remote tags, VERSION
  history, how/when tags were historically cut. Confirm push mechanism and gap.
- **Spike B (20min):** Tag-cadence options — weekly bump? per-release-worthy change?
  manual-only via `fw release`? Score against antifragility / reliability / usability
  / portability.
- **Spike C (15min):** GitHub Release mechanics — `gh release create` from tag,
  auto-generated notes, which tags warrant a Release vs just a tag.
- **Spike D (10min):** Push-fix scope — one-line `--follow-tags` change vs explicit
  `fw git push-tags` subcommand. Which handles the backlog safely.

## Technical Constraints

- Two remotes: `github` (public) and `onedev` (private mirror). Both need tag push.
- Tag push is irreversible externally — once pushed, rewriting requires force-push
  which other consumers may have already fetched.
- `gh` CLI available on this host (check version).
- Framework currently uses annotated tags? Lightweight? (Spike A confirms.)
- Consumer projects pin framework via `.framework.yaml` version — tag push alone
  doesn't force them to upgrade.

## Scope Fence

**IN:** Tag-push gap analysis, tag cadence policy, GitHub Release automation, handover.sh fix
**IN:** Backfill decision — do we push existing `v1.5.742` tag now? Cut a fresh `v1.5.614`?
**OUT:** Versioning scheme redesign (semver vs git-describe — that's T-1253)
**OUT:** Consumer auto-upgrade triggered by new release (separate question)

## Acceptance Criteria

### Agent
- [x] Spike A complete: tag inventory + push mechanism confirmed, findings in research artifact
- [x] Spike B complete: tag-cadence options scored, recommendation chosen (Option 3 weekly cron + Option 1 manual)
- [x] Spike C complete: GitHub Release mechanics documented, `gh release create --generate-notes` path chosen
- [x] Spike D complete: push-fix scope decided (one-liner `--follow-tags` + one-shot backfill command)
- [x] Research artifact written to `docs/reports/T-1255-release-tagging.md`
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

**Recommendation:** GO — four-part structural fix

**Rationale:** Public-facing release surface invisible for 8+ days. Three
independent root causes (push gap, cadence gap, Release gap) all bounded,
testable, reversible.

**Evidence:**
- Local `v1.5.742` tag never pushed to github/onedev (both stop at v1.4.0)
- VERSION `1.5.614` is synthetic (pre-push stamper formula) — not a fetchable tag
- 614 commits since last tag = no bump cadence at all
- `gh` CLI v2.89.0 available on host — Release automation feasible
- `--follow-tags` is standard git, zero new surface
- Cron already used for other framework auto-tasks

**Proposed changes (1h total):**
1. `handover.sh:759` → add `--follow-tags` (5 min)
2. Weekly cron auto-tag via `lib/release.sh` (30 min)
3. `gh release create --generate-notes` on new tags (15 min)
4. Backfill: push existing `v1.5.742`, optionally cut `v1.5.614` (5 min)

**Next step if GO:** Create `T-1256-build: implement weekly release tagging + push-tags fix`

Full research artifact: `docs/reports/T-1255-release-tagging.md`

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

**Rationale**: Recommendation: GO — four-part structural fix

Rationale: Public-facing release surface invisible for 8+ days. Three
independent root causes (push gap, cadence gap, Release gap) all bounded,
testable, reversible.

Evidence:
- Local `v1.5.742` tag never pushed to github/onedev (both stop at v1.4.0)
- VERSION `1.5.614` is synthetic (pre-push stamper formula) — not a fetchable tag
- 614 commits since last tag = no bump cadence at all
- `gh` CLI v2.89.0 available on host — Release automation feasible
- `--follow-tags` is standard git, zero new surface
- Cron already used for other framework auto-tasks

Proposed changes (1h total):
1. `handover.sh:759` → add `--follow-tags` (5 min)
2. Weekly cron auto-tag via `lib/release.sh` (30 min)
3. `gh release create --generate-notes` on new tags (15 min)
4. Backfill: push existing `v1.5.742`, optionally cut `v1.5.614` (5 min)

Next step if GO: Create `T-1256-build: implement weekly release tagging + push-tags fix`

Full research artifact: `docs/reports/T-1255-release-tagging.md`

**Date**: 2026-04-14T20:39:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-14T20:39:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — four-part structural fix

Rationale: Public-facing release surface invisible for 8+ days. Three
independent root causes (push gap, cadence gap, Release gap) all bounded,
testable, reversible.

Evidence:
- Local `v1.5.742` tag never pushed to github/onedev (both stop at v1.4.0)
- VERSION `1.5.614` is synthetic (pre-push stamper formula) — not a fetchable tag
- 614 commits since last tag = no bump cadence at all
- `gh` CLI v2.89.0 available on host — Release automation feasible
- `--follow-tags` is standard git, zero new surface
- Cron already used for other framework auto-tasks

Proposed changes (1h total):
1. `handover.sh:759` → add `--follow-tags` (5 min)
2. Weekly cron auto-tag via `lib/release.sh` (30 min)
3. `gh release create --generate-notes` on new tags (15 min)
4. Backfill: push existing `v1.5.742`, optionally cut `v1.5.614` (5 min)

Next step if GO: Create `T-1256-build: implement weekly release tagging + push-tags fix`

Full research artifact: `docs/reports/T-1255-release-tagging.md`

### 2026-04-14T20:39:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2ea4d063
- **Timestamp:** 2026-06-02T14:56:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
