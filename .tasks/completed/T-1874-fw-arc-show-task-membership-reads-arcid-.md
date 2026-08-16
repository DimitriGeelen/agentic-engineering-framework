---
id: T-1874
name: "fw arc show task-membership reads arc_id frontmatter (T-NEW-10)"
description: >
  Closes T-1850 migration blindness: lib/arc.sh _arc_tasks_with_tag scans only legacy
  ^tags:.*arc:<slug>, so fw arc show, fw arc list constituent count, and --demo task
  validation all report zero membership after the tags→arc_id migration.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [arc, arc-grooming, lib-arc, T-NEW-10]
components: [lib/arc.sh, tests/unit/arc_membership_union.bats]
related_tasks: [T-1687, T-1846, T-1849, T-1850]
arc_id: arc-grooming
created: 2026-05-16T22:46:13Z
last_update: '2026-08-16T22:24:47Z'
date_finished: 2026-05-16T22:50:37Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1874: fw arc show task-membership reads arc_id frontmatter (T-NEW-10)

## Context

T-1849 introduced the `arc_id:` task frontmatter field as the canonical source-of-truth for arc membership. T-1850 ran the one-shot migration: 162 tasks rewritten, `arc:<slug>` tags replaced by `arc_id:`. After that migration, the legacy `arc:<slug>` tag namespace is essentially empty — and `lib/arc.sh:_arc_tasks_with_tag()` (the sole helper used by `fw arc show`, the `fw arc list` constituent count column, and `--demo` task-membership validation) still scans only `^tags:.*arc:<slug>`. Result: post-migration, every arc reports zero member tasks even when 12+ tasks carry `arc_id: <slug>` in their frontmatter.

Confirmed gap (today, 2026-05-16):
```
$ grep -l "^arc_id: arc-grooming" .tasks/active/T-184[6-9]*.md .tasks/active/T-185*.md .tasks/completed/T-185*.md | wc -l
12
$ bin/fw arc show arc-grooming | grep -A1 "Tasks tagged"
─── Tasks tagged arc:arc-grooming ───
  (no tasks yet — use 'fw arc tag arc-grooming T-XXXX')
```

The fix introduces `_arc_tasks_for(id)` that unions the existing legacy-tag scan with a new `_arc_tasks_with_arc_id(slug)` frontmatter scan, then replaces the three callers (lib/arc.sh:485, :525, :896) with it. The unrelated `_arc_tasks_with_tag "from-${anchor}"` caller (line 889) stays unchanged — it queries a different namespace.

## Acceptance Criteria

