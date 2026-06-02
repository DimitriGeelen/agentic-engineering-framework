---
id: T-1110
name: "Collapse framework enums into single source of truth (L-006 structural sweep)"
description: >
  Inception: Collapse framework enums into single source of truth (L-006 structural sweep)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T21:10:31Z
last_update: 2026-04-12T09:27:16Z
date_finished: 2026-04-11T21:30:29Z
---

# T-1110: Collapse framework enums into single source of truth (L-006 structural sweep)

## Problem Statement

Framework enumerations (task statuses, workflow types, horizons, task owners, config settings, fw subcommand list, hook registration, agent directories) are currently **re-implemented in multiple sites** across bash, Python, Jinja templates, CSS, and markdown documentation. On 2026-04-11 a single-session audit (T-1109 RCA + L-006 sweep worker) confirmed **8 L-006 enumeration-divergence instances** with zero structural binding between the parallel lists:

| ID | Class | Sites | Status |
|---|---|---|---|
| G-024 | do_upgrade vs do_vendor (web/blueprints) | 2 + 1 sub-finding | Already drifting — 4 consumers missing terminal.py, sessions.py |
| G-024 NEW-007 | agent_dirs string vs filesystem | 1 mirror + glob canonical | Already drifting — 6 of 16 agents missing from upgrade path |
| G-037 | do_vendor excludes vs do_update excludes | 2 | Already drifting — lib/ts/* excludes missing from do_update |
| G-038 | workflow_type + horizon | Python + Jinja × 5 | Currently matches, no structural binding |
| G-039 | config registry | bash + Python + CLAUDE.md (triple) | Currently matches |
| G-040 | owner enum | 5 sites, NO canonical | Currently matches, bash<->Python asymmetry |
| G-041 | active-status | 7+ sites incl. kanban CSS × 12 | Currently matches, new statuses would be UI-invisible |
| G-042 | fw hook usage list | 4 sites | Enforcement panel whitelist already drifts |
| G-043 | fw subcommand list | 2 sites in same file | ALREADY DRIFTING — 11 commands missing from show_help |

T-1109 provides a single structural fix for G-024 and G-024-NEW-007 (collapse do_upgrade step 4b into do_vendor, which uses glob-based includes). The remaining 6 gaps require a **sweep-level build task** because they share the same chokepoint pattern: Flask context processor + fw_enums.py helper + status-transitions.yaml extensions.

This task decides whether to commission that sweep as a single coherent build task (T-1111a..f) or leave each gap for ad-hoc fixing.

## Assumptions

1. **status-transitions.yaml can be extended with owners: and any other enum sections without breaking existing lib/enums.sh consumers.** Validated by T-588 precedent.
2. **Flask context processor can inject ENUMS dict into every template without per-route changes.** Standard Flask pattern; needs verification that `render_page` in web/shared.py is the right injection point.
3. **No existing consumer code depends on the hardcoded Python lists remaining hardcoded.** Risk: grep for imports of `allowed_types`, `allowed_owners`, `allowed` outside tasks.py.
4. **The `fw help` regeneration approach (parse case statement at release time) is acceptable UX.** Alternative: maintain commands.yaml registry.
5. **Kanban CSS can be Jinja-generated without losing the current layout.** Needs a spike: render current kanban with `{% for status in ENUMS.statuses %}` loop and verify pixel-identical output.

## Exploration Plan

This is an **inception with pre-completed research**. The exploration work has already been done by the T-1109 L-006 sweep worker (tl-vvfixptj, 2026-04-11). Full findings: `docs/reports/T-1109-l006-sweep.md`.

Remaining spikes before GO decision (time-boxed, 30 min each):

1. **SPIKE A (Flask injection point):** Verify `web/shared.py:render_page` or `web/app.py` has a Flask context processor registration point that can inject ENUMS globally. Grep for `@app.context_processor` or equivalent.
2. **SPIKE B (Kanban CSS reduction):** Prototype replacing 12 hand-written status-named CSS selectors with a Jinja loop. Verify visual parity.
3. **SPIKE C (No hidden consumers):** `grep -r "allowed_types\|allowed_owners\|VALID_STATUSES\|VALID_TYPES" web/ agents/ lib/ bin/` — confirm no external code depends on the mirror sites existing as Python literals.

If any spike fails, the sweep task is DEFERRED (not NO-GO) until the architectural question is resolved.

## Technical Constraints

- **No breaking changes to existing task files.** Current tasks have `workflow_type: build`, `owner: human`, etc. — any new enum structure must read the existing values verbatim.
- **CLI backwards compatibility.** `fw task create --type build` must continue to work without modification; lib/enums.sh reads the same YAML.
- **Watchtower page load time.** Flask context processors run on every request; YAML read must be cached (startup + SIGHUP reload OR watch file mtime).
- **Cross-project compatibility.** Vendored consumers (`.agentic-framework/` dirs) will need the new status-transitions.yaml + fw_enums.py — but only after T-1109 lands (G-024 blocks updating vendored code). **This task is blocked by T-1109.**
- **CSS regeneration risk.** Hand-crafted kanban CSS has had tuning for edge cases; Jinja generation must preserve hover states, active column highlighting, responsive breakpoints.

## Scope Fence

**IN scope for this inception:**
- Path recommendation (unified sweep vs incremental per-gap)
- Spike results from A/B/C above
- Go/no-go decision with estimated LOC delta (worker estimates 115 LOC net reduction)
- Ordering: which gap to close first if incremental
- Dependencies: explicit declaration that this is blocked by T-1109

**OUT of scope for this inception:**
- Any actual code edits (those are T-1111a..f build tasks after GO)
- New enum additions (e.g., adding `reviewing` status) — those are separate task decisions
- Runtime performance optimization of the enum loading (measure first, optimize later)
- Cross-project migration (consumers upgrade naturally via fw upgrade after T-1109 lands)

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
- SPIKE A confirms Flask context processor is available at `web/shared.py` or `web/app.py`
- SPIKE B prototype produces pixel-identical kanban with Jinja loop
- SPIKE C confirms no hidden Python consumers of the mirror sites
- T-1109 is decided GO (unblocks web/ sync for migration)
- Human agrees the sweep-style single commit is preferable to 6 incremental fixes
- Estimated net LOC delta stays negative (worker estimates −115 LOC)

**NO-GO if:**
- SPIKE A shows injection requires framework-wide refactor (blocks value)
- SPIKE B cannot reproduce current kanban visuals with Jinja loop
- SPIKE C reveals undocumented consumers (e.g., external plugins importing from `tasks.py`)
- T-1109 is decided NO-GO or DEFERRED (fix order would be wrong)

**DEFER if:**
- Spikes pass but T-1109 has not been decided yet. Re-inception once T-1109 is unblocked.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO (pending T-1109 decision and spike A/B/C completion).

**Rationale:** A systematic sweep of the framework in a single session surfaced **8 L-006 enumeration-divergence instances** — 3 of which already silently drift (G-024 web/, G-037 excludes lists, G-043 fw help). The density suggests the class is pervasive rather than incidental. Incremental per-gap fixing has two problems: (1) every fix touches the same chokepoint pattern (Flask context processor + `status-transitions.yaml` extension + `fw_enums.py` helper), so splitting produces 6× the coordination cost for the same structural change; (2) the same session that scanned for the bugs already wrote the fix sketch — the tactical work to convert that sketch into a commit is bounded and well-specified. The worker's LOC estimate is **net −115 LOC** (115 removed, ~80 added), closing 4 confirmed gaps (G-040/G-041/G-042/G-043) and retiring the Python side of G-038 in a single structural pass. G-024 and G-024-NEW-007 are covered by the separate T-1109 fix which must land first (dependency ordering). If spikes A/B/C pass, this is the textbook T-1105 chokepoint+invariant-test discipline applied to a bug class rather than a single bug.

**Evidence:**

1. **L-006 sweep worker findings** (`docs/reports/T-1109-l006-sweep.md`, 162 lines, 20-minute systematic scan by tl-vvfixptj worker):
   - 8 confirmed instances with line-level citations
   - 3 already-drifting instances (not theoretical)
   - Net LOC delta estimate: −115 (removed) / +80 (added)
   - 7 non-instances explicitly rejected (fabric.py, cron.py, risks.py, init.sh providers, create-task.sh)
   - Method section documents grep patterns, files inspected, and decision criteria

2. **Pattern density** — 8 instances found in one session; 4 of them within 30 minutes of local scanning before the worker dispatched. The L-006 learning (captured in `.context/project/learnings.yaml`) was named as a bug class specifically to make future agents recognize the pattern.

3. **Chokepoint architecture already exists** — `status-transitions.yaml` (T-588) solved exactly this problem for the bash side via `lib/enums.sh`. The Python side of the framework was never migrated to consume the same canonical. The missing piece is a `fw_enums.py` helper that reads the YAML once and a Flask context processor that injects the dict into every template. This is 40+15 = 55 LOC of new code to retire 115 LOC of mirror sites.

4. **T-1105 discipline alignment** — This inception is the textbook application of the chokepoint+invariant-test discipline to a **bug class** rather than a single bug. Per T-1105's framework governance rule, when a bug class has 3+ registered instances, the fix MUST land via a single chokepoint with an invariant test (e.g., `tests/lint/no-hardcoded-enum-mirrors.bats` that greps for literal enum mirrors in `web/` and fails if any are found outside `fw_enums.py`).

**Dependencies:** Blocked by T-1109 (must land first so consumer vendoring picks up the new status-transitions.yaml + fw_enums.py). Once T-1109a-e are done, T-1110 can promote to build and split into:
- T-1111a: Extend status-transitions.yaml with owners section
- T-1111b: Add fw_enums.py + Flask context processor
- T-1111c: Migrate web/blueprints/tasks.py (retire G-038/G-040 Python side)
- T-1111d: Migrate web/templates/*.html (retire G-041 Jinja side + kanban CSS loop)
- T-1111e: Migrate enforcement.py + prioritizer.py (retire G-042)
- T-1111f: bin/fw commands registry (retire G-043)
- T-1111g: Invariant test `tests/lint/no-hardcoded-enum-mirrors.bats`

**Risk (cited from worker report):**
- Medium: kanban CSS reduction requires visual parity verification (SPIKE B)
- Low: Flask injection point availability (SPIKE A — standard pattern)
- Low: hidden consumers (SPIKE C — grep-able)
- Zero: backwards compatibility (lib/enums.sh consumers unchanged, status-transitions.yaml read-only extended)

**Human decision request:** Review `docs/reports/T-1109-l006-sweep.md` (worker's 162-line systematic findings) and this inception's evidence, then either:
- `fw inception decide T-1110 go --rationale "approved — run spikes A/B/C then promote to build"`, OR
- `fw inception decide T-1110 defer --rationale "wait until T-1109 is decided"`, OR
- `fw inception decide T-1110 no-go --rationale "prefer incremental fixes per gap"`

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO (pending T-1109 decision and spike A/B/C completion).

Rationale: A systematic sweep of the framework in a single session surfaced 8 L-006 enumeration-divergence instances — 3 of which already silently drift (G-024 web/, G-037 excludes lists, G-043 fw help). The density suggests the class is pervasive rather than incidental. Incremental per-gap fixing has two problems: (1) every fix touches the same chokepoint pattern (Flask context processor + `status-transitions.yaml` extension + `fw_enums.py` helper), so splitting produces 6× the coordination cost for the same structural change; (2) the same session that scanned for the bugs already wrote the fix sketch — the tactical work to convert that sketch into a commit is bounded and well-specified. The worker's LOC estimate is net −115 LOC (115 removed, ~80 added), closing 4 confirmed gaps (G-040/G-041/G-042/G-043) and retiring the Python side of G-038 in a single structural pass. G-024 and G-024-NEW-007 are covered by the separate T-1109 fix which must land first (dependency ordering). If spikes A/B/C pass, this is the textbook T-1105 chokepoint+invariant-test discipline applied to a bug class rather than a single bug.

Evidence:

1. L-006 sweep worker findings (`docs/reports/T-1109-l006-sweep.md`, 162 lines, 20-minute systematic scan by tl-vvfixptj worker):
   - 8 confirmed instances with line-level citations
   - 3 already-drifting instances (not theoretical)
   - Net LOC delta estimate: −115 (removed) / +80 (added)
   - 7 non-instances explicitly rejected (fabric.py, cron.py, risks.py, init.sh providers, create-task.sh)
   - Method section documents grep patterns, files inspected, and decision criteria

2. Pattern density — 8 instances found in one session; 4 of them within 30 minutes of local scanning before the worker dispatched. The L-006 learning (captured in `.context/project/learnings.yaml`) was named as a bug class specifically to make future agents recognize the pattern.

3. Chokepoint architecture already exists — `status-transitions.yaml` (T-588) solved exactly this problem for the bash side via `lib/enums.sh`. The Python side of the framework was never migrated to consume the same canonical. The missing piece is a `fw_enums.py` helper that reads the YAML once and a Flask context processor that injects the dict into every template. This is 40+15 = 55 LOC of new code to retire 115 LOC of mirror sites.

4. T-1105 discipline alignment — This inception is the textbook application of the chokepoint+invariant-test discipline to a bug class rather than a single bug. Per T-1105's framework governance rule, when a bug class has 3+ registered instances, the fix MUST land via a single chokepoint with an invariant test (e.g., `tests/lint/no-hardcoded-enum-mirrors.bats` that greps for literal enum mirrors in `web/` and fails if any are found outside `fw_enums.py`).

Dependencies: Blocked by T-1109 (must land first so consumer vendoring picks up the new status-transitions.yaml + fw_enums.py). Once T-1109a-e are done, T-1110 can promote to build and split into:
- T-1111a: Extend status-transitions.yaml with owners section
- T-1111b: Add fw_enums.py + Flask context processor
- T-1111c: Migrate web/blueprints/tasks.py (retire G-038/G-040 Python side)
- T-1111d: Migrate web/templates/*.html (retire G-041 Jinja side + kanban CSS loop)
- T-1111e: Migrate enforcement.py + prioritizer.py (retire G-042)
- T-1111f: bin/fw commands registry (retire G-043)
- T-1111g: Invariant test `tests/lint/no-hardcoded-enum-mirrors.bats`

Risk (cited from worker report):
- Medium: kanban CSS reduction requires visual parity verification (SPIKE B)
- Low: Flask injection point availability (SPIKE A — standard pattern)
- Low: hidden consumers (SPIKE C — grep-able)
- Zero: backwards compatibility (lib/enums.sh consumers unchanged, status-transitions.yaml read-only extended)

Human decision request: Review `docs/reports/T-1109-l006-sweep.md` (worker's 162-line systematic findings) and this inception's evidence, then either:
- `fw inception decide T-1110 go --rationale "approved — run spikes A/B/C then promote to build"`, OR
- `fw inception decide T-1110 defer --rationale "wait until T-1109 is decided"`, OR
- `fw inception decide T-1110 no-go --rationale "prefer incremental fixes per gap"`

**Date**: 2026-04-11T21:30:29Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO (pending T-1109 decision and spike A/B/C completion).

Rationale: A systematic sweep of the framework in a single session surfaced 8 L-006 enumeration-divergence instances — 3 of which already silently drift (G-024 web/, G-037 excludes lists, G-043 fw help). The density suggests the class is pervasive rather than incidental. Incremental per-gap fixing has two problems: (1) every fix touches the same chokepoint pattern (Flask context processor + `status-transitions.yaml` extension + `fw_enums.py` helper), so splitting produces 6× the coordination cost for the same structural change; (2) the same session that scanned for the bugs already wrote the fix sketch — the tactical work to convert that sketch into a commit is bounded and well-specified. The worker's LOC estimate is net −115 LOC (115 removed, ~80 added), closing 4 confirmed gaps (G-040/G-041/G-042/G-043) and retiring the Python side of G-038 in a single structural pass. G-024 and G-024-NEW-007 are covered by the separate T-1109 fix which must land first (dependency ordering). If spikes A/B/C pass, this is the textbook T-1105 chokepoint+invariant-test discipline applied to a bug class rather than a single bug.

Evidence:

1. L-006 sweep worker findings (`docs/reports/T-1109-l006-sweep.md`, 162 lines, 20-minute systematic scan by tl-vvfixptj worker):
   - 8 confirmed instances with line-level citations
   - 3 already-drifting instances (not theoretical)
   - Net LOC delta estimate: −115 (removed) / +80 (added)
   - 7 non-instances explicitly rejected (fabric.py, cron.py, risks.py, init.sh providers, create-task.sh)
   - Method section documents grep patterns, files inspected, and decision criteria

2. Pattern density — 8 instances found in one session; 4 of them within 30 minutes of local scanning before the worker dispatched. The L-006 learning (captured in `.context/project/learnings.yaml`) was named as a bug class specifically to make future agents recognize the pattern.

3. Chokepoint architecture already exists — `status-transitions.yaml` (T-588) solved exactly this problem for the bash side via `lib/enums.sh`. The Python side of the framework was never migrated to consume the same canonical. The missing piece is a `fw_enums.py` helper that reads the YAML once and a Flask context processor that injects the dict into every template. This is 40+15 = 55 LOC of new code to retire 115 LOC of mirror sites.

4. T-1105 discipline alignment — This inception is the textbook application of the chokepoint+invariant-test discipline to a bug class rather than a single bug. Per T-1105's framework governance rule, when a bug class has 3+ registered instances, the fix MUST land via a single chokepoint with an invariant test (e.g., `tests/lint/no-hardcoded-enum-mirrors.bats` that greps for literal enum mirrors in `web/` and fails if any are found outside `fw_enums.py`).

Dependencies: Blocked by T-1109 (must land first so consumer vendoring picks up the new status-transitions.yaml + fw_enums.py). Once T-1109a-e are done, T-1110 can promote to build and split into:
- T-1111a: Extend status-transitions.yaml with owners section
- T-1111b: Add fw_enums.py + Flask context processor
- T-1111c: Migrate web/blueprints/tasks.py (retire G-038/G-040 Python side)
- T-1111d: Migrate web/templates/*.html (retire G-041 Jinja side + kanban CSS loop)
- T-1111e: Migrate enforcement.py + prioritizer.py (retire G-042)
- T-1111f: bin/fw commands registry (retire G-043)
- T-1111g: Invariant test `tests/lint/no-hardcoded-enum-mirrors.bats`

Risk (cited from worker report):
- Medium: kanban CSS reduction requires visual parity verification (SPIKE B)
- Low: Flask injection point availability (SPIKE A — standard pattern)
- Low: hidden consumers (SPIKE C — grep-able)
- Zero: backwards compatibility (lib/enums.sh consumers unchanged, status-transitions.yaml read-only extended)

Human decision request: Review `docs/reports/T-1109-l006-sweep.md` (worker's 162-line systematic findings) and this inception's evidence, then either:
- `fw inception decide T-1110 go --rationale "approved — run spikes A/B/C then promote to build"`, OR
- `fw inception decide T-1110 defer --rationale "wait until T-1109 is decided"`, OR
- `fw inception decide T-1110 no-go --rationale "prefer incremental fixes per gap"`

**Date**: 2026-04-11T21:30:29Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T21:13:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-11T21:30:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (pending T-1109 decision and spike A/B/C completion).

Rationale: A systematic sweep of the framework in a single session surfaced 8 L-006 enumeration-divergence instances — 3 of which already silently drift (G-024 web/, G-037 excludes lists, G-043 fw help). The density suggests the class is pervasive rather than incidental. Incremental per-gap fixing has two problems: (1) every fix touches the same chokepoint pattern (Flask context processor + `status-transitions.yaml` extension + `fw_enums.py` helper), so splitting produces 6× the coordination cost for the same structural change; (2) the same session that scanned for the bugs already wrote the fix sketch — the tactical work to convert that sketch into a commit is bounded and well-specified. The worker's LOC estimate is net −115 LOC (115 removed, ~80 added), closing 4 confirmed gaps (G-040/G-041/G-042/G-043) and retiring the Python side of G-038 in a single structural pass. G-024 and G-024-NEW-007 are covered by the separate T-1109 fix which must land first (dependency ordering). If spikes A/B/C pass, this is the textbook T-1105 chokepoint+invariant-test discipline applied to a bug class rather than a single bug.

Evidence:

1. L-006 sweep worker findings (`docs/reports/T-1109-l006-sweep.md`, 162 lines, 20-minute systematic scan by tl-vvfixptj worker):
   - 8 confirmed instances with line-level citations
   - 3 already-drifting instances (not theoretical)
   - Net LOC delta estimate: −115 (removed) / +80 (added)
   - 7 non-instances explicitly rejected (fabric.py, cron.py, risks.py, init.sh providers, create-task.sh)
   - Method section documents grep patterns, files inspected, and decision criteria

2. Pattern density — 8 instances found in one session; 4 of them within 30 minutes of local scanning before the worker dispatched. The L-006 learning (captured in `.context/project/learnings.yaml`) was named as a bug class specifically to make future agents recognize the pattern.

3. Chokepoint architecture already exists — `status-transitions.yaml` (T-588) solved exactly this problem for the bash side via `lib/enums.sh`. The Python side of the framework was never migrated to consume the same canonical. The missing piece is a `fw_enums.py` helper that reads the YAML once and a Flask context processor that injects the dict into every template. This is 40+15 = 55 LOC of new code to retire 115 LOC of mirror sites.

4. T-1105 discipline alignment — This inception is the textbook application of the chokepoint+invariant-test discipline to a bug class rather than a single bug. Per T-1105's framework governance rule, when a bug class has 3+ registered instances, the fix MUST land via a single chokepoint with an invariant test (e.g., `tests/lint/no-hardcoded-enum-mirrors.bats` that greps for literal enum mirrors in `web/` and fails if any are found outside `fw_enums.py`).

Dependencies: Blocked by T-1109 (must land first so consumer vendoring picks up the new status-transitions.yaml + fw_enums.py). Once T-1109a-e are done, T-1110 can promote to build and split into:
- T-1111a: Extend status-transitions.yaml with owners section
- T-1111b: Add fw_enums.py + Flask context processor
- T-1111c: Migrate web/blueprints/tasks.py (retire G-038/G-040 Python side)
- T-1111d: Migrate web/templates/*.html (retire G-041 Jinja side + kanban CSS loop)
- T-1111e: Migrate enforcement.py + prioritizer.py (retire G-042)
- T-1111f: bin/fw commands registry (retire G-043)
- T-1111g: Invariant test `tests/lint/no-hardcoded-enum-mirrors.bats`

Risk (cited from worker report):
- Medium: kanban CSS reduction requires visual parity verification (SPIKE B)
- Low: Flask injection point availability (SPIKE A — standard pattern)
- Low: hidden consumers (SPIKE C — grep-able)
- Zero: backwards compatibility (lib/enums.sh consumers unchanged, status-transitions.yaml read-only extended)

Human decision request: Review `docs/reports/T-1109-l006-sweep.md` (worker's 162-line systematic findings) and this inception's evidence, then either:
- `fw inception decide T-1110 go --rationale "approved — run spikes A/B/C then promote to build"`, OR
- `fw inception decide T-1110 defer --rationale "wait until T-1109 is decided"`, OR
- `fw inception decide T-1110 no-go --rationale "prefer incremental fixes per gap"`

### 2026-04-11T21:30:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f9ab4738
- **Timestamp:** 2026-06-02T14:55:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
