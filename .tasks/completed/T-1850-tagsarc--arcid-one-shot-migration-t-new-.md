---
id: T-1850
name: "tags:[arc:*] → arc_id one-shot migration (T-NEW-3)"
description: >
  Idempotent migration script lib/migrations/arc-id-migration.sh: scans .tasks/{active,completed}/,
  moves arc:X tag → arc_id: X field. T-1717 and T-1719 → arc_id: embeddings-strategy
  (Q3 decision). Multi-arc tasks halt unless --resolve flag supplied. Committable
  report written to .context/audits/arc-id-migration-YYYY-MM-DD.yaml (Q2 answer).
  Second run is no-op (idempotent). Deps: T-NEW-2.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [build, data-migration, idempotent, T-NEW-3]
components: [agents/context/check-arc-id.sh, C-009, 
      lib/migrations/arc-id-migration.sh, 
      tests/unit/arc_id_validation_guard.bats]
related_tasks: [T-1846, T-1847, T-1848, T-1717, T-1719]
arc_id: arc-grooming
created: 2026-05-15T14:52:50Z
last_update: '2026-05-19T17:56:23Z'
date_finished: 2026-05-16T09:27:46Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 4
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=4
      (body:framework-level-ux); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1850: tags:[arc:*] → arc_id one-shot migration (T-NEW-3)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/migrations/arc-id-migration.sh` exists, executable, supports `--dry-run` and `--apply` modes (plus `--resolve T-XXXX=ARC_ID` for multi-arc).
- [x] Migration scans `.tasks/{active,completed}/*.md`, moves `arc:X` from `tags:` list to `arc_id: X` field. Slug form by default; T-1848 arc-NNN form supported by the resolver. 162 tasks migrated.
- [x] T-1717 and T-1719 explicitly resolved to `arc_id: embeddings-strategy` (Q3 per-task decision from T-1846). Both verified post-migration.
- [x] Multi-arc tagged tasks (>1 `arc:*` tag) halt the run unless `--resolve TASK_ID=arc_id` flag supplied. Verified: dry-run with no --resolve flags halted with exit 3 + listed T-1717 + T-1719 with copy-pasteable --resolve hints.
- [x] Migration report at `.context/audits/arc-id-migration-<date>.yaml` with summary counts + migrated list + stale_arc_cleared list + resolutions_applied list.
- [x] Report is `git add`'d and committed atomically with the frontmatter changes (this commit).
- [x] Second run produces no further changes (idempotent). Verified: second `--apply` showed Migrated=0, Stale-arc-cleared=0, all 1841 tasks classified as no_arc_tag.
- [x] After migration: `grep -rE '^tags:.*arc:' .tasks/{active,completed}/` returns zero matches (verified manually).
- [x] Stale-arc class handled: `arc:ntfy` on T-708 + T-710 (no ntfy.yaml exists) stripped from tags without adding arc_id — would have failed T-1849 hook otherwise. Logged in report `stale_arc_cleared:` section.

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
# L-393 (T-1848): scope `bin/fw audit` to a section; use `grep -c >=1` not
# `grep -q` to avoid SIGPIPE-141 under pipefail.

# Script in place + executable
test -x lib/migrations/arc-id-migration.sh
# No arc:* tags left in active or completed
test "$(grep -lE '^tags:.*arc:' .tasks/active/*.md .tasks/completed/*.md 2>/dev/null | wc -l)" -eq 0
# Multi-arc cases resolved to embeddings-strategy
grep -q '^arc_id:[[:space:]]*embeddings-strategy' .tasks/completed/T-1717-*.md
grep -q '^arc_id:[[:space:]]*embeddings-strategy' .tasks/active/T-1719-*.md
# Stale arc tags cleared (no arc_id added)
test "$(grep -c '^arc_id:' .tasks/completed/T-708-*.md)" -eq 0
test "$(grep -c '^arc_id:' .tasks/completed/T-710-*.md)" -eq 0
# Migration report exists
test -f .context/audits/arc-id-migration-2026-05-16.yaml
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

### 2026-05-16 — stale-arc class surfaced by survey, not in original spec

- **What changed:** Inception (T-1846) named two known multi-arc cases (T-1717, T-1719). A pre-flight survey before writing the script also surfaced a **stale-arc** class: `arc:ntfy` referenced by T-708 + T-710 has no corresponding `.context/arcs/ntfy.yaml`. Naively migrating would set `arc_id: ntfy` and immediately fail T-1849's validation hook the next time the file was edited via Claude Code (hostage state — exactly what arc-grooming Q1 exists to prevent). Right behavior: strip the stale arc tag, do NOT set arc_id, log under `stale_arc_cleared:` in the report.
- **Plan impact:** Migration handles three classes, not two: (a) migrate (1 arc, exists), (b) stale-arc-clear (1 arc, missing), (c) multi-arc halt-or-resolve. AC #8 documents stale-arc explicitly.
- **Triggered:** No new sub-task. Stale-arc cases are captured in the committable report (T-1846 Q2) so a human reviewer can decide: register `ntfy.yaml` retroactively and re-migrate, or leave the tasks unassigned. Both T-708 + T-710 are completed work, so the latter is correct by default.

### 2026-05-16 — bash-side file writes bypass T-1849 hook by design

- **What changed:** The new T-1849 PreToolUse hook fires on Claude Code's Write|Edit tools — NOT on bash subprocess file writes. The migration script writes 164 task files via Python heredoc inside bash. Hook chain is silent for these writes. This is correct (the hook guards agent-driven authoring, not framework-internal migrations) but worth pinning so a future agent doesn't try to "fix" the migration to route through Write/Edit and trip its own gate.
- **Plan impact:** None — the design works. Worth noting that PreToolUse hooks are tool-scoped, not file-scoped; framework scripts editing files directly are exempt by mechanism, not by special-case.
- **Triggered:** No new sub-task. Inform via this Evolution entry + commit message.

## Recommendation

**Recommendation:** GO

**Rationale:** T-1850 closes arc-grooming inception Q2 (committable migration report) and Q3 (T-1717/T-1719 → embeddings-strategy). 162 of 164 arc-tagged tasks migrated cleanly to `arc_id:` field. 2 stale-arc cases (`arc:ntfy` with no arc YAML) had tags stripped without arc_id assignment — surfacing them in the report rather than creating hostage state. Multi-arc halt with copy-pasteable `--resolve` hints proved by dry-run. Idempotency proved by second `--apply` reporting 0 migrated. Post-state: zero `^tags:.*arc:` matches anywhere in `.tasks/{active,completed}/`. The new T-1849 hook does NOT fire on bash file writes (correctly) so the migration runs without self-tripping.

**Evidence:**
- `lib/migrations/arc-id-migration.sh`: ~270 lines, executable, --dry-run/--apply/--resolve flags
- `.context/audits/arc-id-migration-2026-05-16.yaml`: 162 migrated + 2 stale_arc_cleared + 2 resolutions_applied + 1677 no_arc_tag = 1841 scanned
- `grep -rE '^tags:.*arc:' .tasks/{active,completed}/`: zero matches post-migration
- Sample frontmatter inspections: T-1850 (arc-grooming), T-1717 (embeddings-strategy via --resolve), T-708 (stale arc:ntfy stripped, no arc_id), T-1719 (embeddings-strategy)
- Idempotent: second `--apply` reports 0 changes
- Multi-arc halt: dry-run without `--resolve` exits 3 with copy-pasteable hints

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

### 2026-05-16T09:20:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-1a2ac80e
- **Timestamp:** 2026-05-16T09:28:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-16T09:27:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** 162 tasks migrated, 2 stale-arc cleared, 2 multi-arc resolved, idempotency verified, 8/8 verification PASS
