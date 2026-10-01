---
id: __TASK_ID__
name: "Write down the objectives of __PROJECT_NAME__"
description: >
  Seeded once by fw upgrade (T-3636): this project has no .context/project/objectives.yaml.
  Author it once, from this project's own material: a headline, a few objectives each
  with a measure, and what is out of scope. Progress is derived from the work afterwards.
status: captured
workflow_type: build
owner: agent
horizon: next
tags: [objectives-authoring]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# __TASK_ID__: Write down the objectives of __PROJECT_NAME__

## Context

`fw upgrade` seeded this task because __PROJECT_NAME__ has no
`.context/project/objectives.yaml`. Every governed project authors its objectives once,
through its own entry point; this is that moment for a project that was onboarded before
the step existed. It is seeded once: upgrade will not add it again, and never if the file
exists.

**Draft from this project's own material only:** its README and docs, the code and its
history, its tasks and arcs, and anything the operator has said. Never copy another
project's objectives, and never the framework's own.

After this, the objectives are not rewritten to stay current. Arcs and tasks point at
objective ids (`supports: [O-n]`), progress is read from that work, and the framework's
audit flags an objective nothing serves.

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

**The flow:** the agent drafts, an independent reviewer checks it where one is available,
and the operator sees it once and ratifies it or says what to change.

## Acceptance Criteria

### Agent
- [ ] `.context/project/objectives.yaml` exists in the shape above: the header line
      saying authored intent, progress is derived; headline; objectives (each with id,
      text, measure); out_of_scope
- [ ] Drafted from this project's own material — never copied from another project or
      from the framework
- [ ] Independent review asked for where available (`fw reviewer __TASK_ID__`, or another
      model), and its corrections applied or answered

### Human
- [ ] [REVIEW] The objectives say what __PROJECT_NAME__ is for, in words you would use
  **Steps:**
  1. Read `.context/project/objectives.yaml`
  2. Check: does the headline say what __PROJECT_NAME__ does and for whom? Is each
     objective an outcome you care about, with a measure you would accept? Is anything
     missing, or anything listed out of scope that should not be?
  **Expected:** You would sign the file as written, or after the changes you named
  **If not:** Tell the agent what to change; it edits the file and hands it back

## Verification

# The objectives file exists and has the shape: headline, objectives each with id/text/measure, out_of_scope list
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/objectives.yaml')); o=d['objectives']; assert str(d['headline']).strip() and o and all(x.get('id') and x.get('text') and x.get('measure') for x in o) and isinstance(d['out_of_scope'], list)"
# It carries the authored-intent header (progress is derived, never written into it)
grep -qi 'authored intent; progress is derived' .context/project/objectives.yaml

## Recommendation

<!-- Fill in once the draft has been reviewed, before handing over with
     `fw task review __TASK_ID__`.

     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** why
     **Evidence:**
     - Finding 1 -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
