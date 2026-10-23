# spawn-env

> lib/spawn-env.sh — T-4647 (SEV-1 T-4635, G-116): the environment a spawned session or dispatch worker starts with is built from an ALLOW-LIST, never "the caller's minus a few".

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/spawn-env.sh`

## What It Does

lib/spawn-env.sh — T-4647 (SEV-1 T-4635, G-116): the environment a spawned session or
dispatch worker starts with is built from an ALLOW-LIST, never "the caller's minus a few".
A `termlink spawn` that finds no tmux server starts one, and that server's global env is the
env it was started with; every later session on it inherits that. The deny-list this replaced
(T-4217, T-4222: `env -u PROJECT_ROOT -u … `) failed open — 1409-sprind's CONTEXT_DIR/TASKS_DIR
seeded the host's default server and, through it, other projects' sessions and workers.
TermLink variables are named exactly, never by prefix (T-4665): only where the hub lives
(TERMLINK_RUNTIME_DIR, TERMLINK_RUNTIME_DIR_FALLBACK) and which binary to call (TERMLINK_BIN).
Identity, socket and per-session variables (TERMLINK_AGENT_ID, TERMLINK_IDENTITY_*,
TERMLINK_SIDECAR_*, TERMLINK_SESSION*) belong to the spawning agent: a worker that inherited

---
*Auto-generated from Component Fabric. Card: `lib-spawn-env.yaml`*
*Last verified: 2026-10-22*
