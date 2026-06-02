---
id: T-954
name: "Human AC classification reform — risk-based AC assignment with programmatic, TermLink E2E, and Playwright verification tiers"
description: >
  Inception: Human AC classification reform — risk-based AC assignment with programmatic, TermLink E2E, and Playwright verification tiers

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: [T-823, T-193, T-325, T-358, T-373]
created: 2026-04-06T11:49:04Z
last_update: 2026-04-13T06:23:29Z
date_finished: 2026-04-06T12:11:48Z
---

# T-954: Human AC classification reform — risk-based AC assignment with programmatic, TermLink E2E, and Playwright verification tiers

## Problem Statement

Human ACs are piling up across multiple projects (82 tasks, 12 waiting >14 days). Many of these may not genuinely require human judgment — they were classified as Human ACs by default rather than by risk assessment. The framework currently has no classification system for deciding what needs human verification vs. what can be verified programmatically.

**For whom:** Project owners drowning in AC review queues across multiple consumer projects.
**Why now:** 82 pending Human ACs and growing. T-823 proved that 37% of a 27-task sample could be auto-verified — suggesting the current AC assignment is over-conservative.

**Core tension:** We do NOT want to remove safeguards against destructive activities ruining codebases. But complete risk avoidance is not the goal — smart, reasonable risk-taking is. The question is: where's the line, and how do we classify it?

**Prior art:** T-823 (inception, GO) validated three verification approaches:
- (A) Programmatic evidence (curl, grep, file checks) — best for server-rendered UI, deterministic
- (B) TermLink E2E testing — works for process-level/CLI tests, needs macOS peer for cross-platform
- (C) Playwright browser automation — sandbox issues on root Linux, inferior to curl for server pages

**What T-823 did NOT answer:** Should we change the framework's AC classification rules? When should a new task get Human vs. Agent ACs? What risk model determines this?

## Assumptions

1. Most RUBBER-STAMP ACs can be safely converted to Agent ACs with programmatic verification
2. REVIEW ACs that involve subjective judgment (writing quality, UX, architecture) genuinely need human eyes
3. A risk classification (e.g., blast radius × reversibility) can distinguish the two categories reliably
4. Reducing Human AC volume will increase the rate at which they actually get reviewed (less noise → more signal)

## Exploration Plan

1. **Categorize existing 82 Human ACs** by type (RUBBER-STAMP vs REVIEW vs unlabelled) and by what they actually verify (30 min)
2. **Design risk classification model** — what dimensions determine Human vs Agent AC? Candidates: blast radius, reversibility, subjectivity, external visibility (30 min)
3. **Evaluate three verification tiers** against the classification (30 min):
   - Tier 1: Programmatic (shell commands, curl, grep) — for deterministic, reversible checks
   - Tier 2: TermLink E2E (process-level, cross-terminal) — for integration/CLI verification
   - Tier 3: Playwright (browser automation) — for interactive UI verification
4. **Draft framework rule changes** — proposed updates to AC assignment rules in CLAUDE.md (30 min)
5. **Risk assessment** — what's the worst case if we get classification wrong? What safeguards prevent it? (15 min)

## Technical Constraints

- Playwright has sandbox issues on root Linux — curl-based verification is the proven alternative
- TermLink E2E requires peer availability (macOS on .107 for cross-platform)
- Some ACs genuinely cannot be automated (writing tone, UX feel, architecture decisions)
- The authority model (Human = SOVEREIGNTY) must be preserved — we're reducing noise, not removing oversight

## Scope Fence

**IN:** Risk classification model, AC assignment rules, verification tier mapping, proposed CLAUDE.md changes
**OUT:** Actually re-classifying all 82 existing ACs (that's a build task if GO), building new tooling (separate build tasks)

## Acceptance Criteria

### Agent
- [x] Categorized existing Human ACs by type and what they verify
- [x] Risk classification model designed with clear dimensions
- [x] Verification tier mapping: which tier handles which AC category
- [x] Draft CLAUDE.md rule changes proposed
- [x] Worst-case risk assessment completed
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review classification model and approve go/no-go decision
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-954-human-ac-classification-reform.md`
  2. Evaluate: does the risk classification model match your intuition about what needs human eyes?
  3. Check: are the safeguards against destructive actions sufficient?
  4. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && bin/fw inception decide T-954 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Identify which classification boundaries feel wrong

## Go/No-Go Criteria

**GO if:**
- Risk classification model clearly separates "needs human judgment" from "can be verified programmatically"
- Safeguards prevent destructive actions from being auto-approved
- At least 40% of current Human ACs could be reclassified without increasing risk
- The verification tiers are technically proven (T-823 evidence)

**NO-GO if:**
- Classification model has ambiguous boundaries that could let destructive changes slip through
- The reduction in Human ACs is <20% (not worth the framework complexity)
- Verification approaches produce false positives (auto-pass when things are broken)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: GO — reclassify deterministic RUBBER-STAMPs to Agent ACs, keep sovereignty and subjective reviews as Human

**Date**: 2026-04-06T12:11:48Z

## Recommendation

- **Recommendation:** GO (three phases: rule change → reclassify existing → tooling)
- **Rationale:** 129 unchecked Human ACs analyzed. 51% genuinely need human judgment (inception decisions, subjective reviews). 31% are deterministic tests mislabeled as Human — they should be Agent ACs with verification commands. Converting them increases reliability (machines > humans for pass/fail) while reducing noise. Safety unchanged: Tier 0, inception gate, authority model all independent of AC classification.
- **Evidence:**
  - 129 ACs categorized across 82 tasks
  - 29 CLI-testable RUBBER-STAMP ACs can convert immediately
  - 12 UI ACs can split into functional (Agent) + aesthetic (Human)
  - T-823 proved all three verification tiers work (programmatic, TermLink E2E, Playwright)
  - Structural safeguards (Tier 0, inception gate, audit D2) are orthogonal — unaffected by reclassification

## Decision

**Decision**: GO

**Rationale**: GO — reclassify deterministic RUBBER-STAMPs to Agent ACs, keep sovereignty and subjective reviews as Human

**Date**: 2026-04-06T12:11:48Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-06T11:50:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T12:11:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** GO — reclassify deterministic RUBBER-STAMPs to Agent ACs, keep sovereignty and subjective reviews as Human

### 2026-04-06T12:11:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3e70dfe2
- **Timestamp:** 2026-06-02T15:05:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
