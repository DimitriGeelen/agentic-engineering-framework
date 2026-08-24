# t2862_greenfield_first_inception_e2e

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2862_greenfield_first_inception_e2e.bats`

## What It Does

── What the live run established (2026-08-11, S-2026-0811) ──────────────────
On a fresh `fw init` greenfield project, doing only the work the seed asks:
1. AC preflight            PASS  (T-2862's fix works — no self-gating AC)
2. review-marker gate      PASS
3. Recommendation gate     PASS
4. P-011 verification      FAILED until the seed line was fixed this session
5. `**Decision**: GO`      RECORDED
6. decide exit code        1, from the Watchtower emit AFTER the record
Two defects found by running it that a scanner could never see — both filed
separately:

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2862_greenfield_first_inception_e2e.yaml`*
*Last verified: 2026-08-11*
