---
id: T-878
name: "Global install sync violates project isolation — fw upgrade still writes to ~/.agentic-framework"
description: >
  fw upgrade step 4c syncs scripts to ~/.agentic-framework despite T-662 establishing project isolation. The INFO message says 'no global install dependency' but then immediately syncs to global. Contradicts isolation principle.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-05T06:08:16Z
last_update: 2026-04-13T13:21:41Z
date_finished: 2026-04-13T13:21:41Z
---

# T-878: Global install sync violates project isolation — fw upgrade still writes to ~/.agentic-framework

## Problem Statement

`fw upgrade` step 4c syncs scripts from framework repo to `$HOME/.agentic-framework/` (bin/fw, lib/*.sh, agents/context/). This contradicts T-662's GO decision to eliminate the global install dependency. The shim pattern (`~/.local/bin/fw` project-detecting script) makes the global install unused, yet upgrades keep it "current."

Line 469 of `lib/upgrade.sh` says "no global install dependency" then line 480 syncs to the global install. The code literally says one thing and does the opposite.

**For whom:** All framework users — global install is dead weight that could cause version confusion.
**Why now:** T-662 GO was decided 2026-03-28. The sync is a leftover from the bridge period (T-660).

## Assumptions

- A-1: The shim at `~/.local/bin/fw` handles all PATH-based `fw` resolution (no need for global install)
- A-2: All 11 consumer projects use vendored `.agentic-framework/bin/fw` (confirmed)
- A-3: No scripts or hooks depend on `~/.agentic-framework/` (the shim bypasses it entirely)
- A-4: Removing the sync won't break any user workflow

## Exploration Plan

**Spike 1 — Verify shim handles all cases (15 min):**
- Check `~/.local/bin/fw` is a shim script (confirmed: file reports Bourne-Again shell script)
- Verify it detects projects correctly by walking up from CWD

**Spike 2 — Map sync code and blast radius (15 min):**
- Read `lib/upgrade.sh:448-558` (the sync block)
- Count lines to remove, identify any side effects

**Spike 3 — Check for hidden dependencies (15 min):**
- Grep all scripts for `$HOME/.agentic-framework` or `~/.agentic-framework`
- Confirm nothing uses the global install at runtime

## Technical Constraints

- `~/.agentic-framework/` still exists on this machine with old docs
- The shim script at `~/.local/bin/fw` is the production PATH-based resolver
- `fw doctor` already checks for global install state (line 790 of `bin/fw`)

## Scope Fence

**IN scope:**
- Remove sync block from `lib/upgrade.sh`
- Add deprecation warning in `fw doctor`
- Validate no runtime dependencies on `~/.agentic-framework/`

**OUT of scope:**
- Auto-deleting `~/.agentic-framework/` (too aggressive)
- Changing the shim pattern itself (already working)
- Cross-machine concerns (TermLink domain)

## Acceptance Criteria

### Agent
- [x] Problem statement validated — sync contradicts T-662 GO decision
- [x] Assumptions tested — shim works, all 11 projects vendored, no dependencies found
- [x] Recommendation written with rationale (GO — Option B: remove sync + deprecation)

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-878-global-install-sync.md`
  2. Evaluate whether removing the sync + adding deprecation is safe
  3. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && bin/fw inception decide T-878 go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- No runtime dependencies exist on `~/.agentic-framework/`
- The shim handles all PATH-based `fw` resolution correctly
- Removing the sync is a clean deletion (no side effects)

**NO-GO if:**
- Any script or hook depends on `~/.agentic-framework/` at runtime
- The shim has edge cases that fall back to the global install
- Users have customizations in `~/.agentic-framework/` that would break

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

## Recommendation

- **Recommendation:** GO (Option B — remove sync + deprecation warning)
- **Rationale:** T-662 decided GO on eliminating global dependency. The shim handles PATH resolution. All 11 projects are vendored. The sync maintains a copy nothing uses and contradicts the isolation principle. Removing 80 lines of sync code + adding a 5-line `fw doctor` deprecation warning completes the T-662 migration.
- **Evidence:**
  - `~/.local/bin/fw` is a project-detecting shim (confirmed via `file` command)
  - All 11 consumer projects have vendored `.agentic-framework/bin/fw`
  - `lib/upgrade.sh:480-558` syncs to unused global install
  - Line 469 says "no global install dependency", line 480 syncs to it — self-contradictory
  - No runtime dependencies found on `~/.agentic-framework/` in grep of all scripts

## Decision

**Decision**: GO

**Rationale**: - Recommendation: GO (Option B — remove sync + deprecation warning)
- Rationale: T-662 decided GO on eliminating global dependency. The shim handles PATH resolution. All 11 projects are vendored. The sync maintains a copy nothing uses and contradicts the isolation principle. Removing 80 lines of sync code + adding a 5-line `fw doctor` deprecation warning completes the T-662 migration.
- Evidence:
  - `~/.local/bin/fw` is a project-detecting shim (confirmed via `file` command)
  - All 11 consumer projects have vendored `.agentic-framework/bin/fw`
  - `lib/upgrade.sh:480-558` syncs to unused global install
  - Line 469 says "no global install dependency", line 480 syncs to it — self-contradictory
  - No runtime dependencies found on `~/.agentic-framework/` in grep of all scripts

**Date**: 2026-04-13T11:08:52Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-05T11:56:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:25Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T11:08:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO (Option B — remove sync + deprecation warning)
- Rationale: T-662 decided GO on eliminating global dependency. The shim handles PATH resolution. All 11 projects are vendored. The sync maintains a copy nothing uses and contradicts the isolation principle. Removing 80 lines of sync code + adding a 5-line `fw doctor` deprecation warning completes the T-662 migration.
- Evidence:
  - `~/.local/bin/fw` is a project-detecting shim (confirmed via `file` command)
  - All 11 consumer projects have vendored `.agentic-framework/bin/fw`
  - `lib/upgrade.sh:480-558` syncs to unused global install
  - Line 469 says "no global install dependency", line 480 syncs to it — self-contradictory
  - No runtime dependencies found on `~/.agentic-framework/` in grep of all scripts

### 2026-04-13T13:21:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** T-1226: GO decision already recorded

### 2026-04-13T13:21:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: GO decision recorded via Watchtower
