# T-2252 — BVP bundle init-refusal vs fw bvp driver --init scope mismatch

> **Inception research artifact** (backfilled by T-2515 from the `T-2252` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-2252-bvp-bundle-init-refusal-vs-fw-bvp-driver.md`. **Decision recorded: GO.**

## Problem Statement

The BVP driver-session bundle (`policy/prompts/bvp-driver-session.md` §"Init refusal", line 146) refuses to run its workflows when EITHER `policy/value-drivers.yaml` OR `policy/bvp-scoring-rubric.md` is absent. But `fw bvp driver --init` (`lib/bvp.sh:661` `_driver_init`) only writes `policy/value-drivers.yaml`. Result: on a fresh consumer, running `fw bvp driver --init` per the bundle's own instructions ("Run `fw bvp driver --init` first") leaves `bvp-scoring-rubric.md` absent, and the bundle's subsequent workflow attempt refuses again. The init verb is the asymmetric leg — the bundle's check is correct (the rubric is cited as the scoring source of truth at bundle line 168), but `--init` copies only one of the two prerequisite files.

**For whom:** every consumer running `fw init` then trying to use the BVP bundle. Today the framework repo has both files; consumers who vendored the framework recently get both. Consumers who only ran `fw bvp driver --init` get a half-initialised state and a confusing refusal loop.

**Why now:** surfaced during T-2251 / arc-006 dogfood (Workflow B grilling). The fix is bounded (~10 LoC) and unblocks the bundle's documented init flow.

## Assumptions

- `policy/bvp-scoring-rubric.md` (212 lines, 12.5K, filed under T-1921) is a stable framework artefact, suitable to copy verbatim as a consumer-side starter (same model as `policy/value-drivers.yaml`).
- The bundle's two-file check is the correct invariant — removing `bvp-scoring-rubric.md` from the refusal would shift the brokenness downstream (estimator can't score without the rubric).

## Open Questions

- **IW-1: Should `fw bvp driver --init` copy `policy/bvp-scoring-rubric.md` symmetrically alongside `policy/value-drivers.yaml`, or should the bundle's init-refusal drop the rubric check?**
  confidence: 3
  disposition: answered
  rationale: Extend `_driver_init` to copy both files (lib/bvp.sh:661-700). Bundle's check is correct — the rubric is cited at policy/prompts/bvp-driver-session.md:168 as the scoring source of truth, removing the check breaks the estimator chain (T-1922 reads from the rubric). The `--init` verb is the leg that needs to be widened.

## Exploration Plan

Done in-line during this exploration:
1. Read `lib/bvp.sh:661-700` (`_driver_init`) — confirmed: copies only `value-drivers.yaml`.
2. Read `policy/prompts/bvp-driver-session.md:146` — confirmed: refuses on OR of two files.
3. `ls policy/bvp-scoring-rubric.md` — confirmed: framework template present (212 lines).
4. Reviewed bundle's downstream references to the rubric — found at line 168 (estimator citation).
Total: ~15 minutes of read-only verification.

## Technical Constraints

None. Pure file-copy extension; same `template.read_bytes()` / `target.write_bytes()` pattern as the existing value-drivers.yaml copy. Idempotent by file-exists check, mirror existing `--force` semantics.

## Scope Fence

**IN scope:**
- Extend `_driver_init` to copy both `policy/value-drivers.yaml` AND `policy/bvp-scoring-rubric.md` from `FRAMEWORK_ROOT/policy/` to `PROJECT_ROOT/policy/`.
- Both files participate in the idempotent / `--force` semantics symmetrically.
- Output messaging mentions both files when created.

**OUT of scope:**
- Auto-running `_driver_init` from `fw init`/`fw upgrade` (T-2229 Slice 2 covers that; this is Slice 1's surface).
- Any change to the bundle's init-refusal logic (it is already correct).
- New CLI verbs (T-2245 IW-3 covers `fw bvp driver create|suggest|recompute|edit|retire` — separate scope).
- The rubric template's content itself (T-1921 owns the artefact).

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** GO

**Rationale:** The fix is one-sided and bounded. Extend `_driver_init` (lib/bvp.sh:661) to copy `policy/bvp-scoring-rubric.md` alongside `policy/value-drivers.yaml`. The bundle's two-file init-refusal is structurally correct: the rubric is the BVP estimator's source of truth (T-1922 reads from it; bundle cites at policy/prompts/bvp-driver-session.md:168). Removing the check would defer the brokenness to estimator-time instead of init-time, which is strictly worse. `--init` is the asymmetric leg.

**Evidence:**
- `lib/bvp.sh:661-700` `_driver_init` copies only `policy/value-drivers.yaml` (template.read_bytes() → target.write_bytes(); idempotent).
- `policy/prompts/bvp-driver-session.md:146` refuses on absence of EITHER file.
- `policy/prompts/bvp-driver-session.md:168` cites `bvp-scoring-rubric.md` as the scoring source of truth for the estimator chain.
- Framework template exists: `policy/bvp-scoring-rubric.md` (212 lines, 12.5K, T-1921-owned).

**Scope of build slice (post-GO):**
- Single-file edit, `lib/bvp.sh:_driver_init`. ~10 LoC: add second `template_b / target_b` pair, mirror the file-exists / `--force` / write_bytes / message lines.
- Test: existing `_driver_init` test pattern (look for `tests/unit/test_bvp_driver_init.bats` or equivalent — extend with rubric assertion).
- Verification: `[ -f policy/value-drivers.yaml ] && [ -f policy/bvp-scoring-rubric.md ]` after running `fw bvp driver --init` on a fresh tmpdir.

**Earlier DEFER was a placeholder:** the producer-leg-3 gate (T-2207, `--recommendation` required at filing under `$CLAUDECODE=1`) forced a recommendation at filing time; DEFER was the easiest fill while the body was empty. This is exactly the failure mode `feedback_defer_for_evidence_not_confidence` warns against: DEFER masking a confidence gap instead of marking an evidence gap. Operator caught it in one question. Recommendation re-filed to GO with the actual evidence walked.

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The fix is one-sided and bounded. Extend `_driver_init` (lib/bvp.sh:661) to copy `policy/bvp-scoring-rubric.md` alongside `policy/value-drivers.yaml`. The bundle's two-file init-refusal is structurally correct: the rubric is the BVP estimator's source of truth (T-1922 reads from it; bundle cites at policy/prompts/bvp-driver-session.md:168). Removing the check would defer the brokenness to estimator-time instead of init-time, which is strictly worse. `--init` is the asymmetric leg.

Evidence:
- `lib/bvp.sh:661-700` `_driver_init` copies only `policy/value-drivers.yaml` (template.read_bytes() → target.write_bytes(); idempotent).
- `policy/prompts/bvp-driver-session.md:146` refuses on absence of EITHER file.
- `policy/prompts/bvp-driver-session.md:168` cites `bvp-scoring-rubric.md` as the scoring source of truth for the estimator chain.
- Framework template exists: `policy/bvp-scoring-rubric.md` (212 lines, 12.5K, T-1921-owned).

Scope of build slice (post-GO):
- Single-file edit, `lib/bvp.sh:_driver_init`. ~10 LoC: add second `template_b / target_b` pair, mirror the file-exists / `--force` / write_bytes / message lines.
- Test: existing `_driver_init` test pattern (look for `tests/unit/test_bvp_driver_init.bats` or equivalent — extend with rubric assertion).
- Verification: `[ -f policy/value-drivers.yaml ] && [ -f policy/bvp-scoring-rubric.md ]` after running `fw bvp driver --init` on a fresh tmpdir.

Earlier DEFER was a placeholder: the producer-leg-3 gate (T-2207, `--recommendation` required at filing under `$CLAUDECODE=1`) forced a recommendation at filing time; DEFER was the easiest fill while the body was empty. This is exactly the failure mode `feedback_defer_for_evidence_not_confidence` warns against: DEFER masking a confidence gap instead of marking an evidence gap. Operator caught it in one question. Recommendation re-filed to GO with the actual evidence walked.

**Date**: 2026-06-08T12:19:38Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3139562b
- **Timestamp:** 2026-06-08T12:19:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T12:19:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
