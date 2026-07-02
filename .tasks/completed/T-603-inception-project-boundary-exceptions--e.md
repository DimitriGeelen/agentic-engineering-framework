---
id: T-603
name: "Inception: Project boundary exceptions — /etc/cron.d and other legitimate outside-PROJECT_ROOT
  writes"
description: >
  T-602 fixed the cron collision symptom, but the boundary exception itself is unexamined.
  The project boundary gate (T-559) blocks writes outside PROJECT_ROOT, yet /etc/cron.d/
  is a legitimate exception. Questions: (1) Is /etc/cron.d/ the only legitimate outside-boundary
  write? (2) How should T-559 gate coexist with this exception — whitelist, escape
  hatch, or structural carve-out? (3) What is the attack surface if agents learn 'some
  outside writes are OK'? (4) Do the cron-triggered audits cover the full project
  scope (confirmed: yes via PROJECT_ROOT), and is this documented? Related: T-559,
  T-602, G-022.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: [T-559, T-602, T-601]
created: 2026-03-24T09:44:00Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-04-13T13:21:32Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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
---

# T-603: Inception: Project boundary exceptions — /etc/cron.d and other legitimate outside-PROJECT_ROOT writes

## Problem Statement

The framework enforces project isolation: agents stay within PROJECT_ROOT. The project boundary gate (T-559) blocks writes outside this boundary. However, `/etc/cron.d/` writes are a legitimate exception — cron jobs MUST live outside PROJECT_ROOT.

T-602 fixed the multi-project collision symptom, but the boundary exception itself was never scoped. This matters because:

1. **Security surface**: If the boundary gate has exceptions, those exceptions define the attack surface. An agent that knows "some outside writes are OK" may generalize that permission.
2. **Audit scope validation**: The cron-triggered audits use PROJECT_ROOT to scan `.tasks/`, `.context/`, `.fabric/` — covering the FULL project, not just framework files. This is correct but undocumented.
3. **Exception inventory**: We don't know if `/etc/cron.d/` is the ONLY legitimate outside-boundary write, or if there are others (e.g., `/tmp/` files, SSH known_hosts, brew installs).
4. **T-559 interaction**: The boundary gate needs a principled exception mechanism, not ad-hoc carve-outs.

## Assumptions

- A-001: `/etc/cron.d/` is the only framework write outside PROJECT_ROOT (needs validation — scan all agent scripts)
- A-002: A whitelist mechanism is safer than a blanket exception (needs validation — compare blast radius)
- A-003: Cron audit scope already covers full project via PROJECT_ROOT (validated — see paths.sh:38-39, audit.sh:350+)
- A-004: Agents cannot learn to exploit boundary exceptions if the mechanism is structural, not behavioral (needs validation)

## Exploration Plan

1. **Inventory outside-boundary writes** — grep all agent scripts for writes to paths not under `$PROJECT_ROOT` (15 min)
2. **Evaluate T-559 exception mechanisms** — whitelist vs. escape hatch vs. structural carve-out (20 min)
3. **Evaluate Option E: symlink architecture** — keep cron definitions inside PROJECT_ROOT, symlink from `/etc/cron.d/` (15 min)
4. **Assess agent exploitation surface** — can an agent chain from "cron write allowed" to arbitrary outside writes? (10 min)
5. **Document audit scope** — confirm and document that cron audits cover full project, not just framework (10 min)

### Option E: Symlink Architecture (human-proposed)

**Concept:** Cron definition file lives at `PROJECT_ROOT/.context/cron/agentic-audit.crontab`. Symlink from `/etc/cron.d/` points to it. One-time `sudo` setup. After that, zero outside-boundary writes.

**Validated:** Debian/Ubuntu/Mint cron follows symlinks in `/etc/cron.d/` IF both symlink and target are root-owned and target is not group/other writable.

**Constraints:**
- Target file must be `root:root 644` — git doesn't track ownership, so `chown` is part of setup
- Works for `/opt/` installs (root context), may fail for user-home installs (non-root context)
- One-time sudo for symlink + chown = natural Tier 0 gate

**Benefits:**
- Eliminates boundary exception entirely after setup
- Cron schedule is git-tracked (traceability, P-002)
- Schedule changes are normal project edits — no sudo, no boundary violation
- Audit trail captures when/why schedule changed

### Option F: Copy-on-Change with Drift Detection (human-proposed)

**Concept:** Cron definitions live inside `PROJECT_ROOT/.context/cron/` as source of truth (git-tracked). On install or when delta detected: copy to `/etc/cron.d/`. Audit detects drift and provides remediation.

