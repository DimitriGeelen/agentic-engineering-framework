---
id: T-1100
name: "Inception: reconcile FIVE isolation patterns (widened from 2 after /opt/termlink T-909 evidence) (G-031)"
description: >
  Inception task — pick canonical isolation model from FIVE patterns currently in production, or document when to use each, then write migration path. Originally scoped as 2 patterns (vendored dir vs shim) on 2026-04-11 morning; widened to 5 same day after /opt/termlink T-909 transcript revealed `fw vendor` and the symlink mode. The five patterns: (1) vendored plain .agentic-framework/ dir, files in project git, no .git inside (proxmox-ring20-management); (2) `fw vendor` subcommand — explicit copy with size exclusions, ~56MB target; (3) project-detecting shim (ring20-dashboard after fw upgrade); (4) manual cp -r — bloated ~349MB, wrong; (5) symlinked .agentic-framework — current /opt/termlink state, contaminates host install with consumer state. None documented as canonical. Origin: G-031.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1093, T-1094, T-1099, T-1101, T-1102, T-1103]
created: 2026-04-11T12:16:16Z
last_update: 2026-04-11T13:00:00Z
date_finished: null
---

# T-1100: Inception: reconcile FIVE isolation patterns (G-031, widened)

## Problem Statement

The Agentic Engineering Framework has FIVE distinct isolation/vendoring patterns in production simultaneously, with no documentation of which is canonical, when to use each, or how to migrate between them:

1. **Vendored plain directory** — `<project>/.agentic-framework/` with framework files committed into the project's own git history, no `.git` inside. Visible in `/root/proxmox-ring20-management`. Created by an earlier `fw init` before shim migration was added; has not been re-upgraded since.
2. **`fw vendor`** — explicit subcommand at `bin/fw:3359` with help text "Copy framework into project for full isolation". Uses size exclusions (~56MB target per /opt/termlink transcript). Not in CLAUDE.md Quick Reference.
3. **Project-detecting shim** — global `~/.local/bin/fw` replaced by `fw upgrade` step 4c with a shim that detects cwd, routes per project, reads `.framework.yaml` for version pin. Visible in `ring20-dashboard` after `fw upgrade` 2026-04-11.
4. **Manual `cp -r`** — bloated (~349MB per /opt/termlink transcript), wrong, no exclusions. The path the user explicitly warned against.
5. **Symlinked `.agentic-framework`** — current `/opt/termlink` state. Contaminates host install with consumer state. T-909 in /opt/termlink is "Fix .agentic-framework symlink — replace with vendored copy" (i.e., migration from pattern 5 → pattern 2).

**For whom:** Every consumer project that wants framework governance. Currently three known consumers (proxmox-ring20-management, ring20-dashboard, /opt/termlink) — three different patterns.

**Why now:** Two same-day incidents (ring20-dashboard onboarding morning, /opt/termlink T-909 afternoon) revealed that BOTH consumer-project agents AND this evaluator session had wrong mental models. Five patterns means roughly 25 possible migration paths, none documented. Risk is now: every new consumer project picks a random pattern from whichever sibling it samples first.

## Assumptions

A-1: The five patterns are not all equivalent — some are deprecated, some are layered (e.g. `fw vendor` produces a result similar to pattern 1 but with a different mechanism), some are wrong (cp -r). Testable by running `fw vendor` and inspecting the output.

A-2: A canonical recommendation exists or can be defined — not all five need to live forever. Testable by reading `fw vendor` source, `lib/upgrade.sh`, and `lib/init.sh` to understand the framework's own intent.

A-3: The portability concern is real — consumers want to pin a framework version per project so framework upgrades on the host don't change consumer behavior. Testable by checking whether `.framework.yaml` already encodes a version pin and whether the shim respects it.

A-4: Migration paths between patterns are non-trivial and need documentation — not just "delete one, run the other". Testable by attempting a migration on a sandbox and recording the steps.

## Exploration Plan

**Phase 1 — Pattern enumeration with mechanism details**
- For each of the five patterns, document: what it produces on disk, what `.framework.yaml` looks like, how `fw` resolves to framework code, what `fw upgrade` does to it, what breaks
- Read `bin/fw` vendor case (line 3359), `lib/upgrade.sh`, `lib/init.sh`
- Inspect each known consumer (proxmox-ring20-management, ring20-dashboard, /opt/termlink) and confirm which pattern they're on

**Phase 2 — Migration matrix**
- 5 patterns = 20 possible non-trivial migrations
- Identify which migrations actually happen in practice (forward only, or two-way?)
- For each likely migration, sketch the steps and identify what breaks

**Phase 3 — Canonical recommendation**
- Pick one (or two complementary) as canonical
- Justify with: simplicity, isolation strength, version-pinning, portability
- Identify which patterns to deprecate and how

**Phase 4 — Recommendation**
- GO Pattern X (and migration plan for the other four) / GO complementary X+Y / NO-GO (no canonical possible) / DEFER

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
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

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
