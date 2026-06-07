# firewall

> Opens UFW firewall ports for TCP traffic when starting network services, with no-op fallback if UFW is not installed or inactive

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/firewall.sh`

## What It Does

lib/firewall.sh — Firewall port management utilities
Provides ensure_firewall_open() for any script that starts network services.
Extracted from bin/watchtower.sh for reuse by T-885 service registry.
Usage:
source "$FRAMEWORK_ROOT/lib/firewall.sh"
ensure_firewall_open 3000

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [firewall](/docs/generated/lib-firewall) | calls | Opens UFW firewall ports for TCP traffic when starting network services, with no-op fallback if UFW is not installed or inactive |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [lib_firewall](/docs/generated/tests-unit-lib_firewall) | called-by | Unit tests for lib/firewall.sh — ensure_firewall_open and UFW port management |
| [firewall](/docs/generated/lib-firewall) | called-by | Opens UFW firewall ports for TCP traffic when starting network services, with no-op fallback if UFW is not installed or inactive |
| [watchtower](/docs/generated/bin-watchtower) | called_by | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [firewall](/docs/generated/lib-firewall) | called_by | Opens UFW firewall ports for TCP traffic when starting network services, with no-op fallback if UFW is not installed or inactive |
| [lib_firewall](/docs/generated/tests-unit-lib_firewall) | called_by | Unit tests for lib/firewall.sh — ensure_firewall_open and UFW port management |
| [lib_firewall](/docs/generated/tests-unit-lib_firewall) | tests_by | Unit tests for lib/firewall.sh — ensure_firewall_open and UFW port management |

## Related

### Tasks
- T-888: Extract ensure_firewall_open to lib/firewall.sh for reuse

---
*Auto-generated from Component Fabric. Card: `lib-firewall.yaml`*
*Last verified: 2026-04-05*
