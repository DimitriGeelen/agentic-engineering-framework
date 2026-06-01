---
id: T-1849
name: "Task arc_id field + Tier-1 validation block (T-NEW-2)"
description: >
  Add arc_id: optional frontmatter field to task schema (template + CLAUDE.md doc); PreToolUse hook refuses task save when arc_id is set + non-empty + does not resolve to .context/arcs/*.yaml (Tier-1 block, Q1 answer). Empty arc_id passes through. Predicated on D-Immutability: valid refs stay valid forever; no hostage state possible. Deps: T-1848 (T-NEW-1.5). Anchor: T-1846.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [build, schema-migration, task-system, validation, T-NEW-2]
components: [C-004, agents/context/check-arc-id.sh, C-009, lib/arc.sh, tests/unit/arc_id_validation_guard.bats, web/blueprints/arcs.py, web/blueprints/core.py]
related_tasks: [T-1846, T-1847, T-1848]
arc_id: arc-grooming
created: 2026-05-15T14:52:45Z
last_update: 2026-05-16T09:19:36Z
date_finished: 2026-05-16T09:19:36Z
---

# T-1849: Task arc_id field + Tier-1 validation block (T-NEW-2)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/default.md` contains `arc_id:` field (commented, optional) — added with inline doc pointing at CLAUDE.md §Task System.
- [x] `CLAUDE.md` §Task System documents `arc_id:` semantics (optional, single-valued; accepts slug form `dispatch-safety` OR arc-NNN form `arc-001`; resolves to `.context/arcs/*.yaml`; override `FW_ALLOW_ARC_ID_DRIFT=1` logged Tier-2; coexists with legacy `tags: [arc:*]` until T-1850).
- [x] PreToolUse hook on Write/Edit blocks task save when `arc_id:` is set + non-empty + does not resolve to an existing arc YAML (exit 2 with actionable message, lists available arcs). Implementation: `agents/context/check-arc-id.py` (Python core) + `agents/context/check-arc-id.sh` (bash wrapper), wired via `fw hook-enable --name check-arc-id --matcher "Write|Edit" --event PreToolUse`.
- [x] Empty/missing/`null` `arc_id:` passes through (unassigned tasks allowed). Covered by bats T-1849 tests #1-3.
- [x] Test: writing a task with `arc_id: nonexistent-arc` → blocked; `arc_id: arc-001` (T-1848 form) or `arc_id: dispatch-safety` (slug form) → passes; empty → passes. Plus Edit-tool tool-substitution case + path-scoping (non-task files skipped) + tool-name filter (Bash skipped) + override env. Full coverage in `tests/unit/arc_id_validation_guard.bats` (15/15 pass).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# L-393 (T-1848): scope `bin/fw audit` to a section. Use `grep -c >=1` not `grep -q`
# to avoid SIGPIPE-141 under pipefail.

# Hook files in place
test -x agents/context/check-arc-id.sh
test -f agents/context/check-arc-id.py
python3 -m py_compile agents/context/check-arc-id.py
# Hook wired into settings.json
grep -q "check-arc-id" .claude/settings.json
# Template has arc_id documented
grep -q "^# arc_id:" .tasks/templates/default.md
# CLAUDE.md documents arc_id
grep -q "arc_id.*T-1849" CLAUDE.md
# Test suite passes
bats tests/unit/arc_id_validation_guard.bats >/dev/null 2>&1
# Audit clean (scope-tight per L-393)
test "$(bin/fw audit --section structure 2>&1 | grep -c 'Fail: 0')" -ge 1

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

### 2026-05-16 — single-field arc_id, no list semantics

- **What changed:** Inception (T-1846) left open whether `arc_id` should be a list (tasks in multiple arcs) or single-valued. Building revealed the right answer is single-valued — multi-arc semantics overlap badly with the existing `tags: [arc:*]` convention and complicate the hostage-state check (which arc must resolve? all? any?). Single-valued + `tags:` as escape hatch for genuinely cross-cutting work keeps the invariant clean: "if arc_id is set, it resolves; if you need many, use tags."
- **Plan impact:** Schema is `arc_id: <single value or empty>`, not `arc_id: [list]`. CLAUDE.md doc states this explicitly. T-1850 migration (`tags:[arc:*]` → `arc_id`) picks ONE arc per task (the first match wins; ambiguous tasks logged for human triage).
- **Triggered:** No new sub-task. T-1850 will deal with multi-arc tag rare-case via a manual triage list.

### 2026-05-16 — bypass-log format reused T-1142 single-quote convention (L-392)

- **What changed:** When writing `log_bypass()` in check-arc-id.py, lifted the YAML emission pattern verbatim from check-human-ac-tick.py — single-quoted scalars with `'→''` escaping, NOT double-quoted. This is L-392's prevention: any new bypass-log writer reuses this idiom without thinking. Pattern propagating naturally.
- **Plan impact:** None — the pattern was already canonical. Worth noting as positive evidence that L-392's META-LEARNING ("YAML scalar quoting is a class") is now habitual rather than per-incident.
- **Triggered:** No new task; just memetic propagation working.

## Recommendation

**Recommendation:** GO

**Rationale:** T-1849 ships the hostage-state guard from arc-grooming inception Q1 (T-1846), predicated on T-1848's D-Immutability axiom. The PreToolUse hook `check-arc-id` enforces the invariant *under agent control only* (CLAUDECODE=1 or AI_AGENT set) — interactive human edits get an advisory note but pass. Empty/missing/null `arc_id` always passes, so existing tasks are not retroactively blocked. Both slug and arc-NNN forms validate. 15/15 bats tests cover all branches (pass cases, block cases, override, path-scoping, tool-name filter, Edit substitution, hook compilation). Cross-cutting: bypass-log format reused L-392 single-quote idiom verbatim.

**Evidence:**
- `agents/context/check-arc-id.py`: Python core, ~200 lines, mirrors check-human-ac-tick.py shape
- `agents/context/check-arc-id.sh`: bash wrapper, exec→python3
- `.claude/settings.json`: hook wired via `fw hook-enable --name check-arc-id --matcher "Write|Edit" --event PreToolUse`
- `.tasks/templates/default.md`: `arc_id:` field added (commented, optional)
- `CLAUDE.md` §Task System: "Optional frontmatter fields" subsection documents arc_id semantics (slug + arc-NNN, override, coexistence with `tags:[arc:*]`)
- `tests/unit/arc_id_validation_guard.bats`: 15/15 pass — empty/null/missing pass; valid slug + arc-NNN pass; invalid blocks; override allows + logs; non-CLAUDECODE advisory; non-task files skipped; Bash tool skipped; Edit substitution detected
- Override path writes `.context/working/.gate-bypass-log.yaml` in L-392 single-quoted YAML form

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:52:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1849-task-arcid-field--tier-1-validation-bloc.md
- **Context:** Initial task creation

### 2026-05-16T09:10:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-c98bb166
- **Timestamp:** 2026-05-16T09:20:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 24
     - evidence: `bats tests/unit/arc_id_validation_guard.bats >/dev/null 2>&1`

### 2026-05-16T09:19:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** All 5 ACs met, 8/8 verification commands PASS, 15/15 bats tests PASS, no Human ACs (no render surface touched)
