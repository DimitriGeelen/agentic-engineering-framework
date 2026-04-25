# T-1145 — Assumption Fabrication/Retraction Cycle RCA

**Source:** P-010 pickup from ring20-dashboard (T-011)
**Severity:** High — recurring across sessions, no framework gate catches it
**Date:** 2026-04-12

## Problem

Agents cycle through contradictory truth states about assumptions across sessions. In the observed case (A-007 in ring20-dashboard T-011), the cycle was:
1. Session 1: Assumed fact
2. Session 2 (post-compact): Retracted as fabricated
3. Session 3 (post-compact): Re-instated via independent verification

No framework gate caught the inconsistency at any stage.

## Five-Layer Root Cause Analysis

### L1 — Tactical: Wrong grep result
Session 2 asserted T-571/T-600 "not found" — actually, 8 files exist. The exact command was never recorded.

### L2 — Process: Negative claims aren't re-verifiable
Free-form prose like "NOT FOUND: T-571. Likely hallucinated." becomes authority for subsequent sessions. Positive claims can be re-verified (read the file). Negative claims cannot (unknown search parameters).

### L3 — Structural: No assumption provenance schema
No required shape for assumption state changes. A good record would contain: session_id, timestamp, tool, command (verbatim), output_digest, conclusion.

### L4 — Compaction interaction: Post-compact self-trust
After compaction, sessions read task files as neutral authority, not as output of a possibly-hallucinating prior version. The resume hook reinjects "current state" but not "how state was established."

### L5 — No cross-section consistency
Assumptions and Recommendation sections can contradict each other within a single task file. No commit hook validates agreement.

## Four Proposed Remediations

### R1 — Assumption provenance schema (L1, L2, L3)
Every assumption state change requires structured record: session_id, timestamp, tool, command, output_digest, conclusion. YAML schema extension to `fw assumption` commands.

**Assessment:** Highest value, highest cost. Requires schema design, CLI changes, Watchtower display changes. Addresses root cause.

### R2 — Negative-claim TTL (L2)
Negative claims auto-expire after N days. Post-compact sessions see a warning: "Assumption A-007 retracted 3d ago, evidence not re-verifiable — consider re-checking."

**Assessment:** Medium value, low cost. Could be implemented as a commit-msg hook or audit check. Partial mitigation — doesn't prevent the initial fabrication.

### R3 — Post-compact quarantine (L4)
After compaction, assumptions in task files are marked "unverified" until the new session re-confirms them. The resume hook could inject a warning about assumption state.

**Assessment:** Medium value, medium cost. Addresses the self-trust problem but adds friction to every compacted session.

### R4 — Cross-section consistency check (L5)
Commit hook or audit check that validates assumptions and recommendations agree. If A-007 is "VERIFIED" in Assumptions but Recommendations says "stands alone," flag the contradiction.

**Assessment:** Low-medium value, medium cost. Requires AST-like parsing of task file sections. Addresses symptom (inconsistency), not root cause (fabrication).

## Recommendation

**DEFER — pending evidence of recurrence frequency.**

The observed cycle happened in one project (ring20-dashboard) during a specific cross-machine coordination scenario. Before investing in structural remediations:

1. Monitor for 30 days — track assumption retraction/reinstatement cycles across all projects
2. If frequency >1/month: GO on R1 (provenance schema) + R4 (consistency check)
3. If frequency <1/month: NO-GO — behavioral learning sufficient

**Rationale:** The 4 remediations range from 2-10 hours of implementation each. Total cost if all built: ~20-30 hours. The observed failure mode is real but may be rare enough that behavioral mitigation (L-002: "always diff subagent output") is sufficient. Evidence from 980+ completed tasks shows this is the first documented instance.

**Risk of deferring:** If the pattern recurs without structural prevention, agents will continue contradicting themselves across compaction boundaries. The human must catch it each time.
