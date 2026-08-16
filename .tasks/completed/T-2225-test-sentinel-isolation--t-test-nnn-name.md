---
id: T-2225
name: "test-sentinel isolation — T-Test-NNN namespace + autouse PROJECT_ROOT patch"
description: >
  Inception: test-sentinel isolation — T-Test-NNN namespace + autouse PROJECT_ROOT
  patch

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-06-06T06:54:02Z
last_update: '2026-08-16T22:24:57Z'
date_finished: 2026-06-06T08:54:03Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-06T06:54:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:11Z'
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
  - ts: '2026-08-16T22:24:57Z'
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
cost_estimate_proposed:
  - ts: '2026-06-06T07:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2225: test-sentinel isolation — T-Test-NNN namespace + autouse PROJECT_ROOT patch

## Problem Statement

`web/test_app.py` uses hardcoded "sentinel" task IDs (`T-997`, `T-998`, `T-999`) as
test fixtures — assumed-reserved IDs the test code uses to probe 404 paths and
write malformed/empty task files to. The reservation is *informal*: the
framework's task-creation flow keeps producing sequential `T-NNNN` IDs and
eventually overlaps with the sentinel range. The `client` fixture also does
NOT monkeypatch `PROJECT_ROOT`, so all requests resolve against the *consumer's
real `.tasks/active/`* — and any consumer past T-997 sees the sentinels collide
with real tasks.

**Live verification 2026-06-06:**
- Sentinel hardcodes at `web/test_app.py:170, 282, 1018, 1098, 1106, 1113, 1121` (4 IDs across 7 sites).
- T-1239 dual-patch (`web.shared.PROJECT_ROOT` alongside `web.blueprints.tasks.PROJECT_ROOT`)
  missing at 5 sites: lines 1023, 1057, 1066, 1103, 1118.
- ring20-dashboard at T-1211+ hits this; framework itself now at T-2225 would hit it.
- Two surfaces of the same root cause (identifier collision + cache leak).

**For whom:** Every consumer that runs `fw test web` from `.agentic-framework/`.
**Why now:** Operator's pickup from ring20-dashboard 2026-05-29 reports 10/145 web-suite
failures from this class. Eight days later the class is unchanged in upstream. Framework
will hit this on its own dogfood soon.

## Assumptions

- **A1:** The framework's task-creation flow ONLY produces `T-NNNN` (numeric) IDs. A
  `T-Test-NNN` namespace is structurally unreachable by `fw work-on` / `fw task create`.
- **A2:** Most production tooling (audit, fabric, episodic, `fw task list`) uses
  regex `T-\d+` or glob `T-[0-9]*` — naturally excludes `T-Test-*` without explicit
  skip logic. (Needs verification — IW-3.)
- **A3:** Pytest's autouse fixture pattern works at module scope; one autouse
  `client_isolation` fixture in `web/test_app.py` covers all current tests.
- **A4:** Operator's D1+D2 priority means a 4x-cost layered fix is preferred over a
  point-fix at the same correctness floor.

## Open Questions

- **IW-1: Which fix shape — strawman (point fixes), steelman (4-layer structural close), or hybrid (namespace + autouse only)?**
  confidence: 2
  disposition: deferred
  rationale: dialogue 2026-06-06 — operator already framed against D1+D2; steelman is the leading candidate but the strawman/hybrid trade-off needs explicit decision (artifact `docs/reports/T-2225-test-sentinel-isolation.md` §3).

- **IW-2: Should `T-Test-*` be invisible to production tooling (skip-listed) or first-class (regex relaxed everywhere)?**
  confidence: 1
  disposition: deferred
  rationale: invisible is the cleaner semantic ("sentinels are outside the task universe"); first-class adds mixing-namespace surface across audit/fabric/episodic with no offsetting benefit. To be confirmed by operator.

- **IW-3: Production-tool audit — which `T-\d+` matchers in the framework need updating (or do they all naturally exclude `T-Test-*`)?**
  confidence: 0
  disposition: deferred
  rationale: spike needed — grep for `T-\[0-9\]+`, `T-\\d+`, `r"T-"` patterns across `lib/`, `agents/`, `bin/fw`, `web/`. Outcome shapes the build-task scope.

