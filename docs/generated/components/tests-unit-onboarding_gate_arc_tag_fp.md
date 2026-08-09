# onboarding_gate_arc_tag_fp

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/onboarding_gate_arc_tag_fp.bats`

## What It Does

T-2881 — the onboarding gate must distinguish an arc tag from set membership.
`has_onboarding_tag` used `re.search(r"\bonboarding\b", tags)`. Both `:` and
`-` are non-word characters, so \b sits happily on either side of the
substring in `arc:onboarding-curriculum` — and every task tagged into the
onboarding-curriculum ARC was read as a member of the gated onboarding SET.
Those are two different things that share a word:
tags: [onboarding]                  the T-532 GATED SET — blocks other work
tags: [arc:onboarding-curriculum]   an ARC — a grouping, gates nothing
Found when arc-017's Half A build task (T-2877, the human curriculum) was
refused by arc-017's Half B invariant for carrying an unticked `### Human` AC.

---
*Auto-generated from Component Fabric. Card: `tests-unit-onboarding_gate_arc_tag_fp.yaml`*
*Last verified: 2026-08-08*
