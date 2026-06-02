---
id: T-1321
name: "Pickup: Vendored .agentic-framework/ tracks Python __pycache__ files — Uncommitted changes present is the #1 audit trend (23×) for consumers (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1130. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-18T22:23:00Z
last_update: 2026-04-18T22:51:30Z
date_finished: 2026-04-18T22:50:58Z
---

# T-1321: Pickup: Vendored .agentic-framework/ tracks Python __pycache__ files — Uncommitted changes present is the #1 audit trend (23×) for consumers (from termlink)

## Problem Statement

Consumer projects vendor the framework into `.agentic-framework/` (per T-909). The vendored copy has no `.gitignore` of its own, so when Watchtower (or any `python3 web/...` invocation) runs from inside the vendored tree, fresh `__pycache__/*.pyc` files get added to the consumer's git index. Over time, every session leaves 5-15 dirty files, which trips the audit's "Uncommitted changes present" check repeatedly. Termlink reports this as the #1 audit trend (23×) on `/opt/termlink`. The recurring noise masks real "uncommitted changes" signals.

Source: termlink T-1130 pickup (P-038).

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

### Agent
- [x] Problem statement validated (do_vendor at bin/fw:181-202 has __pycache__ in excludes for COPY but doesn't ship a .gitignore for RUNTIME-generated files)
- [x] Assumptions tested (framework's own .gitignore excludes __pycache__/ globally; consumer has no equivalent; vendored .agentic-framework/ has no .gitignore)
- [x] Recommendation written with rationale (GO — build sibling T-1323)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Concrete, verified bug. The fix is minimal: ship a `.gitignore` inside the vendored `.agentic-framework/` directory at vendor time. `do_vendor` already excludes `__pycache__` from the COPY step but doesn't prevent RUNTIME pyc creation from being tracked. Side benefit: closes a recurring audit-noise loop that masks real signal (#1 trend at 23 occurrences on a single consumer). Risk near zero — `.gitignore` files are universally understood and additive.

**Evidence:**
- Confirmed `do_vendor` (bin/fw:181-202) excludes `__pycache__` and `*.pyc` from the rsync COPY but does NOT write a `.gitignore` to `$dest`
- Framework repo's own `.gitignore` line 1 is `__pycache__/` — the framework needs the same protection in its vendored form
- Termlink reproduces: `git ls-files .agentic-framework/ | grep -c pycache → 45`
- Termlink trend: "Uncommitted changes present" #1 audit warning, 23 repeats
- Build sibling T-1323 ships the fix + cleanup hint + bats regression

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

Rationale: Concrete, verified bug. The fix is minimal: ship a `.gitignore` inside the vendored `.agentic-framework/` directory at vendor time. `do_vendor` already excludes `__pycache__` from the COPY step but doesn't prevent RUNTIME pyc creation from being tracked. Side benefit: closes a recurring audit-noise loop that masks real signal (#1 trend at 23 occurrences on a single consumer). Risk near zero — `.gitignore` files are universally understood and additive.

Evidence:
- Confirmed `do_vendor` (bin/fw:181-202) excludes `__pycache__` and `.pyc` from the rsync COPY but does NOT write a `.gitignore` to `$dest`
- Framework repo's own `.gitignore` line 1 is `__pycache__/` — the framework needs the same protection in its vendored form
- Termlink reproduces: `git ls-files .agentic-framework/ | grep -c pycache → 45`
- Termlink trend: "Uncommitted changes present" #1 audit warning, 23 repeats
- Build sibling T-1323 ships the fix + cleanup hint + bats regression

**Date**: 2026-04-18T22:51:30Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T22:24:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:50:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete, verified bug. The fix is minimal: ship a `.gitignore` inside the vendored `.agentic-framework/` directory at vendor time. `do_vendor` already excludes `__pycache__` from the COPY step but doesn't prevent RUNTIME pyc creation from being tracked. Side benefit: closes a recurring audit-noise loop that masks real signal (#1 trend at 23 occurrences on a single consumer). Risk near zero — `.gitignore` files are universally understood and additive.

Evidence:
- Confirmed `do_vendor` (bin/fw:181-202) excludes `__pycache__` and `.pyc` from the rsync COPY but does NOT write a `.gitignore` to `$dest`
- Framework repo's own `.gitignore` line 1 is `__pycache__/` — the framework needs the same protection in its vendored form
- Termlink reproduces: `git ls-files .agentic-framework/ | grep -c pycache → 45`
- Termlink trend: "Uncommitted changes present" #1 audit warning, 23 repeats
- Build sibling T-1323 ships the fix + cleanup hint + bats regression

### 2026-04-18T22:50:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:51:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete, verified bug. The fix is minimal: ship a `.gitignore` inside the vendored `.agentic-framework/` directory at vendor time. `do_vendor` already excludes `__pycache__` from the COPY step but doesn't prevent RUNTIME pyc creation from being tracked. Side benefit: closes a recurring audit-noise loop that masks real signal (#1 trend at 23 occurrences on a single consumer). Risk near zero — `.gitignore` files are universally understood and additive.

Evidence:
- Confirmed `do_vendor` (bin/fw:181-202) excludes `__pycache__` and `.pyc` from the rsync COPY but does NOT write a `.gitignore` to `$dest`
- Framework repo's own `.gitignore` line 1 is `__pycache__/` — the framework needs the same protection in its vendored form
- Termlink reproduces: `git ls-files .agentic-framework/ | grep -c pycache → 45`
- Termlink trend: "Uncommitted changes present" #1 audit warning, 23 repeats
- Build sibling T-1323 ships the fix + cleanup hint + bats regression

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5da0b66b
- **Timestamp:** 2026-06-02T14:56:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
