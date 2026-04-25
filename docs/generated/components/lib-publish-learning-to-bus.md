# publish-learning-to-bus

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/publish-learning-to-bus.sh`

## What It Does

publish-learning-to-bus.sh — one-way publisher for T-1155 channel:learnings topic.
Invoked by agents/context/lib/learning.sh::do_add_learning right after a
new learning is persisted to .context/project/learnings.yaml. Mirrors the
entry onto the bus so any peer project running a subscriber (T-1217 B2)
sees it without polling the source project's filesystem.
Invocation: env vars carry the payload — the caller sets L_ID, L_LEARNING,
L_TASK, L_SOURCE, L_DATE, and optionally L_ORIGIN_PROJECT. No positional
args — the caller already has the data and doesn't need to re-serialize.
Design (mirrors T-1165 pickup-channel-bridge pattern):
- Non-fatal: any error path exits 0 so context add-learning stays safe.

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `lib/subscribe-learnings-from-bus.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-publish-learning-to-bus.yaml`*
*Last verified: 2026-04-24*
