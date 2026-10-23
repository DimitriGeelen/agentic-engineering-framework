# t4221_port_in_use_sigpipe

> T-4221 — "is this port held?" must not read SIGPIPE as "free".

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4221_port_in_use_sigpipe.bats`

## What It Does

T-4221 — "is this port held?" must not read SIGPIPE as "free".
bin/watchtower.sh runs under `set -euo pipefail`. port_in_use was
`ss -tlnp | grep -q ":$port "`: on a busy host ss prints ~250 KB, grep -q
exits at the first match, ss takes SIGPIPE, the pipeline returns 141, and the
allocator handed out a port another Watchtower already held (t3662 reds).
lib/watchtower.sh:_watchtower_port_listening had the same idiom.
Each function is extracted from its file and run against a stub `ss` that
prints the held port's line FIRST and then a large tail, under pipefail.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4221_port_in_use_sigpipe.yaml`*
*Last verified: 2026-10-21*
