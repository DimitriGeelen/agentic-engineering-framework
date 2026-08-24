# t2922_greenfield_first_inception

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/t2922_greenfield_first_inception.bats`

## What It Does

T-2922 — a fresh `fw init` project must be able to complete its first
inception with no Watchtower running.
The failure: emit_review (lib/review.sh) resolved its base URL with a bare
base_url=$(_watchtower_url "$task_id")
under `set -e`. _watchtower_url fails LOUD by design — Layer 3 returns 1 with
no stdout when nothing identifies as this project's Watchtower — so on a
machine with no server running that assignment aborted emit_review outright.
The abort happened BEFORE the function's final act: writing
`.context/working/.reviewed-<id>`, which is the T-973 gate's only unblock for
`fw inception decide`.

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [inception](/docs/generated/lib-inception) | calls | fw inception - Inception phase workflow |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [inception](/docs/generated/lib-inception) | tests | fw inception - Inception phase workflow |
| [watchtower](/docs/generated/lib-watchtower) | tests | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [review](/docs/generated/lib-review) | tests | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-t2922_greenfield_first_inception.yaml`*
*Last verified: 2026-08-11*
