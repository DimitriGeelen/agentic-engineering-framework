---
id: T-1829
name: "VERSION-stamping algorithm not cross-tag-monotonic — Level-C fix for T-1828
  class"
description: >
  Level-C fix for the class T-1828 surfaced. Current VERSION stamping in agents/git/lib/hooks.sh
  uses `git describe --tags --match 'v[0-9]*'` and stamps `<major>.<minor>.<commits-since-tag>`.
  The commits-since-tag counter resets to 0 at each new v<M>.<m>.<p> tag, causing
  local VERSION to numerically drop below remote VERSION at the next push. T-1603
  pre-push hook then blocks as monotonicity violation even when commit time is strictly
  newer. Need a stamping algorithm OR a hook upgrade that handles cross-tag-monotonicity
  correctly.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [version-monotonicity, mirror-sync, fw-upgrade-incident-2026-05-14]
components: [agents-git-lib-hooks, lib-mirror, VERSION]
related_tasks: [T-1602, T-1603, T-1828]
created: 2026-05-14T18:24:14Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-14T20:29:30Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1829: VERSION-stamping algorithm not cross-tag-monotonic — Level-C fix for T-1828 class

## Context

T-1828 surfaced the second instance of "T-1603 hook blocks a legitimate forward-progress push". First instance was T-1602 (HEAD reset to old commit; T-1603 was the gate that caught it). Second instance is T-1828: tag-reset of the stamping counter, NOT a real rollback. The hook can't distinguish — both produce `local-VERSION < remote-VERSION` per `sort -V`.

