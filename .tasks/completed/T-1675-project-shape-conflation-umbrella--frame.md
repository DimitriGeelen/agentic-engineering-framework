---
id: T-1675
name: "Project-shape conflation umbrella — framework code assumes consumer shape, silently fails in framework repo / fresh-init / vendored states"
description: >
  Project-shape conflation umbrella — framework code assumes consumer shape, silently fails in framework repo / fresh-init / vendored states

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
arc_id: project-shape-resilience
created: 2026-05-02T10:04:39Z
last_update: 2026-05-02T10:21:20Z
date_finished: 2026-05-02T10:21:20Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1675: Project-shape conflation umbrella — framework code assumes consumer shape, silently fails in framework repo / fresh-init / vendored states

## Problem Statement

Recurring failure pattern: framework code assumes ONE project shape
(initialized consumer with `.framework.yaml` + `.agentic-framework/`)
and silently degrades on the others — framework-repo itself (no
`.framework.yaml`), fresh consumer pre-init, and vendored consumers
with version skew. Each instance gets fixed; the class continues to
ship.

| Shape                       | Marker                                             |
|-----------------------------|----------------------------------------------------|
| framework-repo              | `FRAMEWORK.md` + `bin/fw` at root, NO `.framework.yaml` |
| consumer-initialized        | `.framework.yaml` + `.agentic-framework/bin/fw`    |
| consumer-uninitialized      | bare directory, no fw artifacts                    |
| consumer-vendored-skewed    | `.framework.yaml` present but vendored shim out of sync |

**Anchor incident (this session, 2026-05-02):** `bin/fw config list` from
the framework repo prints `No .framework.yaml found at ...` and exits 1
— the same error a broken consumer would see. `_config_list()` at
`lib/config-file.sh:177-181` hard-fails when the marker is absent rather
than detecting the framework-repo case and falling through to defaults.

**Pattern instances:**
- T-1257 — agents told consumers to run `bin/fw` (framework-repo path);
  same conflation in docs/agent-output layer.
- T-1542 (active) — `fw upgrade` from inside a consumer crashes at step
  4b/9; bare-from-consumer case unhandled.
- T-1634 (captured) — `fw upgrade no-args` should read upstream URL +
  git-fetch; same path-resolution gap.
- T-1635 (captured) — `fw upgrade` fresh-machine simulation guard;
  the missing test infra that would have caught the above.
- T-1673 (this session) — cross-repo fabric cards (absolute paths)
  falsely orphaned; `[ ! -f "$PROJECT_ROOT/$loc" ]` assumed one shape.
- This-session anchor — `fw config list` framework-repo conflation
  (not yet filed as standalone task; covered by this umbrella).

**Why now:** the rate of "successful upgrade from a consumer" is
unknown and unmeasured. Each conflation adds fragility. The user
asked for a structural answer; this is the umbrella to answer it.

## Assumptions

A1. There exists a finite, enumerable set of project shapes (≤5).
    Validated by listing them above; no exotic edge cases observed.
A2. A single classifier function can disambiguate all shapes from
    filesystem signals alone (no environment-variable inputs needed).
    Testable by spike: implement `fw_project_context()`, run on each
    fixture shape, check it returns the right value.
A3. The number of ad-hoc `[ -f .framework.yaml ]` checks across `lib/`
    is small enough (<50) that a one-shot refactor is feasible.
    Testable: `grep -rE "\.framework\.yaml" lib/ | wc -l`.

## Exploration Plan

**Lever 1 — Project-shape classifier**
- Spike: write `fw_project_context()` returning
  `framework | consumer-initialized | consumer-uninitialized | unknown`
- Inventory current `[ -f .framework.yaml ]` call sites (grep)
- Estimate refactor scope (file count × call sites)
- Time-box: 30min

**Lever 2 — Three-shape test matrix**
- Identify the public `fw <verb>` set (`fw help` listing)
- For each verb, classify "needs shape-aware handling?" yes/no
- Fixture template: 3 fixtures (framework / consumer-init / fresh)
- Time-box: 30min for inventory; build-task estimate per verb after.

**Lever 3 — Upgrade simulation CI**
- Audit T-1635 spec (already captured, not started)
- Identify container substrate options (docker / lxc / podman) on this host
- Define "smoke verb set" — which verbs MUST pass post-upgrade
- Time-box: 30min for design; T-1635 retains build scope.

