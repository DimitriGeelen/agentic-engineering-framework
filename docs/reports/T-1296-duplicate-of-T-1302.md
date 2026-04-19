# T-1296 — Duplicate of T-1302

**Status:** DEFER (duplicate)
**Source:** termlink T-1125 pickup
**Conflicts with:** T-1302 (same termlink source, same bug-report)

## Duplicate evidence

- Both tasks cite termlink T-1125 in their pickup envelopes.
- Both titles describe the same issue: "Watchtower Flask secret_key auto-regenerates on every restart — breaks CSRF".
- T-1302 was created first and touched in session S-2026-0419-0047.
- T-1296 was auto-created by a subsequent pickup pass; dedup failed to match.

## Recommendation

DEFER — close this task; keep T-1302 as the canonical record for the CSRF issue.
Work should proceed against T-1302 only.

## Residual concern

The pickup-dedup mechanism let this slip through. That deserves its own inception
if it recurs (currently not worth a dedicated task — G-008 contributors enumerated
already include pickup-dedup leaks).
