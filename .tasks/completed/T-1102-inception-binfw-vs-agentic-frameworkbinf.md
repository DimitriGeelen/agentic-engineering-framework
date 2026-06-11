---
id: T-1102
name: "Inception: bin/fw vs .agentic-framework/bin/fw — framework error messages broken
  in consumer projects (G-033)"
description: >
  Inception task — RCA the recurring 'bin/fw not found' class of bug in consumer projects.
  Framework error messages and review prompts hardcode 'bin/fw' (lib/inception.sh:215,
  lib/review.sh:127, possibly more) under T-609 'Copy-Pasteable Commands' rule, but
  the rule was applied without distinguishing self-host vs consumer-host context.
  In consumer projects bin/fw does not exist — only .agentic-framework/bin/fw or bare
  'fw' (post-shim-migration). Trigger: same class of bug surfaced in BOTH ring20-dashboard
  and /opt/termlink transcripts on 2026-04-11. Investigate: (1) every framework code
  path that emits a copy-paste command — grep for 'bin/fw' across lib/, agents/, web/;
  (2) which contexts each runs in (always self-host, always consumer-host, or both);
  (3) feasibility of a helper function (e.g. lib/colors.sh _fw_cmd_for_user) that
  detects PROJECT_ROOT vs FRAMEWORK_ROOT and emits the right form; (4) interaction
  with shim migration — after fw upgrade, bare 'fw' should work, so the helper might
  emit just 'fw'; (5) recommend GO/NO-GO/DEFER + concrete remediation. Origin: G-033.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: [T-1093, G-033, T-609]
created: 2026-04-11T12:37:33Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-04-12T10:14:30Z
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
---

# T-1102: Inception: bin/fw vs .agentic-framework/bin/fw — framework error messages broken in consumer projects (G-033)

## Problem Statement

T-609 ("Copy-Pasteable Commands" rule) requires copy-pasteable commands in framework error messages and review prompts to use the form `cd /path/to/project && bin/fw <subcommand>`. The rule was applied uniformly across the codebase. But consumer projects (where the agent operates from a project that is NOT the framework repo) do not have a `bin/fw` — they have either `.agentic-framework/bin/fw` (vendored mode) or bare `fw` on PATH (post-shim-migration).

Every framework message that hardcodes `bin/fw` produces a copy-paste failure when relayed to a consumer-project user. The agent must correct manually, burning a round-trip per error.

**Confirmed instances so far:**
- `lib/inception.sh:215` — review-required error
- `lib/review.sh:127` — emit_review post-review prompt

There are likely more. Pattern: "anywhere we tell the user to run `bin/fw something`."

**For whom:** Every consumer project user (and their agents) who hits an inception/review error message. Two same-day incidents (ring20-dashboard 2026-04-11 morning, /opt/termlink T-909 2026-04-11 afternoon) each had the agent correcting `bin/fw → .agentic-framework/bin/fw` by hand.

**Why now:** Recurring class of bug, both transcripts caught it the same day. Cheap fix if we identify all call sites and centralize the helper.

## Assumptions

A-1: Every framework code path that emits a `bin/fw ...` copy-paste command has the same root cause and can be fixed with one helper. (Testable by `grep -rn "bin/fw" lib/ agents/ web/ bin/` and classifying each match.)

A-2: A single helper function (e.g. `_fw_cmd_for_user` in `lib/colors.sh` or a new `lib/path.sh`) can detect consumer-project context (`PROJECT_ROOT != FRAMEWORK_ROOT`) and emit the right form: bare `fw` post-shim-migration, `.agentic-framework/bin/fw` pre-migration, `bin/fw` in self-host. (Testable by sketching the helper and dry-running it in 3 contexts.)

A-3: The shim migration (`fw upgrade` step 4c) makes bare `fw` work for consumer projects with the shim installed — so for those projects the helper can simply emit `fw`. Pre-shim consumer projects need the explicit `.agentic-framework/bin/fw` form. (Testable by checking shim presence in `~/.local/bin/fw`.)

A-4: T-609 does not need to be repealed — its intent (copy-pasteable, no ambiguity) is correct. The fix is making the copy-paste output context-aware. (Testable by re-reading T-609.)

## Exploration Plan

