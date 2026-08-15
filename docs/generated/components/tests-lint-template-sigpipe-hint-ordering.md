# template-sigpipe-hint-ordering

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/template-sigpipe-hint-ordering.bats`

## What It Does

T-3000: the SIGPIPE hint block in .tasks/templates/default.md must lead with the
form that is correct at any output size.
The block ships into the `## Verification` section of every generated task file,
and it accreted chronologically — each task appended its correction below the
previous one. By T-2743 it read as a sequence of "here is the rule / actually
that is wrong / actually that is wrong too", with the conditionally-safe
capture-then-grep form arriving first, labelled "Safe pattern", carrying L-387's
origin citation, and the correction that inverts it 20 lines further down behind
a hint about a different thing.
An agent reading top-down copies the first labelled form. That is not a

---
*Auto-generated from Component Fabric. Card: `tests-lint-template-sigpipe-hint-ordering.yaml`*
*Last verified: 2026-08-14*
