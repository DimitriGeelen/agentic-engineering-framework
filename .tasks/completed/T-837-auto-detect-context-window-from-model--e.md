---
id: T-837
name: "Auto-detect context window from model — eliminate hardcoded CONTEXT_WINDOW default"
description: >
  Inception: Auto-detect context window from model — eliminate hardcoded CONTEXT_WINDOW default

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T12:58:31Z
last_update: 2026-04-17T21:26:29Z
date_finished: 2026-04-13T11:30:46Z
---

# T-837: Auto-detect context window from model — eliminate hardcoded CONTEXT_WINDOW default

## Problem Statement

Hardcoded 300K context window default doesn't adapt to model capabilities (Opus 4.6 supports 1M). Research artifact: `docs/reports/T-837-auto-detect-context-window.md`.

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
- [x] Problem statement validated (T-834 false critical from 200K default)
- [x] Research: model name available in JSONL transcript (`claude-opus-4-6`)
- [x] Recommendation: NO-GO — 300K default + FW_CONTEXT_WINDOW env var is sufficient

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Auto-detection provides clear benefit over manual FW_CONTEXT_WINDOW

**NO-GO if:**
- User preference (300K) matters more than model capability (which it does)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decision

**Decision**: NO-GO

**Rationale**: Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

**Date**: 2026-04-17T21:26:29Z

## Recommendation

**Recommendation:** NO-GO
**Rationale:** 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
**Evidence:**
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T12:59:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T22:23:16Z — status-update [task-update-agent]
- **Change:** horizon: now → later

### 2026-04-13T11:18:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:22:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:22:40Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:24:05Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:27:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:29:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:30:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-13T11:30:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** Inception decision in progress

### 2026-04-13T11:30:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO

### 2026-04-13T11:31:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

### 2026-04-17T21:26:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: NO-GO
Rationale: 300K default + FW_CONTEXT_WINDOW env var is sufficient. Auto-detection adds complexity without clear benefit — the user explicitly wants 300K for quality+cost control, not the model's maximum. Different models have different optimal working windows that don't equal their context limits.
Evidence:
- User feedback: explicit preference for 300K, NOT 1M (even on Opus 4.6 with 1M context)
- FW_CONTEXT_WINDOW env var already provides per-project override capability
- Auto-detection would require API calls or model metadata that may not be available offline
- The "right" context window is a user preference, not a model property

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c5c4b6ee
- **Timestamp:** 2026-06-02T15:05:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
