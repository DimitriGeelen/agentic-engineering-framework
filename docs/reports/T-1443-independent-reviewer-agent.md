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

### 2026-04-25 — Inherited design from T-1442 dialogue (status still: captured, blocked)

T-1442's 6-turn dialogue resolved enough to constrain T-1443's design. Inherited constraints:

1. **Always-invoked, never optional** — reviewer fires on every `--status work-completed`. No skip path. No cache.
2. **Hard prereq gate** — reviewer's verdict structurally blocks status change. "Insufficient evidence" → `work-completed` rejected.
3. **Evidence quality assessment, not pass/fail** — reviewer must detect false-positive anti-patterns: tautology, empty output, mock-only, scope-narrowing, skip-as-pass.
4. **Layer 1 + Layer 2 consultation** — reviewer reads `policy/escalation-patterns.yaml` (mechanical patterns) AND task frontmatter (`risk`, `human_signoff`). Pattern match → escalate to human, regardless of evidence quality.
5. **Three-way verdict, not binary** — `mechanical-tick` / `needs-human` / `insufficient-evidence`. The third triggers the Model V re-run loop.
6. **Input contract specified** — reviewer reads task body `## Verification Output` summary + `docs/reports/T-XXX-evidence.md` full output + optional bus envelope.
7. **Daily cron ALSO uses reviewer** — Pass A re-validation invokes reviewer on fresh evidence; reviewer judges whether drift has occurred.

Spike list updated to add Spike F (anti-pattern catalogue) and Spike G (pattern-consultation interface).

### 2026-04-25 — Inherited Turn 7 (slash-command + orchestrator routing)

User raised in T-1442 dialogue: should reviewer be exposed via `/review` slash command + routed via orchestrator (T-1064) to appropriate model class?

**Answer:** Yes — strong architectural fit.
- `/review T-XXX` is the uniform entry point (slash-command surface)
- Behind it: orchestrator routes per task profile (Haiku for routine, Sonnet for standard, Opus for high-risk, external for specialised)
- Routing inputs: task `risk` + Layer 1 match + evidence size + AC count + blast-radius
- Same primitive as T-1064/T-1065 — no duplicate routing layer
- T-1443 becomes T-1064's first concrete consumer

**Spike B reframed** from "profile scope" to "routing strategy."
**Spike H added**: slash-command interface + orchestrator routing integration.
**Soft dependency:** T-1064 must be operational, or T-1443 ships with hard-coded default and swaps when T-1064 lands.

### Still open (will reopen on T-1442 GO)

- Spike B (now): routing strategy + per-profile model selection
- Spike H: slash-command shape + orchestrator integration
- Output protocol (envelope shape, where verdict lands)
- Failure-mode policy (block vs warn vs human-queue) — strong lean: block
- Reviewer auditability mechanism (sampling rate, shadow review)

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` |
| Linked sister inception | `.tasks/active/T-1442-ac-validation-default-flip--mechanical-v.md` |
| Genesis dialogue | `docs/reports/T-1442-ac-validation-default-flip.md` |
| TermLink dispatch reference | `CLAUDE.md` § TermLink Integration |
| Authority model reference | `CLAUDE.md` § Authority Model |