- **IW-4: Detection rail — lint-grep (in reviewer detector), pytest assertion (in conftest.py), or PreToolUse hook on `web/test_app.py` edits?**
  confidence: 1
  disposition: deferred
  rationale: reviewer detector composes with existing detector pipeline (L-461 stale-PC class proved value of static-scan detectors); conftest.py runs at test-time only (later-binding); PreToolUse hook fires on every Write to that file (eager). Reviewer detector preferred for D1 (catches drift on next reviewer scan).

## Exploration Plan

1. **Spike A — production-tool regex audit** (~15 min): grep all `T-\d+` / `T-[0-9]+` patterns in framework source. Classify: (a) naturally excludes `T-Test-*`, (b) would need explicit skip. Answers IW-3.
2. **Spike B — autouse fixture POC** (~10 min): draft the `client_isolation` autouse fixture in a scratch file; confirm pytest-fixture composition works at module-scope. Answers A3.
3. **Spike C — reviewer detector shape** (~10 min): draft `detect_test_sentinel_dual_patch_missing` in `lib/reviewer/static_scan.py` as a pseudocode block. Decide if the pattern is detectable without false positives. Answers IW-4 partially.
4. **Dialogue** with operator: confirm IW-1 (strawman/steelman/hybrid) + IW-2 (invisible/first-class) given the spike outputs.
5. **Recommendation** updated with concrete scope + decision-trail.
6. **Hand off** via `fw task review T-2225` for go/no-go.

Time-box: 1 hour total exploration; if Spike A reveals >5 production sites needing explicit skip, that becomes a separate sub-question.

## Technical Constraints

- **Pytest scope:** autouse fixture must work without breaking the 135 currently-passing web tests.
- **Backward compat:** existing `T-999`-and-friends hardcodes in `web/test_app.py` must be migrated atomically (one PR) so no in-between commit fails CI.
- **Vendored consumers:** the fix lives in `web/test_app.py` which is vendored to consumers via `fw upgrade`. ring20-dashboard already applied consumer-side band-aids; they need to be cleanly superseded, not double-applied.
- **No new dependencies:** test sentinels should not introduce new pytest plugins or test-only libraries.

## Scope Fence

**IN scope (this inception decides):**
- Fix shape for findings 1 + 2 of the ring20-dashboard pickup (sentinel + dual-patch)
- Namespace decision (T-Test-NNN vs T-99999 vs status quo)
- Production-tool visibility decision (invisible vs first-class)
- Detection-rail choice (reviewer detector vs conftest vs hook)

**OUT of scope (file separately on GO):**
- Findings 3 (`lib/build.sh` vendor chmod) and 4 (TS stale-detector `-nt`) of the pickup — different classes, file as `fw work-on --type build` siblings, NOT folded into this scope.
- VERSION rollback investigation (T-1828/T-1912 already partially healed; needs its own diagnosis).
- Migration of OTHER hardcoded sentinels elsewhere in the codebase (if Spike A surfaces any).
- Generalising the namespace to other test entities (e.g. `G-Test-NNN`, `L-Test-NNN`) — could be valuable but is a separate inception per "one inception = one question".

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Class verified LIVE 2026-06-06 (5 missing patch sites; 4 sentinel hardcodes — 7 sites total). Operator weights D1 antifragility + D2 reliability over cost — strongly favours layered steelman over strawman (point fixes). Research artifact `docs/reports/T-2225-test-sentinel-isolation.md` walks the strawman/steelman/hybrid trade-off against all four directives; steelman dominates D1 + D2. Strawman papers over symptom without strengthening; hybrid loses the antifragile detector layer that makes the system learn from this incident.

Path on GO: three independent build slices (each ≤1 session, each reversible):
1. Layers 1+2 — `T-Test-NNN` namespace + autouse `client_isolation` fixture (target: 145/145 web tests)
2. Layer 4 — reviewer detector `detect_test_sentinel_dual_patch_missing` + `detect_hardcoded_numeric_task_id`
3. Layer 3 — production-tool skip-list for `T-Test-*` across audit/fabric/episodic/task-list

Partial GO is meaningful — operator may accept 1+2 and defer 3 if invasive-skip risk concerns them.

**Evidence:**

