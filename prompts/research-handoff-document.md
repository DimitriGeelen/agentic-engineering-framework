---
id: research-handoff-document
qid: 107/P-007
agent_id: 107
counter: 7
name: "Research handoff document — structure for downstream-ingestion"
description: "Instructions for a research agent to produce a Markdown handoff doc that an AEF agent can ingest with maximum traceability and execution ability."
kind: agent
tags: [handoff, research, traceability, governance, pickup-safety]
variables: []
created: 2026-05-15T11:50:00Z
updated: 2026-05-15T11:50:00Z
---

You are producing a HANDOFF DOCUMENT that a separate agent (working in
the Agentic Engineering Framework) will ingest and convert into one or
more tracked tasks. Maximise their ability to act with traceability;
minimise their need to ask you clarifying questions.

Write a single Markdown file. Filename: `docs/reports/HANDOFF-<topic-slug>-<YYYY-MM-DD>.md`.
Use exactly the sections below, in this order, with these exact H2 names.

## Frontmatter (YAML, required)

    ---
    handoff_id: HANDOFF-<slug>-<YYYY-MM-DD>
    topic: "<one-line topic name>"
    research_dates: <YYYY-MM-DD>..<YYYY-MM-DD>
    researcher: "<your agent name + human collaborator name>"
    intended_workflow: inception | design | build | refactor | decommission
    intended_scope: "<one sentence: the deliverable, not the research>"
    blast_radius: local | project | cross-project | external
    human_decisions_pending: [Q1, Q2, ...]   # empty list if none
    constraints: ["...", "..."]               # hard limits, non-negotiable
    non_goals:   ["...", "..."]               # things the receiving agent must NOT do
    related_tasks: [T-XXXX, T-YYYY]           # if known
    related_files: ["path/a", "path/b"]       # if known
    ---

## 1. TL;DR (3-5 sentences max)

State the problem, the recommendation, and the proposed first concrete
action. The receiving agent should be able to size the work from this
section alone. No qualifiers.

## 2. Problem framing

What were we researching, and why now? What changed that made this
worth investigating? One paragraph.

## 3. Findings

Numbered list. Each finding:
- Statement (one sentence)
- Evidence (specific: file path, URL, command output, measurement, prior task ID)
- Confidence (high / medium / low — explicitly)
- Implication ("therefore, …")

Findings are FACTS as of the research date. If a fact has decayed since,
say so.

## 4. Decisions made during research

For each decision we already settled (i.e. NOT for the receiving agent
to revisit):
- **Chose:** what we settled on
- **Rejected:** alternatives + one-line reason
- **Why:** the load-bearing rationale
- **Reversibility:** cheap | costly | irreversible

If we made no decisions and everything is still open, say so — write
"None — all decision points listed in §6."

## 5. Recommendation

Pick ONE of:
- **GO** — build now, with the scope in §7
- **GO-WITH-MODIFICATIONS** — list what to change before building
- **DEFER** — park, with the trigger that would unpark it
- **NO-GO** — don't build, with the reasoning

If GO or GO-WITH-MODIFICATIONS: state the FIRST deliverable in one
sentence. The receiving agent will create a task from this sentence,
so it must be a real deliverable, not a heading.

## 6. Open questions for the human

Numbered. Each question:
- The question (specific, answerable)
- Why it matters (what gets blocked if unanswered)
- Default if unanswered (what the receiving agent should assume)

These are for the HUMAN. The receiving agent will surface them via
`fw task review`, not answer them.

## 7. Proposed task breakdown

If §5 recommends GO, list the tasks the receiving agent should create.
For each:

### T-NEW-<n>: <name>
- **Workflow type:** inception | design | build | refactor
- **Scope:** one sentence
- **Acceptance Criteria — Agent:** (criteria a script can verify)
  - [ ] <criterion 1: specific, mechanical>
  - [ ] <criterion 2>
- **Acceptance Criteria — Human:** (only if subjective; mark `[REVIEW]`)
  - [ ] [REVIEW] <criterion>
    - **Steps:** numbered, copy-pasteable
    - **Expected:** what success looks like
    - **If not:** fallback / diagnostic
- **Verification (shell commands, one per line, must pass):**

      <cmd 1>
      <cmd 2>

- **Estimated size:** fits-one-session | needs-split
- **Dependencies:** [T-OTHER] or "none"

If a task needs splitting, propose the split. Do not propose a task
that bundles >1 deliverable.

## 8. Constraints, non-goals, blast radius

Restate (don't just point to frontmatter) so the receiving agent
internalises them:
- What the build MUST respect (compat, security, performance)
- What the build MUST NOT do (scope creep traps)
- Who/what is affected if this ships (or breaks)

## 9. Risks and prevention

For each risk:
- The risk (concrete, not "unknown unknowns")
- Likelihood (high/med/low)
- Mitigation (what to bake in)
- Detection (how we'd know it happened)

Include reversibility risks specifically — if the build crosses a
one-way door, flag it.

## 10. Dialogue log

The reasoning trail. Each significant exchange between you and the
human as a bullet:
- **Q (human/agent):** the question or assertion
- **A:** the response
- **Outcome:** what changed in our position

Capture course corrections explicitly. Capture moments where you (the
research agent) updated your prior. The receiving agent reads this to
understand WHY the decisions in §4 are what they are, not just WHAT
they are. Without this, decisions look arbitrary in 3 months.

## 11. Artifacts and links

- Files we read or wrote during research (with line numbers if specific)
- External URLs (with one-line reason for relevance)
- Prior tasks / decisions this builds on (T-XXXX, ADR-NN)
- Anything the receiving agent will want at hand

## 12. Pickup safety markers (REQUIRED)

State these explicitly to prevent the receiving agent from treating
this document as build authorization:

> **This is a research handoff, not a build mandate.** The receiving
> agent should create tasks per §7, set focus, write real ACs (replacing
> any placeholder I wrote), and proceed only after the appropriate
> governance gate (inception decide / task gate) is satisfied. The
> imperative tone of §7 is a PROPOSAL, not an instruction to skip
> scoping. If §7 describes >3 new files, a new subsystem, a new CLI
> route, or a new external integration, the first task MUST be an
> inception task — not a build task.

## Writing rules

- No emojis unless the topic genuinely requires them.
- No marketing voice. Plain declarative sentences.
- Cite specific paths and line numbers (`web/app.py:127`), not vague
  "the auth module".
- If you don't know something, write "unknown" — don't bridge with
  plausible-sounding speculation.
- Don't repeat content across sections. Cross-reference: "see §3, finding 4".
- Every command in §7 verification MUST be runnable from the project
  root, copy-pasteable, single-line per command.
- If a finding contradicts an earlier finding, keep both and flag the
  conflict — do not silently reconcile.
- Length: as long as it needs to be. A small handoff is 2 pages; a
  substantive one is 10. Padding is worse than gaps.

Deliver the file. Then post a one-line summary back to me with the
filename and the §5 recommendation verdict.
