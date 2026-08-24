# corpus-id

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/corpus-id.sh`

## What It Does

lib/corpus-id.sh — serialisation-independent max-id lookup for the YAML memory corpus
Origin: T-2902. `.context/project/{learnings,patterns,decisions}.yaml` are read by
hand-written grep patterns at many independent sites, each encoding an assumption
about how the YAML is serialised. On 2026-04-13 a bulk mining run rewrote
learnings.yaml with yaml.dump(sort_keys=True), moving `id:` off the list-item line:
- id: L-001              ->    - application: TBD
learning: "..."                context: ...
id: L-001        # moved
Every scan keyed on the old shape began matching zero rows. Four sites broke this
way and were discovered one at a time over four months (T-1369 learning.sh,

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_id_allocator](/docs/generated/tests-unit-corpus_id_allocator) | called_by | TODO: describe what this component does |
| [corpus_id_allocator](/docs/generated/tests-unit-corpus_id_allocator) | tests_by | TODO: describe what this component does |
| [add-learning](/docs/generated/add-learning) | called_by | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |

---
*Auto-generated from Component Fabric. Card: `lib-corpus-id.yaml`*
*Last verified: 2026-08-10*
