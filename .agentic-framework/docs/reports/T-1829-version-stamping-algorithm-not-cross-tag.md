# T-1829 — VERSION-stamping algorithm not cross-tag-monotonic — Level-C fix for T-1828

> **Inception research artifact** (backfilled by T-2515 from the `T-1829` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1829-version-stamping-algorithm-not-cross-tag.md`. **Decision recorded: GO.**

## Context

T-1828 surfaced the second instance of "T-1603 hook blocks a legitimate forward-progress push". First instance was T-1602 (HEAD reset to old commit; T-1603 was the gate that caught it). Second instance is T-1828: tag-reset of the stamping counter, NOT a real rollback. The hook can't distinguish — both produce `local-VERSION < remote-VERSION` per `sort -V`.

This is an **inception** task because there are multiple viable approaches with different trade-offs, and the choice affects long-lived infrastructure (the VERSION file format, the pre-push hook semantics, and every consumer's pinned version).

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
