# T-2101: Inception feedback field — structured operator feedback channel

**Status:** inception (research artifact, C-001)
**Filed:** 2026-05-29
**Arc:** arc-008 inception-review-loop (anchor)
**Sibling questions (documented, filed-when-ready):** Q1 template philosophy (generic vs bespoke Human ACs), Q2 frictionless operator instructions (URL, form field name, button label), Q3 reviewer pre-flight (extend `fw reviewer` to verify review-readiness statically)
**Origin:** Operator critical-review challenge on T-2097/T-2098/T-2100 review surface — "add a feedback field … should we RCA & incept this?"

---

## Problem Statement

`fw inception decide T-XXX go|no-go|defer --rationale "..."` is the only operator-to-agent channel for an inception decision. `--rationale` reads as *"why you decided that way"*, not *"what you want changed"*. Today the operator's nuanced feedback — *"GO but split E5 out"*, *"DEFER until T-2092 lands"*, *"NO-GO because the prompt belongs upstream not consumer"* — flows into a chat session and **dies the moment the session ends**. The agent has no surface to read it from on next session.

The Watchtower form (`/review/T-XXX`) inherits the same shape: GO/NO-GO/DEFER + rationale only. No feedback field.

`lib/inception.sh:79-85` confirms the envelope schema:

```
--recommendation GO|NO-GO|DEFER   (interpreted as: human's agreement)
--rationale "<text>"              (interpreted as: human's reason for that agreement)
```

There is no third field — nothing structured for *"here's what the agent should change next."*

## Assumptions

A1. **Operator feedback is a distinct concept from decision rationale.** Conflating them in `--rationale` is lossy.
- Test: read recent NO-GO/DEFER rationales — count how many embed an "I'd approve if X" or "do Y instead" clause vs purely stating a reason.

A2. **A pure-additive field has zero migration cost.** 168 existing inceptions stay valid.
- Test: write a stub PR that adds the field with default empty; verify all 168 still pass audit.

A3. **The agent's resume protocol can be extended to surface a new task-body section.** `fw resume status` already reads task files.
- Test: check `agents/resume/*.sh` and `lib/resume.sh` for the section-extraction pattern.

A4. **The Watchtower `/review/T-XXX` form is extensible for a new textarea.** No HTMX semantics block it.
- Test: read `web/templates/review.html` (or equivalent) for form-field layout.

## Exploration Plan

This question is small enough that the exploration IS the four candidates below + an evidence walk. No spike code required pre-decide.

## Technical Constraints

- **Additive only.** No schema migration of existing inceptions. New field defaults empty; absence is silently valid.
- **CLI parity.** `fw inception decide` and Watchtower form must accept the same field.
- **Task-body persistence.** Feedback lands as a `## Operator Feedback` Markdown section on the task file (read by next agent, rendered on `/tasks/T-XXX`).
- **No semantic re-interpretation of `--rationale`.** That field stays "why you decided" — backwards-compatible.

## Scope Fence

**In:**
- `lib/inception.sh` — accept `--feedback` flag
- Watchtower `/review/T-XXX` form — feedback textarea
- Agent resume protocol — surface `## Operator Feedback` section when set
- Render on `/tasks/T-XXX` and `/inception/T-XXX` detail pages

**Out:**
- Reclassifying `--rationale` (separate question)
- Generic comments thread (this is operator-only, structured-once-per-decision)
- Mirroring to non-inception tasks (separate question if surfaced later)
- AC text changes (T-2102/T-2103/T-2104 cover that)

## Candidates

### Candidate A — `--feedback <text>` flag (RECOMMENDED)

Add a new CLI flag and Watchtower form field. Persists as `## Operator Feedback` section on the task body. Independent of GO/NO-GO/DEFER (operator can leave feedback on any disposition — particularly valuable on GO ["ship it, but also do X"] and DEFER ["I'll come back when Y"]).

**Pros:** clean schema; backwards-compatible; reads naturally; minimal surface (one CLI flag, one form field, one section, one render).
**Cons:** one more thing to fill in (mitigated: defaults empty; no gate).

### Candidate B — Repurpose `--rationale` to mean "feedback + reason combined"

Document a convention that operators put feedback into rationale.

