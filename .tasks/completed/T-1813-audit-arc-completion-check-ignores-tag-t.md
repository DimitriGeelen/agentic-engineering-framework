---
id: T-1813
name: "audit arc-completion check ignores tag-tagged tasks — uses constituent_tasks only; dispatch-safety arc invisible at 6/6"
description: >
  audit arc-completion check ignores tag-tagged tasks — uses constituent_tasks only; dispatch-safety arc invisible at 6/6

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, bug, framework-blindness]
components: [C-004]
related_tasks: [T-1812, T-1811, T-1805, T-1806, T-1807, T-1808, T-1809, T-1810]
arc_id: dispatch-safety
created: 2026-05-13T18:47:28Z
last_update: 2026-05-13T19:00:53Z
date_finished: 2026-05-13T19:00:53Z
---

# T-1813: audit arc-completion check ignores tag-tagged tasks — uses constituent_tasks only; dispatch-safety arc invisible at 6/6

## Context

`agents/audit/audit.sh` arc-completion check (line ~3370-3426) parses `constituent_tasks` from each arc YAML to compute completion ratio. When `constituent_tasks: []` is empty, line 3402 silently `continue`s — skipping the arc entirely. The dispatch-safety arc has 6 work-completed tasks but they live via tag `arc:dispatch-safety`, not via the `constituent_tasks` list. Result: the arc is invisible to the audit's G-062 closure-pressure check. Today's audit shows orchestrator-rethink (28/31, 0.90) → WARN but says nothing about dispatch-safety (6/6, 1.00) which is at 100% completion and a perfect closure-pressure candidate.

