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

## Status (2026-04-25 update)
**T-1442 GO recorded.** Active dialogue underway. Spikes A, D, F (refactored), I resolved. Remaining: B, C, E, G (next), H.

## Dialogue Log (active session)

### 2026-04-25 — Turn 8: Spike A (reviewer interface)

Agent proposed structured envelope:
- **Input**: task file (frontmatter + agent_acs) + evidence (summary + full + optional bus) + context (commits + fabric blast-radius + Layer 1 patterns) + routing metadata (model_class + review_depth)
- **Output**: overall_verdict (mechanical-tick / needs-human / insufficient-evidence) + per-AC granular verdicts + reasoning + reviewer_signature + digest

Three baked-in shape decisions:
1. Output is structured envelope, not free-form text
2. Per-AC verdicts (granular) — reviewer acts per individual Agent AC, not whole task
3. Reviewer signature + digest for auditability + tamper detection

### 2026-04-25 — Turn 9: User question — how is "needs-human" established?

User flagged that my "needs-human" verdict was overloaded. Five distinct drivers identified:

1. **Original AC classification** — `### Human` vs `### Agent` heading at task creation
2. **Layer 1 mechanical patterns** — `policy/escalation-patterns.yaml` (T-1442)
3. **Layer 2 frontmatter** — `risk: high`, `human_signoff: required`
4. **Evidence anti-patterns at runtime** — reviewer-detected (Spike F)
5. **AC content semantic patterns** — subjective-judgment language (codifiable as Layer 1 sub-pattern)

**Verdict rule**: AC needs human if ANY driver fires (additive, not exclusive).

**Critical sovereignty rule**: Reviewer NEVER auto-ticks a `### Human` AC. Original classification is inviolable. Reviewer can only:
- Surface Human ACs with full evidence + recommendation
- Flag classification drift ("could be reclassified Agent")
- Pre-fill verification steps to speed human review

Refined per-AC envelope: `original_classification` + `drivers_evaluated` + `reviewer_judgment` + `classification_drift_flag` + `action`.

### 2026-04-25 — Turn 10: User asks for learning loop — Spike I emerges

User: *"want to emphasize... means to learn, where I can say don't ask me for this in the future or something like that?"*

Two feedback shapes identified:
- **A: "Don't escalate this pattern again"** — suppress matching Layer 1 pattern for fingerprint
- **B: "Reclassify this AC type as Agent"** — tune T-954 guidance, flag drift as resolved

Override mechanism designed:
- File: `policy/escalation-overrides.yaml`
- Per-override: source_pattern + scope (fingerprint, breadth) + action (suppress / downgrade-to-warn) + reason + created_by (always human) + created_at + expires_at + auto_revoke_triggers
- Watchtower UX: collapsed-by-default override checkboxes alongside Approve/Decline/Insufficient buttons
- Antifragility safeguards: auto-revoke on related-incident detection by Pass B audit cron, on concern register hits, on TTL expiry; surface for renewal

Sovereignty: human creates overrides; agent never; auto-revoke triggers respect human authority.

### 2026-04-25 — Turn 11: User emphasizes feedback UX is load-bearing

User: *"these UX capabilities for human to quickly consistently provide feedback is important for this to work well... frictionless feedback, makes regular feedback, pre-formatted feedback options with ability to expand, structured data signals."*

Seven UX principles locked:
1. Default path is one-click (a/d/i keyboard shortcuts)
2. Override options always visible, never required (collapsed-by-default but discoverable)
3. Pre-formatted choices first, free-text last
4. Consistent across every escalation (muscle memory)
5. Structured data only — no free-form classification
6. Aggregable + queryable — every click writes structured record to `.context/working/feedback-stream.yaml`
7. Reversible without penalty — every override has undo + TTL

Feedback stream feeds three downstream consumers: Layer 1 pattern catalogue, T-954 classification guidance, Watchtower analytics page.

### 2026-04-25 — Turn 12: Spike F (anti-pattern catalogue) seed

