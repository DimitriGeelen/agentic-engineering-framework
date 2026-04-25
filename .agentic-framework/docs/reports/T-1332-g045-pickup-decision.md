# T-1332: G-045 Cross-Project Pickup Decision

## Summary

Inception task **T-1332** decided to send a cross-project pickup envelope to TermLink for G-045 fleet-rotation secret distribution UX, narrowed to "hub-assisted secret re-bootstrap after rotation" rather than a full identity redesign.

## Decision

**GO** — recorded 2026-04-24. Send the pickup; TermLink owns accept/reject.

## Rationale (condensed)

- G-045 triggered five times this week on `.121` (5 consecutive auth-mismatch failures since 2026-04-23T17:17Z per `.fleet-failure-state.json`). Recurrence threshold met.
- TermLink already has `termlink remote push` + hub-signed inbox channel — A1 (mechanism exists) is a checkbox, not a spike.
- Scope-fence kept tight: IN = decide whether to send the pickup; OUT = implementing the remediation. GO commits us only to drafting + sending.
- T-1054 / T-1055 are already tracked TermLink-side as the tier-1/tier-2 heal commands.

## Deliverable Locations

| Artifact | Path |
|---|---|
| Inception task body (full Recommendation + Decision + Evidence) | `.tasks/completed/T-1332-meta-rule-codification--a-gap-belongs-in.md` |
| Episodic | `.context/episodic/T-1332.yaml` |
| Concern entry | `.context/project/concerns.yaml` → `G-045` |
| Upstream owner | TermLink `T-1054` (fleet reauth) |

## Note

The deliverable for T-1332 was the cross-project pickup envelope, not a research artifact in this repo. This stub exists to satisfy the C-001 thinking-trail audit (T-1441) and to give future agents a single anchor to find the decision and its downstream owners.
