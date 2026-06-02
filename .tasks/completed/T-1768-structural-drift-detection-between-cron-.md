---
id: T-1768
name: "structural drift detection between cron-registry.yaml and generated crontab and deployed /etc/cron.d/ — prevent recurrence of T-1767 silent non-deploy"
description: >
  Inception: structural drift detection between cron-registry.yaml and generated crontab and deployed /etc/cron.d/ — prevent recurrence of T-1767 silent non-deploy

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: ["structural-fix", "cron", "drift-detection", "T-1767-followup", "G-064-prevention"]
components: []
related_tasks: ["T-1767", "T-1727", "T-1750"]
arc_id: orchestrator-rethink
created: 2026-05-06T12:14:38Z
last_update: 2026-05-06T16:37:41Z
date_finished: 2026-05-06T16:37:41Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1768: structural drift detection between cron-registry.yaml and generated crontab and deployed /etc/cron.d/ — prevent recurrence of T-1767 silent non-deploy

## Problem Statement

The cron-job pipeline has three states with no sync invariant between them:

1. `.context/cron-registry.yaml` — declared source of truth
2. `.context/cron/agentic-audit.crontab` — generated artefact (output of `fw cron generate`)
3. `/etc/cron.d/agentic-audit-<slug>` — deployed artefact (output of `fw cron install`, what cron daemon actually reads)

Drift between any two is silent. T-1767 found a 24+ hour silent non-firing because someone manually edited (2) without updating (1), and (3) had not been refreshed since before the edit. The framework had no mechanism to detect or warn about this divergence — `fw doctor` doesn't compare them; `fw cron install` doesn't pre-flight-check; nothing reads `/etc/cron.d/` to compare.

This is the same family as G-066 (substrate-vs-deliverable conflation) at the deployment layer: the substrate (file) is "right" but the deliverable (cron daemon firing the job) is silently failing.

## Assumptions

A1. `fw cron generate` regenerates the crontab file from the registry (verified — T-1767).
A2. Manual edits to the generated crontab file get overwritten on next `fw cron install` — i.e. they're "drift" by definition (verified — T-1767 saw the round-trip).
A3. There is no test or hook today that detects the drift before it bites (assumption — verify in exploration).
A4. The drift can be detected mechanically by diffing all three states (assumption — likely true given filesystem availability).
A5. The right enforcement point is one of: (a) `fw doctor` warning, (b) `fw cron install` pre-flight refusal, (c) cron-touching task convention (always include `grep /etc/cron.d/` in `## Verification`).

## Exploration Plan

Spike 1 (15 min): grep the codebase for any existing drift detection between registry/generated/deployed. Does `fw doctor` already check this? Does `fw cron status` validate against `/etc/cron.d/`? Time-boxed.

Spike 2 (15 min): read `lib/config-file.sh` and `bin/fw cron install` to understand the install pipeline's existing pre-flight checks and where a drift-detect would naturally sit.

Spike 3 (15 min): consider the three candidate mechanisms (fw doctor warning, fw cron install pre-flight, task-convention) on three axes — coverage (catches all 3-pair drifts?), latency (detects at edit-time vs install-time vs deploy-time), false-positive risk.

Recommendation: pick one path and file as build task.

## Findings (post-spike)

### Spike 1: existing cron drift detection — EXISTS

`bin/fw:1631-1657` (T-1112/T-1114) implements a cron-drift check inside `fw doctor`:
- compares `.context/cron/agentic-audit.crontab` (source) against `/etc/cron.d/agentic-audit-<slug>` (target)
- WARNs "Cron registry drift: $cron_source differs from $cron_target" with hint "Run: fw cron install"
- Also (T-1558) compares flock-wrapper count between registry and deployed file

A1 RE-VALIDATED: detection exists. The original problem statement assumed it did not.

### Spike 2: invocation/surfacing — GAP

- `fw doctor` is interactive only; no cron job invokes it.
- No notification channel converts the WARN into something the agent or user sees outside `fw doctor` runs.
- No watchtower surface, no liveness.jsonl entry, no audit log.
- Result: drift accumulates silently between (rare) interactive invocations.

A3 confirmed (no proactive detection); but the absence is in *invocation*, not in *detection*.

### Spike 3: candidate mechanisms — three axes

