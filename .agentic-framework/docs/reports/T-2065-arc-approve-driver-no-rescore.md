# T-2065 — `fw arc approve-driver` doesn't trigger member BVP recalc

**Task:** [T-2065](/tasks/T-2065) (Inception)
**Date:** 2026-05-28
**Decision:** GO — combined (a)+(d): synchronous re-estimation in `approve_driver` AND separate `fw arc rescore <slug>` verb

## Summary

User reported that approving a new scoped driver on an arc (via `fw arc approve-driver` or Watchtower) updates `scoped_drivers:` on the arc YAML but does NOT trigger BVP re-estimation for the arc's constituent tasks. The new driver's weight contribution sits unrealised until a manual estimator run.

## Decision: GO

**Combined (a)+(d):**
- **(a) Synchronous re-estimation** inside `approve_driver` — deterministic consequence of authorisation
- **(d) Separate `fw arc rescore <slug>` verb** — for ad-hoc recompute (re-estimator runs, manual recovery)

**Sovereignty rail preserved:** the human authorises the driver via `approve-driver` (§ACD-gated); the rescore runs as a deterministic *consequence* of that authorisation, not a separate decision. The standalone `rescore` verb supports recovery and re-runs without re-prompting for approval.

See task body for full Recommendation and rejected candidates (b/c).
