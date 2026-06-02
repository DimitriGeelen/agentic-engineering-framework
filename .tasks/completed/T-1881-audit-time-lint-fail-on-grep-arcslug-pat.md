---
id: T-1881
name: "Audit-time lint: fail on grep arc:slug patterns without arc_id read"
description: >
  Future-prevention companion to T-1879 (T-NEW-14): add audit check or pre-commit lint that scans codebase for grep arc:slug or grep arc: patterns NOT paired with an arc_id read on the same code path. Catches silent-corpus #3 before it ships when a new consumer is added. Proposed audit name: ctl-arc-tag-only-pattern. Lives in agents/audit/audit.sh.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-grooming, future-prevention, audit-check]
components: [C-004, tests/unit/audit_ctl_arc_tag_only_pattern.bats]
related_tasks: [T-1879, T-1880]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T14:07:15Z
last_update: 2026-05-17T15:56:02Z
date_finished: 2026-05-17T15:56:02Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1881: Audit-time lint: fail on grep arc:slug patterns without arc_id read

## Context

Sibling future-prevention slice to T-1880 (shared `lib/arc_membership.{sh,py}`).
After T-1880 consolidation, the only legitimate occurrences of inline
`grep ... arc:<slug>` legacy-tag scans live in the canonical helpers
themselves (`lib/arc_membership.sh`, `lib/arc.sh`) and the one-shot
migration (`lib/migrations/arc-id-migration.sh`). Any NEW occurrence
elsewhere is silent-corpus #3 in waiting — a consumer reinventing the
inline scan and missing the `arc_id` half of the union.

This task adds an audit check (`ctl-arc-tag-only-pattern`) that scans
the framework code for the forbidden pattern and FAILs when it appears
outside the whitelisted canonical sites. The check runs as part of
`fw audit` and on every push (via pre-push audit gate).

Coverage:
- Scope: `lib/`, `web/`, `agents/`, `bin/`, `tools/` (non-test code paths)
- Allowlist: `lib/arc_membership.{sh,py}`, `lib/arc.sh`, `lib/migrations/`,
  `tests/`, `docs/`, `.fabric/` (canonical and ephemeral surfaces)
- Pattern detection: `grep` invocations targeting `arc:<slug>` /
  `^tags:.*arc:` legacy-tag-only scans
