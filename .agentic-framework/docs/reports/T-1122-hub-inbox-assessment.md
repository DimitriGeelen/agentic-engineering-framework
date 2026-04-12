# T-1122 — TermLink U-002: Hub-Level Inbox Assessment

## Problem

`termlink send-file` requires an active target session. When the receiving
machine has zero sessions (idle, between restarts), files cannot be delivered.
ring20-manager reported this as U-002 during T-046 RCA.

## Assessment

### With T-1135 (Persistent Sessions)

If persistent sessions ship, every project has an always-on receptionist session.
The "zero sessions" scenario becomes rare — only occurs during:
- Machine reboot (before persistent session respawns)
- Session crash before respawn watchdog fires
- Initial setup before first persistent session registration

### Without T-1135

Hub-level inbox is needed for reliable cross-machine file delivery. The hub
process persists between sessions and could hold queued files, delivering
them when a session registers.

### Recommendation

**DEFER** until T-1135 outcome is known. If persistent sessions ship, U-002
becomes a nice-to-have (handles the respawn gap). If T-1135 is NO-GO, U-002
becomes critical for reliable cross-machine delivery.

## Workarounds

- SSH + scp (bypasses TermLink entirely)
- TermLink push to /tmp/termlink-inbox/ (filesystem-level, no session needed)
- Wait for session and retry