**Pros:** zero schema change.
**Cons:** ambiguity-by-construction; agent has to parse intent; loses the *"why you decided"* meaning that `--rationale` was designed for; doesn't fix the chat-session leak.

### Candidate C — Watchtower-only comments thread

Skip CLI; only Watchtower can capture feedback.

**Pros:** no CLI work.
**Cons:** breaks CLI/web parity; operator using CLI loses the channel; doesn't address the chat-session leak when feedback comes via terminal.

### Candidate D — Status quo

Operator types feedback into chat. Agent reads it once, hopes to remember.

**Pros:** nothing to change.
**Cons:** this is the bug being filed.

## Recommendation

**Recommendation:** GO — Candidate A.

**Rationale:**
- Pure additive change; no migration cost; backwards-compatible across 168 existing inceptions.
- Surfaces operator intent on the task body itself — read by next agent, rendered on `/tasks/T-XXX`, captured by `fw reviewer` static scan, mineable for future patterns.
- Separates two genuinely distinct concepts (decision *reason* vs requested *change*) — preserves `--rationale` semantics.
- Closes the learning leak that motivated the operator's challenge: feedback no longer dies in chat.
- Lowest-coupling sibling in arc-008 — ships independently of T-2102/T-2103/T-2104.

**Evidence:**
- `lib/inception.sh:79-85` — current decide envelope schema (rationale-only).
- Operator challenge (2026-05-29 session) on T-2097/T-2098/T-2100 review surface — verbatim ask: *"can we please add a feedback field to this in case review is not approved and feedback needs to be given"*.
- 168 inceptions filed with the boilerplate Human AC (`grep -l "Review the Agent Recommendation section and go/no-go criteria" .tasks/{active,completed}/T-*.md | wc -l`) — every one of them would benefit from the field on close.
- L-329 (don't human-gate propagation of authorised decisions) — by symmetry, don't *drop* operator intent the moment authorisation completes.

**Suggested follow-ups (on GO):**
- V1: `lib/inception.sh` — accept `--feedback`; inject `## Operator Feedback` section into task body.
- V2: Watchtower `/review/T-XXX` form — add labelled textarea; wire to POST handler.
- V3: `fw resume status` — surface `## Operator Feedback` when present on focused task.
- V4: `/tasks/T-XXX` + `/inception/T-XXX` render the section visibly.
- V5: bats coverage — additive field accepts empty / single-line / multi-line; rationale semantics unchanged.

**Rejected:**
- B (repurpose rationale) — ambiguity-by-construction; doesn't address chat-session leak; harms existing 168-task body semantics.
- C (Watchtower-only) — breaks CLI/web parity established by T-1259/T-1671.
- D (status quo) — the bug being filed.

---

## Dialogue Log

**2026-05-29.** Operator critically reviewed the resume listing of T-2097/T-2098/T-2100 awaiting decide, applying four lenses:
- (a) Is the operator needed?
- (b) Can the review agent do this?
- (c) If operator needed, are the instructions frictionless?
- (d) Can we add a feedback field for when review is not approved?

Agent first response: proposed one inception bundling all four concerns. Operator pushed back: *"sound too risky to club that all under one inception or am i wrong?"* — caught the umbrella anti-pattern (CLAUDE.md §Task Sizing: "One inception = one question"; "Decomposition signal: 3+ independent problem domains").

Agent decomposed into four sibling questions under arc-008:
- **Q4 = T-2101 (this task) — feedback field.** Zero deps, highest leverage. Ships first.
- Q1 — template philosophy (generic vs bespoke Human ACs).
- Q2 — frictionless operator instructions (URL, form field name, button label).
- Q3 — reviewer pre-flight (extend `fw reviewer` to verify review-readiness statically).

Operator instructed: *"do what is most robust"*. Agent's final call: file the arc + T-2101 (Q4) fully scoped for immediate decide; document Q1/Q2/Q3 here and in the arc description rather than pre-filing them as DEFER stubs. Robustness reasoning: the decomposition is preserved in three places (T-2101 `## Decisions`, this artifact, arc-008 description) so it survives session boundaries; but pre-filing three more inceptions would add review-queue noise without informational gain because their exploration hasn't been done. Spin them out as their own inceptions when each is ready for real exploration — typically post-Q4 ship (when the feedback field itself helps inform Q2's wording).