**Phase 1 — Audit.** `grep -rn "bin/fw" lib/ agents/ web/ bin/ --include="*.sh" --include="*.py"`. Classify each match: framework-emitted message (BUG), framework-internal call (OK if it's the framework calling itself), test fixture (OK), comment (OK).

**Phase 2 — Helper sketch.** Write a `_fw_cmd_for_user` helper. Logic: if `PROJECT_ROOT == FRAMEWORK_ROOT`, return `bin/fw`; elif shim is installed, return `fw`; else return `.agentic-framework/bin/fw`. Sketch in `docs/reports/T-1102-bin-fw-rca.md`.

**Phase 3 — Re-read T-609.** Confirm intent. Check whether the rule explicitly mentions `bin/fw` or just "copy-pasteable".

**Phase 4 — Backwards compat.** Will the helper's output break existing tests, fixtures, or copy-paste examples in docs? Audit `tests/`, `docs/`.

**Phase 5 — Recommendation.** GO (ship helper + replace all hardcoded matches) / DEFER (helper alone is fine, mass replacement can wait) / NO-GO (helper is wrong abstraction — pick a different fix).

## Scope Fence

**IN scope:** RCA, audit, helper sketch, recommendation. May read framework source. May write a sketch in `docs/reports/T-1102-bin-fw-rca.md`.

**OUT of scope:** Implementing the helper. Replacing all hardcoded matches. Updating tests. Build work comes from descendant tasks after the GO decision.

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

**GO if:**
- A helper can detect self-host vs consumer context without false positives (proven: `lib/init.sh:579-583` already has this logic)
- The fix covers all confirmed BUG call sites (inception.sh:215, review.sh:127, check-tier0.sh:377)
- Backward compat preserved for existing tests and docs (confirmed: tests use `$FRAMEWORK_ROOT/bin/fw`, unaffected)
- T-609 intent preserved (confirmed: commands remain single-line, copy-pasteable, unambiguous)

**NO-GO if:**
- Shim detection is unreliable causing false `fw` output in pre-shim consumer projects (mitigated: falls through to `.agentic-framework/bin/fw`)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Two same-day incidents from independent consumer projects (ring20-dashboard, /opt/termlink T-909) confirm the bug class is real and recurring. 3 active user-facing BUGs found (`lib/inception.sh:215`, `lib/review.sh:127`, `agents/context/check-tier0.sh:377`). The fix is a ~15-line helper extracted from an already-proven detection pattern (`lib/init.sh:579-583`). T-609 intent preserved. Zero test breakage risk. Fix propagates automatically via `fw upgrade`.

**Evidence:**
- `lib/inception.sh:215` — emits `bin/fw` unconditionally in error message shown to user in consumer projects
- `lib/review.sh:127` — emits `bin/fw` unconditionally in post-review instruction shown to user
- `agents/context/check-tier0.sh:377` — emits `./bin/fw` unconditionally (also missing `cd PROJECT_ROOT &&`)
- Fix pattern proven: `lib/init.sh:579-583` has identical context-detection logic, just not extracted
- All 40+ test files use `$FRAMEWORK_ROOT/bin/fw` (qualified) — zero breakage risk
- Research artifact: `docs/reports/T-1102-bin-fw-rca.md`

## Structural Upgrade (added 2026-04-11 — chokepoint+test discipline pass per T-1105)

The worker's `_fw_cmd_for_user()` helper is necessary but not sufficient — it fixes 3 known sites but doesn't prevent the next contributor from emitting `bin/fw` literally somewhere new. Upgrade by adding the chokepoint+test pair:

**Chokepoint:**
- Single output formatter `_emit_user_command()` (in `lib/colors.sh` or `lib/paths.sh`) that takes a subcommand string and emits the full copy-pasteable command with the right `fw` form for the current context. ALL framework code that prints command suggestions to the user goes through this function.
- The `_fw_cmd_for_user()` helper from the worker fix is the implementation detail; `_emit_user_command()` is the user-facing chokepoint that includes the `cd $PROJECT_ROOT &&` prefix per T-609.

**Invariant test:**
- `tests/lint/no-hardcoded-fw-paths.bats` — greps `lib/ agents/ web/` for the literal string `bin/fw` in echo/printf/heredoc contexts. Allowlist: framework-internal calls (`source $FW_BIN_DIR/...`) are exempt; only user-facing emissions are checked. Fails CI if found.
- Pre-commit hook variant: flag any new `bin/fw` or `./bin/fw` strings in modified `.sh`/`.py` files.

**Why this is more reliable:** the helper alone leaves 3 sites fixed today and unbounded sites broken tomorrow. The chokepoint funnels all callers through one place; the test makes "bypass the chokepoint" impossible without a CI failure.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Two same-day incidents from independent consumer projects (ring20-dashboard, /opt/termlink T-909) confirm the bug class is real and recurring. 3 active user-facing BUGs found (`lib/inception.sh:215`, `lib/review.sh:127`, `agents/context/check-tier0.sh:377`). The fix is a ~15-line helper extracted from an already-proven detection pattern (`lib/init.sh:579-583`). T-609 intent preserved. Zero test breakage risk. Fix propagates automatically via `fw upgrade`.

Evidence:
- `lib/inception.sh:215` — emits `bin/fw` unconditionally in error message shown to user in consumer projects
- `lib/review.sh:127` — emits `bin/fw` unconditionally in post-review instruction shown to user
- `agents/context/check-tier0.sh:377` — emits `./bin/fw` unconditionally (also missing `cd PROJECT_ROOT &&`)
- Fix pattern proven: `lib/init.sh:579-583` has identical context-detection logic, just not extracted
- All 40+ test files use `$FRAMEWORK_ROOT/bin/fw` (qualified) — zero breakage risk
- Research artifact: `docs/reports/T-1102-bin-fw-rca.md`

**Date**: 2026-04-11T20:07:51Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Two same-day incidents from independent consumer projects (ring20-dashboard, /opt/termlink T-909) confirm the bug class is real and recurring. 3 active user-facing BUGs found (`lib/inception.sh:215`, `lib/review.sh:127`, `agents/context/check-tier0.sh:377`). The fix is a ~15-line helper extracted from an already-proven detection pattern (`lib/init.sh:579-583`). T-609 intent preserved. Zero test breakage risk. Fix propagates automatically via `fw upgrade`.

Evidence:
- `lib/inception.sh:215` — emits `bin/fw` unconditionally in error message shown to user in consumer projects
- `lib/review.sh:127` — emits `bin/fw` unconditionally in post-review instruction shown to user
- `agents/context/check-tier0.sh:377` — emits `./bin/fw` unconditionally (also missing `cd PROJECT_ROOT &&`)
- Fix pattern proven: `lib/init.sh:579-583` has identical context-detection logic, just not extracted
- All 40+ test files use `$FRAMEWORK_ROOT/bin/fw` (qualified) — zero breakage risk
- Research artifact: `docs/reports/T-1102-bin-fw-rca.md`

**Date**: 2026-04-11T20:07:51Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T20:07:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Two same-day incidents from independent consumer projects (ring20-dashboard, /opt/termlink T-909) confirm the bug class is real and recurring. 3 active user-facing BUGs found (`lib/inception.sh:215`, `lib/review.sh:127`, `agents/context/check-tier0.sh:377`). The fix is a ~15-line helper extracted from an already-proven detection pattern (`lib/init.sh:579-583`). T-609 intent preserved. Zero test breakage risk. Fix propagates automatically via `fw upgrade`.

Evidence:
- `lib/inception.sh:215` — emits `bin/fw` unconditionally in error message shown to user in consumer projects
- `lib/review.sh:127` — emits `bin/fw` unconditionally in post-review instruction shown to user
- `agents/context/check-tier0.sh:377` — emits `./bin/fw` unconditionally (also missing `cd PROJECT_ROOT &&`)
- Fix pattern proven: `lib/init.sh:579-583` has identical context-detection logic, just not extracted
- All 40+ test files use `$FRAMEWORK_ROOT/bin/fw` (qualified) — zero breakage risk
- Research artifact: `docs/reports/T-1102-bin-fw-rca.md`

### 2026-04-12T09:30:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T10:14:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Build task T-1143 completed — _fw_cmd helper added, 3 sites fixed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-512b2706
- **Timestamp:** 2026-06-02T14:55:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
