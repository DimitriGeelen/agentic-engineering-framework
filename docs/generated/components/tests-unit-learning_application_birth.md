# learning_application_birth

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/learning_application_birth.bats`

## What It Does

T-2901: `application:` must not be born populated.
832 measured the shape on their tree at 2.3% (rail 491 §1) and left the remedy
to us, correctly — per L-559 it belongs at the site of GENERATION, which is
ours. Measured here: 572/604 (94.7%) of learnings carried the literal string
"TBD" written by the generator itself, 21 (3.48%) were genuinely hand-written.
A field born populated is worse than an absent one. It makes "nobody filled
this in" textually identical to "someone considered it and this is the answer",
and no query separates them afterwards — which is why the field went 94.7% dead
for the entire life of the file without anything noticing.
NOTE ON SHAPE. These legs run against the LIVE repo rather than a synthetic

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [add-learning](/docs/generated/add-learning) | calls | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [add-learning](/docs/generated/add-learning) | tests | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-learning_application_birth.yaml`*
*Last verified: 2026-08-09*
