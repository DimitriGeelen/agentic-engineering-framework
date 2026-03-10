---
id: T-411
name: "Refactoring audit: directive-scored review of codebase"
description: >
  Inception: Systematic codebase refactoring audit — 5 parallel agents explore
  Python, JS, shell, HTML, and architecture layers for refactoring opportunities.
  Findings scored against four constitutional directives. Produces phased
  refactoring plan with prioritized build tasks.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [refactoring, quality, audit, governance]
components: [web/blueprints/discovery.py, web/static/js/chat.js, agents/task-create/update-task.sh, web/templates/base.html]
related_tasks: [T-404, T-406, T-409, T-412, T-413, T-414, T-415, T-416, T-417, T-418, T-419, T-420, T-421, T-422, T-423, T-424, T-425, T-426, T-427, T-428, T-429, T-430, T-431, T-432]
created: 2026-03-10T20:54:13Z
last_update: 2026-03-10T22:47:30Z
date_finished: null
---

# T-411: Refactoring audit: directive-scored review of codebase

## Problem Statement

After rapid feature development (T-379 through T-410 — settings, search, docs, chat, health indicators),
the codebase has accumulated structural debt across all layers. Human requested a systematic review
to identify refactoring opportunities. The question is not "should we refactor?" but "which refactorings
deliver the most value per constitutional directive?"

Evidence of accumulated debt:
- Shell: 25+ files duplicate path resolution logic (exposed by T-406 shared-tooling fix)
- Python: 6+ identical YAML try/except blocks despite shared load_yaml() existing (T-404 added it but adoption is partial)
- JS: chat.js and search-qa.js duplicate 70% of streaming logic (both written in rapid succession T-388/T-409)
- HTML: 218 inline style attributes across 30+ templates (accumulated across T-379–T-400 UI work)
- Architecture: gaps.yaml fallback still in code despite T-397 migration to concerns.yaml

Research artifact: `docs/reports/T-411-refactoring-directive-scoring.md`

## Assumptions

- A1: Refactoring effort is justified — the debt is causing real friction, not just cosmetic
- A2: The four directives provide a useful scoring lens for prioritization
- A3: Phased execution (quick wins → core → modernization → polish) is safer than a big-bang refactor
- A4: 15 "DO" findings at ~55h total can be decomposed into independent build tasks

## Exploration Plan

| # | Spike | Time-box | Deliverable | Status |
|---|-------|----------|-------------|--------|
| 1 | Dispatch 5 parallel Explore agents (one per layer) | 30min | 5 agent reports in /tmp/ | DONE |
| 2 | Consolidate findings and cross-cutting themes | 15min | Summary table | DONE |
| 3 | Score all 64 findings against 4 directives | 30min | Directive scoring matrix | DONE |
| 4 | Present to human for Go/No-Go | 10min | Decision on phases | PENDING |

## Technical Constraints

- Refactoring must not break existing functionality (all verification gates must pass)
- Shell lib extraction must support both standalone and shared-tooling modes (PROJECT_ROOT pattern)
- JS changes must work without build tools (no bundler — vanilla JS with ES5 compat)
- Template changes must maintain htmx/Pico CSS patterns
- Each refactoring task must be independently committable (no cross-task dependencies unless explicit)

## Scope Fence

