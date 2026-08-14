# consumer-recover

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/consumer-recover.sh`

## What It Does

fw consumer-recover - one-command recovery for legacy vendored consumers
Wraps the 4-step recipe documented in feedback_t2232_forward_looking_recovery
(SSH to host, clone upstream, env-scoped fw upgrade, cleanup) behind a single
verb. Dry-run by default — operator must pass --apply to execute.
Authorised under T-2233 GO (2026-06-07). Full design spec:
docs/reports/T-2233-consumer-recover-design.md
Exit codes:
0   dry-run printed OR --apply succeeded
1   precondition failed (unreachable / missing tooling / project not found)
2   consumer is post-T-2232 — refused with redirect to plain fw upgrade

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_consumer_recover](/docs/generated/tests-unit-test_consumer_recover) | called_by | TODO: describe what this component does |
| [test_consumer_recover](/docs/generated/tests-unit-test_consumer_recover) | tests_by | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-consumer-recover.yaml`*
*Last verified: 2026-06-07*