| Mechanism | Coverage | Latency | FP risk | Cost |
|-----------|----------|---------|---------|------|
| (a) `fw doctor` extension — also check registry↔generated | adds 1 of 3 pair-drifts | manual | low | small |
| (b) `fw cron install` pre-flight | catches edit-not-yet-generated | install-time | low | small |
| (c) Cron-touching task verification convention — `## Verification` line `bin/fw doctor \| grep -q "in sync"` | all detectable drifts at task-close | task-completion | low | doc-only |
| (d) `fw doctor` runs in cron + propagates to a notification | all drifts, periodic | ≤ 24 h | medium (alert fatigue) | medium |
| (e) Bump cron-drift WARN to FAIL in `fw doctor`, count in `fw audit` summary | escalation-only | manual | low | tiny |

## Scope Fence

**IN scope:**
- Make existing cron-drift detection actionable (surfacing, not detecting).
- Cover the failure mode T-1767 hit: registry edited but never deployed; OR deployed file edited but registry not updated.

**OUT of scope:**
- Deeper structural redesign of cron pipeline (`fw cron install` could become idempotent post-flight, etc.) — over-scoped.
- Generalising drift detection beyond cron (config-file drift, doc drift) — separate concern.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO — combine (c) + (e), small scope

**Rationale:**

Spikes revealed the original framing was wrong: detection EXISTS in `fw doctor:1631-1657`. The gap is surfacing, not detection. That collapses the structural fix from "build a drift detector" to two small touches:

1. **(e) Bump cron-drift WARN to a counted failure in `fw audit` summary** — `fw audit` already runs in cron (`structural-30m`). If `fw audit` calls into `fw doctor`'s cron-drift check (or replicates it), drift gets counted alongside other audit findings. Visible on `/audit` watchtower page. Same surface as fabric drift, hook threshold, etc. — established pattern, no new alert channel.

2. **(c) CLAUDE.md addendum: cron-touching task `## Verification` MUST include `bash -c 'bin/fw doctor 2>&1 | grep -q "Cron registry in sync"'`** — catches drift at task-completion time, before the broken state ships. Single-line convention, no code change.

Together: (e) catches drift in autonomous monitoring (escalating alongside existing audit findings); (c) prevents the specific T-1767 mode (cron-touching task that never deploys) at task-close.

**REJECTED:**
- (a) lone — already partially exists; extending to registry↔generated drift is a small PR but doesn't fix the surfacing gap.
- (b) lone — narrow window; misses the post-install drift.
- (d) — alert fatigue + new channel + dedicated cron job for one check; over-scoped.

**Decision-block: GO into a build task. Implementation small enough to fit one slice:**

| Touch | Files | Lines |
|-------|-------|-------|
| `fw audit` calls cron drift check OR sources `bin/fw:1631-1657` | `agents/audit/audit.sh` | ~15 |
| `## Verification` convention written into CLAUDE.md | `CLAUDE.md` | ~10 |
| Bats fixture: simulated drift produces audit FAIL | `tests/unit/test_audit_cron_drift.bats` | ~30 |

Build task to file: T-1769 ("Make cron drift actionable: audit-summary visibility + cron-touching task verification convention").

**Evidence:**

- `bin/fw:1631-1657` — existing cron drift check (T-1112/T-1114)
- `bin/fw:1659-1676` — existing flock parity check (T-1558)
- `agents/audit/audit.sh` — current audit shell (where (e) would land)
- `tools/g064-readiness.py` — companion gauge proves "deployed but not firing" is its own class
- T-1767 commit `f62e32501` — concrete failure mode this prevents

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

**Rationale**: Recommendation: GO — combine (c) + (e), small scope

Rationale:

Spikes revealed the original framing was wrong: detection EXISTS in `fw doctor:1631-1657`. The gap is surfacing, not detection. That collapses the structural fix from "build a drift detector" to two small touches:

1. (e) Bump cron-drift WARN to a counted failure in `fw audit` summary — `fw audit` already runs in cron (`structural-30m`). If `fw audit` calls into `fw doctor`'s cron-drift check (or replicates it), drift gets counted alongside other audit findings. Visible on `/audit` watchtower page. Same surface as fabric drift, hook threshold, etc. — established pattern, no new alert channel.

