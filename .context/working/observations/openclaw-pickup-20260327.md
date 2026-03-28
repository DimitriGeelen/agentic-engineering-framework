# Pickup: 7 Framework Integration Tasks from OpenClaw Evaluation

**From:** OpenClaw evaluation project (`/opt/openclaw-evaluation`)
**To:** Framework agent (`/opt/999-Agentic-Engineering-Framework`)
**Date:** 2026-03-27

## Summary

The OpenClaw evaluation (331K+ star TypeScript AI assistant) identified 7 high-value patterns
that can improve the Agentic Engineering Framework. Each pattern has been:
1. Located in OpenClaw's codebase
2. Extracted into a zero-dependency standalone module
3. Mapped to specific framework gaps/bugs with evidence
4. Written up as a full inception task with go/no-go criteria

**Extracted modules:** `/opt/openclaw-evaluation/docs/extracted/` (7 TypeScript files)
**Evaluation report:** `/opt/openclaw-evaluation/docs/reports/EVALUATION-SUMMARY.md`

## The 7 Inception Tasks (by priority)

### T-038: Upgrade loop detection (Priority 1 — NOW)
**Pattern:** `docs/extracted/tool-loop-detection.ts` (300 LOC)
**Target:** `lib/ts/src/loop-detect.ts` (current 270 LOC)
**Why:** Current detector has 3 basic detectors with hardcoded thresholds (5/10).
OpenClaw has 4 detectors with graduated thresholds, global circuit breaker,
result-outcome hashing, and warning key dedup. The sprechloop incident
(checkpoint.sh:116 — "23 handover commits") shows the detection gap.
**Integration:** Near drop-in. Same stdin/stdout/exit-code contract.

### T-039: Add dedupe cache to hooks (Priority 2 — NOW)
**Pattern:** `docs/extracted/dedupe-cache.ts` (100 LOC)
**Target:** `checkpoint.sh` re-entry lock (line 113), `pre-compact.sh` git-log dedup (line 17)
**Why:** Ad-hoc dedup guards with known failure modes. checkpoint.sh comment says
"caused 23 handover commits in sprechloop." Proper TTL+LRU cache replaces all
ad-hoc guards with one-line `dedup.check(key)`.
**Integration:** Needs bash-callable wrapper (Python one-liner or compiled node).

### T-040: Skills budget for post-compaction (Priority 3 — NOW)
**Pattern:** `docs/extracted/skills-budget.ts` (90 LOC)
**Target:** `post-compact-resume.sh` context injection
**Why:** Post-compaction injects fixed-format context. With 17 active tasks, block is large.
3-tier degradation (full → compact → binary-search-fit) adapts to available budget.
**Integration:** Port algorithm to bash in post-compact-resume.sh.

### T-041: Config diff for CLAUDE.md (Priority 4 — NEXT)
**Pattern:** `docs/extracted/config-diff.ts` (120 LOC)
**Target:** New PostToolUse hook
**Why:** CLAUDE.md changes mid-session go unnoticed. Mtime detection + diff classification.
**Integration:** New hook, moderate effort.

### T-042: Keyed async queue for TermLink (Priority 5 — NEXT)
**Pattern:** `docs/extracted/keyed-async-queue.ts` (50 LOC)
**Target:** `fw termlink dispatch`
**Why:** Fire-and-forget dispatch. Keyed queue serializes per task, parallelizes across.
**Integration:** Queue in fw CLI or TermLink Rust layer.

### T-043: Session key hierarchy (Priority 6 — LATER)
**Pattern:** `docs/extracted/session-key-utils.ts` (110 LOC)
**Target:** Session identification throughout framework
**Why:** Flat IDs don't encode agent type/scope/nesting. Future multi-agent foundation.

### T-044: DM access policy (Priority 7 — LATER)
**Pattern:** `docs/extracted/dm-access-policy.ts` (160 LOC)
**Target:** Tier 0/1/2 enforcement scripts
**Why:** Multi-source ACL merge. Evaluate applicability only.

## How to Pick Up

Full inception files at `/opt/openclaw-evaluation/.tasks/active/T-0XX-*.md` with problem
statements, artifact tables, comparison tables, assumptions, exploration plans, go/no-go criteria.

Extracted patterns at `/opt/openclaw-evaluation/docs/extracted/*.ts` — zero-dependency, self-contained.

Recommended start: T-038 (loop detection) — most self-contained, near drop-in replacement.
Read the extracted file, compare with `lib/ts/src/loop-detect.ts`, create a framework inception.
