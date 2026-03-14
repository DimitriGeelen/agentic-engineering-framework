---
id: T-477
name: "Risk-based governance declaration layer — machine-readable predictability×blast-radius matrix that runtime maps to enforcement levels"
description: >
  Inception: Risk-based governance declaration layer — machine-readable predictability×blast-radius matrix that runtime maps to enforcement levels

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [governance, enforcement, architecture]
components: []
related_tasks: [T-061, T-139, T-193]
created: 2026-03-14T11:20:55Z
last_update: 2026-03-14T11:20:55Z
date_finished: null
---

# T-477: Risk-based governance declaration layer — machine-readable predictability×blast-radius matrix that runtime maps to enforcement levels

## Problem Statement

The initiative/authority distinction only works if someone specifies in advance which operations require authority and which the agent can take freely. Part of that specification already exists in the risk register — but the risk register currently lacks proper impact assessment. That's the gap.

### What exists

The risk register captures threat and likelihood. The Tier 0 patterns capture a specific class of dangerous commands. The task gate enforces accountability at the work level. These work because they reduce to simple predicates with known inputs and binary outcomes.

Concretely, the framework's enforcement surface breaks into two categories:

**Machine-readable (structurally enforced):**
- Tier 0 patterns (`check-tier0.sh`) — regex on destructive commands like force push, rm -rf, DROP TABLE
- Task gate (`check-active-task.sh`) — binary: active task file exists in `.tasks/active/` or it doesn't
- Tool hooks (`settings.json`) — which tools trigger which gate checks, wired at session start
- AC verification — pass/fail on shell commands in the Verification section

**Prose (LLM-interpreted only):**
- Autonomous mode boundaries — what the agent may do when told "proceed as you see fit"
- Human task closure rules — when the agent may suggest closing, what evidence is required
- Authority per action class — which operations need human approval vs. agent initiative
- Quality standards — what counts as "done" for stochastic outputs like content or architecture

What's missing is a systematic assessment of impact — not just "is this dangerous" but "what is the actual consequence if this goes wrong, and how certain is that consequence."

### The missing axis

Risk without impact assessment is incomplete. The current model asks: how dangerous is this operation? The missing question is: how predictable is the outcome, and what is the blast radius?

Deterministic operations have knowable outputs. Running tests, committing a file, creating a directory — you can assess risk in advance because you know what will happen. Pattern-matching works here — Tier 0 handles this well.

Stochastic operations involve agent judgment. Writing a README, choosing between implementation approaches, deciding a task is complete — the output varies, quality is only assessable after the fact, and the blast radius depends on what the agent decided. You cannot pre-authorize these with a gate check.

Crossing both dimensions gives four cells:

- **Low impact, deterministic** — full initiative. `mkdir`, `git add`, run tests. Outcome known, blast radius small. No governance needed beyond audit trail.
- **Low impact, stochastic** — initiative plus audit trail. Choose next task, write a commit message. Outcome varies but stakes are low. Log the decision, move on.
- **High impact, deterministic** — pre-auth gate. `git push --force`, `rm -rf`, DROP TABLE. Outcome known, just dangerous. This is Tier 0 today — pattern-match the command, block or allow. Works well.
- **High impact, stochastic** — authority required, every time. Architectural decisions, closing human tasks, public-facing content, selecting between implementation approaches. Agent judgment meets real consequences. This cell currently has no structural enforcement.

### Prose as stochastic enforcement

The stochastic element isn't just the operation — it's the enforcement mechanism itself. Prose IS stochastic enforcement. The LLM interprets CLAUDE.md differently depending on context pressure, compaction state, attention budget, and model version. The same paragraph may produce consistent behavior for weeks, then fail silently when context is tight.

This is why Tier 0 works and prose boundaries don't. Deterministic plus high impact reduces cleanly to pattern matching — same input, same enforcement decision, every time. Stochastic plus high impact cannot be reduced to regex — it requires a human in the loop, and the system needs to know that structurally, not from a paragraph in a markdown file.

The framework's most consequential governance rules currently depend on its least reliable enforcement mechanism.

### The path forward

The risk register needs an impact dimension: predictability of outcome crossed with blast radius. Not a permission spreadsheet — a declaration format where those two inputs drive enforcement level. The runtime derives the gate from the risk profile; the human maintains the profile, not a list of every possible operation.

The work is extending what's already there. The risk thinking exists. Impact assessment is the missing half.

## Assumptions

- A1: The enforcement-mechanism axis (deterministic vs. stochastic/prose) captures the governance-relevant risk better than impact-only tiers
- A2: Operation classes can be meaningfully categorized without enumerating every possible action (dimension classification, not action enumeration)
- A3: The declaration format can be kept small enough that humans actually maintain it (not a permission spreadsheet)
- A4: Existing enforcement mechanisms (PreToolUse hooks, settings.json) can consume a declaration file without major refactoring
- A5: LLM agents can read a risk classification and adjust behavior — the declaration doesn't have to be purely mechanical

## Exploration Plan

### Spike 1: Audit current enforcement surface (1h)
Map every enforcement point in the framework to the 2×2 matrix. Identify which quadrant each currently serves and which quadrant each *should* serve. Quantify: how many governance rules are prose-only vs. machine-enforced?

### Spike 2: Declaration format design (2h)
Draft a minimal `governance.yaml` (or section in `.framework.yaml`) that declares operation classes with their predictability and blast-radius dimensions. Test: can the current Tier 0 patterns be expressed in this format? Can the "Autonomous Mode Boundaries" prose be reduced to declarations?

### Spike 3: Runtime mapping feasibility (1h)
Sketch how PreToolUse hooks would consume the declaration file to derive enforcement level. Key question: can stochastic operations be intercepted at tool-call time, or do they require post-hoc review gates?

## Technical Constraints

- Must work within Claude Code's hook system (PreToolUse/PostToolUse, settings.json matchers)
- Must not require changes to Claude Code itself — only framework-level files
- Declaration file must be human-editable YAML (consistent with framework conventions)
- Runtime overhead: hooks run on every tool call — declaration lookup must be O(1) or cached
- Must degrade gracefully: missing/invalid declaration = current behavior (fail-open for initiative, not fail-closed)

## Scope Fence

**IN scope:**
- Problem validation: is the 2×2 matrix the right model?
- Declaration format: what does the file look like?
- Enforcement mapping: how does the runtime consume it?
- Migration path: can current Tier 0-3 be expressed in the new model?

**OUT of scope:**
- Building the full enforcement runtime (that's a build task post-GO)
- UI for managing declarations (Watchtower page — separate task)
- Multi-agent coordination (G-004, R-036 — orthogonal concern)
- Retroactive classification of all 470+ historical tasks

## Acceptance Criteria

- [ ] Problem statement validated — the 2×2 matrix captures governance gaps that impact-only tiers miss
- [ ] Current enforcement surface mapped to the matrix (Spike 1)
- [ ] Draft declaration format exists and can express both current Tier 0 and prose-only rules (Spike 2)
- [ ] Runtime mapping is feasible within Claude Code hook constraints (Spike 3)
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- The 2×2 matrix exposes governance gaps that are real (not theoretical) — evidenced by historical incidents
- A declaration format under 50 lines can express 80%+ of current governance rules
- Runtime enforcement is feasible without modifying Claude Code itself

**NO-GO if:**
- The matrix doesn't add insight beyond current tiers — impact-only is sufficient
- Declaration format becomes a permission spreadsheet that nobody will maintain
- Stochastic operations fundamentally can't be intercepted at tool-call time (enforcement impossible)

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
