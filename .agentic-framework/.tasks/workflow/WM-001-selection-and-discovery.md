---
id: WM-001
name: "Selection and discovery — deciding what to work on next"
description: >
  Standing workflow-management task. Focus here to read state, rank work and
  decide what to do next. Never closes. Fenced: no source writes.
status: standing
workflow_type: workflow-management
owner: agent
fence: no-source-writes
created: 2026-09-28
---

# WM-001: Selection and discovery

## What this is for

Focus here when the work is **deciding what to work on**, not doing it:

- reading arcs, tasks, BVP rankings, the review queue, the register
- running `fw doctor`, `fw audit`, `fw metrics`, `fw bvp`, `checkpoint.sh budget`
- ranking candidates and choosing the next unit of work

This exists because selection **is** work, and work needs a task. Before WM-001,
an agent between tasks had no focus, and the gate — correctly — refused it
everything. The answer is not an exemption from the rule; it is a task the rule
is satisfied by.

## The fence

**No source writes.** Enforced in `check-active-task.sh` via `lib/wm_tasks.sh`,
not by convention. Writes to `.context/`, `.tasks/`, `.claude/` and `.git/` are
permitted — that is what selection legitimately records.

**The moment selection turns into building, it needs a real task.** That is the
line, and the fence is what makes it a line rather than a suggestion.

## Not a place to park work

If you find yourself wanting to edit source under WM-001, the answer is
`fw work-on "<name>"`, not a bypass. A standing task that could write source
would be a standing exemption, which is the exact risk the task gate exists to
prevent.

## Log

Entries name their real subject, so `WM-001` stays an attribution channel rather
than a black hole (R3). Append, never rewrite.

<!-- ### YYYY-MM-DDTHH:MMZ — <what was being selected among, and what was chosen> -->
