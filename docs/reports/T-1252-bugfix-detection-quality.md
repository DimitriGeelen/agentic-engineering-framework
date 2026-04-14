# T-1252 — Audit detection quality: bugfix-learning denominator

**Task:** T-1252
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14

## Problem

The audit at `agents/audit/audit.sh:952-990` counts any completed task whose name
matches `fix|bugfix|hotfix|RCA|G-[0-9]` as a "bugfix" and expects each to have a
learning. Denominator is 242. But per CLAUDE.md "Bug-Fix Learning Checkpoint",
the rule only applies to **field-discovered** bugs — not dev-discovered ones.

Result: a mismatched denominator inflates the FAIL; the metric loses signal.

## Spikes

### Spike A — Classification signal run — DONE

Ran a bulk classifier across all 242 matching completed tasks. Field-discovery signals:
1. Name contains `consumer`, `production`, `external`, `user report/testing`, `field`
2. Body mentions consumer/production/external/found-in-production/the-wild
3. Name references a G-XXX gap (G-NNN format)
4. Name contains `RCA` (explicit root cause analysis)

**Result:** 83 of 242 (34%) match at least one field signal. 159 (66%) appear
dev-discovered.

Sampling caveat: the signals are approximate. A manual read of 20 would refine
the ratio but the magnitude is clear — most "fix" tasks are dev-cleanup, not
field bugs.

### Spike B — Mechanical detection signals — DONE

Practical signals the audit can check from the task file alone:

| Signal | Source | Strength |
|--------|--------|----------|
| `\bRCA\b` in name | task frontmatter name | Strong (explicit) |
| `G-[0-9]+` in name or body | task file content | Strong (gap reference) |
| Task created via pickup | `.pickup-*` directory origin | Strong (needs metadata) |
| Name contains `consumer\|production\|external\|field` | name grep | Medium |
| Body contains "reported by", "found in production", "the wild" | body grep | Medium |
| Linked from a concerns register entry (`related_tasks:` reverse lookup) | cross-file | Strong (but slower) |

Proposed narrower regex for the audit match:

```bash
# Current:
echo "$task_name" | grep -qiE '\bfix\b|\bbugfix\b|\bhotfix\b|\bRCA\b|\bG-[0-9]'

# Proposed:
# Only RCA/gap-tagged OR "fix" with field-discovery body keyword
is_field_bug() {
    local name="$1" body="$2"
    # Always include RCA and gap references
    echo "$name" | grep -qiE '\bRCA\b|\bG-[0-9]|\bhotfix\b' && return 0
    # Include "fix" only when body has a field signal
    if echo "$name" | grep -qiE '\bfix\b|\bbugfix\b'; then
        echo "$body" | grep -qiE '(consumer|production|external|field|in the wild|user reported|regression in)' && return 0
    fi
    return 1
}
```

### Spike C — Revised denominator impact — DONE

Rough projection:
- Current: 1/242 = 0.4% (FAIL, below 10%)
- After filter (estimated from signal run): 1/~83 = 1.2% (still FAIL)
- If we also catch the historical 83 that should have had learnings — still structural gap

**Key insight:** Narrowing the denominator doesn't magically fix the coverage
problem. It reveals the TRUE coverage rate (~1-2% of field bugs have learnings),
which is still a FAIL but a _meaningful_ FAIL rather than an artifact of mis-detection.

Threshold recalibration: keep 10% FAIL / 35% target. Focus on capture improvements
(see T-1251) rather than denominator games.

## Findings

1. 66% of current denominator (159/242) are dev-discovered cleanup — inflation confirmed
2. Mechanical field-bug signals exist and are deterministic
3. Narrowing the denominator does NOT reach PASS on its own — the capture problem is real
4. The proposed filter combines explicit signals (RCA, G-NNN) with content-based heuristics

## Recommendation

**Recommendation:** GO — implement the narrower filter

**Rationale:** The current audit metric is ~2-3x too broad in its denominator. A
narrower filter would give agents a truthful signal about field-bug learning
coverage rather than penalizing them for trivial dev cleanups. This paired with
T-1251 (capture-side improvements) addresses both the signal and the behavior.

**Evidence:**
- 66% inflation rate in current denominator (159/242 dev-discovered per signal run)
- Filter proposal uses only metadata already present in task files (no schema change)
- Coverage stays at FAIL even after narrowing — meaning the metric remains useful

**Next step if GO:** Create `T-1255-build: narrow bugfix-learning detector to field-discovered bugs in audit.sh`

## Dialogue Log

### 2026-04-14 — Original audit escalation context

User asked for bugfix inception tasks after audit showed `[FAIL] Bugfix-learning
coverage: 0% (1/242)`. The FAIL level is set below 10% coverage; current rate is
~0.4%. Created T-1251 (capture-side RCA) and T-1252 (detection quality) as separate
inceptions per "one inception = one question" rule.


## Dialogue Log

<!-- Conversational reasoning trail. -->
