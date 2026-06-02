---
id: T-1084
name: "Gate bypass discoverability — every block message must name its bypass"
description: >
  Inception: Gate bypass discoverability — every block message must name its bypass

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T09:03:48Z
last_update: 2026-04-12T09:27:15Z
date_finished: 2026-04-11T09:17:18Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1084: Gate bypass discoverability — every block message must name its bypass

## Problem Statement

When a framework gate blocks an agent action, its error message often does NOT print the exact bypass command. The agent then guesses (often wrong), the user runs the wrong command, gets a confusing error, and the cycle repeats. Observed in T-908 session (/opt/termlink): agent suggested `fw tier0 approve` for an inception commit-msg block; real bypass was `git commit --no-verify`.

**Research artifact:** `docs/reports/T-1084-gate-bypass-discoverability.md`

## Assumptions

- A1: 3+ gates currently lack bypass-command-in-error-output
- A2: Adding the bypass command to error output is mechanical (no infra redesign)
- A3: Copy-pasteable commands (T-609 rule) satisfy the user requirement

## Exploration Plan

1. Audit each of the 10 identified gates: run it in a controlled test, capture block message, assess bypass clarity (0/5/10 min each)
2. Identify gaps (which gates print nothing, which print wrong thing, which are good examples)
3. Design standard error template
4. Scope the fix (LOC per gate)
5. Go/no-go decision

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

**GO if:** 3+ gates lack or mislead on bypass AND fix is mechanical (no infra redesign).
**NO-GO if:** <3 gates affected OR fix requires architectural change.

**Audit result:** 3 gates actively broken (commit-msg task-ref, commit-msg inception, pre-push audit), 1 partial (project boundary). → GO.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** The T-908 incident is a specific symptom of a copy-paste bug baked into 3 git-hook gate error messages. All 3 print `fw tier0 approve` as part of the bypass recipe, which is wrong in both human-terminal context (the command errors because no pending block exists, breaking the `&&` chain) and agent-Bash context (the agent never hits the git hook because Tier 0 fires first on `--no-verify`). Fix is mechanical: edit 4 messages, bump hook VERSION, propagate via `--force` install-hooks on 11 consumer projects.

**Evidence:**
- 11 gates audited: 6 GOOD, 3 BROKEN (#6, #7, #8), 1 PARTIAL (#10), 1 N/A (budget — good as-is)
- The broken gates are `agents/git/lib/hooks.sh` lines 75-79 (commit-msg task-ref), 128-130 (commit-msg inception), 377-379 (pre-push audit)
- The same file's research-artifact gate (line 169) gets it right with just `git commit --no-verify` — pattern to copy
- Good examples from task-first gate (`check-active-task.sh:167-169`) and G-020 (`check-active-task.sh:341-344`) prove the template is learnable and clear
- Full audit in `docs/reports/T-1084-gate-bypass-discoverability.md`

**Proposed follow-up tasks:**
1. T-1085 (build): Fix commit-msg task-ref gate bypass message
2. T-1086 (build): Fix inception commit-msg gate bypass message
3. T-1087 (build): Fix pre-push audit gate bypass message
4. T-1088 (build): Add TermLink workaround to project boundary gate error (PARTIAL)
5. Bump hook VERSION → 1.6, propagate to 11 consumers via `install-hooks --force` (rolled into one of the above or a separate small task)

Out of scope (separate inceptions if wanted): `fw gates` inventory command, unified `fw bypass` wrapper, context-aware `fw tier0 approve` suggestions.

## Decisions

**Decision**: GO

**Rationale**: 5 broken gates + Watchtower truncation + invisible marker coupling — fix systemically

**Date**: 2026-04-11T09:17:18Z
## Decision

**Decision**: GO

**Rationale**: 5 broken gates + Watchtower truncation + invisible marker coupling — fix systemically

**Date**: 2026-04-11T09:17:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T09:04:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-11T09:17:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 5 broken gates + Watchtower truncation + invisible marker coupling — fix systemically

### 2026-04-11T09:17:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:15Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0302c62b
- **Timestamp:** 2026-06-02T14:55:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
