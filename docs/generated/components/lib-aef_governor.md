# aef_governor

> arc-020 S5: environmental governor v1 — loadavg-based provisioning admission.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/aef_governor.py`

## What It Does

Per-core normalized 1-min loadavg admission ceiling. 0.8 leaves real
headroom before saturation (1.0/core); override via FW_PROVISION_LOAD_MAX.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/web-blueprints-config) | called_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |

---
*Auto-generated from Component Fabric. Card: `lib-aef_governor.yaml`*
*Last verified: 2026-09-07*