**IN scope:** Scoring existing findings, creating build tasks for approved phases, documenting decisions
**OUT of scope:** Executing refactoring work (that's the build tasks), adding new features, performance optimization beyond what refactoring naturally provides

## Acceptance Criteria

### Agent
- [x] Problem statement validated with evidence from 5 agent reports
- [x] 64 findings scored against all 4 directives (D1–D4)
- [x] DO/MAYBE/SKIP verdicts assigned with rationale
- [x] Phased refactoring plan proposed with effort estimates
- [x] Research artifact written to docs/reports/
- [x] Go/No-Go decision recorded
- [x] Build tasks created for approved phases (with research references)

### Human
- [ ] [REVIEW] Review directive scoring and phase plan
  **Steps:**
  1. Read `docs/reports/T-411-refactoring-directive-scoring.md`
  2. Review the 15 "DO" findings and 5-phase plan
  3. Decide: approve all phases, approve subset, or reject
  **Expected:** Clear direction on which phases to execute
  **If not:** Discuss specific findings or scoring disagreements

## Go/No-Go Criteria

**GO if:**
- Human approves at least Phase 1 (quick wins, 8h)
- Findings align with observed friction from recent development
- Effort estimates are reasonable for the expected value

**NO-GO if:**
- Scoring reveals refactoring is cosmetic (no D1/D2 impact) — refuted: D2 avg 1.9 across all layers
- Effort exceeds value (>100h for marginal improvement) — refuted: 55h for 15 high-scoring findings
- Current feature velocity is more important than structural quality

## Verification

test -f docs/reports/T-411-refactoring-directive-scoring.md
grep -q "CONSOLIDATED" docs/reports/T-411-refactoring-directive-scoring.md
grep -q "Dialogue Log" docs/reports/T-411-refactoring-directive-scoring.md

## Decisions

### 2026-03-10 — Phase approval and task creation strategy
- **Chose:** Three-tier task creation — DO as now, MAYBE as next, SKIP in later inception
- **Why:** Human directed all tiers get tasks. Preserves all findings while focusing effort on highest directive-scoring work first. Each tier gets appropriate horizon for scheduling.
- **Rejected:** Single-phase (too much WIP), DO-only (loses MAYBE findings), big-bang refactor (too risky)

**Decision**: GO

**Rationale**: Human approved all three tiers: DO findings as horizon:now build tasks, MAYBE as horizon:next, SKIP in horizon:later inception for re-evaluation. 64 findings, 5 layers, 4 directives. D2 Reliability dominates.

**Date**: 2026-03-10T21:01:34Z

## Updates

### 2026-03-10T20:54:13Z — task-created [task-create-agent]
- **Action:** Created inception task for refactoring audit
- **Context:** Human requested systematic review after rapid T-379–T-410 feature development

### 2026-03-10T20:55:00Z — spike-1-complete [agent]
- **Action:** Dispatched 5 parallel Explore agents (Python, JS, shell, HTML, architecture)
- **Output:** 64 total findings across all layers (13+12+14+14+11)
- **Context:** Each agent wrote to /tmp/fw-agent-refactor-{layer}.md

### 2026-03-10T21:05:00Z — spike-2-3-complete [agent]
- **Action:** Consolidated findings, scored all 64 against four directives
- **Output:** `docs/reports/T-411-refactoring-directive-scoring.md`
- **Context:** 15 DO (≥7), 22 MAYBE (5-6), 27 SKIP (≤4). D2 Reliability dominates.

### 2026-03-10T21:20:00Z — go-decision-and-task-creation [agent]
- **Action:** Recorded GO decision, created 21 build tasks from findings
- **Output:** T-412 through T-432 (11 DO horizon:now, 9 MAYBE horizon:next, 1 SKIP inception horizon:later)
- **Context:** Human approved three-tier approach. All tasks reference research artifact. Governance verified (15/15 checks pass).

### 2026-03-10T21:01:26Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Human approved all three tiers: DO findings as horizon:now build tasks, MAYBE findings as horizon:next build tasks, SKIP findings captured in horizon:later inception for re-evaluation. 64 findings across 5 layers, scored against 4 directives. D2 Reliability dominates.

### 2026-03-10T21:01:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Human approved all three tiers: DO findings as horizon:now, MAYBE as horizon:next, SKIP in horizon:later inception. 64 findings, 5 layers, 4 directives. D2 Reliability dominates.

### 2026-03-10T22:46:37Z — status-update [task-update-agent]
- **Change:** horizon: now → now
