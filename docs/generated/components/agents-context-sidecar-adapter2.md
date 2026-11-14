# sidecar-adapter2

> sidecar-adapter2.sh — Claude Code adapter for TermLink's termlink.adapter/2 contract (T-5054).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/sidecar-adapter2.sh`

## What It Does

sidecar-adapter2.sh — Claude Code adapter for TermLink's termlink.adapter/2 contract (T-5054).
Registered on PreToolUse, PostToolUse and SessionEnd with the hook name as its one
argument (pre-tool | post-tool | session-end). The prompt, stop and session-start
reports are sent from lib/sidecar/hooks.py, because the lease claim needs the
receiver's origin_checked in the same process (docs/reports/T-5054-adapter2-design.md).
Body: lib/sidecar/adapter2.py. Off unless TERMLINK_ADAPTER2=1 and a sidecar socket is
configured. Fails open (exit 0) — never blocks a tool call; a fault is logged by the
adapter to .context/sidecar/receiver/hook-errors.log. `python3 -S` keeps the off path
cheap: it runs on every tool call.
Invoked as: fw hook sidecar-adapter2 <pre-tool|post-tool|session-end>

---
*Auto-generated from Component Fabric. Card: `agents-context-sidecar-adapter2.yaml`*
*Last verified: 2026-11-13*
