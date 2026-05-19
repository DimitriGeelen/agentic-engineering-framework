# AGENTS.md — Agentic Engineering Framework

> Standard agent instruction file (AAIF/Linux Foundation convention).
> For Claude Code-specific integration, see `CLAUDE.md`.
> For the full provider-neutral guide, see `FRAMEWORK.md`.

## Identity

- **Name:** Agentic Engineering Framework
- **Purpose:** Governance framework for AI coding agents — enforces task traceability, structural gates, session continuity, and audit trails.
- **Version:** 1.0.0

## Core Principle

**Nothing gets done without a task.** This is enforced structurally, not by agent discipline.

## Rules

1. **Create a task before editing files.** Use `fw work-on "description" --type build` to create and focus.
2. **Every commit references a task.** Format: `T-XXX: description`. Enforced by commit-msg hook.
3. **Never bypass structural gates.** If a gate blocks you, stop and ask the human.
4. **Destructive commands require approval.** Force push, hard reset, `rm -rf`, DROP TABLE → `fw tier0 approve`.
5. **Generate a handover before ending.** Use `fw handover --commit` to preserve session context.

## Authority Model

```
Human     → SOVEREIGNTY  → Can override anything
Framework → AUTHORITY    → Enforces rules, checks gates
Agent     → INITIATIVE   → Can propose, never decides
```

## Quick Commands

| Action | Command |
|--------|---------|
| Start work | `fw work-on "name" --type build` |
| Commit | `fw git commit -m "T-XXX: description"` |
| Run audit | `fw audit` |
| Health check | `fw doctor` |
| End session | `fw handover --commit` |
| Check status | `fw context status` |

## Enforcement Tiers

| Tier | Scope | Bypass |
|------|-------|--------|
| 0 | Destructive commands | Human approval via `fw tier0 approve` |
| 1 | All file modifications | Create a task first |
| 2 | Situational exceptions | Single-use, mandatory logging |
| 3 | Read-only operations | Pre-approved |

## Memory System

The framework maintains three memory layers:
- **Working memory** (`.context/working/`) — Current session state
- **Project memory** (`.context/project/`) — Patterns, decisions, learnings
- **Episodic memory** (`.context/episodic/`) — Completed task histories

## File Structure

```
bin/fw              CLI entry point
agents/             Agent scripts (audit, context, git, handover, healing, task-create)
.tasks/active/      In-progress tasks
.tasks/completed/   Finished tasks
.context/           Memory system
.fabric/            Component topology map
```

## Getting Started

```bash
fw doctor           # Check framework health
fw context init     # Initialize session
fw work-on "Fix the bug" --type build   # Create task + start
# ... do work ...
fw git commit -m "T-XXX: Fix the bug"   # Commit with traceability
fw handover --commit                     # End session
```

## Arc-Scoped Driver Suggestion Workflow (T-1925, arc-006)

When a new arc is created, the primary agent runs this 5-step workflow **after the arc's anchor-task body is filled** but **before any driver is approved**. Goal: surface arc-specific drivers that distinguish the arc from global D1-D4 directives. Approval stays with the human (D8 — sovereignty at policy-edit time).

**Steps (D5 timing):**

1. Read the arc anchor-task body in full. Don't propose drivers from the arc name alone.
2. List 2-3 candidate drivers, each with a one-line rationale stating what the driver distinguishes that D1-D4 do not. If you can't state the distinction in one line, the candidate isn't worth proposing.
3. Write candidates to `proposed_scoped_drivers:` in the arc YAML (each as `{name, rationale, source: agent, ts}`). This is a proposal — `scoped_drivers:` only mutates via `fw arc approve-driver` (T-1926, §ACD-gated).
4. Surface proposals via `fw arc show-suggestions <arc-id>` (D7-reframe — workflow verb the human runs when focus shifts to an arc, not a debug verb). Human approves up to 3 with `fw arc approve-driver` or runs `--none --justification "..."`.
5. Zero approved drivers is a valid outcome. Arcs without scoped drivers rank by global D1-D4 only.

**R5 mitigation — the verbatim rule:**

> Manufacturing drivers to look thorough is worse than proposing zero and recommending --none.

**D6 quality criterion:**

> Rationale must explain what each driver distinguishes that globals don't.

**Caps:**
- `proposed_scoped_drivers:` — uncapped (D7-reframe: persists for reuse).
- `scoped_drivers:` — max **3** entries, each weight **≤6** (M2). Approved only.

**Worked example.** Arc `replay-debug` ("agent replays a failed dispatch from `dispatches.jsonl` and observes the same outcome → confirms determinism") might propose:
- `determinism` (weight 5) — distinguishes from D1 (Antifragility): tests reproducibility, not stress-resilience.
- `replay-fidelity` (weight 4) — distinguishes from D2: not just "no silent failures" but "bit-identical outcome under identical inputs".
- `forensic-detail` (weight 3) — distinguishes from D3 (Usability): for the developer replaying, not the agent working.

Bad candidates (don't do this): `reliability`, `usability`, `correctness` — duplicate global drivers, dilute scoring.

For the complete operating guide, see [FRAMEWORK.md](FRAMEWORK.md).
