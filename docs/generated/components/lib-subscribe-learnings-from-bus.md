# subscribe-learnings-from-bus

> Consumer-side poller for channel:learnings — drains new learning envelopes from a TermLink hub session's event bus via 'event poll' and appends de-duplicated entries to .context/project/received-learnings.yaml. Runs every 5 minutes via cron. Cron-safe: silent no-op when termlink missing, hub down, or no sessions.

**Type:** script | **Subsystem:** learnings-bus | **Location:** `lib/subscribe-learnings-from-bus.sh`

**Tags:** `cron`, `learnings`, `termlink`, `peer-learning`, `T-1168`, `T-1217`, `T-1219`

## What It Does

subscribe-learnings-from-bus.sh — T-1168 B2 consumer-side poller for channel:learnings.
Drains new learning envelopes from a hub session's event bus and appends
de-duplicated entries to ${PROJECT_ROOT}/.context/project/received-learnings.yaml.
Mirror of the publisher (lib/publish-learning-to-bus.sh, T-1168 B1).
Design (revised per T-1219 after T-1217 v1 bug):
- Consumes via `termlink event poll <session> --topic channel:learnings
--since=<cursor>`. Events broadcast to `channel:learnings` fan out to
every registered session's private event bus; polling any one session
gets the full stream. (v1 used `event collect` which only delivers
events broadcast by the collector's own session — missed cross-session

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `lib/publish-learning-to-bus.sh` | calls |
| `.context/project/received-learnings.yaml` | writes |
| `.context/working/.subscribe-learnings-bus.cursor` | writes |

---
*Auto-generated from Component Fabric. Card: `lib-subscribe-learnings-from-bus.yaml`*
*Last verified: 2026-04-24*
