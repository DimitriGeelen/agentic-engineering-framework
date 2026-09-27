# corpus_id_allocator

> T-2902 — the L-/PL- allocator must not reissue a live id when the corpus changes shape.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/corpus_id_allocator.bats`

## What It Does

T-2902 — the L-/PL- allocator must not reissue a live id when the corpus changes shape.
WHAT MAKES THIS SUITE NON-VACUOUS, read this before adding legs:
The bug being pinned is NOT "the regex was wrong". It is that a scan matching zero
rows is indistinguishable from an empty corpus, so the allocator returns its seed
with confidence. Any test that only asserts "the new code gets the right answer on
the shapes we know about" would have passed against BOTH broken versions of this
allocator on the shapes they knew about. That is exactly how T-1369's fix shipped
and how the same defect then recurred at three more sites (G-079).
So the load-bearing leg is `pre-fix allocator is RED on the same fixture` — it runs
the OLD pattern against the SAME corpus and asserts it finds nothing, proving the

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus-id](/docs/generated/lib-corpus-id) | calls | lib/corpus-id.sh — serialisation-independent max-id lookup for the YAML memory corpus |
| [corpus-id](/docs/generated/lib-corpus-id) | tests | lib/corpus-id.sh — serialisation-independent max-id lookup for the YAML memory corpus |
| [add-learning](/docs/generated/add-learning) | tests | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [learning](/docs/generated/agents-context-lib-learning) | tests | Context Agent - add-learning command Add a learning to project memory |

---
*Auto-generated from Component Fabric. Card: `tests-unit-corpus_id_allocator.yaml`*
*Last verified: 2026-08-10*
