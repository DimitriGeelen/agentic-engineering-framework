# index-health

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/index-health.sh`

## What It Does

Vector-index freshness verdict — T-3013 (T-3005 slice 4).
Extracted from bin/fw doctor so it can be tested without running doctor. The
first version lived inline; pinning its three verdicts then cost five full
doctor runs per suite, which is a test nobody would run twice — the same
"instrument that never fires" problem this whole arc is about, one level up.
Emits one line: VERDICT|MESSAGE|HINT
OK   — index is younger than the threshold
WARN — older than the threshold, or age not determinable
SKIP — web.embeddings not importable (consumer without the embedding extras)
Embed-free by construction: it reads the corpus manifest, or stats the database

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test_index_doctor_rail](/docs/generated/tests-unit-test_index_doctor_rail) | tests_by | TODO: describe what this component does |
| [embeddings](/docs/generated/web-blueprints-embeddings) | called_by | TODO: describe what this component does |
| [test_index_doctor_rail](/docs/generated/tests-unit-test_index_doctor_rail) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-index-health.yaml`*
*Last verified: 2026-08-15*
