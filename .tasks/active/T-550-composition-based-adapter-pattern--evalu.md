---
id: T-550
name: "Composition-based adapter pattern — evaluate for agent provider and TermLink
  backend abstraction"
description: >
  OpenClaw uses a composition-with-optional-slots pattern for 17+ channel integrations
  instead of inheritance. Evaluate whether this pattern applies to: (1) agent provider
  abstraction (Claude Code, Cursor, Windsurf, Copilot), (2) TermLink backend types
  (tmux, screen, SSH, containers). Source: T-549 OpenClaw evaluation, P5 channel abstraction
  finding. Low urgency — no multi-adapter problem exists today.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: [T-549]
created: 2026-03-23T15:49:01Z
last_update: '2026-05-19T18:27:46Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-550: Composition-based adapter pattern — evaluate for agent provider and TermLink backend abstraction

## Problem Statement

OpenClaw uses a composition-with-optional-slots pattern for 17+ messaging channel integrations. Each channel plugin is a bag of capabilities (17 optional adapter slots like `sendMessage`, `onReaction`, `editMessage`) rather than a subclass. Three-phase loading (setup-only → config-loaded → full runtime) and multi-account support (`listAccountIds` + `resolveAccount`).

Evaluate whether this pattern applies to our abstraction needs: (1) agent provider abstraction (Claude Code, Cursor, Windsurf, Copilot — each supports different capabilities), (2) TermLink backend types (tmux, screen, SSH, containers — each with different primitives).

No multi-adapter problem exists today. This is a "when/if" exploration.

## OpenClaw Source References

- **Evaluation project:** `/opt/openclaw-evaluation/` on 192.168.10.107
- **OpenClaw repo:** https://github.com/openclaw/openclaw
- **Key source files:**
  - `src/plugin-sdk/channel-contract.ts` — adapter composition shape (17 slots)
  - `src/plugin-sdk/channel-*.ts` — ~25 files, ~400 LOC core
  - `extensions/discord/index.ts` — example channel plugin implementation
  - `extensions/telegram/index.ts` — example channel plugin
  - `extensions/whatsapp/index.ts` — example channel plugin

## Research Documentation (in this project)

- `docs/reports/T-549-openclaw-architecture-mapping.md` — full architecture analysis
- `docs/reports/T-549-openclaw-design-patterns.md` — pattern inventory (channel abstraction = Pattern A)
- `docs/reports/T-549-openclaw-component-quality.md` — quality assessment (channel: A grade)
- `docs/reports/T-549-openclaw-value-extraction.md` — extraction roadmap (P5 = this pattern)
- `docs/reports/T-549-openclaw-framework-learnings.md` — framework improvement items
- `docs/reports/T-549-openclaw-termlink-learnings.md` — TermLink gaps

## Assumptions

- A1: Composition pattern applies to agent providers (NOT VALIDATED — no second provider to test with)
- A2: TermLink backend abstraction needs framework-level adapter (INVALID — TermLink handles this internally)
- A3: Multi-adapter problem exists or is imminent (INVALID — zero demand, single provider)
- A4: OpenClaw's pattern is transferable (PARTIALLY VALID — pattern is sound, problem space doesn't justify it)

## Exploration Plan

1. Audit current abstraction surfaces (done — agent provider deeply coupled, TermLink backend-agnostic)
2. Evaluate composition pattern applicability (done — would help for agent providers but no demand)
3. Check TermLink backend needs (done — TermLink handles backend abstraction internally)
4. Make recommendation (done — DEFER)

## Technical Constraints

- Hook system relies on Claude Code's exact JSON format (tool_name, tool_input)
- Abstracting hook input would require rewriting the hook pipeline
- No second agent provider available for testing
- TermLink backend abstraction is Rust-level, not framework-level

## Scope Fence

**IN:** Whether composition-based adapters apply to our abstraction needs.
**OUT:** Building adapters (separate build tasks). TermLink Rust changes. Actual multi-provider support.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (4 assumptions — 1 not validated, 2 invalid, 1 partial)
- [x] Go/No-Go recommendation made (DEFER)

### Human
- [ ] [REVIEW] Review findings and confirm defer decision
  **Steps:**
  1. Read `docs/reports/T-550-composition-adapter-pattern.md`
  2. Consider: is multi-provider support needed before launch?
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-550 no-go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Discuss specific concerns

## Go/No-Go Criteria

**GO if:**
- A real second agent provider is being targeted
- Agent tooling converges on a common hook API
- Users request multi-provider support

**NO-GO/DEFER if:**
- No multi-adapter problem exists (true)
- Building abstraction for one consumer is premature (true)
- TermLink handles its own backend abstraction (true)

## Recommendation

**Recommendation:** DEFER — parked until multi-adapter need materialises.

**Rationale:** This is a "when/if" exploration. Today the framework has exactly ONE agent provider (Claude Code) and TermLink handles its own backend abstraction internally. Introducing a composition-based adapter pattern speculatively would add architectural overhead for a problem that doesn't yet exist. Re-evaluate when a second agent provider (Cursor, Windsurf, Copilot) actually needs to be integrated.

**Evidence:**
- Research artifact: `docs/reports/T-550-composition-adapter-pattern.md`
- No current multi-adapter problem (single provider = no abstraction pressure)
- TermLink owns its backend diversity (framework just calls `termlink`)
- Building abstraction for one consumer is premature (true)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER — parked until multi-adapter need materialises.

Rationale: This is a "when/if" exploration. Today the framework has exactly ONE agent provider (Claude Code) and TermLink handles its own backend abstraction internally. Introducing a composition-based adapter pattern speculatively would add architectural overhead for a problem that doesn't yet exist. Re-evaluate when a second agent provider (Cursor, Windsurf, Copilot) actually needs to be integrated.

Evidence:
- Research artifact: `docs/reports/T-550-composition-adapter-pattern.md`
- No current multi-adapter problem (single provider = no abstraction pressure)
- TermLink owns its backend diversity (framework just calls `termlink`)
- Building abstraction for one consumer is premature (true)

**Date**: 2026-04-24T09:24:52Z

## Updates

### 2026-03-28 — inception-research [agent]
- **Research artifact:** docs/reports/T-550-composition-adapter-pattern.md
- **Recommendation:** DEFER — no multi-adapter problem exists, single provider, TermLink handles own backends

### 2026-03-28T10:37:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T16:46:49Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-24T09:24:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER — parked until multi-adapter need materialises.

Rationale: This is a "when/if" exploration. Today the framework has exactly ONE agent provider (Claude Code) and TermLink handles its own backend abstraction internally. Introducing a composition-based adapter pattern speculatively would add architectural overhead for a problem that doesn't yet exist. Re-evaluate when a second agent provider (Cursor, Windsurf, Copilot) actually needs to be integrated.

Evidence:
- Research artifact: `docs/reports/T-550-composition-adapter-pattern.md`
- No current multi-adapter problem (single provider = no abstraction pressure)
- TermLink owns its backend diversity (framework just calls `termlink`)
- Building abstraction for one consumer is premature (true)

### 2026-04-28T16:09:25Z — status-update [task-update-agent]
- **Change:** horizon: next → next
