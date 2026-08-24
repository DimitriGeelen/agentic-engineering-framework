# watchtower_url_no_guess

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/watchtower_url_no_guess.bats`

## What It Does

T-2802 — `fw watchtower url` must not answer with a guess.
do_url used to end in `echo "http://localhost:$(fw_config PORT 3000)"` — a
well-known-port guess emitted in exactly the shape of a verified answer.
lib/watchtower.sh's _watchtower_url has refused to do that since T-1803
("never return a URL to a service we didn't positively identify"); this
accessor — the one CLAUDE.md tells agents to put inside ## Verification —
kept doing it.
Why it matters more than it sounds: consumer projects run the same Flask app,
so a foreign Watchtower on the guessed port answers 200 for almost any path.
A verification line built on the guess passes while asserting nothing. That is

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [watchtower](/docs/generated/lib-watchtower) | tests | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [watchtower](/docs/generated/bin-watchtower) | tests | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-watchtower_url_no_guess.yaml`*
*Last verified: 2026-08-04*
