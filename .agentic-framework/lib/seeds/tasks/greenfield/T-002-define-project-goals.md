---
id: T-002
name: "Define goals and architecture for __PROJECT_NAME__"
description: >
  Inception task: define what __PROJECT_NAME__ will do, its constraints, and initial
  architecture. This is the foundational decision — everything else follows from here.
status: captured
workflow_type: inception
owner: human
horizon: now
tags: [onboarding, inception]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-002: Define goals and architecture for __PROJECT_NAME__

## Context

This is an inception task. Define the problem __PROJECT_NAME__ solves, its goals, constraints, and initial architecture. Create a research artifact in `docs/reports/T-002-*.md` to capture findings.

**How this task closes.** The agent explores, writes the artifact, fills in
`## Recommendation` below, and hands off with `fw task review T-002`. The GO/NO-GO
decision itself is yours — you record it in Watchtower, not the agent on the command
line. That split is deliberate: initiative is delegated, authority is not.

## For the Operator

*This is the one step in the prologue that ends with a decision only you can make.*

**What is happening:** the agent is writing down what __PROJECT_NAME__ is for, before
anything gets built. This is an **inception** — the framework's word for exploring a
question and reaching a go/no-go, as opposed to a *build* task which produces code.

**Why it matters to you:** inceptions end with a human decision, always. The agent will
research, write it up, and hand it to you with a recommendation — GO, NO-GO, or DEFER,
with its reasoning. You confirm or overrule. The agent is structurally prevented from
deciding this itself; the framework refuses the command when an agent runs it.

**What you will be asked to do:** the agent will run `fw task review T-002` and give you a
link. Open it, read the recommendation, decide. Take your time — the prologue waits, and
nothing degrades while it does.

**Go deeper:** `fw corpus explain aef-inception-flow` — how a question becomes a decision
becomes build tasks.

## Acceptance Criteria

### Human
- [ ] [REVIEW] Problem statement is clear and scoped
  **Steps:**
  1. Read `docs/reports/T-002-*.md`
  2. Check: does it explain WHAT __PROJECT_NAME__ does and WHY?
  **Expected:** Clear problem statement, target users, key constraints
  **If not:** Add missing context to the research artifact

### Agent
- [ ] Research artifact exists: `docs/reports/T-002-*.md`
- [ ] Problem statement documented
- [ ] `## Recommendation` below is filled in — a real GO/NO-GO/DEFER with rationale
      and evidence, replacing the template comment
- [ ] Handed to the human for the decision: `fw task review T-002`

<!-- T-2862: an Agent AC reading "Go/no-go decision recorded: fw inception decide
     T-002 go" used to sit here. It was removed, for three independent reasons:

       1. It deadlocked. The decide preflight (lib/inception.sh) refuses while any
          Agent AC is unchecked — and this AC WAS the decision, so it could never
          be satisfied before the thing it gated. Every new project's first
          inception was un-completable by construction.
       2. It asserted nothing. "The decision was recorded" is exactly what the
          `## Decision` block below IS; ticking it duplicated a fact the file
          already carries.
       3. It told the agent to run a command agents are structurally forbidden to
          run. `fw inception decide` is agent-blocked under $CLAUDECODE=1 (T-1259)
          because the decision is the human's. The agent's job ends at the handoff.

     The replacement ACs are things the agent can actually do and a reader can
     actually check. The decide command itself is still documented, in the two
     places it belongs: the handoff AC above and the `## Decision` block below. -->

## Verification

# Research artifact exists
ls docs/reports/T-002-*.md
# Recommendation is filled in, not the shipped template comment (T-2862).
#
# Anchored at column 0 with no sed pre-pass. The template's own
# "**Recommendation:** GO / NO-GO / DEFER" line lives INDENTED inside the HTML
# comment below, so `^\*\*` already distinguishes a real filled recommendation
# from the shipped placeholder — the comment-stripping stage was never doing
# work the anchor doesn't do.
#
# It was also actively harmful: the P-011 extractor strips HTML comments from
# the task body before running these lines, which ate the `<!--` and `-->`
# LITERALS out of the command itself and executed `sed '//d'` — an empty regex,
# "no previous regular expression", exit 1. The greenfield first inception
# therefore failed its own verification gate on a fresh install. Found by the
# T-2862 end-to-end run; the extractor defect is filed separately.
grep -qE '^\*\*Recommendation:\*\*[[:space:]]*(GO|NO-GO|DEFER)' .tasks/active/T-002-*.md

## Recommendation

<!-- Fill this in before running `fw inception decide`. Watchtower renders this
     section — if it is empty, the reviewer sees a blank decision form.

     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** why, citing what the exploration actually turned up
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps: if the research artifact is
     already complete, commit to GO or NO-GO with the rationale you have. -->

## Decision

<!-- Filled at completion via:
     fw inception decide T-002 go|no-go|defer --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
