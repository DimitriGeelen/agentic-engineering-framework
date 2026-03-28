# T-580: Error Classification — Permanent vs Transient Separation in Healing Loop

## Problem Statement

The healing agent (`agents/healing/lib/diagnose.sh`) classifies errors into 5 types: `code`, `dependency`, `environment`, `design`, `external`. This classification drives recovery suggestions via the Error Escalation Ladder (A-D).

**What's missing:** No permanent vs transient distinction. The healing agent suggests retry-based recovery for ALL failure types — including failures that can never succeed. Example: "Add retry logic with backoff" for an external API that has been permanently decommissioned.

**OpenClaw reference:** OpenClaw's delivery queue (`src/delivery/delivery-queue.ts`) classifies errors as permanent (chat not found, bot blocked → move to `failed/`) vs transient (network error, 5xx → retry with backoff). This prevents wasting retries on unrecoverable failures.

## Current State Analysis

### Healing Agent Architecture

```
healing.sh → diagnose | resolve | patterns | suggest
         ↓
diagnose.sh:
  1. classify_failure() — keyword scoring across 5 types
  2. find_similar_patterns() — semantic search via Ollama
  3. Suggest recovery — static ladder A-D per type
```

### patterns.yaml Structure (failure_patterns)

Current fields per pattern:
- `id` (FP-XXX)
- `pattern` (short name)
- `description` (what happened)
- `learned_from` (task ID)
- `date_learned`
- `mitigation` (what fixed it)
- `escalation_step` (A/B/C/D)
- `occurrences_at_step` (counter)
- `last_escalated` (timestamp)
- `scope` (optional: project/global)

**Missing fields:** No `permanence` indicator. No way to mark "this pattern will never self-resolve."

### Recovery Suggestion Gap

In `diagnose.sh:150-198`, recovery suggestions are type-based:
- `external` → "Add retry logic with backoff" (always)
- `environment` → "Add environment validation" (always)
- `dependency` → "Consider alternative package" (always)

No branching on whether the error is retryable. A permanently removed API gets the same "add retry with backoff" advice as a transient 503.

## Exploration

### What Would Permanent/Transient Add?

**Permanent errors:** Cannot self-resolve. No amount of retry will fix them.
- API permanently removed
- Package permanently yanked from registry
- Configuration file permanently changed upstream
- Permission permanently revoked (not a timeout — a policy change)
- Design flaw (wrong approach entirely)

**Transient errors:** May self-resolve with time or retry.
- Network timeout (try again)
- 5xx server error (server may recover)
- Rate limiting (wait and retry)
- Intermittent test failure (timing-dependent)
- Resource temporarily locked

### Design Options

#### Option A: Add `permanence` field to patterns.yaml

```yaml
failure_patterns:
  - id: FP-012
    pattern: "API endpoint removed"
    permanence: permanent     # NEW FIELD
    description: "..."
    mitigation: "Replace with alternative API"
```

**Pro:** Simple, backward-compatible, no code changes needed for existing patterns
**Con:** Requires manual classification of each pattern; existing 11 patterns need backfill

#### Option B: Auto-classify based on occurrence history

If the same error pattern has occurred 3+ times with no successful resolution between occurrences, mark as likely permanent.

```
if occurrences_at_step >= 3 and escalation_step == 'A':
    → permanent (same fix keeps failing)
```

**Pro:** No manual classification needed; evidence-based
**Con:** Requires occurrence tracking improvements; can misclassify intermittent issues

#### Option C: Hybrid — manual field + auto-detection

Add `permanence` field (default: `unknown`). Auto-classify on resolution:
- If `healing resolve` is called with `--permanent`: mark permanent
- If same pattern triggers 3+ times at same escalation step: suggest permanent
- Healing diagnose shows different advice for permanent vs transient

### Impact on diagnose.sh

With permanence awareness, `diagnose.sh` recovery suggestions change:

```bash
# For transient errors:
echo "   - Add retry logic with backoff"
echo "   - Add circuit breaker"

# For permanent errors:
echo "   - This is a PERMANENT failure — retry will not help"
echo "   - Replace the dependency/API/approach"
echo "   - Escalate to Level C/D (tooling/process change)"
```

### Scope Assessment

**Changes needed:**
1. Add `permanence` field to patterns.yaml schema (trivial)
2. Modify `diagnose.sh` to read and act on permanence (small)
3. Modify `resolve.sh` to accept `--permanent` flag (small)
4. Backfill existing 11 failure patterns (trivial — all are permanent-class)
5. Optional: auto-detection heuristic (medium — can defer)

**Effort:** ~1 session for Option A + partial Option C
**Risk:** Low — additive change, backward-compatible

## Go/No-Go Assessment

**GO criteria check:**
- [x] Clear problem with concrete symptom (retry advice for permanent errors)
- [x] Small, bounded scope (2-3 files, 1 new field)
- [x] Backward-compatible (new field with default `unknown`)
- [x] Real value — stops bad advice from healing agent

**NO-GO criteria check:**
- [ ] Too complex — No, this is small
- [ ] Not enough evidence — No, we have 11 patterns to validate against
- [ ] Better alternative exists — No, this is the natural extension

**Recommendation: GO** with Option C (hybrid). Add the field, modify diagnose/resolve, defer auto-detection to a future task.

## Dialogue Log

- Research conducted by reviewing: healing agent code, patterns.yaml, OpenClaw value extraction report (T-549)
- No human dialogue (agent-driven inception from T-549 findings)
