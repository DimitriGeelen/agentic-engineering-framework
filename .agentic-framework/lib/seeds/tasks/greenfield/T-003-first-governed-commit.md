---
id: T-003
name: "First governed commit for __PROJECT_NAME__"
description: >
  Create the initial project structure and make the first governed commit. This validates
  the governance loop: task reference → commit-msg hook → post-commit advisory.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-003: First governed commit for __PROJECT_NAME__

## Context

Create initial project files (README, directory structure, entry point) and commit through the framework. The commit-msg hook validates the task reference.

## For the Operator

**What is happening:** the first commit that goes through the framework's own git hooks.
Note the message format — `T-003: Initial project structure`. That `T-003:` prefix is not
decoration.

**Why it matters to you:** every commit in this project must name the task it belongs to,
and a hook refuses the commit if it does not. Six months from now, `git log` will answer
*why does this line exist* by pointing at a task file that still holds the reasoning, the
acceptance criteria, and the decisions made along the way. That link is the entire point,
and it only survives if it is enforced on every commit rather than remembered on most.

**What you can do meanwhile:** nothing required. If you are curious, run `git log --oneline`
after this step and notice that the history has become an index.

**Go deeper:** `fw corpus explain aef-task-lifecycle` — the states a task moves through, and
which gates guard each transition.

## Acceptance Criteria

### Agent
- [ ] Create initial project structure (README.md, src/ or appropriate dirs)
- [ ] Commit using `fw git commit -m "T-003: Initial project structure"`
- [ ] Commit succeeds (hook validates T-003 reference)

## Verification

# Some commit in history references this task.
#
# NOT `git log -1 --format=%s` alone (T-2996 / G-006): that asserts a property
# of HEAD, true the moment this task completes and false from the very next
# commit onward -- a permanently-red CTL-013 in every project built on AEF,
# clearable by nothing, because the work it checks is correct and the question
# is wrong.
#
# NO PIPE AT ALL, deliberately (L-387 + T-2743). The obvious repair is
# `out=$(git log --format=%s); echo "$out" | grep -q "T-XXX"`, and it is still
# wrong: that form is SIGPIPE-free only while the capture fits the 65536-byte
# pipe buffer. This framework's own log is 608KB, and the repaired line exited
# 141 under P-011 on the first run. A fresh consumer would not hit it; a mature
# one would -- which is the same "goes red later" shape as the original defect.
#
# `git log --grep` filters inside git, so nothing is piped and nothing can
# SIGPIPE, at any history length. `-1` bounds git's own output AFTER filtering,
# so this is still a search over all history, not a check on HEAD.
# ANCHORED, and the subject compared explicitly (T-2999). `git log --grep`
# searches the whole commit MESSAGE, subject and body -- so an unanchored
# pattern passes on any commit that merely mentions this task id in its body,
# and --format then prints THAT commit's subject, which belongs to someone
# else. Observed in a consumer repo: --grep=T-003 selected
# "T-016: close onboarding gate, complete T-013, add T-015".
#
# The property both halves of this line mean is "a commit whose SUBJECT is this
# task". A bare -n test cannot express it: it only asks whether anything
# printed at all.
s=$(git log --grep='^T-003:' -1 --format=%s); [ "${s%%:*}" = "T-003" ]

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
