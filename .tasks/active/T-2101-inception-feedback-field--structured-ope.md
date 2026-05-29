---
id: T-2101
name: "Inception feedback field — structured operator feedback channel on fw inception decide + Watchtower form"
description: >
  fw inception decide accepts only GO|NO-GO|DEFER + free-text rationale. Operator
  nuance (split E5 out, defer until T-2092 lands, ship upstream instead) dies in
  chat. Add additive --feedback field that lands on task body and is read by next
  session. Arc-008 anchor; sibling of T-2102/T-2103/T-2104.

status: started-work
workflow_type: inception
owner: agent
horizon: now
arc_id: inception-review-loop
tags: [inception, review-loop, operator-feedback, arc-008]
components: []
related_tasks: [T-2097, T-2098, T-2100]
created: 2026-05-29T21:20:30Z
last_update: 2026-05-29T21:25:00Z
date_finished: null
# revisit_at: YYYY-MM-DD
# revisit_evidence_needed:
---

# T-2101: Inception feedback field — structured operator feedback channel on fw inception decide + Watchtower form

## Problem Statement

`fw inception decide T-XXX go|no-go|defer --rationale "..."` is the only operator→agent channel for an inception decision. `--rationale` reads as *"why you decided that way"*, not *"what you want changed"*. Operator nuance (split E5 out, defer until T-2092 lands, prompt belongs upstream not consumer) flows into chat and dies the moment the session ends — agent has no surface to read it from on next session.

Watchtower `/review/T-XXX` form inherits the same shape (rationale only).

Origin: operator critical-review of T-2097/T-2098/T-2100 review-step text (2026-05-29). Verbatim ask: *"can we please add a feedback field to this in case review is not approved and feedback needs to be given"*.

Full research artifact: `docs/reports/T-2101-inception-feedback-field.md`.

## Assumptions

- A1: Operator feedback is a distinct concept from decision rationale.
- A2: A pure-additive field has zero migration cost across 168 existing inceptions.
- A3: Resume protocol can surface a new `## Operator Feedback` task-body section.
- A4: Watchtower `/review/T-XXX` form is extensible for a new textarea.

## Exploration Plan

Research complete (`docs/reports/T-2101-inception-feedback-field.md`). Four candidates evaluated (A: `--feedback` flag, B: repurpose `--rationale`, C: Watchtower-only, D: status quo). Recommendation: A.

## Technical Constraints

- Additive only (no schema migration of 168 existing inceptions).
- CLI / web parity required (T-1259, T-1671 precedent).
- Feedback persists as `## Operator Feedback` Markdown section on task body.
- `--rationale` semantics preserved ("why you decided" — backwards-compatible).

## Scope Fence

**In:** `lib/inception.sh` flag; Watchtower form field; resume-protocol read; task/inception detail render.

**Out:** reclassifying `--rationale`; generic comments thread; mirroring to non-inception tasks; AC text changes / template philosophy / frictionless-instructions wording / reviewer pre-flight (these are documented sibling questions Q1/Q2/Q3 in `docs/reports/T-2101-inception-feedback-field.md`; arc-008 description names them; they get filed as their own inceptions when ready for exploration).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Decide GO / NO-GO / DEFER on Candidate A (--feedback flag)
  **Steps:**
  1. Open <http://192.168.10.107:3000/review/T-2101> in your browser
  2. Read the Recommendation block + the four candidates in `docs/reports/T-2101-inception-feedback-field.md`
  3. Submit the form: select disposition, fill rationale; if you'd change anything about the proposal, dogfood the new pattern by typing it into the rationale (until the feedback field itself ships)
  **Expected:** Decision recorded, task moves to completed; on GO, build slices V1–V5 are filed
  **If not:** reply in chat with the change you want — agent will re-scope and re-file

## Go/No-Go Criteria

**GO if:**
- Operator agrees `--rationale` is genuinely lossy for "what to change" intent
- Pure-additive surface (no schema migration) is acceptable
- Build slices V1–V5 fit one PR each

**NO-GO if:**
- Operator prefers Candidate B (repurpose rationale) — different scope
- Operator prefers Candidate C (Watchtower-only) — different scope
- Operator wants this delayed until reviewer pre-flight (T-2104) ships first — defer pattern

## Verification

# Inception phase — no verification commands; decision recorded via fw inception decide.

## Recommendation

**Recommendation:** GO — Candidate A (`--feedback <text>` flag on `fw inception decide` + Watchtower form textarea).

**Rationale:** Pure additive change; zero migration cost across 168 existing inceptions; backwards-compatible. Separates two genuinely distinct concepts (decision reason vs requested change). Surfaces operator intent on the task body — read by next agent, rendered on `/tasks/T-XXX`, captured by `fw reviewer`. Closes the learning leak that motivated this inception. Lowest-coupling sibling in arc-008 — ships independently of the three documented sibling questions (Q1 template philosophy, Q2 frictionless instructions, Q3 reviewer pre-flight) which remain filed-when-ready.

**Evidence:**
- `lib/inception.sh:79-85` — current decide envelope schema (rationale-only)
- Operator challenge (2026-05-29) — verbatim ask for feedback field
- 168 inceptions ship with same boilerplate Human AC
- L-329 symmetry — don't drop operator intent the moment authorisation completes
- Full research: `docs/reports/T-2101-inception-feedback-field.md`

**Suggested follow-ups (on GO):**
- T-2101-V1: `lib/inception.sh` — accept `--feedback`; inject `## Operator Feedback` section
- T-2101-V2: Watchtower `/review/T-XXX` form — labelled textarea + POST handler
- T-2101-V3: `fw resume status` — surface `## Operator Feedback` when present
- T-2101-V4: `/tasks/T-XXX` + `/inception/T-XXX` render
- T-2101-V5: bats coverage — additive field semantics + rationale unchanged

**Rejected:**
- B (repurpose `--rationale`) — ambiguity by construction; doesn't address chat-session leak.
- C (Watchtower-only) — breaks CLI/web parity (T-1259, T-1671 precedent).
- D (status quo) — the bug being filed.

## Decisions

### 2026-05-29 — Sibling decomposition under arc-008

- **Chose:** four-question decomposition under arc-008; file T-2101 (Q4 feedback field, this task) first because it has zero dependencies and highest leverage-per-cost; document Q1 (template philosophy), Q2 (frictionless instructions), Q3 (reviewer pre-flight) as sibling questions in the research artifact + arc description; spin them out as their own inceptions when ready for exploration
- **Why:** operator caught umbrella anti-pattern in agent's first framing; CLAUDE.md §Task Sizing requires one-inception-one-question; each Q has different fix surface, blast radius, and dependency profile; pre-filing Q1/Q2/Q3 as DEFER stubs would add review-queue noise without informational gain (the decomposition is preserved in T-2101 + arc-008)
- **Rejected:** single mega-inception bundling all four (umbrella, all-or-nothing decide, coarse rationale, scope-creep risk in build slices); pre-filing all 4 sibling inceptions now (premature DEFER recommendations, review-queue noise)

## Decision

<!-- Filled at completion via: fw inception decide T-2101 go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion. -->
