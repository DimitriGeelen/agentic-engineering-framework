# t3045_embed_host_resolution

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3045_embed_host_resolution.bats`

## What It Does

T-3045 A6 — how Config.EMBED_HOST resolves, pinned.
WHY THIS FILE EXISTS AT ALL:
`.context/settings.yaml` is gitignored. A wrong `embed_host:` there is invisible
to code review, absent from CI, and survives every test the repo runs. That is
how this install spent a day embedding against a dead loopback sidecar
(127.0.0.1:11435, no listener) while T-3017's failover quietly answered every
request from ollama_host — the same machine by LAN IP. Nothing was broken and
nothing was right.
These tests cannot see settings.yaml (nor should they). What they CAN pin is
the resolution RULE in web/config.py, which is tracked: unset falls back to

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3045_embed_host_resolution.yaml`*
*Last verified: 2026-08-16*
