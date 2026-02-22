---
id: T-200
name: "Discovery layer design — pattern detection, omission finding, insight surfacing (T-194 Phase 4)"
description: >
  Inception: Discovery layer design — pattern detection, omission finding, insight surfacing (T-194 Phase 4)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [discovery, assurance, antifragility, temporal-analysis]
related_tasks: [T-194]
components: [docs/reports/T-200-discovery-layer-design.md]
created: 2026-02-19T19:29:30Z
last_update: 2026-02-21T23:20:57Z
date_finished: null
---

# T-200: Discovery layer design — pattern detection, omission finding, insight surfacing (T-194 Phase 4)

## Problem Statement

The framework has three assurance layers designed in T-194. Layers 1-2 (hooks + OE tests) answer "are controls working?" Layer 3 (discovery) should answer "what are we missing?" — finding patterns, omissions, and insights that no single check can see by analyzing data across time. This is the antifragility layer: the system getting smarter from its own history.

**For whom:** Human operator — discoveries surface things that need attention but aren't violations.

**Why now:** T-194 GO decision deferred Phase 4 to this inception. OE test infrastructure exists. 234 cron audits, 235 episodics, 230 completed tasks, and 550+ commits provide a substantial data corpus for temporal analysis.

## Assumptions

- A-022: Temporal analysis across audit history reveals actionable patterns not visible in point-in-time checks
- A-023: Discovery jobs can run as cron (same infrastructure as OE tests) without excessive compute
- A-024: A small number of high-value discoveries (5-8) provides more value than many low-signal ones
- A-025: The human will act on surfaced discoveries if presented well (not alert fatigue)
- A-026: Existing data sources (audits, episodics, git, tasks) are sufficient — no new data collection needed

## Exploration Plan

### Phase 1: Discovery Capability Inventory (with human)
- **1a.** Catalog candidate discoveries from T-194 genesis + new ideas from data review
- **1b.** Classify each: omission detection vs insight generation vs trend analysis
- **1c.** Score each: value (1-5) x feasibility (1-5)
- **1d.** Human dialogue: prioritize, cut low-value, validate scoring

### Phase 2: Surfacing Model Design (with human)
- **2a.** Design how discoveries reach the human: cron output, session-start summary, Watchtower page, or combination
- **2b.** Define "actionable finding" format: what context does the human need to act?
- **2c.** Design false-positive mitigation: thresholds, suppression, acknowledgment
- **2d.** Human dialogue: validate surfacing model, discuss frequency

### Phase 3: Technical Spike
- **3a.** Prototype 2-3 highest-priority discoveries against real data
- **3b.** Measure: accuracy, false positive rate, runtime
- **3c.** Validate output format with human

### Phase 4: Decision
- **4a.** Synthesize findings into architecture proposal
- **4b.** Map build tasks
- **4c.** Go/No-Go with evidence

## Technical Constraints

- File-based only (D4 Portability) — no databases, no external services
- Must run as cron jobs (bash + standard tools) — same infrastructure as OE tests
- Must work when no Claude session is active
- Runtime per discovery job: target <5s (cron runs every 15-30 min)
- Output must be machine-readable (YAML) for Watchtower consumption
- Must not create alert fatigue — quality over quantity

## Scope Fence

**IN scope:**
- Discovery capability design and prioritization
- Surfacing model (how findings reach the human)
- False-positive mitigation strategy
- Technical spikes on top 2-3 discoveries
- Build task mapping

**OUT of scope:**
- Full implementation of all discoveries (build tasks come after GO)
- AI/ML-based pattern detection (keep it bash/python, no models)
- Cross-project analysis (AEF only for now)
- Real-time streaming alerts (batch/cron only)

## Acceptance Criteria

- [x] Discovery capabilities cataloged and prioritized (>= 5 candidates scored)
- [x] Surfacing model designed (how findings reach human)
- [x] False-positive mitigation strategy defined
- [x] Technical spike on 2-3 top discoveries validates feasibility
- [x] All research persisted in docs/reports/T-200-*
- [x] Go/No-Go decision made with rationale

## Go/No-Go Criteria

**GO if:**
- At least 3 high-value discoveries are feasible with existing data and infrastructure
- Surfacing model avoids alert fatigue (findings are actionable, not noisy)
- Technical spikes demonstrate <5s runtime and <20% false positive rate
- Build effort estimated at 1-2 sessions for initial set

**NO-GO if:**
- Discoveries are mostly redundant with existing audit checks
- Data is insufficient for meaningful temporal analysis
- Runtime exceeds acceptable cron budgets
- False positive rate makes findings untrustworthy

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 12 discovery capabilities cataloged and scored against real data. Top 5 score 20-25. 58% episodic decay rate validates D1 immediately. 10 temporal infrastructure gaps identified — zero temporal intelligence exists despite 234 cron audits. Gap-to-discovery mapping complete. Build tasks for top discoveries.

**Date**: 2026-02-21T23:37:37Z
## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-19T19:29:38Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → later

### 2026-02-20T08:42:13Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-02-21T23:20:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-21T23:37:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 12 discovery capabilities cataloged and scored against real data. Top 5 score 20-25. 58% episodic decay rate validates D1 immediately. 10 temporal infrastructure gaps identified — zero temporal intelligence exists despite 234 cron audits. Gap-to-discovery mapping complete. Build tasks for top discoveries.