**Output of exploration:** Recommendation block names which lever
(or combination) ships first, with build tasks filed separately.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN scope:**
- Naming the project-shape conflation pattern as a single class
- Cataloguing prior incidents (T-1257, T-1542, T-1634, T-1635, T-1673
  + this session's `fw config list` anchor)
- Evaluating the three structural levers
- Writing a recommendation that names the FIRST lever to fund
- Filing per-lever build tasks (separate IDs) on GO
- Registering the umbrella concern in `concerns.yaml`

**OUT of scope:**
- Implementing any of the levers in this task (per inception
  discipline; build tasks own implementation)
- Closing T-1542 / T-1634 / T-1635 — those retain their own scope and
  may be re-anchored under whichever lever ships first
- Cross-repo coordination with `/opt/termlink` (no substrate-side
  conflation observed)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated (≥3 prior incidents named, class boundaries clear)
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested — A2 spike (25-line bash classifier disambiguates 4 shapes across 4 synthetic + 13 live-host fixtures, zero misses) AND A3 spike (103 refs / 11 files / ~13 conflation sites — well under 50-site ceiling). Both load-bearing assumptions hold.
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale (Lever 1 first; Lever 2 next; Lever 3 over-Q)
<!-- @auto-tick-on-decide -->
- [x] Umbrella concern G-063 registered in `.context/project/concerns.yaml` linking constituent tasks

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

**Recommendation:** GO — start with Lever 1 (project-shape classifier)

**Rationale:** Lever 1 is the smallest investment with the broadest
return because most observed conflations vanish once classification is
centralized — there's literally one place to get the shape detection
right. Lever 2 (test matrix) becomes much cheaper to write AFTER
Lever 1 lands (3-shape fixtures all use `fw_project_context()` to
assert state). Lever 3 (upgrade-CI) is the highest-payoff long-term
but has the heaviest infrastructure (container substrate, ratchet
fixture management) and is partially captured in T-1635 already.

Sequence:
1. **Lever 1 first** — file as build task on GO, ~0.5 days. Single
   `fw_project_context()` function; refactor existing `[ -f
   .framework.yaml ]` sites that silently mis-handle non-consumer
   shapes (anchor: `_config_list` + `_config_get` + `_config_set` in
   `lib/config-file.sh`).
2. **Lever 2 next** — file as build task immediately after Lever 1
   ships. Three-shape fixture pattern + parametrized tests; one new
   fixture per public verb (`config list`, `doctor`, `metrics`,
   `audit`, `init`, `upgrade`).
3. **Lever 3 over Q** — promote T-1635 to `horizon: now` once Lever 1
   + Lever 2 establish the test scaffolding.

**Evidence:**
- Six prior incidents named in Problem Statement, all reducible to
  "framework code assumed one shape."
- T-1673 (this session) used the 3-fixture pattern (absolute /
  relative-existing / relative-missing) and the regression test
  pinned the fix in 0.66s with zero flakes — the pattern works.
- `lib/config-file.sh:177-181` is the smallest tractable
  demonstration of the conflation; fixing it via Lever 1 produces a
  visible win on the very next `fw config list` run from the
  framework repo.

**Tradeoff to flag:** Lever 1 is a touch-many-files refactor
(estimated <50 sites grepping `.framework.yaml`). Risk: scope creep.
Mitigation: strict criterion — only refactor sites where current
behavior is wrong, not every `[ -f .framework.yaml ]` check.

**Promotion criteria for revisiting:**
- If Lever 1 ships AND a new conflation incident still slips through →
  Lever 2 promotes immediately to `now`.
- If Lever 1 + Lever 2 ship AND a consumer reports an upgrade failure
  not caught locally → Lever 3 promotes to `now`.

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

**Rationale**: Recommendation: GO — start with Lever 1 (project-shape classifier)

Rationale: Lever 1 is the smallest investment with the broadest
return because most observed conflations vanish once classification is
centralized — there's literally one place to get the shape detection
right. Lever 2 (test matrix) becomes much cheaper to write AFTER
Lever 1 lands (3-shape fixtures all use `fw_project_context()` to
assert state). Lever 3 (upgrade-CI) is the highest-payoff long-term
but has the heaviest infrastructure (container substrate, ratchet
fixture management) and is partially captured in T-1635 already.

Sequence:
1. Lever 1 first — file as build task on GO, ~0.5 days. Single
   `fw_project_context()` function; refactor existing `[ -f
   .framework.yaml ]` sites that silently mis-handle non-consumer
   shapes (anchor: `_config_list` + `_config_get` + `_config_set` in
   `lib/config-file.sh`).
2. Lever 2 next — file as build task immediately after Lever 1
   ships. Three-shape fixture pattern + parametrized tests; one new
   fixture per public verb (`config list`, `doctor`, `metrics`,
   `audit`, `init`, `upgrade`).
3. Lever 3 over Q — promote T-1635 to `horizon: now` once Lever 1
   + Lever 2 establish the test scaffolding.

Evidence:
- Six prior incidents named in Problem Statement, all reducible to
  "framework code assumed one shape."
- T-1673 (this session) used the 3-fixture pattern (absolute /
  relative-existing / relative-missing) and the regression test
  pinned the fix in 0.66s with zero flakes — the pattern works.
- `lib/config-file.sh:177-181` is the smallest tractable
  demonstration of the conflation; fixing it via Lever 1 produces a
  visible win on the very next `fw config list` run from the
  framework repo.

Tradeoff to flag: Lever 1 is a touch-many-files refactor
(estimated <50 sites grepping `.framework.yaml`). Risk: scope creep.
Mitigation: strict criterion — only refactor sites where current
behavior is wrong, not every `[ -f .framework.yaml ]` check.

Promotion criteria for revisiting:
- If Lever 1 ships AND a new conflation incident still slips through →
  Lever 2 promotes immediately to `now`.
- If Lever 1 + Lever 2 ship AND a consumer reports an upgrade failure
  not caught locally → Lever 3 promotes to `now`.

**Date**: 2026-05-02T10:21:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-02T10:07:10Z — status-update [task-update-agent]
- **Change:** tags: +arc:project-shape-resilience

### 2026-05-02T10:21:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — start with Lever 1 (project-shape classifier)

Rationale: Lever 1 is the smallest investment with the broadest
return because most observed conflations vanish once classification is
centralized — there's literally one place to get the shape detection
right. Lever 2 (test matrix) becomes much cheaper to write AFTER
Lever 1 lands (3-shape fixtures all use `fw_project_context()` to
assert state). Lever 3 (upgrade-CI) is the highest-payoff long-term
but has the heaviest infrastructure (container substrate, ratchet
fixture management) and is partially captured in T-1635 already.

Sequence:
1. Lever 1 first — file as build task on GO, ~0.5 days. Single
   `fw_project_context()` function; refactor existing `[ -f
   .framework.yaml ]` sites that silently mis-handle non-consumer
   shapes (anchor: `_config_list` + `_config_get` + `_config_set` in
   `lib/config-file.sh`).
2. Lever 2 next — file as build task immediately after Lever 1
   ships. Three-shape fixture pattern + parametrized tests; one new
   fixture per public verb (`config list`, `doctor`, `metrics`,
   `audit`, `init`, `upgrade`).
3. Lever 3 over Q — promote T-1635 to `horizon: now` once Lever 1
   + Lever 2 establish the test scaffolding.

Evidence:
- Six prior incidents named in Problem Statement, all reducible to
  "framework code assumed one shape."
- T-1673 (this session) used the 3-fixture pattern (absolute /
  relative-existing / relative-missing) and the regression test
  pinned the fix in 0.66s with zero flakes — the pattern works.
- `lib/config-file.sh:177-181` is the smallest tractable
  demonstration of the conflation; fixing it via Lever 1 produces a
  visible win on the very next `fw config list` run from the
  framework repo.

Tradeoff to flag: Lever 1 is a touch-many-files refactor
(estimated <50 sites grepping `.framework.yaml`). Risk: scope creep.
Mitigation: strict criterion — only refactor sites where current
behavior is wrong, not every `[ -f .framework.yaml ]` check.

Promotion criteria for revisiting:
- If Lever 1 ships AND a new conflation incident still slips through →
  Lever 2 promotes immediately to `now`.
- If Lever 1 + Lever 2 ship AND a consumer reports an upgrade failure
  not caught locally → Lever 3 promotes to `now`.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-08a496fd
- **Timestamp:** 2026-06-02T14:59:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — Umbrella concern G-063 registered in `.context/project/concerns.yaml` linking constituent tasks
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/concerns.yaml in: Umbrella concern G-063 registered in `.context/project/concerns.yaml` linking constituent tasks`
### 2026-05-02T10:21:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
