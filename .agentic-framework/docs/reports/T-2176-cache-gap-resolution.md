# T-2176 — Cache-gap resolution: 14 fresh-FAIL tasks

**Scan:** 2026-06-02T15:10:44Z — catalogue v1.3-seed, post-T-2177 detector tightening

**Audit pre-T-2177 (2026-06-02 08:33 UTC) said FAIL=31; fresh audit re-run post-T-2177 (15:13 UTC): FAIL=14.** Cached `## Reviewer Verdict` blocks in completed/ now also show FAIL=14 — three measures aligned. The 17-task delta is T-2177's `skip-as-pass` quoted-context + same-line-assertion suppressions clearing detector FPs that were genuinely false (audit shows `skip-as-pass` fires dropped 23 → 2 between the two runs).

## Per-task analysis

### T-123 — Framework shakedown — end-to-end lifecycle validation on throwaway project
- **Patterns:** tautology

### T-229 — Fix HIGH severity enforcement bypasses — B-001 (--no-verify) and B-005 (hook config)
- **Patterns:** swallowed-errors, AC-verify-mismatch

### T-303 — Create fw preflight command and integrate into fw init
- **Patterns:** skip-as-pass

### T-341 — Rewrite 7 deep-dive posts in Dimitri voice using style guide
- **Patterns:** swallowed-errors

### T-415 — Decompose update-task.sh into modular functions (S13)
- **Patterns:** swallowed-errors, l387-sigpipe-risk

### T-445 — README overhaul: sharpen positioning, add 5-min demo, honest enforcement gradient
- **Patterns:** tautology

### T-454 — Build fw upstream report — safe issue creation from field installations
- **Patterns:** swallowed-errors, l387-sigpipe-risk

### T-774 — Pickup pipeline core — lib/pickup.sh with receive/process/dedup/log
- **Patterns:** swallowed-errors

### T-876 — Upgrade 11 consumer projects to v1.4.553
- **Patterns:** tautology

### T-1356 — T-1346-B1: flip resolve_framework rule order — vendored beats global
- **Patterns:** swallowed-errors, empty-output-success

### T-1360 — G-053-B: hook dispatcher degrades gracefully on missing script (unblocks stuck sessions)
- **Patterns:** swallowed-errors, AC-verify-mismatch

### T-1378 — Eliminate hardcoded :3000 in 3 agent-facing anti-pattern sites (T-1376 B1+B2+B3)
- **Patterns:** swallowed-errors, AC-verify-mismatch

### T-1594 — Mirror cascade auto-recovery — fw mirror sync command + cron (T-1591 Prevention #3)
- **Patterns:** skip-as-pass, AC-verify-mismatch, l387-sigpipe-risk

### T-1694 — fw doctor extensions — pi-installed check (Q13) + workflow schema linter (Q14)
- **Patterns:** swallowed-errors, l387-sigpipe-risk


## Cluster mapping (against T-2173's 1-6)

T-2173's cluster taxonomy:
- **Cluster 1:** skip-as-pass — bare `--dry-run`/`--check-only` without output assertion
- **Cluster 2:** swallowed-errors — `cmd || true` / `cmd | head` masks failure
- **Cluster 3:** mock-only-integration — `mock.patch` test verifications
- **Cluster 4:** AC-verify-mismatch — AC text references files/paths Verification doesn't grep
- **Cluster 5:** l387-sigpipe-risk — pipefail-unsafe `cmd | grep -q` (advisory CONCERN, can compound to FAIL)
- **Cluster 6:** empty-output-success — `cmd > /dev/null` with no assertion

### Distribution of 14 fresh FAILs by primary pattern

| Pattern | Count | Cluster | Tasks |
|---------|-------|---------|-------|
| swallowed-errors | 6 | Cluster 2 | T-229, T-341, T-415, T-454, T-774, T-1356, T-1360, T-1378 |
| tautology | 3 | NEW (Cluster 7?) | T-123, T-445, T-876 |
| skip-as-pass | 3 | Cluster 1 | T-303, T-1594, T-1694 |
| AC-verify-mismatch | 2 | Cluster 4 | secondary on T-229, T-1360 |
| empty-output-success | 1 | Cluster 6 | secondary on T-1356 |
| l387-sigpipe-risk | 2 | Cluster 5 | secondary on T-415, T-454 |

### Routing decision

- **Clusters 1, 2, 4, 5, 6** already exist in T-2173's taxonomy. The 14 FAILs fit Clusters 1+2+4+5+6.
- **tautology** is a NEW pattern (3 fires: T-123, T-445, T-876) NOT in T-2173's Clusters 1-6. → File Fix D as horizon:later sibling.

### Pre-T-2177 vs post-T-2177

The audit's 31 FAILs minus today's 14 = 17 FPs cleared by T-2177's `skip-as-pass` tightening (quoted-context + same-line-assertion suppression). This matches the empirical pattern-fire delta:

| Pattern | Audit fires | Today's grep-l "FAIL" | Notes |
|---------|-------------|------------------------|-------|
| skip-as-pass | 23 | 3 in cached FAILs | T-2177 cleared 20 fires; only 3 remain as primary FAIL drivers |
| swallowed-errors | 11 | 8 in cached FAILs | unchanged by T-2177 |
| tautology | 5 | 3 in cached FAILs | unchanged; new cluster surfaced |