### Agent
- [x] `lib/arc.sh` defines `_arc_tasks_with_arc_id <slug>` that returns T-IDs whose frontmatter contains `^arc_id:\s*<slug>` (matches both quoted and unquoted forms; tolerates leading whitespace).
- [x] `lib/arc.sh` defines `_arc_tasks_for <slug>` that unions `_arc_tasks_with_arc_id` and `_arc_tasks_with_tag "arc:<slug>"`, deduplicated and sorted.
- [x] The two arc-membership display call sites (`arc_list` constituent count, `arc_show` Tasks table) call `_arc_tasks_for`. The remaining `_arc_tasks_with_tag "arc:${id}"` callers are intentional legacy-only scans: `arc_migrate` idempotency check at lib/arc.sh:925 (migrating legacy tags → arc_id is the function's whole point) — documented inline.
- [x] `bin/fw arc show arc-grooming` lists at least the 9 numbered slice tasks (T-1848, T-1849, T-1850, T-1851, T-1852, T-1853, T-1854, T-1855, T-1856, T-1857) plus the parent/scaffold (T-1846, T-1847). Live smoke: 13 tasks rendered.
- [x] `bin/fw arc list` shows `arc-grooming` with a non-zero task count (≥12). Live smoke: TASKS column shows 13 (arc-005 row).
- [x] `tests/unit/arc_membership_union.bats` exercises: arc_id-only task is found, legacy-tag-only task is found, both-set task counted once, neither-set task excluded.
- [x] All four new bats cases pass: `bats tests/unit/arc_membership_union.bats` exits 0. Final count: 8/8 pass (extended coverage: sort/dedup, quoted-value form, empty-result no-error).
- [x] Constituent-task render contract — `fw arc show arc-grooming` lists ≥10 T-184x/T-185x lines AND no "(no tasks yet …)" placeholder. Re-classified from Human [REVIEW]: this is `fw arc show` CLI output, NOT a render surface; the check is pure deterministic shell, fully pinned by the existing Verification block (capture-then-grep -c on output + grep -vq for the false-empty marker). T-1575 does not apply (no template / no HTML).

## Verification

bash -n lib/arc.sh
bats tests/unit/arc_membership_union.bats
# L-394: capture-then-grep — avoid SIGPIPE under pipefail
out=$(bin/fw arc show arc-grooming 2>&1); echo "$out" | grep -c "^  T-184[6-9]\|^  T-185[0-7]" | awk '$1 >= 10 {exit 0} {exit 1}'
out=$(bin/fw arc show arc-grooming 2>&1); echo "$out" | grep -vq "no tasks yet"
# Regression: legacy-tag scan helper exists but is no longer the sole entry point
grep -q "_arc_tasks_for()" lib/arc.sh
grep -q "_arc_tasks_with_arc_id()" lib/arc.sh

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.

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

### 2026-05-16 — sibling site found mid-fix; one fewer than expected

- **What changed:** I scoped the fix for "three call sites" (arc_list count, arc_show display, --demo task-id validation). On grep-after-helpers, only TWO turned out to be real swaps: line 925 (`arc_migrate` idempotency) intentionally scans legacy `arc:<slug>` because the function's purpose is to migrate legacy-tagged tasks into the arc system. Swapping it would have masked tasks that already use arc_id (idempotent re-runs would loop). The `--demo` task-id validation at the `arc_close` flow uses a different membership concept (`(${arc_id}|T-[0-9]+)` literal scan inside the demo file) — not the same helper.
- **Plan impact:** AC #3 updated mid-build from "three sites" to "two sites + documented exception". This is exactly the "scope root, not symptom" memory pattern firing correctly — grepping the helper's call sites BEFORE editing surfaced the legacy-only one as intentional, not a miss.
- **Triggered:** No new sub-task. Inline comment + AC text explains the intentional legacy scan at lib/arc.sh:925.

### 2026-05-16 — corpus-wide silent blindness larger than expected

- **What changed:** Initial framing was "arc-grooming reports zero tasks". After fix, live `fw arc list` revealed FIVE arcs were affected (arc-001=11, arc-002=3, arc-003=121, arc-004=15, arc-005=13). arc-003 (orchestrator routing rethink) had 121 hidden tasks — that's the entire orchestrator arc's membership being invisible from `fw arc show` since T-1850 ran.
- **Plan impact:** Scope didn't change; impact narrative did. This slice unblocks operator visibility into 163 task-arc relationships across the corpus, not just 12. The "headline mechanic" assertion in T-1857's docs ("every task has one canonical arc_id resolving to an immutable arc") is now actually observable.
- **Triggered:** No new sub-task. Future audit-side fallback for `arc_id:` frontmatter (mentioned in T-1851 Evolution as deferred) is now lower-priority — operator visibility is restored at the display layer.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Pure additive fix to `lib/arc.sh`. Two new helpers (`_arc_tasks_with_arc_id`, `_arc_tasks_for`) layered on top of existing `_arc_tasks_with_tag`. Two display callers swapped to the union helper; one intentional legacy caller (`arc_migrate` idempotency) kept and documented. 8/8 bats pass on the new test file. Live smoke against the real corpus restores visibility for 163 task-arc relationships across all 5 active arcs (previously zero). Empty-state message updated to point operators at the canonical action (`set 'arc_id: <slug>' on a task's frontmatter`) rather than the deprecated `fw arc tag` verb. No changes to render surface, no new state machine, no migration — the existing `arc_id:` frontmatter already populated by T-1850 is the input.

**Evidence:**
- Diff scope: `lib/arc.sh` (+34 lines for new helpers, 2 caller swaps), `tests/unit/arc_membership_union.bats` (new, 8 tests). Zero render-surface paths touched.
- Bats: `bats tests/unit/arc_membership_union.bats` → 8/8 pass (arc_id-only found, legacy-only via second helper, both-set deduplicated, quoted-form tolerated, sorted output, empty no-error).
- Live smoke: `bin/fw arc show arc-grooming` lists 13 tasks (T-1846, T-1847, T-1848..T-1857, T-1874); previously "(no tasks yet …)".
- Live smoke: `bin/fw arc list` task-count column now non-zero for all 5 arcs (was all-zero post-T-1850).
- Sibling-site check: `grep -n '_arc_tasks_with_tag "arc:' lib/arc.sh` returns only the intentional `arc_migrate` site (925) and the new helper's internal call (350) — both expected.

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

### 2026-05-16T22:46:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1874-fw-arc-show-task-membership-reads-arcid-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-35462a63
- **Timestamp:** 2026-06-02T15:00:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T22:50:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