- `web/test_app.py` — 7 sentinel hardcode sites verified live: lines 170, 282, 1018, 1098, 1106, 1113, 1121
- `web/test_app.py` — 5 dual-patch-missing sites: lines 1023, 1057, 1066, 1103, 1118
- ring20-dashboard pickup: channel `framework-agent` artifact `33df8954b2a9b70d`, 2026-05-29
- Related learnings recalled at filing: L-421 (test-isolation pollution has two module-state causes), L-245 (Playwright tests POST to live PROJECT_ROOT), L-066 (`fw doctor` nested `.agentic-framework`)
- Research artifact: `docs/reports/T-2225-test-sentinel-isolation.md` (full strawman/steelman/hybrid + directive matrix + dialogue log)

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

Rationale:

Class verified LIVE 2026-06-06 (5 missing patch sites; 4 sentinel hardcodes — 7 sites total). Operator weights D1 antifragility + D2 reliability over cost — strongly favours layered steelman over strawman (point fixes). Research artifact `docs/reports/T-2225-test-sentinel-isolation.md` walks the strawman/steelman/hybrid trade-off against all four directives; steelman dominates D1 + D2. Strawman papers over symptom without strengthening; hybrid loses the antifragile detector layer that makes the system learn from this incident.

Path on GO: three independent build slices (each ≤1 session, each reversible):
1. Layers 1+2 — `T-Test-NNN` namespace + autouse `client_isolation` fixture (target: 145/145 web tests)
2. Layer 4 — reviewer detector `detect_test_sentinel_dual_patch_missing` + `detect_hardcoded_numeric_task_id`
3. Layer 3 — production-tool skip-list for `T-Test-` across audit/fabric/episodic/task-list

Partial GO is meaningful — operator may accept 1+2 and defer 3 if invasive-skip risk concerns them.

Evidence:

- `web/test_app.py` — 7 sentinel hardcode sites verified live: lines 170, 282, 1018, 1098, 1106, 1113, 1121
- `web/test_app.py` — 5 dual-patch-missing sites: lines 1023, 1057, 1066, 1103, 1118
- ring20-dashboard pickup: channel `framework-agent` artifact `33df8954b2a9b70d`, 2026-05-29
- Related learnings recalled at filing: L-421 (test-isolation pollution has two module-state causes), L-245 (Playwright tests POST to live PROJECT_ROOT), L-066 (`fw doctor` nested `.agentic-framework`)
- Research artifact: `docs/reports/T-2225-test-sentinel-isolation.md` (full strawman/steelman/hybrid + directive matrix + dialogue log)

**Date**: 2026-06-06T08:54:03Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-06T06:54:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-06T08:54:03Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Class verified LIVE 2026-06-06 (5 missing patch sites; 4 sentinel hardcodes — 7 sites total). Operator weights D1 antifragility + D2 reliability over cost — strongly favours layered steelman over strawman (point fixes). Research artifact `docs/reports/T-2225-test-sentinel-isolation.md` walks the strawman/steelman/hybrid trade-off against all four directives; steelman dominates D1 + D2. Strawman papers over symptom without strengthening; hybrid loses the antifragile detector layer that makes the system learn from this incident.

Path on GO: three independent build slices (each ≤1 session, each reversible):
1. Layers 1+2 — `T-Test-NNN` namespace + autouse `client_isolation` fixture (target: 145/145 web tests)
2. Layer 4 — reviewer detector `detect_test_sentinel_dual_patch_missing` + `detect_hardcoded_numeric_task_id`
3. Layer 3 — production-tool skip-list for `T-Test-` across audit/fabric/episodic/task-list

Partial GO is meaningful — operator may accept 1+2 and defer 3 if invasive-skip risk concerns them.

Evidence:

- `web/test_app.py` — 7 sentinel hardcode sites verified live: lines 170, 282, 1018, 1098, 1106, 1113, 1121
- `web/test_app.py` — 5 dual-patch-missing sites: lines 1023, 1057, 1066, 1103, 1118
- ring20-dashboard pickup: channel `framework-agent` artifact `33df8954b2a9b70d`, 2026-05-29
- Related learnings recalled at filing: L-421 (test-isolation pollution has two module-state causes), L-245 (Playwright tests POST to live PROJECT_ROOT), L-066 (`fw doctor` nested `.agentic-framework`)
- Research artifact: `docs/reports/T-2225-test-sentinel-isolation.md` (full strawman/steelman/hybrid + directive matrix + dialogue log)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e66aaf5b
- **Timestamp:** 2026-06-06T08:54:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T08:54:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
