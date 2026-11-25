# t5405_publish_ban

> T-5405 — publishing to Anthropic is blocked by default: deny rules from fw init/upgrade, config key PUBLISH_TO_ANTHROPIC (allow is operator-only), egress class `forbidden`, doctor/audit state line.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5405_publish_ban.bats`

## What It Does

T-5405 — publishing to Anthropic is blocked by default: deny rules from fw init/upgrade,
config key PUBLISH_TO_ANTHROPIC (allow is operator-only), egress class `forbidden`,
doctor/audit state line. Hermetic: temp projects, synthetic payloads; no publish tool is called.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5405_publish_ban.yaml`*
*Last verified: 2026-11-24*
