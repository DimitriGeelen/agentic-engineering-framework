# T-1768: Cron drift detection — surfacing, not detection

**Date:** 2026-05-06
**Trigger:** T-1767 found 24+ hours of silent cron non-firing (escalation-scan-v0.5).
**Question:** What structural change prevents recurrence of the registry ↔ generated ↔ deployed drift class?

## Initial Hypothesis (proven wrong)

"There is no drift detection between the three states; build one." — assumed in T-1768 problem-statement.

## Spike 1 — Existing detection

**Question:** Is there any cron-drift detection in the codebase today?

**Method:** `grep -rn "cron.*registry\|/etc/cron.d" lib/ agents/ bin/fw`

**Finding:** YES — `bin/fw:1631-1657` (T-1112/T-1114) implements a cron-drift check:

```bash
# Check: Cron registry drift (T-1112/T-1114)
local cron_source="$PROJECT_ROOT/.context/cron/agentic-audit.crontab"
local cron_target="$cron_target_dir/agentic-audit-${cron_slug}"
if diff -q "$cron_source" "$cron_target" >/dev/null 2>&1; then
    echo -e "  ${GREEN}OK${NC}  Cron registry in sync with $cron_target"
else
    echo -e "  ${YELLOW}WARN${NC}  Cron registry drift: $cron_source differs from $cron_target"
    warnings=$((warnings + 1))
fi
```

A second check at `bin/fw:1659-1676` (T-1558) compares flock-wrapper count between registry and deployed file.

**Conclusion:** Detection exists. Original problem statement was incorrect.

## Spike 2 — Invocation / surfacing

**Question:** Why didn't the existing detection catch T-1767's drift?

**Method:** Search for cron jobs invoking `fw doctor`; search for "Cron registry drift" in audit/notification surfaces.

**Finding:**
- `fw doctor` is interactive only. No cron job invokes it.
- The WARN string does not appear in any audit log, watchtower template, liveness JSONL, or notification channel.
- Drift accumulates silently between (rare) interactive `fw doctor` runs.

**Conclusion:** The gap is in invocation/surfacing, not detection.

## Spike 3 — Candidate mechanisms

| # | Mechanism | Coverage | Latency | FP risk | Cost |
|---|-----------|----------|---------|---------|------|
| a | Extend `fw doctor` to also check registry↔generated drift | adds 1 of 3 pair-drifts | manual | low | small |
| b | `fw cron install` pre-flight refusal on drift | catches edit-not-yet-generated | install-time | low | small |
| c | CLAUDE.md convention: cron-touching task `## Verification` MUST include `fw doctor \| grep -q "in sync"` | all detectable drifts at task-close | task-completion | low | doc-only |
| d | Add `fw doctor` to cron + propagate WARN to notification | all drifts, periodic | ≤24h | medium (alert fatigue) | medium |
| e | Bump cron-drift WARN to counted failure in `fw audit` summary | drift visible on `/audit` watchtower surface | audit-cron | low | tiny |

## Recommendation: GO — combine (c) + (e)

(c) catches the specific T-1767 mode (cron-touching task, never deploys) at task-close — single-line convention, no code change.

(e) makes drift visible in the established audit-finding surface that already runs in cron and is surfaced to watchtower, without spawning a new alert channel. Same pattern as fabric drift, hook threshold count, etc.

**Rejected:**
- (a) lone — extends detection, doesn't fix surfacing.
- (b) lone — narrow window, misses post-install drift.
- (d) — over-scoped, alert fatigue, new channel for one check.

## Implementation envelope (for T-1769)

| Touch | File | LOC |
|-------|------|-----|
| `fw audit` invokes cron-drift check; counts as failure | `agents/audit/audit.sh` (or `lib/task-audit.sh`) | ~15 |
| `## Verification` convention | `CLAUDE.md` § Verification Gate (P-011) | ~10 |
| Bats fixture: simulated drift → audit FAIL | `tests/unit/test_audit_cron_drift.bats` | ~30 |

Total ≈55 LOC. One slice. File T-1769 post-decide.

## Decision request

Recommendation is GO. Awaiting human decide via `fw task review T-1768`.