This is the same data-source inconsistency T-1811 captured at the AC level: `fw arc show` uses tag-based scanning (`_arc_tasks_with_tag arc:${id}` in lib/arc.sh:290), while the audit uses the old `constituent_tasks` pathway. Tasks tagged via `fw task update --add-tag arc:foo` (instead of `fw arc tag`) never make it into `constituent_tasks`, so the audit goes blind.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` arc-completion check falls back to tag-based scan when `constituent_tasks` is empty: inline python tag-scan added at lines ~3389-3411 mirroring `lib/arc.sh:_arc_tasks_with_tag` so audit and `fw arc show` use the same task-discovery pathway
- [x] After the fix, `bin/fw audit 2>&1 | grep dispatch-safety` shows the dispatch-safety arc — verified live: `[WARN] Arc 'dispatch-safety': 7/8 tasks completed (0.8750) but arc still in-progress`
- [x] No regression: existing arcs continue to appear — verified live: `embeddings-strategy 1/3`, `orchestrator-rethink 28/31`, `project-shape-resilience 3/6`
- [x] `bin/fw audit` Pass/Warn/Fail counts incremented correctly — before: Warn=28; after: Warn=29 (+1 for dispatch-safety closure pressure)

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

# Use saved audit YAML to avoid audit-lock conflicts when multiple
# verifications run sequentially. Each line is a separate shell invocation
# so the audit path is inlined in each grep rather than via a variable.
grep -E "Arc 'dispatch-safety'" "$(ls -t .context/audits/2026-*.yaml | head -1)" | grep -qE "[0-9]+/[0-9]+ tasks completed"
grep -E "Arc 'orchestrator-rethink'" "$(ls -t .context/audits/2026-*.yaml | head -1)" | grep -qE "[0-9]+/[0-9]+"
grep -E "Arc 'embeddings-strategy'" "$(ls -t .context/audits/2026-*.yaml | head -1)" | grep -qE "[0-9]+/[0-9]+"

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

**Symptom:** Today's `bin/fw audit` reported closure-pressure for `orchestrator-rethink` (28/31, 0.90) but said NOTHING about `dispatch-safety` — even though dispatch-safety has 6 work-completed slice tasks (T-1805..T-1810) tagged `arc:dispatch-safety` and would otherwise hit a 6/6 (1.00) closure-pressure WARN. Discovered while triaging next steps after T-1812 reviewer-pass — the agent expected to see a closure-pressure signal for dispatch-safety and didn't.

**Root cause:** `agents/audit/audit.sh` arc-completion check parsed the `constituent_tasks: [...]` field from each arc YAML. For `dispatch-safety.yaml`, `constituent_tasks: []` is empty — the arc's tasks were tagged via `fw task update --add-tag arc:dispatch-safety` (or equivalent direct edit) rather than `fw arc tag` (which would have populated `constituent_tasks`). When `total=0`, the audit hit line 3402 `continue` and silently skipped the arc.

**Why structurally allowed:** Data-source drift between two task-discovery pathways for arcs:
1. **`fw arc show <id>`** uses `lib/arc.sh:_arc_tasks_with_tag` — scans `.tasks/{active,completed}/*.md` for the `arc:<id>` tag
2. **`agents/audit/audit.sh` arc-completion check** uses `constituent_tasks` field of the arc YAML

When a task is added to an arc via tagging (not via `fw arc tag`), it shows up in (1) but is invisible to (2). The audit produced false negatives for tag-only arcs. This is the same vocabulary-substrate drift pattern T-1811 captured at the AC level (T-1443 reviewer-agent vocabulary updated, T-954 classification did not) — same L-340 class: substrate introduced without the audit/check infrastructure being updated to read from it.

**Prevention:** Tag-based fallback added directly in audit.sh's python heredoc (lines ~3389-3411) — when `constituent_tasks` is empty, scan `.tasks/{active,completed}/*.md` for files whose `tags:` line contains `arc:<id>`, extract `id:` field. Same algorithm as `_arc_tasks_with_tag`, inlined to avoid the python<->shell boundary cost. Tested live: dispatch-safety arc now surfaces correctly; no regression on the 3 already-visible arcs.

Longer-term consideration (not in scope here): the two discovery pathways should converge — either always tag-scan, or auto-populate `constituent_tasks` from tags on every `fw arc show`/audit call. For now, the fallback closes the silent-skip gap.

## Evolution

### 2026-05-13 — Arc shows 7/8 not 6/6 (tag scope wider than slice tasks)
- **What changed:** Initial AC said "the correct 6/6 ratio" assuming only T-1805..T-1810 are tagged `arc:dispatch-safety`. Actually 8 tasks carry the tag: the 6 slice tasks PLUS T-1812 (reviewer-pass on the arc, completed 4 min before) PLUS T-1813 (this fix task, started). So the live audit reads 7/8 (T-1813 still started-work). After this task completes → 8/8 (1.0).
- **Plan impact:** Updated Verification commands to assert any `[0-9]+/[0-9]+` pattern matches rather than the exact 6/6, since the tagged set is wider than just the spec slices and grows as arc-adjacent tasks ship.
- **Triggered:** None — recognition that "arc tasks" is broader than "spec slices" is consistent with how the framework already uses tags (T-1812 is arc-adjacent infra, T-1813 is arc audit-blindness fix). The discovery is good: it means the audit fix has wider effect than just the original spec slices.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes a silent framework-blindness pattern (same L-340 class as T-1811): the audit's closure-pressure check used `constituent_tasks` only, while `fw arc show` used tag-based scan — so arcs whose tasks are tagged (not explicitly listed) were invisible to the audit's G-062 detection. Dispatch-safety v1 is genuinely at code-complete (now 7/8, will be 8/8 on this task's completion) but the audit had no signal until this fix. Minimal-surface change: tag-based fallback inlined in audit.sh's python heredoc, mirroring lib/arc.sh's existing algorithm.

**Evidence:**
- Before: `bin/fw audit 2>&1 | grep dispatch-safety` returned nothing (4 audits in a row, per `.context/audits/2026-05-{06,07,09,10,13}.yaml`)
- After: `[WARN] Arc 'dispatch-safety': 7/8 tasks completed (0.8750) but arc still in-progress`
- No regression on the 3 already-visible arcs (orchestrator-rethink 28/31, embeddings-strategy 1/3, project-shape-resilience 3/6)
- Pass/Warn counts shifted correctly: Pass: 390→390 (no PASS-class for the arc, since it's an in-progress-with-pressure WARN), Warn: 28→29 (+1)

**Next steps (not in this task):**
1. Longer-term convergence: either always tag-scan in audit, or auto-populate `constituent_tasks` from tags via a sync helper. Open question — file as inception if discovery surfaces additional drift patterns.
2. Watchtower `/orchestrator` or arc dashboard panel could similarly surface tag-based completion ratios (parity check)
3. **L-370 capture candidate:** "Audit/observability checks must use the same task-discovery pathway as the CLI verb that creates the relationship. Pattern: tag-based scan ↔ `_arc_tasks_with_tag`. If audit/X uses `Y_field` and `fw verb` uses `tag-scan`, the two diverge silently — file at discovery, not at next audit."

## Decisions

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-13T18:47:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1813-audit-arc-completion-check-ignores-tag-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-79cacaed
- **Timestamp:** 2026-05-13T19:00:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/audit/audit.sh` arc-completion check falls back to tag-based scan when `constituent_tasks` is empty: inline python tag-scan added at lines ~3389-3411 mirroring `lib/arc.sh:_arc_tasks_with_tag`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `agents/audit/audit.sh` arc-completion check falls back to tag-based scan when `constituent_tasks` is empty: inline python tag-scan added at lines ~33`

### 2026-05-13T19:00:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
