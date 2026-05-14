---
id: T-1833
name: "T-1736 spike harvest read session JSONLs outside PROJECT_ROOT — path-isolation violation (Layer 3 RCA of fw-upgrade-incident-2026-05-14)"
description: >
  Layer 3 root cause of fw-upgrade-incident-2026-05-14 cluster. T-1736 spike (prompt-triage classifier accuracy bench, 2026-05-05) read Claude Code session JSONLs from outside PROJECT_ROOT to build its training corpus. The harvest content (3114 entries, removed in commit 7fba568e7 under T-1828) included full context-compaction summaries from those sessions, one of which contained an Azure AD OAuth client secret embedded in narrative text. Surfaced 9 days later when T-1828 mirror-unstick push hit GitHub secret-scanning protection. Violation per feedback_path_isolation_strict: even read-only inspection of paths outside PROJECT_ROOT is forbidden. The secret leak is the consequence; the read was the violation. Need: prevention pattern for spike-tooling cross-project reads + audit of other spikes for similar harvests.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [bug, fw-upgrade-incident-2026-05-14, path-isolation, spike-harvest, security]
components: []
related_tasks: []
created: 2026-05-14T20:42:00Z
last_update: 2026-05-14T20:42:00Z
date_finished: null
---

# T-1833: T-1736 spike harvest read session JSONLs outside PROJECT_ROOT — path-isolation violation (Layer 3 RCA of fw-upgrade-incident-2026-05-14)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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
