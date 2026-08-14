# T-2409 — inbox.queued CLI deposit-path investigation (summary)

**Date:** 2026-07-05 · **Worker:** TermLink dispatch `t2409-inbox-gap` rooted at `/opt/termlink` (T-559 boundary — investigation ran in the target project's own context). Full report: `/opt/termlink/docs/reports/T-2409-inbox-queued-cli-gap.md` (termlink-side task T-2362, commits `8d628e1a`, `867c6b94`).

## Findings

Two independent `inbox.queued` emit sites exist in the hub:

- **Site 1 (legacy):** `mirror_inbox_deposit_with()` — `crates/termlink-hub/src/channel.rs:166-218`, reached only from `handle_event_emit_to` (`router.rs:366-378`, T-1636).
- **Site 2 (current):** inline emit in generic `handle_channel_post()` for any `inbox:`-prefixed topic — `channel.rs:748-768` (T-1637).

### (a) CLI deposit-path trace

1. **`file send` (local)** — primary T-1249 path posts to `inbox:<target>` via `channel.post` → Site 2 (`file.rs:216-272`); legacy fallback calls `event.emit_to` → Site 1 (`file.rs:67`). **Both reach an emit on current HEAD.**
2. **`remote send-file`** — primary path fine; **legacy fallback is the bug**: `remote.rs:1750` calls RPC `event.emit` (not `event.emit_to`). The hub has no `event.emit` handler; the call falls through to generic `forward_to_target()` (`router.rs:1599-1658`) which returns `SESSION_NOT_FOUND` for an offline target **without reaching the inbox deposit at all** — the exact scenario the fallback exists for is the one it cannot handle.
3. **`channel post` with a kill-9'd member** — not a bug: the hub keeps no channel-membership registry; only `inbox:*`/`dm:*` topics get addressee-aware wakeup emits by design.

### (b) Live reproduction

`termlink channel post inbox:t2409-scratch-target --msg-type file.init --ensure-topic` fired `inbox.queued` end-to-end on this host's running hub (captured via `termlink event watch --hub --topic inbox.queued`) — Site 2 confirmed working on a current binary.

### (c) Fix homed where it lives (§Gap Homing, T-1333)

**termlink T-2363** — "Fix remote send-file legacy fallback uses wrong RPC" — scoped to `remote.rs:1750` + a two-node hub integration test, references framework T-2409.

## RCA (framework-side)

- **Symptom:** framework subscriber long-polling `inbox.queued` saw nothing on two "no-consumer deposit" CLI flows (T-1820 AC#3).
- **Root cause:** one flow was a wrong-RPC bug in termlink's legacy fallback (`event.emit` vs `event.emit_to`); the other was a design mismatch in the test expectation (no membership registry exists to detect a dead member).
- **Why structurally allowed:** T-1636's integration test covered the inner crate function, not the CLI surface; the two emit sites (T-1636/T-1637) evolved independently, so a CLI path could miss both without any test noticing.
- **Prevention:** termlink T-2363 adds the CLI-surface integration test (two-node hub harness); this summary + the termlink report record the two-emit-site topology for future tracers.
