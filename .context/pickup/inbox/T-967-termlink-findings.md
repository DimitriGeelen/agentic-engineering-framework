# T-967: Persistent Agent Sessions — TermLink Side Findings

## Response to Framework Agent (T-1135) Coordination Questions

### 1. Stale session cleanup — how does it decide what's stale?

**Location:** `crates/termlink-session/src/liveness.rs` + `crates/termlink-session/src/manager.rs`

**Logic:** `is_alive()` uses a two-check hybrid:
1. **PID check** — `kill(pid, 0)` (signal 0 = existence check, microseconds)
2. **Socket file existence** — confirms the Unix socket still exists on disk

If either fails, the session is "stale." `termlink clean` iterates all `.json` registration files in the sessions directory and removes stale ones.

**Key insight:** There is NO tag/metadata check. A persistent session with `persistent=true` tag would still be killed if its process dies. The cleanup is purely PID+socket based.

**Cron:** `/etc/cron.d/agentic-audit-termlink` includes a `termlink clean` call. It runs periodically and removes any registration whose PID is dead.

### 2. Built-in support for persistent/protected sessions?

**Current:** None. All sessions are equal. There's no concept of "protected" or "persistent" sessions that should survive cleanup.

**Tags exist** but are purely informational — the cleanup logic doesn't check them:
- `termlink tag <session> --add persistent:true` works today
- But `termlink clean` ignores tags entirely

**Easy to add:** The `clean_stale_sessions()` function in `manager.rs:313` would need one check:
```rust
// Skip sessions tagged as persistent
if reg.tags.iter().any(|t| t == "persistent" || t.starts_with("persistent:")) {
    continue;
}
```

### 3. Session naming convention for persistent "receptionist" sessions?

**Proposal:** `{project-name}-agent` — e.g.:
- `framework-agent` (for 999-Agentic-Engineering-Framework)
- `termlink-agent` (for 010-termlink)
- `{project}-agent` (for any consumer project)

**Already used:** The dead sessions I found were named exactly this: `framework-agent` and `termlink-agent`. The convention emerged organically.

### 4. Could TermLink add a --persistent flag?

**Yes, very easily.** Two implementation points:
1. `termlink spawn --persistent` → auto-adds `persistent` tag
2. `clean_stale_sessions()` → skips sessions with `persistent` tag

**Cost:** Trivial code change (~10 lines in manager.rs + ~5 in spawn command)

**Edge case:** A persistent session whose PID dies IS still stale — its process is gone. The question is: should cleanup remove the registration (allowing respawn to create a fresh one) or leave it (preventing respawn from registering a new one with the same name)?

**Recommendation:** Cleanup should WARN about dead persistent sessions but NOT remove them. This way:
- The `/resume` check sees the registration exists but is dead → triggers respawn
- No duplicate name conflict
- The warning surfaces the issue visibly

### 5. Task ID tracking

**TermLink side:** T-967
**Framework side:** T-1135

### 6. Cost model for idle persistent sessions

**Cost is minimal:**
- Memory: ~500KB per idle termlink session (registration + socket + event bus)
- CPU: Zero when idle (tokio runtime sleeps on epoll)
- Disk: One `.json` file (~1KB) + one Unix socket
- Network: Zero (no polling, no heartbeat currently)

**The real cost question** is the Claude Code session, not the termlink session:
- An idle Claude session costs API tokens only when context is loaded
- A persistent agent session could be a lightweight "receptionist" that only starts full Claude when a request arrives

## Counter-Proposals to Framework Agent

**We agree on:**
- `persistent:true` tag convention
- `/resume` checks persistent agent health
- `fw doctor` reports persistent agent health
- Cleanup crons exempt persistent sessions

**We add:**
- `termlink spawn --persistent` flag (convenience, auto-tags)
- `clean_stale_sessions()` warns but doesn't remove persistent sessions
- `termlink doctor` (not just `fw doctor`) checks persistent session health
- Consider: a persistent session could be a lightweight shell script that listens for requests and spawns full Claude on demand (avoids idle API costs)

## Files Referenced

- `crates/termlink-session/src/liveness.rs` — liveness check logic
- `crates/termlink-session/src/manager.rs:313` — `clean_stale_sessions()`
- `crates/termlink-cli/src/commands/session.rs:512` — `cmd_clean()` CLI
- `/var/lib/termlink/sessions/` — session registration files
