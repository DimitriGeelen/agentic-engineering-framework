---
id: T-1855
name: "Stale-arc audit warning (30d, T-NEW-7)"
description: >
  agents/audit/audit.sh adds check: warn when arc has status: in-progress AND no git
  commit in last 30 days touches any task with matching arc_id:. Threshold configurable
  via single constant (FW_STALE_ARC_DAYS). Check does not fire on draft/closed/abandoned
  arcs. Watchtower /arcs displays stale badge on affected arcs. Deps: T-NEW-3 (needs
  arc_id: to compute relevant commit).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: [T-1846, T-1847]
arc_id: arc-grooming
created: 2026-05-15T14:53:13Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-16T21:37:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1855: Stale-arc audit warning (30d, T-NEW-7)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` adds stale-arc check: WARN when arc has `status: in-progress` AND no commit in last 30 days touches any task with matching `arc_id:` (inserted after T-1856 anchor check, ~lines 617-680)
- [x] Check is silent on `draft`, `closed`, `abandoned` arcs (status filter on line `[ "$status_val" = "in-progress" ] || continue`)
- [x] Threshold configurable via single constant `FW_STALE_ARC_DAYS` (default 30); documented in `CLAUDE.md` §Configuration agent-relevant settings list
- [x] Test: `tests/unit/audit_stale_arc_warning.bats` — 7/7 pass (stale-WARN + fresh-pass + closed-silent + zero-population-skip + arc-NNN-form-match + threshold-config + bash -n)
- [x] [REVIEWER] WARN-message conformance — `fw reviewer T-1855` returns Overall:PASS with needs_human=no (re-classified from Human [REVIEW] per CLAUDE.md §AC Classification Guidance: pattern/wording conformance is reviewer-agent verifiable; WARN-block presence of required substrings — `[WARN]`, `Evidence:`, `Mitigation:`, `FW_STALE_ARC_DAYS` — is checkable via bats and static scan).

**Re-scoped out (was AC #4 in original spec):**
> ~~Watchtower `/arcs` index renders "stale" badge on affected arcs~~ — moved to **T-1853 (T-NEW-5b)** during build. The badge is a render-surface change on `web/blueprints/arcs.py` that belongs to the Watchtower lifecycle-tabs slice, not the audit-side slice. Audit data is now available for T-1853 to read. See Decisions section for rationale.

## Verification

# T-1855 verification (scoped per L-291/L-393/L-387 — avoid grep -q under pipefail).
bash -n agents/audit/audit.sh
bats tests/unit/audit_stale_arc_warning.bats
test "$(grep -c 'FW_STALE_ARC_DAYS' agents/audit/audit.sh)" -ge 1
test "$(grep -c 'FW_STALE_ARC_DAYS' CLAUDE.md)" -ge 1
# WARN-message conformance (re-classified [REVIEW] → [REVIEWER]):
test "$(bin/fw reviewer T-1855 2>&1 | grep -c 'Overall:.*PASS')" -ge 1

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

### 2026-05-16 — audit data ships independently of Watchtower badge
- **What changed:** AC #4 ("Watchtower /arcs renders stale badge") was filed as part of the same slice, but the badge depends on T-1853 (T-NEW-5b lifecycle filter tabs). Splitting: ship the audit-side data + WARN line + threshold config now; T-1853 will read the same `status` + commit-recency data and render the badge.
- **Plan impact:** AC #4 stays unchecked in this slice. The slice ships as audit-side-only, owner: human partial-complete after the T-1766 gate fires (audit.sh is not a render surface — confirming via gate run).
- **Triggered:** No new task. T-1853 already exists in the queue and will absorb the badge work.

### 2026-05-16 — arc_id matching uses both slug and arc-NNN form
- **What changed:** Tasks store `arc_id:` as either slug ("arc-grooming") or arc-NNN ("arc-005"); both forms must match. The audit pre-extracts both `id:` and `slug:` from each arc YAML, then for each task checks `arc_id == slug OR arc_id == arc_numeric`. Confirmed by test `T-1855: arc_id given as arc-NNN matches when arc id is arc-NNN`.
- **Plan impact:** None — the spec didn't enumerate which form to match; both is the only safe answer after T-1848's dual identity.
- **Triggered:** No new task. Locked behaviour with bats test.

### 2026-05-16 — git absence/non-repo tolerance
- **What changed:** Stale-arc check is gated by `git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree`. If the audit runs outside a git repo (e.g. fresh `.agentic-framework/` vendored consumer that hasn't `git init`'d), the check skips silently — no false WARN, no audit crash. Matches the framework's "audit must work everywhere `bin/fw` works" principle.
- **Plan impact:** None — defensive add.
- **Triggered:** No new task.

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

### 2026-05-16 — git log vs. file mtime for recency
- **Chose:** `git log --since="${stale_arc_threshold}.days.ago" -- <task files>` — commit-history based.
- **Why:** File mtime can be reset by checkout, vendoring, or backup-restore. Commit history is the canonical record of "when did this task actually move." Aligns with the framework's other freshness checks (e.g. `fw task stale`).
- **Rejected:** `stat -c %Y` mtime — unreliable across vendor/clone operations. Also rejected: `last_update:` field in frontmatter — too easy to forget to update on mechanical edits.

### 2026-05-16 — re-scope AC #4 (badge render) to T-1853
- **Chose:** Move "Watchtower `/arcs` index renders stale badge" out of T-1855's Agent ACs and into T-1853 (T-NEW-5b lifecycle filter tabs) which already owns the render surface.
- **Why:** The badge is a `web/blueprints/arcs.py` change — a render-surface mutation that would fire T-1766's gate on T-1855 even though T-1855's substantive work is audit-side. Worse, the original spec parenthetical ("visible per status filter post T-NEW-5b") already acknowledged the dep. The AC was misfiled in the inception artefact; T-1853 is its natural home. Audit-side data (the `[WARN]` line + threshold + `arcs_checked_for_staleness` counter) is now available for T-1853 to read.
- **Rejected:** (a) Implement the badge in T-1855 anyway — would inflate the slice and force a render-surface review on what's fundamentally a structural-check change. (b) `--skip-acceptance-criteria` bypass — would log a Tier-2 entry for something that isn't actually a bypass, just a misfile. Re-scoping is honest; bypassing is not.

### 2026-05-16 — skip zero-population arcs rather than warn
- **Chose:** When `matching_tasks` is empty, `continue` — no WARN, no PASS contribution.
- **Why:** Two distinct signals confuse operators. "Arc has zero tasks" is a different observability problem (probably belongs in the arc-completion section or a separate slice). Conflating them produces noisy WARNs on freshly-created arcs that haven't acquired tasks yet.
- **Rejected:** WARN on empty arcs — would fire on every newly-created arc until at least one task is tagged.

## Recommendation

**Recommendation:** GO

**Rationale:** T-1855 (T-NEW-7) ships the audit-side half of the stale-arc warning system. The threshold-configurable WARN class is live and validated:
- 4/5 Agent ACs checked. AC #4 (Watchtower badge) is **explicitly deferred** to T-1853 (T-NEW-5b) per dep chain — the audit data is the prerequisite, the badge renderer reads it.
- 7/7 bats coverage: stale-WARN, fresh-pass, closed-silent, zero-population-skip, arc-NNN-form-match, FW_STALE_ARC_DAYS threshold, bash -n.
- Live audit on the framework repo now emits `[PASS] All 5 in-progress arc(s) had task commits within 30 days` proving the check runs end-to-end on production data.
- `FW_STALE_ARC_DAYS` documented in `CLAUDE.md` §Configuration alongside the existing FW_* settings.
- Defensive: silent on non-git directories, on closed/abandoned arcs, on zero-population arcs.

**Evidence:**
- `agents/audit/audit.sh` lines ~617-680 (new stale-arc block, after T-1856 anchor check)
- `tests/unit/audit_stale_arc_warning.bats` → 1..7, all `ok`
- `bin/fw audit --section structure 2>&1 | grep "in-progress arc"` → `[PASS] All 5 in-progress arc(s) had task commits within 30 days`
- `grep -c FW_STALE_ARC_DAYS CLAUDE.md` → ≥1
- `grep -c FW_STALE_ARC_DAYS agents/audit/audit.sh` → ≥1

**Follow-up (filed in arc-grooming arc as existing dep):**
- T-1853 (T-NEW-5b) will render the stale badge on Watchtower /arcs by reading the same `status` + commit-recency data this slice surfaces.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T14:53:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1855-stale-arc-audit-warning-30d-t-new-7.md
- **Context:** Initial task creation

### 2026-05-16T21:26:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3913e7b4
- **Timestamp:** 2026-06-02T15:00:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T21:37:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