**Flow:**
1. Agent edits `.context/cron/*.crontab` (inside PROJECT_ROOT, normal edit, git-tracked)
2. `fw audit schedule install` or periodic audit detects: project file ≠ installed file
3. If root/sudo available → auto-copy
4. If not → print exact `sudo cp` command for user to run
5. New cron jobs added to project → same delta detection → same copy flow

**Graceful degradation:**
- Root context → auto-copy, zero friction
- Sudo available → auto-copy with sudo
- No sudo → print exact command + WARN in audit
- Audit drift check → never silently out of sync

**Advantages over Option E (symlinks):**
- No root-ownership constraint on project files (git-tracked normally by any user)
- No symlink platform dependency (works on macOS launchd with same pattern, different target)
- Non-root installs get clear instructions instead of silent failure
- More portable: copy pattern adapts to any scheduler (cron.d, launchd, systemd timers)

**Trade-offs:**
- Requires periodic drift check (audit already does this)
- Two copies of the file (project + installed) — but project is source of truth
- Sudo still needed for the copy step (but degradation is graceful, not blocking)

## Technical Constraints

- `/etc/cron.d/` requires root/sudo — already a natural gate
- T-559 boundary gate is a PreToolUse hook — operates at tool call level
- Cron writes happen via `fw audit schedule install` — a specific command, not arbitrary Write/Edit
- Framework agents also write to `/tmp/` for transient files — unclear if this counts as "outside boundary"

## Scope Fence

**In:** Inventory all outside-boundary writes, evaluate exception mechanisms for T-559, document audit scope
**Out:** Implementing the chosen mechanism (that's a build task), changing how cron works, modifying audit sections

## Acceptance Criteria

### Agent
- [x] Complete inventory of all framework writes outside PROJECT_ROOT
- [x] Evaluate 3+ exception mechanism options with pros/cons
- [x] Document current audit scope (what cron checks cover for consumer projects)
- [x] Research artifact created at `docs/reports/T-603-boundary-exceptions.md`

### Human
- [ ] [REVIEW] Review exception mechanism recommendation and approve direction
  **Steps:**
  1. Read `docs/reports/T-603-boundary-exceptions.md`
  2. Evaluate whether the recommended exception mechanism fits the security model
  **Expected:** Clear recommendation with trade-offs articulated
  **If not:** Discuss specific concerns

- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Outside-boundary writes are enumerable (finite, known list)
- A whitelist or structural mechanism can contain the exception without weakening the general boundary
- The mechanism is implementable in T-559's PreToolUse hook

**NO-GO if:**
- Outside-boundary writes are too numerous or unpredictable to whitelist
- Any exception mechanism would create a general "escape hatch" that undermines project isolation
- The security surface of exceptions exceeds the value of the boundary gate itself

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Option F (copy-on-change with drift detection) wins: cron definitions as git-tracked project artifacts in PROJECT_ROOT/.context/cron/, copied to /etc/cron.d/ with graceful sudo degradation and audit drift detection. Eliminates ongoing boundary violations, works cross-platform, handles non-root installs.

## Decisions

**Decision**: GO

**Rationale**: Option F (copy-on-change with drift detection) wins: cron definitions as git-tracked project artifacts in PROJECT_ROOT/.context/cron/, copied to /etc/cron.d/ with graceful sudo degradation and audit drift detection. Eliminates ongoing boundary violations, works cross-platform, handles non-root installs.

**Date**: 2026-03-24T09:50:54Z
## Decision

**Decision**: GO

**Rationale**: Option F (copy-on-change with drift detection) wins: cron definitions as git-tracked project artifacts in PROJECT_ROOT/.context/cron/, copied to /etc/cron.d/ with graceful sudo degradation and audit drift detection. Eliminates ongoing boundary violations, works cross-platform, handles non-root installs.

**Date**: 2026-03-24T09:50:54Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-24T09:50:54Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Option F (copy-on-change with drift detection) wins: cron definitions as git-tracked project artifacts in PROJECT_ROOT/.context/cron/, copied to /etc/cron.d/ with graceful sudo degradation and audit drift detection. Eliminates ongoing boundary violations, works cross-platform, handles non-root installs.

### 2026-03-24T09:51:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-06T22:29:32Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-13T13:21:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
- **Reason:** T-1226: GO decision already recorded

### 2026-04-13T13:21:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1175c890
- **Timestamp:** 2026-06-02T15:03:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
