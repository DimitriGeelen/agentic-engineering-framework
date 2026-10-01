---
id: T-002
name: "Define goals and objectives for __PROJECT_NAME__"
description: >
  Inception task: define what __PROJECT_NAME__ will do, its constraints, and initial
  architecture, and write it down ONCE as .context/project/objectives.yaml. This is
  the foundational decision — everything else follows from here.
status: captured
workflow_type: inception
owner: human
horizon: now
tags: [onboarding, inception, objectives-authoring]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-002: Define goals and objectives for __PROJECT_NAME__

## Context

This is an inception task. Define the problem __PROJECT_NAME__ solves, its goals,
constraints, and initial architecture.

**The outcome is a file, not an essay:** `.context/project/objectives.yaml`. This is the
one moment in the project's life where its objectives are authored. After this, they are
not rewritten to stay current: progress is derived from the work (arcs and tasks point
at objective ids), and the framework's audit flags objectives nothing serves. Free prose
written here would be read once and never again, so the structured file is the
deliverable. A research artifact in `docs/reports/T-002-*.md` is optional, for the
reasoning behind it.

**If the file already exists** (the installer asked for the project goal and wrote a
first version), do not start again: refine that file from what the exploration turns up,
keep its ids, and hand it over the same way.

**How this task closes.** The agent drafts the file, gets it reviewed by an independent
reviewer if one is available (`fw reviewer T-002`, or another model), fills in
`## Recommendation` below, and hands off with `fw task review T-002`. You see the draft
once and ratify it, or say what to change. The GO/NO-GO decision itself is yours — you
record it in Watchtower, not the agent on the command line. That split is deliberate:
initiative is delegated, authority is not.

### The shape to write

```yaml
# Project objectives — __PROJECT_NAME__.
#
# Authored intent; progress is derived, never written here.
# Arcs reference these ids via `supports: [O-n, ...]`.
headline: >-
  One or two sentences: who this is for and what it does for them.
objectives:
  - id: O-1
    text: >-
      An outcome a user or operator would notice, not an activity.
    measure: >-
      How you would know it holds. Say plainly if it is not measured yet.
  - id: O-2
    text: >-
      ...
    measure: >-
      ...
out_of_scope:
  - "Something a reasonable person might expect this project to do, and it will not."
```

Keep objectives few (three to six). Every objective needs a `measure`, even if the honest
answer is "not measured yet": the gap is then on the record instead of hidden.

## For the Operator

*This is the one step in the prologue that ends with a decision only you can make.*

**What is happening:** the agent is writing down what __PROJECT_NAME__ is for, before
anything gets built, as a short file of objectives: a headline, a handful of objectives
each with a way to tell whether it holds, and what is deliberately out of scope. This is
an **inception** — the framework's word for exploring a question and reaching a
go/no-go, as opposed to a *build* task which produces code.

**Why it matters to you:** this is the only time you will be asked to author the
project's objectives. Later work points back at them, so whether the project is on
course can be read from the work rather than from a document someone has to keep
updating. The agent drafts; you read it once and confirm or correct.

**What you will be asked to do:** the agent will run `fw task review T-002` and give you a
link. Open it, read `.context/project/objectives.yaml` and the recommendation, decide.
Take your time — the prologue waits, and nothing degrades while it does.

**Go deeper:** `fw corpus explain aef-inception-flow` — how a question becomes a decision
becomes build tasks.

## Acceptance Criteria

### Human
- [ ] [REVIEW] The objectives say what __PROJECT_NAME__ is for, in words you would use
  **Steps:**
  1. Read `.context/project/objectives.yaml`
  2. Check: does the headline say WHAT __PROJECT_NAME__ does and for WHOM? Is each
     objective an outcome you care about, with a measure you would accept? Is anything
     you expect it to do missing, or anything listed out of scope that should not be?
  **Expected:** You would sign the file as written, or after the changes you named
  **If not:** Tell the agent what to change; it edits the file and hands it back

### Agent
- [ ] `.context/project/objectives.yaml` exists in the shape above: the header line
      saying authored intent, progress is derived; headline; objectives (each with id,
      text, measure); out_of_scope
- [ ] Drafted from the material of this project (what the operator said, the problem, any
      existing notes) — never copied from another project or from the framework
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

     T-3636: the deliverable changed from free prose in docs/reports/T-002-*.md
     (read once, linked to by nothing, never checked for staleness) to the
     structured objectives file (T-3535 IW-3, one authoring moment per project). -->

## Verification

# The objectives file exists and has the shape: headline, objectives each with id/text/measure, out_of_scope list
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/objectives.yaml')); o=d['objectives']; assert str(d['headline']).strip() and o and all(x.get('id') and x.get('text') and x.get('measure') for x in o) and isinstance(d['out_of_scope'], list)"
# It carries the authored-intent header (progress is derived, never written into it)
grep -qi 'authored intent; progress is derived' .context/project/objectives.yaml
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
