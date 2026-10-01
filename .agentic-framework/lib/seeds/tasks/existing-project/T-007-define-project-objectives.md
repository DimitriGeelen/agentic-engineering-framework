---
id: T-007
name: "Write down the objectives of __PROJECT_NAME__"
description: >
  Author .context/project/objectives.yaml once, from this project's own material:
  a headline, a few objectives each with a measure, and what is out of scope.
  Progress is derived from the work afterwards; the file is not rewritten to stay current.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding, objectives-authoring]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-007: Write down the objectives of __PROJECT_NAME__

## Context

__PROJECT_NAME__ already has a purpose; it was settled before the framework arrived. What
it usually does not have is that purpose written down somewhere the framework can use.
This task writes it once, as `.context/project/objectives.yaml`.

By now the agent has oriented itself (T-001), committed under governance (T-002), mapped
the code (T-003), run a task end to end (T-004), written a handover (T-005) and recorded a
learning (T-006). It knows the codebase well enough to draft what the project is for.

**Draft from this project's own material only:** the README and docs, the code and its
history, issue trackers, and anything the operator has said. Never copy another project's
objectives, and never the framework's own.

**If the file already exists**, do not start again: check it against the shape below,
fill any gaps (an objective without a `measure`, a missing `out_of_scope`), keep its ids.

After this, the objectives are not rewritten to stay current. Arcs and tasks point at
objective ids, progress is read from that work, and the framework's audit flags an
objective nothing serves.

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
out_of_scope:
  - "Something a reasonable person might expect this project to do, and it will not."
```

Keep objectives few (three to six). Every objective needs a `measure`, even if the honest
answer is "not measured yet".

## For the Operator

**What is happening:** the agent writes down what __PROJECT_NAME__ is for, as a short file:
a headline, a handful of objectives each with a way to tell whether it holds, and what is
deliberately out of scope. It drafts this from your code, docs and history, has it checked
by an independent reviewer where one is available, and hands it to you once.

**Why it matters to you:** this is the only time the project's objectives get authored.
Later work points back at them, so whether the project is on course can be read from the
work rather than from a document someone has to keep updating.

**What you can do:** read `.context/project/objectives.yaml` when the agent hands it over.
Nothing waits for you; if a word is wrong or an objective is missing, tell the agent and
it edits the file. You know what this project is for better than any reading of its code.

**After this task closes, the prologue is over.** The gate holding the agent to onboarding
work lifts, and it starts on whatever you actually came here to build.

**Go deeper:** `fw corpus explain aef-existing-project-onboarding` — the whole prologue,
this step included.

## Acceptance Criteria

### Agent
- [ ] `.context/project/objectives.yaml` exists in the shape above: the header line
      saying authored intent, progress is derived; headline; objectives (each with id,
      text, measure); out_of_scope
- [ ] Drafted from this project's own material — never copied from another project or
      from the framework
- [ ] Independent review asked for where available (`fw reviewer T-007`, or another
      model), and its corrections applied or answered
- [ ] Handed to the operator to read once: `fw task review T-007`

## Verification

# The objectives file exists and has the shape: headline, objectives each with id/text/measure, out_of_scope list
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/objectives.yaml')); o=d['objectives']; assert str(d['headline']).strip() and o and all(x.get('id') and x.get('text') and x.get('measure') for x in o) and isinstance(d['out_of_scope'], list)"
# It carries the authored-intent header (progress is derived, never written into it)
grep -qi 'authored intent; progress is derived' .context/project/objectives.yaml

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