Agent drafted 12-category seed:
1. Tautology assertion
2. Empty-body test
3. Mock-only integration
4. Empty-output success
5. Skip-as-pass
6. Safety-mechanism bypass
7. Stale evidence
8. AC-verification mismatch
9. Output spoofing
10. Swallowed errors
11. Zero-test gaming
12. Partial-truth scope

Each with detection mechanism (static / dynamic) and tier applicability.

### 2026-04-25 — Turn 13: User flags severity-axis conflation — major refactor

User: *"not sure if we using classification low/medium/high correctly here... believe we are mixing risks with occurrences / type of failure / cause of failure can that be?"*

**Conceded conflation.** Three axes were collapsed into one HIGH/MEDIUM label:
- Detection confidence (am I sure this IS the pattern?)
- Lie severity (how badly does the evidence shape mislead?)
- Action severity (what should the framework do in response?)

**Refactored model:**

**Axis A — about the anti-pattern itself (intrinsic):**
- `detection_confidence`: deterministic / heuristic / semantic
- `lie_severity`: complete / severe / partial / narrow / staleness

**Axis B — about the task being verified (already-existing concerns):**
- `task.risk` (T-1442 Layer 2 frontmatter)
- `task.blast_radius` (`fw fabric impact`)
- `task.workflow_type`

**Axis C — action = function(A, B, overrides)** — separate policy file `policy/action-matrix.yaml`. Decision matrix combines anti-pattern attributes with task attributes to determine action (block / escalate / note). Spike I overrides apply at the action layer.

Default action mapping (rough):
| lie_severity | risk | action |
|---|---|---|
| complete or severe | any | block (insufficient-evidence) |
| partial | low | escalate (needs-human) |
| partial | medium / high | block |
| narrow | low | note |
| narrow | medium | escalate |
| narrow | high | block |
| staleness | any | re-run (Model V mandates) |

User also raised that catalogue should be expanded beyond agent's view via:
- External research (industry test-smell catalogues, mutation testing literature, academic SE)
- Internal corpus mining (`.tasks/completed/` evidence files, `.context/audits/`, `concerns.yaml`)
- Peer-agent TermLink dispatch for cross-project anti-pattern capture

→ Captured as **B-Anti-Patterns-Expansion** (B-N) follow-up build task.

## Decisions captured (so far)

1. **Reviewer interface = structured envelope** with per-AC granularity + signature + digest (Spike A)
2. **Per-AC verdicts, not whole-task** — partial blocks possible (Spike A + D)
3. **Sovereignty preservation: reviewer NEVER ticks `### Human` ACs** — structurally enforced
4. **5-driver "needs-human" model**: original classification + Layer 1 + Layer 2 + anti-patterns + AC semantic class — additive (Turn 9)
5. **Spike I — override mechanism**: don't-ask-pattern + reclassify-AC-type with TTL + auto-revoke; human creates, agent never
6. **7 UX principles** for Watchtower feedback (Turn 11)
7. **Anti-pattern catalogue 12-category seed** + multi-source expansion (Spike F + Turn 13)
8. **Severity refactor**: separate pattern attributes from task attributes from action policy
9. **Three policy files** anticipated: `policy/anti-patterns.yaml` (catalogue) + `policy/action-matrix.yaml` (action) + `policy/escalation-overrides.yaml` (Spike I overrides). Plus `policy/escalation-patterns.yaml` from T-1442.

## Still open (next)

- **Spike G** (NEXT): Pattern-consultation interface — how reviewer mechanically loads + applies all policy files together
- **Spike B**: Routing strategy + per-profile model selection
- **Spike H**: Slash-command shape + orchestrator integration
- **Spike C**: Authority bounds (cannot-list, structural enforcement)
- **Spike E**: Reviewer auditability mechanism (sampling rate, shadow review)

## Anchor files

| Artifact | Path |
|---|---|
| Inception task body | `.tasks/active/T-1443-independent-reviewer-agent--termlink-dis.md` |
| Linked sister inception | `.tasks/active/T-1442-ac-validation-default-flip--mechanical-v.md` |
| Genesis dialogue | `docs/reports/T-1442-ac-validation-default-flip.md` |
| TermLink dispatch reference | `CLAUDE.md` § TermLink Integration |
| Authority model reference | `CLAUDE.md` § Authority Model |
