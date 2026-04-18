# T-1313: Umbrella Inception Anti-Pattern (already codified)

**Source:** termlink (sourced from T-1112) pickup (P-035)
**Status:** DEFER (already codified in CLAUDE.md)
**Date:** 2026-04-18

## Proposal

Termlink reports a recurring anti-pattern: "umbrella inceptions" that bundle N independent decisions into a single go/no-go. Symptom: T-1112 went NO-GO because two of its three sub-questions were undecidable; the one tractable sub-question was lost in the all-or-nothing decision.

## Analysis

The rule is **already codified** in `CLAUDE.md` under "Task Sizing Rules":

> One inception = one question. An inception task should explore one problem and produce one go/no-go decision. "Umbrella inceptions" that bundle independent explorations create all-or-nothing decisions and coarse progress tracking.

T-1112's NO-GO is exactly the failure mode the rule predicts — and the rule worked: the human (or agent acting on behalf) refused to ship a half-decided umbrella.

## Why DEFER (no structural enforcement)

Codifying via a structural enforcement gate (e.g., "block `fw inception decide` if problem statement contains >N independent questions") is hard:
- "Sub-question" is a judgment call, not a regex match
- Detecting "and X, and Y, and Z" via parsing has high false-positive risk on natural prose
- The existing rule + episodic evidence (T-1112 NO-GO becomes a teachable artifact) is the right level of enforcement

## Decision Trail

- Source pickup: `.context/pickup/processed/P-035-pattern.yaml`
- Existing codification: `CLAUDE.md` "Task Sizing Rules" section
- Episodic evidence: T-1112 NO-GO (the rule already firing via human judgment)
- Recommendation: DEFER — no enforcement gate appetite given codification cost
