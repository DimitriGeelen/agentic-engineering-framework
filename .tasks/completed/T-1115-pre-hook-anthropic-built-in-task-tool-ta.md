---
id: T-1115
name: "Pre-hook Anthropic built-in Task tool (TaskCreate/TaskUpdate) into framework T-XXX governance"
description: >
  Inception: Pre-hook Anthropic built-in Task tool (TaskCreate/TaskUpdate) into framework T-XXX governance

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T22:18:48Z
last_update: 2026-04-12T09:27:16Z
date_finished: 2026-04-11T22:46:46Z
---

# T-1115: Pre-hook Anthropic built-in Task tool (TaskCreate/TaskUpdate) into framework T-XXX governance

## Problem Statement

The Claude Code session UI shows a built-in todo list populated by the
agent via `TaskCreate` / `TaskUpdate` / `TaskList` tool calls. These items
render visually identical to framework `T-XXX` tasks, creating confusion
about whether the agent is running a parallel ungoverned task system.
Human caught it mid-session today (2026-04-12 during T-1114 work) and
asked "are you bypassing framework governance and using your own task
system?". Per human Q7, this is a recurring class, not first-incident.

Full RCA + 7-question dialogue + research findings captured at
`docs/reports/T-1115-anthropic-task-tool-prehook.md`.

## Assumptions

- A1: Claude Code fires PreToolUse hooks on `TaskCreate` / `TaskUpdate` /
  `TaskList` / `TaskGet` (UNVERIFIED — see Exploration Plan spike 1).
  Official docs list PreToolUse-capable tools and Task* are absent.
- A2: PreToolUse hooks cannot rewrite a call for one tool into a call
  for a different tool; only intra-tool `updatedInput` is supported
  (CONFIRMED via research agent spawn).
- A3: Exit-2-with-stderr-redirect is a valid pattern for blocking
  Claude-visible tools and having the model pick up the redirect on
  the next turn (CONFIRMED — `block-plan-mode.sh` proves the pattern
  for `EnterPlanMode` → `/plan`).
