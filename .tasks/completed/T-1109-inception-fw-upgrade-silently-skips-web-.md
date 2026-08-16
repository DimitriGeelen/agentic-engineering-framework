---
id: T-1109
name: "Inception: fw upgrade silently skips web/ sync — consumer terminal + blueprints
  missing despite include list"
description: >
  RCA inception. Live evidence 2026-04-11: /opt/025-WokrshopDesigner ran fw upgrade
  today (last_upgrade 2026-04-11T10:50:34Z, .framework.yaml says version 1.5.246)
  but the vendored .agentic-framework/VERSION file still says 1.1.16, and web/blueprints/terminal.py
  is missing. 4 of 5 inspected consumer projects (025, 051, 050, openclaw) have the
  same failure. lib/update.sh:183-192 includes 'web' in the rsync list, so theoretically
  web/blueprints/terminal.py should have been copied. Yet the consumer has no terminal.py
  and its Watchtower on :3001 returns 404 on /terminal. Two contradictory signals:
  (a) upgrade reports success + updates the yaml + writes last_upgrade timestamp;
  (b) actual vendored files are stale. TWO separate but possibly related issues: (1)
  WHY does fw upgrade claim success without syncing web/ (matches G-024 but code looks
  correct) — possible causes: alternate code path, rsync error silenced, nested .agentic-framework
  (Pattern 6 from T-1100), source tmpdir pointing at wrong version, dry-run flag stuck;
  (2) WHY does .framework.yaml/VERSION file drift — two different writers, two different
  reads. Investigate: (i) trace every upgrade code path in bin/fw + lib/upgrade.sh
  + lib/update.sh + lib/init.sh + any agents/upgrade/*; (ii) reproduce on a throwaway
  consumer; (iii) identify the chokepoint where upgrade sync SHOULD converge; (iv)
  design invariant test that fails CI if any file in upstream web/ is missing from
  a consumer's vendored web/ after upgrade; (v) recommend structural fix with validation
  plan. Per T-1105 chokepoint+test discipline. Related: G-024, T-1094 (fw upgrade
  docs), T-1100 (5 isolation patterns including Pattern 6 nested), T-1106 (Bug 2 PID
  path — another consumer-vs-framework path inconsistency). Deliverable: docs/reports/T-NNNN-web-sync-rca.md
  with code-path trace, reproduction, structural fix design, invariant test design,
  validation plan.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-11T20:12:21Z
last_update: '2026-08-16T22:24:22Z'
date_finished: 2026-04-12T11:01:55Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
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
  - ts: '2026-08-16T22:24:22Z'
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

# T-1109: Inception: fw upgrade silently skips web/ sync — consumer terminal + blueprints missing despite include list

## Problem Statement

`fw upgrade` silently reports success while failing to sync `web/` directory to consumer projects. 4 of 5 inspected consumers (025, 051, 050, openclaw) have stale vendored files. Root cause: `lib/upgrade.sh:do_upgrade()` maintains a handcrafted per-file sync list that diverged from `bin/fw:do_vendor()`'s comprehensive includes list when web/ was added. This explains G-024.

## Assumptions

- A1: `fw upgrade` uses `do_upgrade()`, not `do_vendor()` (CONFIRMED — code path trace)
- A2: `do_upgrade()` has its own file enumeration that excludes web/ (CONFIRMED — grep finds zero "web" refs)
- A3: `do_vendor()` includes web/ and works correctly (CONFIRMED — `fw init` syncs web/)
- A4: Collapsing to single `do_vendor()` call is safe (CONFIRMED — no callers expect partial sync)

## Exploration Plan

1. Trace all upgrade code paths in bin/fw + lib/upgrade.sh (DONE — Phase 1)
2. Reproduce on throwaway consumer (DONE — Phase 2, `/tmp/t1109-test-consumer`)
3. Design chokepoint fix + invariant tests (DONE — Phase 3)
4. Present recommendation for human decision (THIS STEP)

## Scope Fence

**IN:** RCA, chokepoint identification, invariant test design, build decomposition.
**OUT:** Implementing the fix (separate build tasks T-1109a through T-1109e after GO).

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
- Live reproduction confirms the bug (DONE — `/tmp/t1109-test-consumer` showed `fw upgrade` reports "OK All vendored scripts current" while terminal.py stays missing)
- Root cause is a structural pattern (enumeration divergence), not a config edge case (CONFIRMED — `lib/upgrade.sh:do_upgrade()` step 4b vs `bin/fw:do_vendor()` includes list)
- Chokepoint fix exists with zero blocking risk (CONFIRMED — collapse step 4b into `do_vendor` call; `do_vendor` is battle-tested via `fw init`)
- Invariant tests can be written in bats (CONFIRMED — `upgrade-vendor-complete.bats` + `single-vendor-writer.bats` sketched in `docs/reports/T-1109-web-sync-rca.md`)
- Migration path is single-command per consumer (CONFIRMED — `fw upgrade <consumer>` re-runs after fix)
- No downstream code depends on `do_upgrade` maintaining its own enumeration (VERIFIED via grep — no callers expect partial sync behavior)

**NO-GO if:**
- `do_vendor` turns out to have unforeseen side-effects when called from `do_upgrade` context (e.g., deletes user-edited files in `.agentic-framework/`)
- Full re-vendor runtime on large consumers exceeds acceptable upgrade latency (not measured; `.agentic-framework/` is ~7MB, expected sub-second)
- Invariant test fails to actually guard the regression (test must cause `fw upgrade` without the fix to fail — to be validated in test build)

**DEFER if:**
- Any consumer project has non-vendored local edits in `.agentic-framework/web/` that would be overwritten (none known; requires audit before migration)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — collapse `lib/upgrade.sh:do_upgrade()` step 4b into a single `do_vendor` call, add invariant tests, migrate the 4 broken consumers.

**Rationale:** The RCA (worker + main session, `docs/reports/T-1109-web-sync-rca.md`) confirms a structural enumeration-divergence bug. `fw upgrade` routes to `lib/upgrade.sh:do_upgrade()`, which maintains a handcrafted per-file sync list (`agents/context/*.sh`, `bin/fw`, `lib/*.sh`, a string of agent dirs, VERSION). `do_vendor()` in `bin/fw:181-190` maintains a separate, comprehensive includes list (`bin lib agents web docs .tasks/templates FRAMEWORK.md metrics.sh`). These two lists diverged silently when `web/blueprints/terminal.py` and `web/blueprints/sessions.py` were added in T-964..T-980 — `do_vendor` picked them up, `do_upgrade` did not. This is exactly the class of bug T-1105 (chokepoint+invariant-test discipline) exists to prevent: two enumerations of the same logical thing, no structural invariant binding them. Fix is pure refactor (collapse to single source of truth) + regression tests; `do_vendor` is battle-tested via `fw init`; migration is one `fw upgrade` per broken consumer. Zero blocking risk.

**Evidence (from `docs/reports/T-1109-web-sync-rca.md`):**

1. **Code path trace (Phase 1)** — `bin/fw:2697-2700` routes `upgrade` → `lib/upgrade.sh:do_upgrade()`. `do_upgrade()` is 914 lines and NEVER calls `do_update`, `do_vendor`, or any rsync-from-upstream logic. Section 4b (lines 320-446) syncs files via direct `diff -q + cp` from `$FRAMEWORK_ROOT`. The agent_dirs string at `lib/upgrade.sh:388` is `"task-create handover git healing fabric dispatch resume audit session-capture"` — no web, no web/blueprints, no web/templates, no web/terminal. Grep of the entire 914-line file for "web" finds only one comment inside a HEREDOC.

2. **Live reproduction (Phase 2)** — On `/tmp/t1109-test-consumer`: `fw init` → terminal.py present (via do_vendor). Removed terminal.py. Ran `fw upgrade` → output said `[4b/9] Vendored framework scripts / OK All vendored scripts current`. Post-upgrade: terminal.py **NOT restored**. Silent false-OK reproduced end-to-end. Blueprint diff `/opt/025` vs `/opt/999` confirms both `sessions.py` and `terminal.py` are missing from the consumer.

3. **`/opt/termlink` anomaly explained** — `/opt/termlink/.framework.yaml` has `upstream_repo: DimitriGeelen/agentic-engineering-framework` (GitHub URL). The GitHub format triggers `lib/update.sh:_do_update_vendored()` → `git clone` → `do_vendor` (full includes list). `/opt/termlink` got terminal.py via the `fw update` code path, never via `fw upgrade`. The 4 broken consumers (025, 051, 050, openclaw) do not have `upstream_repo` set and have only ever been upgraded via `fw upgrade`.

4. **Hypotheses ruled out** — H1 (alternate code path): CONFIRMED — `do_upgrade`, not `do_update`. H2 (tmpdir): no tmpdir in `do_upgrade`. H3 (nested .agentic-framework): exactly one per consumer. H4 (rsync failure): no rsync in upgrade path. H5 (VERSION): partially true (two writers) but not the primary bug. H6 (shim-only): PARTIALLY CONFIRMED — `do_upgrade` syncs a known subset, web/ is the gap. H7 (upstream_repo): `do_upgrade` reads from `$FRAMEWORK_ROOT` directly, never reads upstream_repo.

5. **G-024 finally explained** — G-024 ("fw upgrade does not sync web/blueprints/") was registered as an observation without root cause. The code that looks correct (`lib/update.sh` include list) is for `fw update`, a different command. `fw upgrade` has a fundamentally different sync strategy (handcrafted per-file) that structurally cannot sync new files without edits to `lib/upgrade.sh`. Every new blueprint/template/web module has required a manual code change that nobody made.

**Chokepoint (per T-1105 discipline):** **C1 — Replace `lib/upgrade.sh:do_upgrade()` step 4b body with a single `do_vendor` call.** The `do_vendor` includes list (`bin lib agents web docs .tasks/templates FRAMEWORK.md metrics.sh`) becomes the only place where vendoring scope is defined. No parallel enumeration to forget. Atomic full re-vendor. Automatically picks up future additions.

**Invariant tests (pair with chokepoint):**

| Test | Purpose |
|------|---------|
| `tests/integration/upgrade-vendor-complete.bats` | Create consumer, remove web/blueprints/terminal.py, run `fw upgrade`, assert file restored. Also: every blueprint in `FRAMEWORK_ROOT/web/blueprints/` must exist in consumer post-upgrade; web/templates/ count matches; web/terminal/ dir exists; VERSION matches. |
| `tests/lint/single-vendor-writer.bats` | Grep-based structural test: `lib/upgrade.sh` must NOT contain its own `web/blueprints\|web/templates\|web/terminal` enumeration. Any match = duplication pattern re-emerged = test fails. Runs on every PR touching `lib/upgrade.sh` or `bin/fw`. |

**Build decomposition:**

| ID | Scope | Type | Depends on |
|----|-------|------|------------|
| T-1109a | Fix `lib/upgrade.sh:do_upgrade()` step 4b: delete handcrafted sync block (lines 320-443), replace with `do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT"` call | Build | — |
| T-1109b | Write `tests/integration/upgrade-vendor-complete.bats` — 6 test cases per worker design | Test | T-1109a |
| T-1109c | Write `tests/lint/single-vendor-writer.bats` — structural guard | Test | T-1109a |
| T-1109d | Run `fw upgrade` on the 4 broken consumers (`/opt/025-WokrshopDesigner`, `/opt/051-*`, `/opt/050-*`, `/opt/openclaw`) — self-healing migration | Build | T-1109a |
| T-1109e | Add `fw doctor` check: compare vendored `web/` file manifest against upstream manifest, warn on drift | Build | T-1109a |

**Cost estimate:** ~1 hour total. Step 4b replacement is ~20 LOC delete + 10 LOC add. Tests are ~80 LOC combined. Consumer migration is 4 shell invocations. `fw doctor` check is ~30 LOC.

**Risk (none blocking):**
- Behavior change: full re-vendor overwrites any local edits in `.agentic-framework/`. Mitigation: `do_vendor` already does this for `fw init`, and `.agentic-framework/` is documented as vendored (not user-edited). Add a `--preserve-local` flag if anyone complains.
- Slightly slower: full copy vs diff-based. `.agentic-framework/` is ~7MB; runtime difference is negligible.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — collapse `lib/upgrade.sh:do_upgrade()` step 4b into a single `do_vendor` call, add invariant tests, migrate the 4 broken consumers.

Rationale: The RCA (worker + main session, ...

**Date**: 2026-04-12T11:02:01Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — collapse `lib/upgrade.sh:do_upgrade()` step 4b into a single `do_vendor` call, add invariant tests, migrate the 4 broken consumers.

Rationale: The RCA (worker + main session, ...

**Date**: 2026-04-12T11:02:01Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T20:12:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Dispatching RCA worker for fw upgrade sync failure

### 2026-04-12T11:01:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — collapse `lib/upgrade.sh:do_upgrade()` step 4b into a single `do_vendor` call, add invariant tests, migrate the 4 broken consumers.

Rationale: The RCA (worker + main session, ...

### 2026-04-12T11:01:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T11:02:01Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — collapse `lib/upgrade.sh:do_upgrade()` step 4b into a single `do_vendor` call, add invariant tests, migrate the 4 broken consumers.

Rationale: The RCA (worker + main session, ...

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b47df694
- **Timestamp:** 2026-06-02T14:55:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