This is an **inception** task because there are multiple viable approaches with different trade-offs, and the choice affects long-lived infrastructure (the VERSION file format, the pre-push hook semantics, and every consumer's pinned version).

## Acceptance Criteria

### Agent
- [x] Document at least 3 candidate fixes with trade-offs (algorithm change vs hook change vs hybrid) — 4 candidates documented below (A/B/C/D)
- [x] For each candidate: characterise migration impact on existing consumers (VERSION pins, parsers, semver-style filters)
- [x] For each candidate: identify the regression class it could introduce (e.g., "stamping algorithm that ignores tags loses release-train signal")
- [x] Recommendation in `## Recommendation` block before inception decision — Recommendation D

### Human
- [x] [REVIEW] Decide go/no-go AND which approach (A/B/C/D)
  **Steps:**
  1. Open the review page (link in `fw task review T-1829`)
  2. Read Candidates section and Recommendation
  3. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-1829 go --rationale "..."` once approach is chosen
  **Expected:** Decision recorded; agent files a build task to implement the chosen approach.
  **If not:** Defer and revisit when next mirror-stall recurrence hits — this is a Level-C structural fix, not a hot-fix.

## Verification

# No verification at inception stage. After GO decision and implementation:
# bats tests/unit/test_version_stamp_monotonic.bats  (filed by the build task)
# git push --dry-run github master  (should succeed without --no-verify)

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

**Date**: 2026-05-14T20:29:30Z

## Decisions

### 2026-05-14 — choose this is inception not build

- **Chose:** workflow_type=inception (NOT build).
- **Why:** the design has multiple viable approaches with different blast radius. The hook is critical infrastructure (mistake here = mirror stays broken or worse, real rollbacks slip through). T-1603 was added because a legitimate-rollback class slipped — we cannot weaken protection casually.
- **Rejected:** going straight to build with a chosen algorithm. The wrong choice would couple consumer VERSION pins to the framework's tag-creation policy, OR weaken the rollback gate to noise.

## Candidates

### Candidate A: total-commits-on-branch counter

Stamp `<major>.<minor>.<git rev-list --count HEAD>`. Strictly monotonic across all tags.

- **Pro:** simplest implementation (one-line change). Unconditionally monotonic.
- **Con:** counter jumps from ~260 to ~2000+ in one release — breaks consumer VERSION pins that assumed `<patch>` was a small integer. Loses the "commits since release tag" semantic that v1.5.X / v1.6.X provided.
- **Migration:** every consumer with `version_pin: 1.6.X` would need to update.

### Candidate B: 4-segment VERSION

Stamp `<major>.<minor>.<tag-patch>.<commits-since-tag>` = `1.6.2.148`. Reads as 4 ordered integers under `sort -V`. Tag-creation moves the 3rd segment forward (`1.6.2.0` > `1.6.1.260`), so it's monotonic.

- **Pro:** monotonic across tags. Preserves release-train signal (`1.6.2.x` is the v1.6.2 train).
- **Con:** every VERSION parser breaks. Consumers using `awk -F. '{print $3}'` get `2` not `148`. semver-style filters in CI may reject 4-segment.

### Candidate C: smarter T-1603 hook (ancestor check)

Keep current stamping algorithm. In the hook, if `local-VERSION < remote-VERSION`, perform `git merge-base --is-ancestor $remote_sha $local_sha`. If TRUE → local is genuinely forward in commit time, allow. If FALSE → divergence (or pre-tag-reset world), block.

- **Pro:** zero impact on VERSION file format. Zero impact on consumers. Hook becomes strictly more correct (allows tag-reset forward, still blocks real rollback).
- **Con:** hook does git operations on the remote sha — requires `git fetch` for remote-sha to be locally known. Pre-push hook has stdin's `$_remote_sha` but resolving it may need network. Original hook deliberately stays local-only.
- **Mitigation:** the remote_sha is supplied via stdin to the pre-push hook; if `git cat-file -e $_remote_sha` returns true, we already have it (which is the common case after a `git fetch` — most users do this routinely). Fall back to current behavior if not locally known.

### Candidate D: hybrid — Candidate C primary, mirror-sync wrapper logs stderr

Implement C, plus update `lib/mirror.sh` to capture and surface the full pre-push hook stderr in `.context/working/.mirror-sync.log` so the next stall is diagnosable in <15min, not after consumers report (Level-B from T-1828 prevention plan).

- **Pro:** belt + suspenders. Even if C misses an edge case, mirror-sync log shows the actual error.
- **Con:** scope creep — bundles a B-level observability fix with the C-level algorithm fix.

## Recommendation

**Recommendation:** GO with **Candidate D (C + B observability)**, defer A and B as alternatives if C proves incorrect.

**Rationale:** Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

**Evidence:**
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

## Updates

### 2026-05-14T18:24:14Z — task-created [task-create-agent]
- **Action:** Created via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1829-version-stamping-algorithm-not-cross-tag.md
- **Context:** Filed as Level-C follow-up to T-1828 (this session's surfaced mirror-stall RCA)

### 2026-05-14T18:35Z — inception-content [framework-agent]
- **Action:** Converted to inception, filled Candidates + Recommendation
- **Output:** 4 candidates documented (A=total-commits, B=4-segment, C=smarter-hook, D=C+observability), Recommendation D
- **Context:** This task does NOT implement the fix — it surfaces the design choice for human go/no-go

### 2026-05-14T18:29:55Z — status-update [task-update-agent]
- **Change:** workflow_type: inception → inception

### 2026-05-14T19:11:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

### 2026-05-14T19:11:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

### 2026-05-14T19:24:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

### 2026-05-14T19:24:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

### 2026-05-14T19:27:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

### 2026-05-14T20:09:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

### 2026-05-14T20:29:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Candidate D (C + B observability), defer A and B as alternatives if C proves incorrect.

Rationale: Candidate C is the smallest-blast-radius fix that addresses the root cause. The current VERSION file format is preserved (no consumer impact). The hook upgrade is purely additive — `local < remote` no longer auto-blocks; it asks "is remote an ancestor of local?". The bundled mirror-sync stderr logging (B) is cheap insurance against the next class. Candidates A and B require consumer migration; that cost is hard to justify when C is available.

Evidence:
- T-1828 RCA shows this is the SECOND incident of the class; if we don't fix the root cause, will hit again on next tag.
- `git merge-base --is-ancestor` is O(graph traversal), measured fast on this 2000+ commit history (<100ms).
- Mirror-sync stderr capture is a 3-line change to `lib/mirror.sh` `do_mirror_sync_to`.
- T-1602 protection class (real-rollback) is preserved: if `local < remote` AND `remote_sha NOT ancestor of local_sha`, that's a divergence → still blocks.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-adfa06c3
- **Timestamp:** 2026-06-02T14:59:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T20:29:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
