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
updated: 2026-05-15T14:25:00Z
---

You are producing a HANDOFF DOCUMENT that a separate agent (working in
the Agentic Engineering Framework) will ingest and convert into one or
more tracked tasks. Maximise their ability to act with traceability;
minimise their need to ask you clarifying questions.

## Bindings (read these first; they govern the whole document)

1. **Traceability by ID, not prose.** Every Finding gets an ID (F1, F2…),
   every Decision gets an ID (D1, D2…), every Assumption gets an ID
   (A1, A2…), every Open Question gets an ID (Q1, Q2…). Later sections
   reference earlier IDs explicitly. "Because of F3 + F7" is auditable;
   "based on our research" is not.
2. **Evidence or nothing.** Findings without specific evidence (file:line,
   command + output, URL + section, prior-task ID, measurement) get
   dropped. Soft phrases — "I think", "probably", "in my experience" —
   are anti-evidence; if that's all you have, mark the item as an
   Assumption (§4a), not a Finding.
3. **Research is not authorization.** Your §7 task breakdown is a PROPOSAL.
   The receiving agent decides scope and gate (build vs inception). Do
   not phrase it as instructions.

Write a single Markdown file. Filename: `docs/reports/HANDOFF-<topic-slug>-<YYYY-MM-DD>.md`.
Use exactly the sections below, in this order, with these exact H2 names.

## Frontmatter (YAML, required)

    ---
    handoff_id: HANDOFF-<slug>-<YYYY-MM-DD>
    version: 1                                # bump on revisions
    supersedes: <prior_handoff_id|null>       # if this replaces an earlier handoff
    depends_on_handoffs: []                    # blocking — see §11.5. The §5 recommendation
                                               # in THIS handoff cannot be acted on until each
                                               # listed handoff has reached §5: GO AND its
                                               # first deliverable has shipped. Receiving
                                               # agent halts and surfaces to the human if
                                               # either condition is unmet.
    related_handoffs: []                       # informational only — "see also" references.
                                               # NOT enforced by §11.5. Use this for context-
                                               # adjacent work; reserve depends_on_handoffs:
                                               # for genuinely blocking dependencies.
    topic: "<one-line topic name>"
    research_dates: <YYYY-MM-DD>..<YYYY-MM-DD>
    researcher: "<your agent name + human collaborator name>"
    intended_workflow: inception | design | build | refactor | decommission
    intended_scope: "<one sentence: the deliverable, not the research>"
    blast_radius: local | project | cross-project | external
    decided_by_overall: human | agent | jointly   # who is sovereign for the §5 verdict
    human_decisions_pending: [Q1, Q2, ...]     # IDs from §6; empty list if none
    constraints: ["...", "..."]                # hard limits, non-negotiable
    non_goals:   ["...", "..."]                # things the receiving agent must NOT do
    related_tasks: [T-XXXX, T-YYYY]            # if known
    related_files: ["path/a", "path/b"]        # if known
    ---

## 1. TL;DR (3-5 sentences max)

State the problem, the recommendation, and the proposed first concrete
action. The receiving agent should be able to size the work from this
section alone. No qualifiers.

## 2. Problem framing

What were we researching, and why now? What changed that made this
worth investigating? One paragraph.

## 3. Findings

