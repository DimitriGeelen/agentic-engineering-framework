# t3379_review_placeholder_foreign_port

> T-3379 — the "Watchtower not running" placeholder must never name a port that something else already holds.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3379_review_placeholder_foreign_port.bats`

## What It Does

T-3379 — the "Watchtower not running" placeholder must never name a port that
something else already holds.
Observed 2026-09-17, after a host reboot killed this project's Watchtower.
`fw task review T-2171` correctly reported "No Watchtower reachable" and then
printed `http://localhost:3000/review/T-2171`. The link came from
`_watchtower_base_or_placeholder`, which built it from the bare configured
port. On that host :3000 was held by a DIFFERENT project's Watchtower,
running the same Flask app, so the human-review handoff pointed at a foreign
server (the T-1376/T-2732 wrong-server class). Low task IDs collide across
projects, so such a link can render a real-looking page for the wrong task.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [watchtower](/docs/generated/lib-watchtower) | tests | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3379_review_placeholder_foreign_port.yaml`*
*Last verified: 2026-09-17*
