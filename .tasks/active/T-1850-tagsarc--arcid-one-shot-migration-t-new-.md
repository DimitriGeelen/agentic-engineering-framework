---
id: T-1850
name: "tags:[arc:*] → arc_id one-shot migration (T-NEW-3)"
description: >
  Idempotent migration script lib/migrations/arc-id-migration.sh: scans .tasks/{active,completed}/, moves arc:X tag → arc_id: X field. T-1717 and T-1719 → arc_id: embeddings-strategy (Q3 decision). Multi-arc tasks halt unless --resolve flag supplied. Committable report written to .context/audits/arc-id-migration-YYYY-MM-DD.yaml (Q2 answer). Second run is no-op (idempotent). Deps: T-NEW-2.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [build, arc:arc-grooming, data-migration, idempotent, T-NEW-3]
components: []
related_tasks: [T-1846, T-1847, T-1848, T-1717, T-1719]
created: 2026-05-15T14:52:50Z
last_update: 2026-05-15T14:52:50Z
date_finished: null
---

# T-1850: tags:[arc:*] → arc_id one-shot migration (T-NEW-3)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] `lib/migrations/arc-id-migration.sh` exists, executable, supports `--dry-run` and `--apply` modes
- [ ] Migration scans `.tasks/{active,completed}/*.md`, moves `arc:X` from `tags:` list to `arc_id: X` (or `arc_id: arc-NNN` if T-1848 ID scheme is in effect) field
- [ ] T-1717 and T-1719 explicitly resolved to `arc_id: embeddings-strategy` (Q3 per-task decision from T-1846)
- [ ] Multi-arc tagged tasks (>1 `arc:*` tag) halt the run unless `--resolve TASK_ID=arc_id` flag supplied (refuse silent guess)
- [ ] Migration report at `.context/audits/arc-id-migration-<date>.yaml` with: count migrated, count skipped, multi-arc cases listed by task ID, resolutions applied
- [ ] Report is `git add`'d and committed atomically with the frontmatter changes
- [ ] Second run produces no further changes (idempotent — verified by `git status` returning clean after second invocation)
- [ ] After migration: `grep -rE 'tags:.*arc:' .tasks/{active,completed}/` returns zero matches

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

### 2026-05-15T14:52:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1850-tagsarc--arcid-one-shot-migration-t-new-.md
- **Context:** Initial task creation
