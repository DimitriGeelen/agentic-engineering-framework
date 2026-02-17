# Observation Analysis — Onboarding Cycle 1

**Source:** `docs/onboarding-observations.md` (O-001 through O-010)
**Date:** 2026-02-17
**Task:** T-124

## Classification

| ID | Summary | Type | Severity | Effort |
|----|---------|------|----------|--------|
| O-001 | No history/welcome on first session | STRUCTURAL | P1 | quick |
| O-002 | Options as prose, not numbered list | INSTRUCTION | P1 | quick |
| O-003 | Agent ran ahead on inception without review | INSTRUCTION+STRUCTURAL | **P0** | medium |
| O-004 | `fw resume quick` useless on new project | STRUCTURAL | P1 | quick |
| O-005 | Agent kept building (escalation of O-003) | STRUCTURAL | **P0** | medium |
| O-006 | Web app built but not started, user not told | INSTRUCTION | P1 | quick |
| O-007 | No port/network discovery | NEW FEATURE | P1 | large |
| O-008 | No in-session guardrail injection | STRUCTURAL | P1 | large |
| O-009 | CLAUDE.md template drifted from framework | INSTRUCTION+STRUCTURAL | **P0** | medium |
| O-010 | Browser API constraints missed in inception | INSTRUCTION | P1 | quick |

## Symptom Clusters

### Cluster A: Inception Has No Enforcement Boundary (O-003, O-005, O-010)
Inception tasks are workflow-typed but the framework enforces no structural difference from build tasks. The agent treated inception exactly like build — filling template, writing code, committing — without human-in-the-loop gates.

### Cluster B: No First-Session Scaffolding (O-001, O-004)
Framework assumes prior history exists. `fw context init` looks for LATEST.md; `fw resume quick` reads working memory. Neither has a new-project branch.

### Cluster C: Template Drift Has No Detection (O-009, O-010)
After T-102 generated the template, subsequent improvements (P-011, horizon, task sizing) never propagated. No mechanism to detect or warn about drift.

### Cluster D: Agent Autonomy Has No Structural Brake (O-003, O-005, O-008)
Same gap from three angles. The framework relies entirely on instruction discipline but has no hook for consecutive-commit counting or STOP file detection.

## Top 3 Root Causes

### RC-1: Inception tasks are not structurally gated
The commit-msg hook doesn't check task type. Tier 1 checks for active task but not inception approval state. Agent can make unlimited build commits without go/no-go.

### RC-2: Framework assumes session continuity; no new-project on-ramp
Every orientation tool assumes prior state. First session is the worst experience.

### RC-3: Template drift has no detection mechanism
Manual maintenance only. New projects silently miss critical governance sections.

## Minimum Viable Fix Set for Cycle 2

| Fix | Addresses | Effort |
|-----|-----------|--------|
| 1. Inception commit gate (block builds before `fw inception decide`) | O-003, O-005 | medium |
| 2. First-session detection in context init + resume quick | O-001, O-004 | quick |
| 3. Template sync + behavioral rules (numbered choices, start web app) | O-002, O-006, O-009 | quick (done) |
| 4. Technical Constraints section in inception template | O-010 | quick |
| 5. `fw audit` template drift warning | O-009 prevention | medium |

**Deferred:** O-007 (port discovery — large, new feature), O-008 (circuit breaker — large, inception gate covers most cases)
