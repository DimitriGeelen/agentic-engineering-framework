---
id: T-1284
name: "Watchtower port discovery regression — current _watchtower_url probes common ports and picks anything that answers (picked :8080 which was not Watchtower). Redesign against 4 directives (antifragility, reliability, usability, portability)."
description: >
  Inception: Watchtower port discovery regression — current _watchtower_url probes common ports and picks anything that answers (picked :8080 which was not Watchtower). Redesign against 4 directives (antifragility, reliability, usability, portability).

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-17T16:48:04Z
last_update: 2026-04-26T19:30:17Z
date_finished: null
---

# T-1284: Watchtower port discovery regression — current _watchtower_url probes common ports and picks anything that answers (picked :8080 which was not Watchtower). Redesign against 4 directives (antifragility, reliability, usability, portability).

## Problem Statement

`_watchtower_url` returned `http://192.168.10.107:8080` for T-1283's review URL. 
That port is NOT Watchtower — it's an unrelated Python service that returned 200 
for arbitrary paths. Port 3000 (real Watchtower, PID 3122424) was running but 
the task-specific probe (`/inception/T-1283`) returned 404 there (Watchtower 
had not restarted after T-1283 creation), so the probe fell through to :8080.

Full analysis: docs/reports/T-1284-watchtower-port-discovery-redesign.md

## Assumptions

- A1: All Watchtower instances can write `.pid/.port/.url` triple to 
  `.context/working/` on startup (needs verification for consumer projects)
- A2: `/api/_identity` handshake cost is negligible (< 50ms per CLI invocation)
- A3: Watchtower-prod (LXC gunicorn) can expose the same `/api/_identity` endpoint
- A4: Breaking "any responding port is Watchtower" does not orphan callers 
  (all routes go through `_watchtower_url`)

## Exploration Plan

Completed in this inception:
- Reproduced regression by running `fw task review T-1283` and observing :8080
- Inspected current `lib/watchtower.sh` (`_watchtower_url`)
- Mapped all currently listening ports on .107
- Designed 3-layer replacement (PID triple, identity handshake, fail-loud)
- Scored current vs proposed against four directives

See: docs/reports/T-1284-watchtower-port-discovery-redesign.md

## Technical Constraints

- Must remain backward-compatible with consumer projects (Watchtower via 
  `.agentic-framework/bin/fw serve` must still work)
- Must handle Watchtower-prod (LXC) which runs gunicorn under systemd
- Must not require Watchtower restart for every new task (or must auto-restart)
- `_watchtower_url` is called synchronously during `fw` commands — cost budget 
  is tight (< 100ms total)

## Scope Fence

**IN scope:** `/api/_identity` endpoint, startup triple file (pid/port/url), 
rewrite of `_watchtower_url`, decommission of hardcoded port list, regression 
test for masquerading services, `fw doctor` surfacing.

**OUT of scope:** auto-restart Watchtower on task creation, HTTPS/auth for 
identity endpoint, multi-Watchtower coordination (one-per-project vs shared).

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
- Proposed design scores ≥ current on all four directives (antifragility, 
  reliability, usability, portability) — ✓ shown in artifact scoring
- Build units fit one session each (B1-B6 identified, each <1 session)
- No breaking change to `_watchtower_url` public signature
- Identity-handshake cost stays < 100ms per CLI call

**NO-GO if:**
- A3 (Watchtower-prod can expose identity endpoint) proves untestable → 
  reduce scope to local-only discovery and reconsider
- PID/port/URL triple write races under concurrent Watchtower starts
- Handshake pushes `fw` commands past latency budget

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** The current `_watchtower_url` port discovery fails Reliability 
(silent wrong answer observed) and Antifragility (any sibling Python service 
can masquerade). The 3-layer redesign (PID/port/URL triple → identity 
handshake → fail-loud) restores all four directives. Scope is bounded into 
6 build units, each under one session. Fix is reversible (current function 
is the only caller surface).

**Evidence:**
- Reproduced regression live: `fw task review T-1283` returned `:8080` when 
  Watchtower was on `:3000` and the :8080 service is unrelated (see artifact)
- :8080 returned 200 for `/inception/T-1283` because it's a catch-all — no 
  identity check would pass it as Watchtower
- Three fallback layers in current function can all converge on wrong service; 
  single-source-of-truth (PID triple) eliminates ambiguity
- Pattern (identity handshake) is reusable for any future framework service
- Full scoring of current vs proposed against four directives in the artifact

See: docs/reports/T-1284-watchtower-port-discovery-redesign.md

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The current `_watchtower_url` port discovery fails Reliability 
(silent wrong answer observed) and Antifragility (any sibling Python service 
can masquerade). The 3-layer redesign (PID/port/URL triple → identity 
handshake → fail-loud) restores all four directives. Scope is bounded into 
6 build units, each under one session. Fix is reversible (current function 
is the only caller surface).

Evidence:
- Reproduced regression live: `fw task review T-1283` returned `:8080` when 
  Watchtower was on `:3000` and the :8080 service is unrelated (see artifact)
- :8080 returned 200 for `/inception/T-1283` because it's a catch-all — no 
  identity check would pass it as Watchtower
- Three fallback layers in current function can all converge on wrong service; 
  single-source-of-truth (PID triple) eliminates ambiguity
- Pattern (identity handshake) is reusable for any future framework service
- Full scoring of current vs proposed against four directives in the artifact

See: docs/reports/T-1284-watchtower-port-discovery-redesign.md

**Date**: 2026-04-17T19:21:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-17T16:51:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-17T19:20:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The current `_watchtower_url` port discovery fails Reliability 
(silent wrong answer observed) and Antifragility (any sibling Python service 
can masquerade). The 3-layer redesign (PID/port/URL triple → identity 
handshake → fail-loud) restores all four directives. Scope is bounded into 
6 build units, each under one session. Fix is reversible (current function 
is the only caller surface).

Evidence:
- Reproduced regression live: `fw task review T-1283` returned `:8080` when 
  Watchtower was on `:3000` and the :8080 service is unrelated (see artifact)
- :8080 returned 200 for `/inception/T-1283` because it's a catch-all — no 
  identity check would pass it as Watchtower
- Three fallback layers in current function can all converge on wrong service; 
  single-source-of-truth (PID triple) eliminates ambiguity
- Pattern (identity handshake) is reusable for any future framework service
- Full scoring of current vs proposed against four directives in the artifact

See: docs/reports/T-1284-watchtower-port-discovery-redesign.md

### 2026-04-17T19:21:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The current `_watchtower_url` port discovery fails Reliability 
(silent wrong answer observed) and Antifragility (any sibling Python service 
can masquerade). The 3-layer redesign (PID/port/URL triple → identity 
handshake → fail-loud) restores all four directives. Scope is bounded into 
6 build units, each under one session. Fix is reversible (current function 
is the only caller surface).

Evidence:
- Reproduced regression live: `fw task review T-1283` returned `:8080` when 
  Watchtower was on `:3000` and the :8080 service is unrelated (see artifact)
- :8080 returned 200 for `/inception/T-1283` because it's a catch-all — no 
  identity check would pass it as Watchtower
- Three fallback layers in current function can all converge on wrong service; 
  single-source-of-truth (PID triple) eliminates ambiguity
- Pattern (identity handshake) is reusable for any future framework service
- Full scoring of current vs proposed against four directives in the artifact

See: docs/reports/T-1284-watchtower-port-discovery-redesign.md

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e543476d
- **Timestamp:** 2026-06-02T14:56:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
