---
id: T-495
name: "Path isolation — eliminate hardcoded absolute paths from all committed files"
description: >
  G-021. fw init bakes machine-specific absolute paths into .claude/settings.json (12 hooks), .framework.yaml, and CLAUDE.md. On any clone/move/different machine, ALL enforcement hooks silently fail — task gate, tier 0, budget gate, plan mode block, all of them. fw doctor, fw upgrade, and fw self-test all give false green because they dont validate paths. This is existential: the frameworks entire enforcement layer is a facade on any non-original environment. Spikes: (1) fw hook subcommand for runtime path resolution, (2) .framework.yaml path discovery, (3) fw doctor hook path validation, (4) fw upgrade path repair, (5) cross-machine self-test phase, (6) CLAUDE.md template path elimination.

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [portability, enforcement, P0]
components: []
related_tasks: []
created: 2026-03-14T22:25:26Z
last_update: 2026-03-14T22:25:26Z
date_finished: null
---

# T-495: Path isolation — eliminate hardcoded absolute paths from all committed files

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