- A4: Issue 45427 (human's own RFC) confirms PreToolUse hooks are
  fundamentally insufficient against subagent bypass and model
  self-modification. Even a successful Level-1 hook is a ceiling, not a
  floor. True structural enforcement requires Anthropic's proposed
  `toolGate` layer inside the CLI.

## Exploration Plan

- **Spike 1 — Hook firing verification (BLOCKING must-verify).**
  Write `tests/spikes/taskcreate-hook-probe.sh` that logs stdin + argv
  to `.context/working/.taskcreate-probe.log` and exits 0. Add a
  PreToolUse matcher for `TaskCreate|TaskUpdate|TaskList|TaskGet` in
  `.claude/settings.json` (committed under a spike-only flag). Human
  restarts Claude Code in a fresh session and invokes a harmless
  `TaskList` read. If the log populates, A1 is true and Level 1
  implementation proceeds. If the log is empty, A1 is false and we fall
  back to CLAUDE.md rule + PostToolUse scanner.
  *Time-box:* spike authoring ~30 min; verification by human ~2 min
  after next session restart.

- **Spike 2 — Fallback implementation (non-blocking, parallel).**
  Write the CLAUDE.md §"Claude Code Built-in Task Tool Ban" rule and a
  PostToolUse scanner (`agents/context/audit-claude-todo.sh`) that
  inspects the session transcript for `TaskCreate`/`TaskUpdate` calls
  and emits a warning with count + timestamps. Valuable regardless of
  spike 1 outcome — if hooks fire, it becomes a belt-and-braces
  detector; if they don't, it's the primary enforcement.

- **Dialogue (DONE this session, Segment 1–4 of research artifact).**
  Options L1/L2/L3 presented, 7 questions asked, human answered all 7.
  Rewrite preference collapsed to block-with-redirect because cross-tool
  rewrite is mechanically impossible.

## Technical Constraints

- Claude Code hooks are snapshotted at session start. Mid-session hook
  changes do NOT take effect until restart. Any empirical verification
  of A1 therefore requires a fresh session.
- PreToolUse hook JSON output schema (`hookSpecificOutput.updatedInput`)
  supports intra-tool rewriting but NOT cross-tool redirection.
- Subagent bypass (issue 45427 Failure Mode 1) means that even a
  successful Level-1 hook at the parent session layer does not protect
  against sub-agents invoking the built-in Task tool under their own
  context. Documented as acknowledged upper bound.
- Model self-modification (issue 45427 Failure Mode 3) means the model
  can theoretically weaken its own hook config by editing
  `.claude/settings.json`. This is covered by the existing
  `check-active-task.sh` gate on Write operations, but not perfectly.

## Scope Fence

**IN:** Inception dialogue with human (DONE). Research on hook surface
capabilities (DONE). T-1105 discipline applied to this bug class (DONE).
Two-phase build plan (Phase 1 spike artifacts this session; Phase 2
implementation next session based on spike result). Fallback path if
hooks don't fire.

**OUT:** Actual hook implementation (Phase 2, next session). Changes
to Anthropic's tool definitions (out of boundary). Opinions on whether
Anthropic should expose the hook surface (covered by issue 45427).
Subagent-layer enforcement (requires toolGate per RFC — not ours to
build). Rewriting TaskCreate into a Bash call (mechanically impossible).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Phase-1 spike artifacts land in this session (probe script + fallback
  rule + PostToolUse scanner) without touching live
  `.claude/settings.json`, so the current session is not disturbed.
- Human agrees to run the probe in the next fresh Claude Code session
  and report whether `.context/working/.taskcreate-probe.log` is
  populated (the evidence gate for Phase 2).
- Fallback path (CLAUDE.md rule + PostToolUse scanner) is built in
  parallel so it is ready regardless of spike outcome.
- T-1105 discipline respected: a single chokepoint is identified (the
  hook file, if it fires) and a corresponding invariant test is
  designed (bats test piping fake JSON, asserting exit 2 + redirect
  message).

**NO-GO if:**
- Spike 1 cannot be designed to run against a fresh session without
  introducing cross-session coupling the human is unwilling to accept.
- Fallback path alone is judged sufficient — human prefers to skip the
  hook attempt entirely and rely on CLAUDE.md rule + PostToolUse
  detection only. (Would downgrade T-1115 from GO to DEFER.)
- Issue 45427's Failure Mode 3 (model self-modification) is judged so
  severe that building Level 1 creates false confidence, and the
  preferred response is to escalate upward to Anthropic (via the RFC)
  rather than build local patches.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO (two-phase)

**Rationale:** The recurring Claude-Code-todo-list confusion is a real
governance signal per human Q7. Cross-tool rewrite is mechanically
impossible (research confirmed), so the achievable intervention is
block-with-redirect on exit 2 — modelled on `block-plan-mode.sh`. But
we do not yet know whether PreToolUse fires on `TaskCreate` at all
(docs silent; Task* tools absent from the documented capable-tool
list). Building Level 1 now without verification risks installing a
hook on traffic that never traverses it.

The two-phase plan unblocks progress: write the spike artifact
(`tests/spikes/taskcreate-hook-probe.sh`) and the fallback
(CLAUDE.md rule + PostToolUse scanner) this session, commit both,
then verify empirically in the next fresh session. Phase 2 branches
on the spike result:
- Hooks fire → build Level 1 hook (`block-task-tools.sh`) + bats invariant test
- Hooks don't fire → promote the fallback to primary

**Evidence:**
- Research agent confirmed PreToolUse hook JSON-output contract
  supports intra-tool `updatedInput` but not cross-tool redirection —
  rewrite of `TaskCreate → Bash bin/fw work-on` not supported
- Claude Code docs list PreToolUse-capable tools; Task* tools absent
  → A1 is UNVERIFIED, must spike
- `block-plan-mode.sh` proves the exit-2-with-redirect-message pattern
  for `EnterPlanMode → /plan` — direct template if A1 is true
- Issue 45427 (human's own RFC) documents PreToolUse subagent bypass
  + model self-modification as upper bounds on any hook-based
  enforcement — we acknowledge the ceiling, we do not attempt to build
  past it; that requires Anthropic to ship the proposed `toolGate`
- T-1105 chokepoint+invariant-test discipline formally applicable:
  single chokepoint (hook file), single invariant test (bats pipe-fake-
  JSON assertion), single bug class (Q7-confirmed recurrence)
- Human-answered 7 questions (Q1 L1+reroute, Q2 investigate +ingest
  45427, Q3 both, Q4 block if cannot rewrite, Q5 no mirror, Q6
  elaborated in research artifact §T-1105 Discipline, Q7 recurring)
- Phase 1 + Phase 2 split explicitly approved (A=two-phase, B=finish
  T-1114 first, T-1115 reviewed async)

**Build decomposition (Phase 1 — this session, after T-1114 lands):**
- T-1116a: `tests/spikes/taskcreate-hook-probe.sh` + human-run checklist
- T-1116b: CLAUDE.md §"Claude Code Built-in Task Tool Ban" rule
- T-1116c: `agents/context/audit-claude-todo.sh` PostToolUse scanner
- T-1116d: Dedicated bats test for the PostToolUse scanner

**Build decomposition (Phase 2 — next session, conditional on spike):**
- T-1116e: Level 1 hook `agents/context/block-task-tools.sh` (if A1 true)
- T-1116f: `.claude/settings.json` matcher registration (if A1 true)
- T-1116g: `tests/integration/block-task-tools.bats` invariant test (if A1 true)
- T-1116h: Consume G-XXX (new gap to register for this bug class)

**Scope fence reminder:** No modification to live `.claude/settings.json`
this session — all changes stay in `tests/spikes/` + CLAUDE.md +
`agents/context/`. Fresh-session test drives Phase 2.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO (two-phase)

Rationale: The recurring Claude-Code-todo-list confusion is a real
governance signal per human Q7. Cross-tool rewrite is mechanically
impossible (research confirmed), so the achievable intervention is
block-with-redirect on exit 2 — modelled on `block-plan-mode.sh`. But
we do not yet know whether PreToolUse fires on `TaskCreate` at all
(docs silent; Task* tools absent from the documented capable-tool
list). Building Level 1 now without verification risks installing a
hook on traffic that never traverses it.

The two-phase plan unblocks progress: write the spike artifact
(`tests/spikes/taskcreate-hook-probe.sh`) and the fallback
(CLAUDE.md rule + PostToolUse scanner) this session, commit both,
then verify empirically in the next fresh session. Phase 2 branches
on the spike result:
- Hooks fire → build Level 1 hook (`block-task-tools.sh`) + bats invariant test
- Hooks don't fire → promote the fallback to primary

Evidence:
- Research agent confirmed PreToolUse hook JSON-output contract
  supports intra-tool `updatedInput` but not cross-tool redirection —
  rewrite of `TaskCreate → Bash bin/fw work-on` not supported
- Claude Code docs list PreToolUse-capable tools; Task* tools absent
  → A1 is UNVERIFIED, must spike
- `block-plan-mode.sh` proves the exit-2-with-redirect-message pattern
  for `EnterPlanMode → /plan` — direct template if A1 is true
- Issue 45427 (human's own RFC) documents PreToolUse subagent bypass
  + model self-modification as upper bounds on any hook-based
  enforcement — we acknowledge the ceiling, we do not attempt to build
  past it; that requires Anthropic to ship the proposed `toolGate`
- T-1105 chokepoint+invariant-test discipline formally applicable:
  single chokepoint (hook file), single invariant test (bats pipe-fake-
  JSON assertion), single bug class (Q7-confirmed recurrence)
- Human-answered 7 questions (Q1 L1+reroute, Q2 investigate +ingest
  45427, Q3 both, Q4 block if cannot rewrite, Q5 no mirror, Q6
  elaborated in research artifact §T-1105 Discipline, Q7 recurring)
- Phase 1 + Phase 2 split explicitly approved (A=two-phase, B=finish
  T-1114 first, T-1115 reviewed async)

Build decomposition (Phase 1 — this session, after T-1114 lands):
- T-1116a: `tests/spikes/taskcreate-hook-probe.sh` + human-run checklist
- T-1116b: CLAUDE.md §"Claude Code Built-in Task Tool Ban" rule
- T-1116c: `agents/context/audit-claude-todo.sh` PostToolUse scanner
- T-1116d: Dedicated bats test for the PostToolUse scanner

Build decomposition (Phase 2 — next session, conditional on spike):
- T-1116e: Level 1 hook `agents/context/block-task-tools.sh` (if A1 true)
- T-1116f: `.claude/settings.json` matcher registration (if A1 true)
- T-1116g: `tests/integration/block-task-tools.bats` invariant test (if A1 true)
- T-1116h: Consume G-XXX (new gap to register for this bug class)

Scope fence reminder: No modification to live `.claude/settings.json`
this session — all changes stay in `tests/spikes/` + CLAUDE.md +
`agents/context/`. Fresh-session test drives Phase 2.

**Date**: 2026-04-11T22:46:46Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO (two-phase)

Rationale: The recurring Claude-Code-todo-list confusion is a real
governance signal per human Q7. Cross-tool rewrite is mechanically
impossible (research confirmed), so the achievable intervention is
block-with-redirect on exit 2 — modelled on `block-plan-mode.sh`. But
we do not yet know whether PreToolUse fires on `TaskCreate` at all
(docs silent; Task* tools absent from the documented capable-tool
list). Building Level 1 now without verification risks installing a
hook on traffic that never traverses it.

The two-phase plan unblocks progress: write the spike artifact
(`tests/spikes/taskcreate-hook-probe.sh`) and the fallback
(CLAUDE.md rule + PostToolUse scanner) this session, commit both,
then verify empirically in the next fresh session. Phase 2 branches
on the spike result:
- Hooks fire → build Level 1 hook (`block-task-tools.sh`) + bats invariant test
- Hooks don't fire → promote the fallback to primary

Evidence:
- Research agent confirmed PreToolUse hook JSON-output contract
  supports intra-tool `updatedInput` but not cross-tool redirection —
  rewrite of `TaskCreate → Bash bin/fw work-on` not supported
- Claude Code docs list PreToolUse-capable tools; Task* tools absent
  → A1 is UNVERIFIED, must spike
- `block-plan-mode.sh` proves the exit-2-with-redirect-message pattern
  for `EnterPlanMode → /plan` — direct template if A1 is true
- Issue 45427 (human's own RFC) documents PreToolUse subagent bypass
  + model self-modification as upper bounds on any hook-based
  enforcement — we acknowledge the ceiling, we do not attempt to build
  past it; that requires Anthropic to ship the proposed `toolGate`
- T-1105 chokepoint+invariant-test discipline formally applicable:
  single chokepoint (hook file), single invariant test (bats pipe-fake-
  JSON assertion), single bug class (Q7-confirmed recurrence)
- Human-answered 7 questions (Q1 L1+reroute, Q2 investigate +ingest
  45427, Q3 both, Q4 block if cannot rewrite, Q5 no mirror, Q6
  elaborated in research artifact §T-1105 Discipline, Q7 recurring)
- Phase 1 + Phase 2 split explicitly approved (A=two-phase, B=finish
  T-1114 first, T-1115 reviewed async)

Build decomposition (Phase 1 — this session, after T-1114 lands):
- T-1116a: `tests/spikes/taskcreate-hook-probe.sh` + human-run checklist
- T-1116b: CLAUDE.md §"Claude Code Built-in Task Tool Ban" rule
- T-1116c: `agents/context/audit-claude-todo.sh` PostToolUse scanner
- T-1116d: Dedicated bats test for the PostToolUse scanner

Build decomposition (Phase 2 — next session, conditional on spike):
- T-1116e: Level 1 hook `agents/context/block-task-tools.sh` (if A1 true)
- T-1116f: `.claude/settings.json` matcher registration (if A1 true)
- T-1116g: `tests/integration/block-task-tools.bats` invariant test (if A1 true)
- T-1116h: Consume G-XXX (new gap to register for this bug class)

Scope fence reminder: No modification to live `.claude/settings.json`
this session — all changes stay in `tests/spikes/` + CLAUDE.md +
`agents/context/`. Fresh-session test drives Phase 2.

**Date**: 2026-04-11T22:46:46Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T22:19:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-11T22:46:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (two-phase)

Rationale: The recurring Claude-Code-todo-list confusion is a real
governance signal per human Q7. Cross-tool rewrite is mechanically
impossible (research confirmed), so the achievable intervention is
block-with-redirect on exit 2 — modelled on `block-plan-mode.sh`. But
we do not yet know whether PreToolUse fires on `TaskCreate` at all
(docs silent; Task* tools absent from the documented capable-tool
list). Building Level 1 now without verification risks installing a
hook on traffic that never traverses it.

The two-phase plan unblocks progress: write the spike artifact
(`tests/spikes/taskcreate-hook-probe.sh`) and the fallback
(CLAUDE.md rule + PostToolUse scanner) this session, commit both,
then verify empirically in the next fresh session. Phase 2 branches
on the spike result:
- Hooks fire → build Level 1 hook (`block-task-tools.sh`) + bats invariant test
- Hooks don't fire → promote the fallback to primary

Evidence:
- Research agent confirmed PreToolUse hook JSON-output contract
  supports intra-tool `updatedInput` but not cross-tool redirection —
  rewrite of `TaskCreate → Bash bin/fw work-on` not supported
- Claude Code docs list PreToolUse-capable tools; Task* tools absent
  → A1 is UNVERIFIED, must spike
- `block-plan-mode.sh` proves the exit-2-with-redirect-message pattern
  for `EnterPlanMode → /plan` — direct template if A1 is true
- Issue 45427 (human's own RFC) documents PreToolUse subagent bypass
  + model self-modification as upper bounds on any hook-based
  enforcement — we acknowledge the ceiling, we do not attempt to build
  past it; that requires Anthropic to ship the proposed `toolGate`
- T-1105 chokepoint+invariant-test discipline formally applicable:
  single chokepoint (hook file), single invariant test (bats pipe-fake-
  JSON assertion), single bug class (Q7-confirmed recurrence)
- Human-answered 7 questions (Q1 L1+reroute, Q2 investigate +ingest
  45427, Q3 both, Q4 block if cannot rewrite, Q5 no mirror, Q6
  elaborated in research artifact §T-1105 Discipline, Q7 recurring)
- Phase 1 + Phase 2 split explicitly approved (A=two-phase, B=finish
  T-1114 first, T-1115 reviewed async)

Build decomposition (Phase 1 — this session, after T-1114 lands):
- T-1116a: `tests/spikes/taskcreate-hook-probe.sh` + human-run checklist
- T-1116b: CLAUDE.md §"Claude Code Built-in Task Tool Ban" rule
- T-1116c: `agents/context/audit-claude-todo.sh` PostToolUse scanner
- T-1116d: Dedicated bats test for the PostToolUse scanner

Build decomposition (Phase 2 — next session, conditional on spike):
- T-1116e: Level 1 hook `agents/context/block-task-tools.sh` (if A1 true)
- T-1116f: `.claude/settings.json` matcher registration (if A1 true)
- T-1116g: `tests/integration/block-task-tools.bats` invariant test (if A1 true)
- T-1116h: Consume G-XXX (new gap to register for this bug class)

Scope fence reminder: No modification to live `.claude/settings.json`
this session — all changes stay in `tests/spikes/` + CLAUDE.md +
`agents/context/`. Fresh-session test drives Phase 2.

### 2026-04-11T22:46:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next
