---
id: T-550
name: "Composition-based adapter pattern — evaluate for agent provider and TermLink backend abstraction"
description: >
  OpenClaw uses a composition-with-optional-slots pattern for 17+ channel integrations instead of inheritance. Evaluate whether this pattern applies to: (1) agent provider abstraction (Claude Code, Cursor, Windsurf, Copilot), (2) TermLink backend types (tmux, screen, SSH, containers). Source: T-549 OpenClaw evaluation, P5 channel abstraction finding. Low urgency — no multi-adapter problem exists today.

status: captured
workflow_type: inception
owner: human
horizon: later
tags: []
components: []
related_tasks: [T-549]
created: 2026-03-23T15:49:01Z
last_update: 2026-03-23T15:49:01Z
date_finished: null
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

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
