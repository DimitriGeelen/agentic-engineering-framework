---
id: T-1768
name: "structural drift detection between cron-registry.yaml and generated crontab and deployed /etc/cron.d/ — prevent recurrence of T-1767 silent non-deploy"
description: >
  Inception: structural drift detection between cron-registry.yaml and generated crontab and deployed /etc/cron.d/ — prevent recurrence of T-1767 silent non-deploy

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: ["arc:orchestrator-rethink", "structural-fix", "cron", "drift-detection", "T-1767-followup", "G-064-prevention"]
components: []
related_tasks: ["T-1767", "T-1727", "T-1750"]
created: 2026-05-06T12:14:38Z
last_update: 2026-05-06T12:16:21Z
date_finished: null
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

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** DEFER

**Rationale:**

Filed as a follow-up to T-1767 to track the structural fix. Recommendation deferred until exploration of three candidate mechanisms (fw doctor drift check vs fw cron install pre-flight vs cron-touching task verification convention) selects the lightest-touch path. Scope-decision boundary not yet drawn. Inception is the right phase per L-291/L-364 — symptomatic fix shipped in T-1767, structural prevention requires its own evaluation.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

### 2026-05-06T12:16:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