2. (c) CLAUDE.md addendum: cron-touching task `## Verification` MUST include `bash -c 'bin/fw doctor 2>&1 | grep -q "Cron registry in sync"'` — catches drift at task-completion time, before the broken state ships. Single-line convention, no code change.

Together: (e) catches drift in autonomous monitoring (escalating alongside existing audit findings); (c) prevents the specific T-1767 mode (cron-touching task that never deploys) at task-close.

REJECTED:
- (a) lone — already partially exists; extending to registry↔generated drift is a small PR but doesn't fix the surfacing gap.
- (b) lone — narrow window; misses the post-install drift.
- (d) — alert fatigue + new channel + dedicated cron job for one check; over-scoped.

Decision-block: GO into a build task. Implementation small enough to fit one slice:

| Touch | Files | Lines |
|-------|-------|-------|
| `fw audit` calls cron drift check OR sources `bin/fw:1631-1657` | `agents/audit/audit.sh` | ~15 |
| `## Verification` convention written into CLAUDE.md | `CLAUDE.md` | ~10 |
| Bats fixture: simulated drift produces audit FAIL | `tests/unit/test_audit_cron_drift.bats` | ~30 |

Build task to file: T-1769 ("Make cron drift actionable: audit-summary visibility + cron-touching task verification convention").

Evidence:

- `bin/fw:1631-1657` — existing cron drift check (T-1112/T-1114)
- `bin/fw:1659-1676` — existing flock parity check (T-1558)
- `agents/audit/audit.sh` — current audit shell (where (e) would land)
- `tools/g064-readiness.py` — companion gauge proves "deployed but not firing" is its own class
- T-1767 commit `f62e32501` — concrete failure mode this prevents

**Date**: 2026-05-06T16:37:41Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-06T12:16:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-06T16:37:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — combine (c) + (e), small scope

Rationale:

Spikes revealed the original framing was wrong: detection EXISTS in `fw doctor:1631-1657`. The gap is surfacing, not detection. That collapses the structural fix from "build a drift detector" to two small touches:

1. (e) Bump cron-drift WARN to a counted failure in `fw audit` summary — `fw audit` already runs in cron (`structural-30m`). If `fw audit` calls into `fw doctor`'s cron-drift check (or replicates it), drift gets counted alongside other audit findings. Visible on `/audit` watchtower page. Same surface as fabric drift, hook threshold, etc. — established pattern, no new alert channel.

2. (c) CLAUDE.md addendum: cron-touching task `## Verification` MUST include `bash -c 'bin/fw doctor 2>&1 | grep -q "Cron registry in sync"'` — catches drift at task-completion time, before the broken state ships. Single-line convention, no code change.

Together: (e) catches drift in autonomous monitoring (escalating alongside existing audit findings); (c) prevents the specific T-1767 mode (cron-touching task that never deploys) at task-close.

REJECTED:
- (a) lone — already partially exists; extending to registry↔generated drift is a small PR but doesn't fix the surfacing gap.
- (b) lone — narrow window; misses the post-install drift.
- (d) — alert fatigue + new channel + dedicated cron job for one check; over-scoped.

Decision-block: GO into a build task. Implementation small enough to fit one slice:

| Touch | Files | Lines |
|-------|-------|-------|
| `fw audit` calls cron drift check OR sources `bin/fw:1631-1657` | `agents/audit/audit.sh` | ~15 |
| `## Verification` convention written into CLAUDE.md | `CLAUDE.md` | ~10 |
| Bats fixture: simulated drift produces audit FAIL | `tests/unit/test_audit_cron_drift.bats` | ~30 |

Build task to file: T-1769 ("Make cron drift actionable: audit-summary visibility + cron-touching task verification convention").

Evidence:

- `bin/fw:1631-1657` — existing cron drift check (T-1112/T-1114)
- `bin/fw:1659-1676` — existing flock parity check (T-1558)
- `agents/audit/audit.sh` — current audit shell (where (e) would land)
- `tools/g064-readiness.py` — companion gauge proves "deployed but not firing" is its own class
- T-1767 commit `f62e32501` — concrete failure mode this prevents

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8fc77b73
- **Timestamp:** 2026-06-02T14:59:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-06T16:37:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
