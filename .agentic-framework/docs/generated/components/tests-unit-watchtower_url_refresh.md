# watchtower_url_refresh

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/watchtower_url_refresh.bats`

## What It Does

T-1622 — `do_url` in `bin/watchtower.sh` MUST refresh the LAN URL from
`detect_lan_ip` when Watchtower is running. The cached `watchtower.url` file
goes stale on DHCP IP rotation (T-1621 root cause) — every review URL emitted
in chat after a lease move ends up 404ing from LAN clients.
Witness: 2026-04-30 on host `dimitrimintdev` — NetworkManager DHCP-bounced
enp5s0 between .123 and .107 8x in one day; file held .123 for hours.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [watchtower](/docs/generated/bin-watchtower) | calls | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [watchtower](/docs/generated/bin-watchtower) | tests | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-watchtower_url_refresh.yaml`*
*Last verified: 2026-04-30*