Numbered with stable IDs. Each finding:

    ### F<n>: <one-line statement>
    - **Evidence:** <file:line | command + output snippet | URL + section
                    | prior-task ID | measurement>
    - **Confidence:** high | medium | low
    - **Implication:** therefore, …
    - **Polarity:** positive (works / exists) | negative (ruled out / doesn't work)

Findings are FACTS as of the research date. If a fact has decayed since,
say so on the finding line.

**Anti-evidence (must not appear in a Finding):** "I think", "probably",
"in my experience", "it should", "typically", "usually", unsourced
statistics, bare URLs without the relevant section, references to "the
docs" without a path. If that's all you have, demote to §4a Assumption
or §6 Open Question.

## 4. Decisions made during research

Numbered with stable IDs. Each:

    ### D<n>: <one-line topic>
    - **Chose:** what we settled on
    - **Rejected:** alternatives + one-line reason each
    - **Why:** the load-bearing rationale
    - **Decided-by:** human | agent | jointly       # authority trail
    - **Supports:** F<x>, F<y>                       # findings it relies on
    - **Reversibility:** cheap | costly | irreversible

If we made no decisions and everything is still open, write "None — all
decision points listed in §6."

## 4a. Assumptions

Propositions the §5 recommendation is **conditional on**. If any breaks,
the recommendation is no longer load-bearing and §5 needs re-evaluation.

    ### A<n>: <the proposition>
    - **Why we believe it:** <basis: F<x>, external doc, conventional wisdom>
    - **What breaks if false:** <which Decisions or §7 tasks collapse>
    - **How to test:** <command, file check, or "ask <party>">
    - **Confidence:** high | medium | low

Write "None" if the recommendation is unconditional. (Rare — most builds
sit on at least one assumption about the environment, the upstream API,
or what the human will accept.)

## 5. Recommendation

Pick ONE of:
- **GO** — build now, with the scope in §7. Cite supporting Findings/Decisions: "supports: F1, F3, D2"
- **GO-WITH-MODIFICATIONS** — list what to change before building. Cite which Finding/Assumption forces the modification.
- **DEFER** — park, with the trigger that would unpark it (e.g. "A2 resolved", "F4 confirmed by measurement", or "HANDOFF-<id> ships its first deliverable" — in which case also list it in `depends_on_handoffs:`).
- **NO-GO** — don't build, with the reasoning. Cite the blocking Finding/Assumption.

If GO or GO-WITH-MODIFICATIONS: state the FIRST deliverable in one
sentence. The receiving agent will create a task from this sentence,
so it must be a real deliverable, not a heading.

## 6. Open questions for the human

Numbered with stable IDs. Each:

    ### Q<n>: <the question>
    - **Why it matters:** what gets blocked / decided wrong if unanswered
    - **Default if unanswered:** what the receiving agent should assume to proceed
    - **What we assumed during research:** <if any; may match the default>

These are for the HUMAN. The receiving agent will surface them via
`fw task review`, not answer them.

## 7. Proposed task breakdown

If §5 recommends GO, list the tasks the receiving agent should create.
For each:

    ### T-NEW-<n>: <name>
    - **Workflow type:** inception | design | build | refactor | decommission
    - **Scope:** one sentence
    - **Operationalises:** F<x>, D<y>                       # which findings/decisions this task delivers
    - **Acceptance Criteria — Agent:** (criteria a script can verify)
      - [ ] <criterion 1: specific, mechanical> (covers F<x>)
      - [ ] <criterion 2>                       (covers D<y>)
    - **Acceptance Criteria — Human:** (only if subjective; mark `[REVIEW]`)
      - [ ] [REVIEW] <criterion>
        - **Steps:** numbered, copy-pasteable
        - **Expected:** what success looks like
        - **If not:** fallback / diagnostic
    - **Verification (shell commands, one per line, must pass):**

          <cmd 1>
          <cmd 2>

    - **Sizing:**
        - files_touched: <n>           # new + modified
        - new_components: <n>          # new modules / files / endpoints
        - novel_mechanism: yes | no    # is there a new pattern not present in the repo
        - est_hours: <n>               # honest estimate
        - verdict: fits-one-session | needs-split   # split if est_hours >4 OR new_components >3 OR novel_mechanism=yes
    - **Dependencies:** [T-OTHER] or "none"

The `T-NEW-<n>` placeholder is intentional — the receiving agent
assigns the real T-ID. Do not invent T-IDs.

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
one-way door (see §12 trigger list), flag it here too.

## 10. Dialogue log

The reasoning trail. Distilled, not verbatim — capture the moments
that moved the position, not every exchange. Each significant moment:
- **Q (human/agent):** the question or assertion
- **A:** the response
- **Outcome:** what changed in our position (cite the F/D/A IDs that emerged or shifted)

Capture course corrections explicitly. Capture moments where you (the
research agent) updated your prior. The receiving agent reads this to
understand WHY the decisions in §4 are what they are. Without this,
decisions look arbitrary in 3 months.

## 11. Artifacts and links

- Files we read or wrote during research (with line numbers if specific)
- External URLs (with one-line reason for relevance)
- Prior tasks / decisions this builds on (T-XXXX, ADR-NN)
- Supporting artifacts produced (spike code, screenshots, dataset extracts):
  state path + one-line description. The receiving agent will preserve
  these; do not leave them in `/tmp`.

## 11.5. Pre-action checks (for the receiving agent)

Before acting on this handoff, the receiving agent should verify:

- [ ] Every path cited in §3 / §11 still exists at the cited location.
      (Files move; cited line numbers drift. Stale references = stale handoff.)
- [ ] Every task ID cited (T-XXXX) still has the status assumed in this doc.
      (A "completed" cited task may have been reopened; an "active" one may
      have been closed and superseded.)
- [ ] No newer handoff supersedes this one (search prompts/, docs/reports/
      for `supersedes: <this handoff_id>`).
- [ ] Every handoff listed in `depends_on_handoffs:` (frontmatter) has
      reached **both** of these states:
      1. Its §5 recommendation is **GO** (not DEFER, not NO-GO, not unresolved).
      2. Its first deliverable has **shipped** (the task created from its §5
         first-deliverable sentence has reached `work-completed` and the
         commit has landed on master).
      Failure modes are different and report differently:
      - §5 not GO → "<handoff_id> recommendation is <verdict>; this handoff
        depends on it and may never materialise. Surface to human."
      - §5 is GO but first deliverable not shipped → "<handoff_id> reached
        GO at <timestamp>; first deliverable <task_id> is <status>. This
        handoff cannot proceed until that deliverable lands. Halt and wait
        / surface to human."
      Do NOT silently proceed. The `related_handoffs:` field exists for
      non-blocking "see also" references — if a listed dependency turns
      out to be misclassified, the human will move it to `related_handoffs:`.
- [ ] Every tool / command cited in §7 Verification is installed and on PATH
      (or the task's Verification commands cleanly skip when not — `command -v X && …`).
- [ ] Every Assumption in §4a still holds (check via the `How to test:` field).
      If any has flipped since `research_dates`, halt and request a §5 re-evaluation
      before creating tasks.

If any check fails: post a one-line summary back to the human and do not
proceed to task creation.

## 12. Pickup safety markers (REQUIRED)

State these explicitly to prevent the receiving agent from treating
this document as build authorization:

> **This is a research handoff, not a build mandate.** The receiving
> agent should create tasks per §7, set focus, write real ACs (replacing
> any placeholder I wrote), and proceed only after the appropriate
> governance gate (inception decide / task gate) is satisfied. The
> imperative tone of §7 is a PROPOSAL, not an instruction to skip
> scoping.

**Inception-required triggers.** If §7 (alone or combined) describes
ANY of the following, the first task MUST be an inception task — not
a build task:

- More than 3 new files, or any new subsystem
- A new CLI route or top-level command
- A new external integration (network call, third-party API, new vendor)
- A force-push requirement (rewriting shared history)
- A destructive migration (data loss possible, even if intended)
- A schema break (downstream consumers will break without coordinated update)
- Secret handling (creation, rotation, transit, storage of credentials)
- Cross-repo coordination (changes must land in another repo to be valid)
- An irreversible external action (publish, deploy to prod, send communication)

## Writing rules (reference; bindings at top govern)

- No emojis unless the topic genuinely requires them.
- No marketing voice. Plain declarative sentences.
- Cite specific paths and line numbers (`web/app.py:127`), not vague
  "the auth module".
- If you don't know something, write "unknown" — don't bridge with
  plausible-sounding speculation. Demote weak claims to §4a or §6.
- Don't repeat content across sections. Cross-reference by ID:
  "see F3" / "addressed by D2" / "blocked on Q1".
- Every command in §7 Verification MUST be runnable from the project
  root, copy-pasteable, single-line per command.
- If a finding contradicts an earlier finding, keep both and flag the
  conflict — do not silently reconcile.
- Length: as long as it needs to be. A small handoff is 2 pages; a
  substantive one is 10. Padding is worse than gaps.

Deliver the file. Then post a one-line summary back to me with the
filename, the §5 recommendation verdict, and the count of open Q<n>
items.
