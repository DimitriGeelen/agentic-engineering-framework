# t4469_inception_verdict_commit

> T-4469 — a reviewer's verdict-only commit (.context/reviews/ only) on an undecided inception must pass the commit-msg inception gates (commit limit + research artifact), and a refused verdict commit must not leave its row staged.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4469_inception_verdict_commit.bats`

## What It Does

T-4469 — a reviewer's verdict-only commit (.context/reviews/ only) on an undecided
inception must pass the commit-msg inception gates (commit limit + research
artifact), and a refused verdict commit must not leave its row staged.
Origin: 832 (v1.8.12) — `fw reviewer verdict record --commit` on inception T-1215
was refused at the research-artifact gate; the row stayed staged, the next
unrelated commit carried it, and the append-only ledger blocked every push.
Hermetic: hooks are installed into a temp repo whose .framework.yaml points at
this checkout; the commit-msg hook is run directly against the staged index.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4469_inception_verdict_commit.yaml`*
*Last verified: 2026-10-20*
