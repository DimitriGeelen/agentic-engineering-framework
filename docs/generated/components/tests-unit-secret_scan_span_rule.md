# secret_scan_span_rule

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/secret_scan_span_rule.bats`

## What It Does

T-2898: the ANNOUNCED pair must match at NON-OVERLAPPING SPANS.
T-2897 wrote the rule down — "a pair that one word can complete is not a
pair" — and then satisfied it by curating the two word lists by hand. Hand
curation does not survive the next word. `pass` went into the noun list
alongside `password` and `passwd` in the qualifier list, `pass` is a substring
of both, and three config filenames classified as key material.
So the load-bearing test here is the GENERATIVE one. A test pinned to the
three broken filenames would pass against a fix that special-cased those three
strings, and would say nothing about the seventh word someone adds next year.
Leg (c) enumerates both lists at run time, so a future edit is caught by

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | TODO: describe what this component does |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-secret_scan_span_rule.yaml`*
*Last verified: 2026-08-09*
