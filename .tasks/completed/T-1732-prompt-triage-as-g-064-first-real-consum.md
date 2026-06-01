---
id: T-1732
name: "prompt-triage as G-064 first real consumer — orchestrator-driven user-prompt classifier (T-1729 sibling 3)"
description: >
  Inception: prompt-triage as G-064 first real consumer — orchestrator-driven user-prompt classifier (T-1729 sibling 3)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [meta-rca:T-1729, G-064-closure, supersedes-T-1726-as-v0.5]
components: []
related_tasks: [T-1729, T-1726, T-1727, T-1689, T-1690, T-1691, T-1692, T-1697]
arc_id: orchestrator-rethink
created: 2026-05-05T05:42:02Z
last_update: 2026-05-05T06:47:22Z
date_finished: 2026-05-05T06:47:22Z
---

# T-1732: prompt-triage as G-064 first real consumer — orchestrator-driven user-prompt classifier (T-1729 sibling 3)

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

**Recommendation:** GO

**Rationale:**

Layer-1 mitigation from T-1729 meta-RCA: UserPromptSubmit hook routes user message through fw resolver dispatch with prompt-triage workflow (ollama-local default, cloud fallback, fail-OPEN, latency target <500ms p95, cost cap $0.001/call). Verdict: GO/NO-GO/DEFER on whether prompt requires task creation. On GO, surface additionalContext warning the agent. Closes G4 (text output has no surface for governance) which structural fixes 1+2 cannot reach. Promotes to v0.5 over T-1726 escalation-scan because: higher severity (governance bypass > symptom-fix), hot-path (per-prompt vs daily), visible win on every prevented breakdown. T-1726 demoted to v0.6 (same envelope shape, near-zero incremental cost). Recommendation GO because spike path is bounded (Spike A: latency/cost; Spike B: precision/recall on 30-day backlog), substrate (T-1689/1690/1691/1692) is shipped, and the failure class is recurring.

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

**Decision**: GO

**Rationale**: Layer-1 mitigation from T-1729 meta-RCA: UserPromptSubmit hook routes user message through fw resolver dispatch with prompt-triage workflow (ollama-local default, cloud fallback, fail-OPEN, latency target <500ms p95, cost cap $0.001/call). Verdict: GO/NO-GO/DEFER on whether prompt requires task creation. On GO, surface additionalContext warning the agent. Closes G4 (text output has no surface for governance) which structural fixes 1+2 cannot reach. Promotes to v0.5 over T-1726 escalation-scan because: higher severity (governance bypass > symptom-fix), hot-path (per-prompt vs daily), visible win on every prevented breakdown. T-1726 demoted to v0.6 (same envelope shape, near-zero incremental cost). Recommendation GO because spike path is bounded (Spike A: latency/cost; Spike B: precision/recall on 30-day backlog), substrate (T-1689/1690/1691/1692) is shipped, and the failure class is recurring.

**Date**: 2026-05-05T06:47:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-05T05:42:28Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-05T05:42:28Z — status-update [task-update-agent]
- **Change:** tags: +meta-rca:T-1729

### 2026-05-05T05:42:28Z — status-update [task-update-agent]
- **Change:** tags: +G-064-closure

### 2026-05-05T05:42:29Z — status-update [task-update-agent]
- **Change:** tags: +supersedes-T-1726-as-v0.5

### 2026-05-05T06:47:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Layer-1 mitigation from T-1729 meta-RCA: UserPromptSubmit hook routes user message through fw resolver dispatch with prompt-triage workflow (ollama-local default, cloud fallback, fail-OPEN, latency target <500ms p95, cost cap $0.001/call). Verdict: GO/NO-GO/DEFER on whether prompt requires task creation. On GO, surface additionalContext warning the agent. Closes G4 (text output has no surface for governance) which structural fixes 1+2 cannot reach. Promotes to v0.5 over T-1726 escalation-scan because: higher severity (governance bypass > symptom-fix), hot-path (per-prompt vs daily), visible win on every prevented breakdown. T-1726 demoted to v0.6 (same envelope shape, near-zero incremental cost). Recommendation GO because spike path is bounded (Spike A: latency/cost; Spike B: precision/recall on 30-day backlog), substrate (T-1689/1690/1691/1692) is shipped, and the failure class is recurring.

### 2026-05-05T06:47:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.4)

- **Scan ID:** R-285aed82
- **Timestamp:** 2026-05-05T06:47:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-05T06:47:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
