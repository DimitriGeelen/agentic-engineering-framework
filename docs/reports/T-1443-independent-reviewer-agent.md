# T-1443: Independent Reviewer Agent — TermLink-Dispatched, Evidence-Gated

## Status
**Phase:** Captured (blocked on T-1442 GO)
**Linked:** T-1442 (I-A AC validation default-flip — prerequisite)

## Problem

If T-1442 lands a default-flip toward mechanical verification with persisted evidence, *something* must judge whether the recorded evidence is sufficient to tick an Agent AC. Today the agent self-assesses (P-011 only checks exit codes). A second-opinion check would close the loop and make the system antifragile to a single agent's blind spots.

## Framing (inherits from T-1442)

Same North Star: frictionless development, preserve 4 directives, remove friction without removing rigor. This inception adds the mechanism that *enforces* the rigor without the human bottleneck.

## Proposal Sketch (subject to dialogue)

A separate agent profile (e.g. `agents/reviewer/`), dispatched **independently via TermLink** (true context isolation, not Task tool sub-agent), that:

1. Reads recorded evidence (shape determined by I-A / T-1442)
2. Judges whether each Agent AC is properly evidenced
3. **May auto-tick Agent ACs** when evidence is sufficient (confirmed by user 2026-04-25)
4. Escalates to human only when reviewer says "needs human" — judgment-level Human ACs preserved
5. Output is an audit trail (where? — open question)

## Open Questions (in scope for this inception)

- **Q4 — Profile scope**: generic AC reviewer, or specialised one-per-tier (programmatic-reviewer / e2e-reviewer / ui-reviewer)? Hybrid (generic dispatcher → specialist sub-routines)?
- **Q5b — Slot in existing flow**: where does reviewer fire — pre-`work-completed` gate, post-`work-completed` validator, on-demand `fw task review-evidence`?
- **Q (emergent) — Output protocol**: `fw bus post` envelope? Append to task body Updates section? Watchtower review page? All three?
- **Q (emergent) — Authority bounds**: explicit list of what reviewer **cannot** do (e.g. cannot tick Human ACs, cannot decide inceptions, cannot mark `work-completed` itself).
- **Q (emergent) — Failure mode**: reviewer says "evidence insufficient" — does that block, warn, or surface to human queue?
- **Q (emergent) — Reviewer's own auditability**: reviewer is an agent making decisions. Who reviews the reviewer? Sampling? Periodic audit of reviewer ticks?

## Confirmed-yes (locked, not in dialogue)

- Reviewer authority = **mechanical tick on Agent ACs only** (NOT Human ACs).
- Independent dispatch via **TermLink** (not Task tool sub-agent) — context-isolated.
- Sovereignty over Human ACs **preserved** — reviewer cannot escalate authority, only initiative.
- Two linked inceptions; this one waits for T-1442 GO before active dialogue.

## Pre-conditions

- T-1442 reaches GO with at least Q3 (trigger model) and Q1 (evidence shape) decided. Without those, this inception cannot meaningfully design the reviewer's input contract.

## Dialogue Log

### 2026-04-25 — Captured

Genesis dialogue lives in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log. This task captured concurrently with horizon=next pending I-A's GO.

User answers relevant to this inception:
- Q2 ✅ "Auto-tick Agent ACs and only escalate Human ACs when reviewer says 'needs human'"
- Q4 → "incept that" (reviewer scope = explore here)
- Q5 → "incept that, think about our goals and purpose of framework and risks we are trying to manage while enabling frictionless development"

### Next dialogue turn

Wait for T-1442 GO. Then reopen with sketch of reviewer interface (input = evidence shape from T-1442; output = TBD per Q-emergent).

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` |
| Linked sister inception | `.tasks/active/T-1442-ac-validation-default-flip--mechanical-v.md` |
| Genesis dialogue | `docs/reports/T-1442-ac-validation-default-flip.md` |
| TermLink dispatch reference | `CLAUDE.md` § TermLink Integration |
| Authority model reference | `CLAUDE.md` § Authority Model |
