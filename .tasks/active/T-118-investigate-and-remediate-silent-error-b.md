---
id: T-118
name: Investigate and remediate silent error bypass behavior
description: >
  User observed a recurring pattern: agent silently works around errors instead of investigating root causes. Examples this session: (1) fw command not found — silently switched to direct path instead of investigating PATH issue. (2) Previous sessions had similar patterns where errors were glossed over. This is a Level D (ways of working) issue. The agent treats errors as friction to work around, not signals to investigate. Need to: audit episodic memory for all instances of silent bypass, identify root cause in agent behavior/instructions, design remediation (CLAUDE.md instructions, hook-based enforcement, or practice codification). This is a governance gap similar to T-108 premature closure — the framework should make investigation the path of least resistance.

status: started-work
workflow_type: inception
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T14:43:20Z
last_update: 2026-02-17T14:45:32Z
date_finished: null
---

# T-118: Investigate and remediate silent error bypass behavior

## Problem Statement

The agent systematically bypasses errors instead of investigating root causes. When a tool fails, the agent silently switches to an alternative path without reporting WHY the original failed. This is a Level D (ways-of-working) gap that affects reliability and antifragility.

**Evidence:** 7 documented instances across project history in 3 root cause categories:

| Category | Instances | Mechanism | Current Mitigation |
|----------|-----------|-----------|-------------------|
| **Agent behavioral** | T-118/L-037 (fw not found → silent switch), FP-005 (plugin override) | Agent treats errors as friction, not signals | CLAUDE.md error protocol |
| **Silent tool failure** | T-115/L-035 (pattern data loss), T-078/L-014 (checkpoint cache) | Tool reports success but data doesn't land | Specific bug fixes only |
| **Governance gap** | T-108/L-034 (premature closure + post-closure drift) | System allows actions that should be gated | AC gate (T-113), closed-task warning (T-114) |

**Root behavior:** The agent defaults to "work around errors" instead of "investigate errors." Three instances in a single session (S-2026-0217-1549) triggered user escalation.

## Assumptions

- A1: The pattern is systematic (not random one-offs) → **VALIDATED** — 7 instances across 5+ sessions, 3 distinct mechanisms
- A2: CLAUDE.md instructions alone are insufficient → **PARTIALLY VALIDATED** — instructions help but are not structural; the framework philosophy is enforcement > guidance
- A3: PostToolUse hooks can detect Bash failures and inject investigation reminders → **TO TEST** — hook format supports this (tool_response.exitCode + additionalContext JSON output)

## Exploration Plan

1. **Historical audit** (30min) — Mine all episodics for bypass instances → DONE (7 found)
2. **Root cause categorization** (15min) — Group by mechanism → DONE (3 categories above)
3. **Hook feasibility spike** (30min) — Design PostToolUse error-watchdog for Bash
4. **Implementation** (30min) — Build hook, update settings, test

## Scope Fence

**IN scope:** Bash error detection hook, inception analysis, practice documentation
**OUT of scope:** Post-write file verification (separate spike needed), redesigning the error handling system, automated testing framework

## Acceptance Criteria

- [x] Problem statement validated with historical evidence
- [x] Root cause mechanisms categorized (3 categories, 7 instances)
- [x] Error-watchdog PostToolUse hook built and tested
- [x] Go/No-Go decision recorded

## Go/No-Go Criteria

**GO if:**
- Pattern is systematic (not one-offs) → YES (7 instances)
- Hook-based detection is feasible via PostToolUse → YES (tool_response has exitCode/stderr)
- Overhead is acceptable (<50ms per Bash call) → YES (only fires for Bash, fast-path exit for success)

**NO-GO if:**
- Instances are unrelated one-offs → NO (systematic)
- Hook overhead is prohibitive → NO (acceptable)
- False positive rate makes warnings useless → TBD (conservative pattern list should avoid this)

## Decisions

### 2026-02-17 — Enforcement mechanism for error investigation
- **Chose:** PostToolUse error-watchdog hook (pattern-based Bash error detection) + CLAUDE.md protocol
- **Why:** Two-layer approach: instructional (CLAUDE.md) + structural (hook). Hook detects high-confidence errors (exit 127, tracebacks, etc.) and injects investigation reminder via additionalContext. Conservative pattern list avoids false positives on benign exit codes (grep, test).
- **Rejected:** (1) Post-write file verification hook — too complex for marginal benefit, needs separate spike. (2) CLAUDE.md only — instructional without structural enforcement contradicts framework philosophy. (3) Warn on all non-zero exits — too many false positives (grep, test, command -v).

## Decision

**GO** — All three go criteria met: pattern is systematic (7 instances, 3 mechanisms), hook detection is feasible (PostToolUse tool_response has exitCode/stderr), overhead is acceptable (~25ms per Bash call on success path).

Phased implementation:
1. Phase 1 (done, prev session): CLAUDE.md error investigation protocol
2. Phase 2 (done, this session): error-watchdog.sh PostToolUse hook
3. Phase 3 (deferred): Promote L-037 to practice after 3+ applications
4. Phase 4 (deferred): Post-write file verification (separate inception if pattern recurs)

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
