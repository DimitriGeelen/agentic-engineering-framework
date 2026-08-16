---
id: T-548
name: "npm install pathway — evaluate whether to build npm-based framework installation"
description: >
  Inception: npm install pathway — evaluate whether to build npm-based framework installation

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T11:10:41Z
last_update: '2026-08-16T22:25:33Z'
date_finished: 2026-04-12T07:56:32Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-548: npm install pathway — evaluate whether to build npm-based framework installation

## Problem Statement

Should the framework offer `npm install` as an installation pathway? The framework is bash + Python, not JavaScript, but T-586 GO on TypeScript adoption raises the question. Research artifact: `docs/reports/T-548-npm-install-pathway.md`.

## Assumptions

- A1: Node.js developers would benefit from npm-based installation (NOT VALIDATED — no user requests, no Node.js consumer projects)
- A2: npm packaging would be straightforward for a bash framework (INVALID — requires runtime dependency, complex packaging)
- A3: Dual install paths are maintainable (INVALID — two upgrade paths, two bug surfaces)

## Exploration Plan

1. Audit current installation methods (done — 4 methods exist)
2. Analyze npm packaging for non-JS CLI tools (done — wrong distribution channel)
3. Check user demand evidence (done — zero requests)

## Technical Constraints

- Framework is bash + Python, not JavaScript
- npm would add Node.js as a runtime dependency
- bin entries pointing to shell scripts require platform-specific handling

## Scope Fence

**IN:** Whether to add npm as an install pathway.
**OUT:** Changing existing install methods, npm for TermLink only.

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested (3 assumptions — 1 not validated, 2 invalid)
- [x] Go/No-Go decision made (NO-GO recommended)

## Go/No-Go Criteria

**GO if:** User demand exists AND Node.js runtime is already required AND dual-path maintenance is justified

**NO-GO if:** No user demand, framework is not JavaScript, runtime dependency is incoherent (all true)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** NO-GO
**Rationale:** Framework is bash+Python, not JavaScript. npm is the wrong distribution channel. Zero user demand. Adding Node.js as runtime dependency for a non-JS tool is incoherent.
**Evidence:**
- 4 install methods already exist (git clone, curl, Homebrew, fw init --vendor)
- Framework has no JavaScript code in core (Watchtower frontend is optional)
- A-001 (demand exists) — NOT VALIDATED: zero GitHub issues or requests
- A-002 (npm simplifies install) — INVALID: npm for non-JS tools adds confusion
- A-003 (compatible with bash entry point) — INVALID: requires platform-specific bin entries

## Decisions

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-06T22:23:16Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-12T07:56:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-12T07:56:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0440ca9e
- **Timestamp:** 2026-06-02T15:03:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
