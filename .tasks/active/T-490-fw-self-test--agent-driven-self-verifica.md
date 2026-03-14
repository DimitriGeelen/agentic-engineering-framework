---
id: T-490
name: "fw self-test — agent-driven self-verification with terminal spawning, failure capture, and fix-retest loop"
description: >
  Inception: fw self-test — agent-driven self-verification with terminal spawning, failure capture, and fix-retest loop

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-14T16:54:16Z
last_update: 2026-03-14T16:54:16Z
date_finished: null
---

# T-490: fw self-test — agent-driven self-verification with terminal spawning, failure capture, and fix-retest loop

## Problem Statement

The framework agent cannot test its own functionality. When a change breaks `fw init`, `fw serve`, or an enforcement gate, the only way to discover this is for the human to open another terminal, run the commands manually, and paste the output back. This is slow, error-prone, and defeats the purpose of an autonomous engineering framework.

The agent needs to: (1) spawn a clean environment, (2) run its own commands against it, (3) see what happens (the terminal streaming question), (4) diagnose failures, (5) fix them, (6) re-test — all within a single session.

This is the difference between "framework that humans test" and "framework that tests itself."

### The streaming question

When the agent runs `fw serve` in the background, how does it see what's happening? Currently Claude Code's `run_in_background` is fire-and-forget. The agent can't watch a terminal. Three possible approaches:
- **Polling:** Start process → wait → poll health endpoint → tail log file. Simple, sufficient for most cases.
- **Log streaming:** Add a `/logs/live` SSE endpoint to Watchtower that the agent can curl with `--no-buffer`.
- **Named pipe:** Process writes to both file and pipe; agent reads pipe. Most complex, most real-time.

### Prior art in this framework

- `web/smoke_test.py` already uses Flask test client (no server needed) — proves in-process testing works
- `fw doctor` already checks health endpoint — proves polling works
- `agents/onboarding-test/test-onboarding.sh` — proves post-init validation pattern exists
- `bin/watchtower.sh` already polls `/health` after starting Flask — proves the startup-poll pattern

## Assumptions

- A1: Claude Code's Bash `run_in_background` can start `fw serve` and the agent can poll health endpoints in subsequent tool calls
- A2: Polling + log tailing is sufficient for the feedback loop (real-time streaming is nice-to-have, not required)
- A3: Enforcement gates (Tier 0, task gate) can be tested programmatically by attempting blocked operations and checking exit codes
- A4: A self-test run can complete in <15 minutes (fits in a session without context explosion)
- A5: Test failures can be classified automatically (framework bug vs. environmental vs. transient)

## Exploration Plan

### Spike 1: Claude Code terminal capabilities (45min)
Empirically test what Claude Code can and cannot do with background processes. Can it start `fw serve`, poll health, tail logs, kill the process? What's the latency? What fails? Actually try it.

### Spike 2: Gate testability audit (30min)
Map every enforcement gate (Tier 0, task gate, budget gate, AC gate, verification gate, build readiness gate). For each: can it be tested by running a command and checking exit code? What test fixtures are needed?

### Spike 3: Self-test architecture design (45min)
Design `fw self-test` command. Define phases, output format, failure classification, CI integration. Produce a concrete file structure and pseudocode.

## Technical Constraints

- Must work within Claude Code's Bash tool (no pseudo-TTY, no tmux, no interactive commands)
- `run_in_background` processes have no live output streaming — must use file/endpoint polling
- Background process cleanup must be reliable (kill on exit, timeout protection)
- Must not interfere with the agent's current project (use temp directory or separate port)
- Test must produce machine-readable output (JSON) for CI/CD and agent consumption
- Context budget: self-test invocation + result parsing must fit in <50K tokens

## Scope Fence

**IN:** `fw self-test` command design. Terminal capability testing. Gate testability audit. Failure classification model. CI/CD integration design.
**OUT:** Building the full self-test (separate build tasks post-GO). MCP server. Multi-agent testing. Deployment testing. Performance benchmarks.

## Acceptance Criteria

- [ ] Claude Code terminal capabilities empirically tested (what works, what doesn't)
- [ ] Every enforcement gate assessed for programmatic testability
- [ ] `fw self-test` architecture designed with phases, output format, failure classification
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Claude Code can start a background process and poll its health endpoint (A1 validated)
- At least 4 of 6 enforcement gates are testable via exit codes (A3 validated)
- The full test can complete in <15 minutes with <50K tokens context cost

**NO-GO if:**
- Claude Code cannot reliably manage background processes (kill, poll, detect failure)
- Gate testing requires interactive terminal input (no programmatic path)
- Self-test would consume >100K tokens per run (context budget incompatible)

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
