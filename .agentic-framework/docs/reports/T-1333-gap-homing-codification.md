# T-1333: Gap Homing Meta-Rule Codification

## Summary

Inception task **T-1333** codified the rule: **"a gap belongs in the register where the FIX lives, not where it was HIT."**

## Decision

**GO** — codify as Tier-1 CLAUDE.md prose. Skip schema enforcement (Tier 2) and audit checks (Tier 3) until evidence shows the prose is being ignored.

## Rationale (condensed)

- Spike A (executed inline this session) scanned `.context/project/concerns.yaml` (64 entries) for cross-project / upstream-fix signals.
- Result: 5 entries (G-031, G-045, G-048, G-049, G-050) textually signal "fix locus elsewhere" — ~8% of register.
- Volume is low enough that schema enforcement would be over-engineering, but high enough that codified prose has recurring application.
- Cross-project rule is sound as a directional heuristic, not a hard schema invariant.
- Scope-fenced: IN = codify the rule; OUT = re-home existing entries.

## Deliverable Location

The codification landed in **`CLAUDE.md` § "Gap Homing (T-1333)"** — search for that heading. Worked example cited inline (G-045 / TermLink T-1054).

## Why Not docs/reports/T-1333-spike-A-scan.md?

Spike A was a one-shot grep over an existing file (concerns.yaml), not a multi-phase research effort. Findings fit in the inception task body. The deliverable IS the CLAUDE.md edit; this stub captures the link.

## Anchor Files

| Artifact | Path |
|---|---|
| Inception task body (Recommendation + Decision + Evidence) | `.tasks/completed/T-1333-meta-rule-codification--a-gap-belongs-in.md` |
| Episodic | `.context/episodic/T-1333.yaml` |
| Codification destination | `CLAUDE.md` § Gap Homing (T-1333) |
| Canonical example referenced in rule | `concerns.yaml` → G-045 (TermLink T-1054) |