- Failure mode: FAIL (not WARN) — silent corpora are the exact class
  this check exists to prevent; tolerance defeats the purpose

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` has a `ctl-arc-tag-only-pattern` block (lines 679-714) that scans `lib/`, `web/`, `agents/`, `bin/`, `tools/` for `grep` invocations matching legacy `arc:<slug>` tag patterns
- [x] Allowlist excludes `lib/arc_membership.{sh,py}`, `lib/arc.sh`, `lib/migrations/`, `tests/`, `docs/`, `.fabric/`, `.context/`
- [x] When zero violations: emits `[PASS] No inline arc:<slug> tag-only scans outside canonical lib (T-1881)`
- [x] When violations found: emits `[FAIL]` per violation with file:line + evidence (first 5 lines) + mitigation pointing at `lib/arc_membership.{sh,py}`
- [x] Regression test pins the check: `tests/unit/audit_ctl_arc_tag_only_pattern.bats` (9 tests: clean-state PASS, synthetic violations in web/agents, allowlist coverage for tests/docs/canonical-lib, multi-violation count, false-positive guards for current_arc/arc_id)
- [x] Live tree scan returns 0 violations (`Violations: 0` against `PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework`)

### Human
<!-- No human verification required — pure static-scan lint, no rendering surface. -->

## Verification

cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/audit_ctl_arc_tag_only_pattern.bats
cd /opt/999-Agentic-Engineering-Framework && grep -q "ctl-arc-tag-only-pattern" agents/audit/audit.sh
# Live-tree sanity: 0 violations (post-T-1880 clean state). Inline bash
# rather than `fw audit` to avoid the full audit lifecycle (~90s+) in
# completion-gate Verification context.
cd /opt/999-Agentic-Engineering-Framework && test "$(PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash -c 'v=0; for d in lib web agents bin tools; do while IFS= read -r h; do [ -z "$h" ] && continue; case "$h" in *lib/arc_membership.sh:*|*lib/arc_membership.py:*|*lib/arc.sh:*|*lib/migrations/*|*tests/*|*docs/*|*.fabric/*|*.context/*) continue ;; esac; v=$((v+1)); done < <(grep -RnE "grep[^|]*\"\^?tags:.*arc:|grep[^|]*arc:[A-Za-z0-9_-]" --include="*.sh" --include="*.py" --include="*.bash" "$PROJECT_ROOT/$d" 2>/dev/null || true); done; echo $v')" = "0"

## RCA

This is a future-prevention build task (not a single-incident bug fix),
but the title keyword "fail" trips the bug-class classifier. Treating
the silent-corpus-#1+#2 cluster as the originating "bug" the RCA
addresses:

**Symptom:** Two clusters of silent-corpus surfaces (T-1874/75/76/77
and T-1879) where every consumer site reading legacy `arc:<slug>` tags
inline returned zero rows after the T-1850 storage migration. 9 sites
fixed across 4 commits over 2 days; users discovered each via missing
counts on /arcs landing, /tasks?arc filter, audit blindness, handover
narrative drift.

**Root cause:** Each consumer re-implemented the legacy-tag scan
inline as a one-line `grep arc:<slug>`. The T-1850 migration converted
storage but left every consumer to update independently. With no
canonical helper and no audit lint, the framework had no way to detect
inline scans that missed the `arc_id:` half of the union.

**Why structurally allowed:** No shared library forced consolidation
(T-1880 fixes this). No audit check forbade the inline pattern
(this task fixes that). The bug class is "duplicated read-paths
across a storage format boundary" — invisible until a migration runs.

**Prevention:**
- T-1880 — canonical shared `lib/arc_membership.{sh,py}` so future
  migrations update one location.
- T-1881 (this task) — audit check `ctl-arc-tag-only-pattern` that
  FAILs on any inline `grep arc:<slug>` outside the canonical sites,
  enforced via `fw audit` and pre-push gate. Catches silent-corpus-#3
  at the moment of introduction.
- L-396 (brace+pipe output drop), L-397 (silent-corpus migration
  pattern) — captured as framework learnings + auto-memory.

## Evolution

### 2026-05-17 — Allowlist scope wider than originally planned

- **What changed:** Initial plan listed allowlist as just
  `lib/arc_membership.{sh,py}` + `lib/migrations/`. Survey of the
  current tree showed legitimate non-canonical inline scans in
  `lib/arc.sh` (legacy thin-wrapper helpers kept as compat shim by
  T-1880's design decision).
- **Plan impact:** Expanded allowlist to: canonical lib + lib/arc.sh
  (T-1880 compat) + lib/migrations/ (one-shot) + tests/ + docs/ +
  .fabric/ + .context/ (ephemeral surfaces).
- **Triggered:** Updated ACs and check code to reflect the wider
  allowlist; no new sub-task needed.

### 2026-05-17 — Test strategy: extract check block, not run fw audit

- **What changed:** Originally intended to test by running `fw audit`
  end-to-end and grepping output. The audit takes >90s per invocation
  (full lifecycle: stale-tasks + structure + arc-progress + fabric +
  cron + secret-scan + ...). Running it per-test makes the bats suite
  flaky and slow.
- **Plan impact:** Extract the check-block logic into the bats test's
  `run_check` helper — sources just the pattern + allowlist code,
  evaluates against a synthetic PROJECT_ROOT. 9 tests run in ~150ms
  total. Live tree separately verified once via inline bash one-liner
  ('Violations: 0') and committed to memory.
- **Triggered:** None — internal test architecture.

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

## Recommendation

- **Recommendation:** GO — ship. Pure static-scan lint; no rendering
  surface; all checks deterministic.
- **Rationale:** Completes the L-397 silent-corpus-migration prevention
  layer started by T-1880. T-1880 consolidates so future migrations
  only update one place; T-1881 catches the case where someone bypasses
  the canonical lib and reintroduces inline scans. Together: one place
  to maintain + enforcement that prevents drift.
- **Evidence:**
  - 9/9 bats tests pass: `tests/unit/audit_ctl_arc_tag_only_pattern.bats`
  - Live tree returns 0 violations (clean post-T-1880 consolidation)
  - False-positive guards verified: `current_arc:` lookups, `arc_id:`
    reads, tests/, docs/, canonical lib all exempt
  - FAIL emits file:line evidence + mitigation pointer to
    `lib/arc_membership.{sh,py}`
  - No render-surface touched (audit.sh + test only) → completion gate
    does NOT route to partial-complete; this can close cleanly.

## Updates

### 2026-05-17T14:07:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1881-audit-time-lint-fail-on-grep-arcslug-pat.md
- **Context:** Initial task creation

### 2026-05-17T15:42:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-70d12e24
- **Timestamp:** 2026-06-02T15:00:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T15:56:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
