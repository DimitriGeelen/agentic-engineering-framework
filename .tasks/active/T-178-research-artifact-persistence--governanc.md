---
id: T-178
name: "Research artifact persistence — governance and enforcement"
description: >
  Systemic gap: agent research outputs (e.g., T-174's 3-agent investigation) exist only in conversation context and vanish at session end. Episodic memory captures task metadata but NOT investigation substance. No structural enforcement ensures research is captured — it's agent discipline only (violates P-012). PRIOR ART: L-026 established docs/reports/ as the location with YAML frontmatter. L-027 identified the pattern of capturing thinking-out-loud sessions. Existing examples: docs/reports/2026-02-17-agent-communication-bus-research.md, T-174-compaction-vs-handover.md. The LOCATION question is answered (docs/reports/). The remaining questions are ENFORCEMENT: (1) How to structurally enforce capture? (Gate on inception completion? Hook on sub-agent dispatch? Audit check?) (2) How to inject into future sessions? (Watchtower scan? fw resume? Handover references?) (3) How to prevent bloat? (Age out? Summarize?) (4) Should episodic.yaml reference the research doc? (Yes — see T-174 as pattern)

status: captured
workflow_type: inception
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T19:27:31Z
last_update: 2026-02-18T19:27:31Z
date_finished: null
---

# T-178: Research artifact persistence — governance and enforcement

## Problem Statement

Sub-agent dispatch protocol (CLAUDE.md) says content generators "MUST write output to disk" and investigators should use `fw bus post`. Reality: fw bus has NEVER been used (empty results/blobs dirs). T-174's 3 agents all returned full results to orchestrator context — would have been lost without manual save to docs/reports/. The protocol exists but has zero enforcement. Additionally, `fw resume status` doesn't scan docs/reports/ or .context/bus/, so even persisted research isn't surfaced on recovery.

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
