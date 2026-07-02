---
id: T-1256
name: "Implement weekly release tagging + push-tags fix"
description: >
  Implement weekly release tagging + push-tags fix

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-14T20:42:44Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-14T21:22:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1256: Implement weekly release tagging + push-tags fix

## Context

Build follow-up from T-1255 inception (GO recorded). Four deliverables:

1. **Push fix:** `handover.sh:759` → `git push --follow-tags HEAD`
2. **Weekly auto-tag:** `lib/release.sh` + cron entry that cuts `v1.5.N` when commits exist since last tag
3. **Release automation:** same script calls `gh release create --generate-notes` after successful tag push
4. **Backfill already done tactically (v1.5.742 pushed + Release created)** — structural fix ensures next bump also reaches remotes

Research artifact: `docs/reports/T-1255-release-tagging.md`

## Acceptance Criteria

### Agent
- [x] `agents/handover/handover.sh` line 759 uses `git push --follow-tags` (not bare `push HEAD`)
- [x] `lib/release.sh` exists with `tag-and-release` subcommand that:
      (a) exits 0 if no commits since last tag (idempotent),
      (b) computes next version by patch-bumping the latest v* tag,
      (c) creates annotated tag,
      (d) pushes tag to all remotes (github + onedev),
      (e) calls `gh release create --generate-notes --latest` if `gh` available
- [x] Cron registry entry `release-weekly` added to `.context/cron-registry.yaml` (Monday 10:00)
- [x] `fw release` command routes to `lib/release.sh release_main` (`--dry-run`, `--bump`, `status`, `help` supported)
- [x] Dry-run shows what would happen without making changes
- [x] Unit tests: `tests/unit/lib_release.bats` — 17 tests, all passing (bumping, idempotent, dry-run, status, main routing, happy path with tag creation)
- [x] All existing tests still pass (`fw test unit` → 747 tests, exit 0)

## Verification

grep -q "push --follow-tags" agents/handover/handover.sh
test -x lib/release.sh
bin/fw release --dry-run 2>&1 | grep -qE "would (tag|skip)"
bin/fw test unit 2>&1 | tail -1 | grep -qE "ok |pass"

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

### 2026-04-14T20:42:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1256-implement-weekly-release-tagging--push-t.md
- **Context:** Initial task creation

### 2026-04-14T21:22:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b63e311d
- **Timestamp:** 2026-06-02T14:56:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#3 (Agent)** — Cron registry entry `release-weekly` added to `.context/cron-registry.yaml` (Monday 10:00)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/cron-registry.yaml in: Cron registry entry `release-weekly` added to `.context/cron-registry.yaml` (Monday 10:00)`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bin/fw release --dry-run 2>&1 | grep -qE "would (tag|skip)"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw test unit 2>&1 | tail -1 | grep -qE "ok |pass"`
