# session-end

> SessionEnd hook — S1 reason logger + S2 handover trigger. Always exits 0. S1: appends {ts, session_id, reason} JSON line to .context/working/.session-end-log. S2: if no handover exists for current session_id, runs `fw handover` in the background (fast return, some end-reasons like API 500 give little grace). Fallback: session-silent-scanner via cron every 15 min catches sessions where this hook never fired.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/session-end.sh`

**Tags:** `hook`, `session-end`, `handover`, `T-1212`

## What It Does

SessionEnd hook — S1 reason logger + S2 handover trigger (T-1212)
Fires on session termination. Always exits 0.
S1: appends {ts, session_id, reason} JSON line to
.context/working/.session-end-log for reason-field telemetry.
S2: if no handover exists for the current session_id
(`.context/handovers/LATEST.md` frontmatter session_id mismatch), runs
`fw handover` in the background. Background so the hook returns fast
(<2s) regardless of handover duration — some session-end reasons
(e.g. API 500 kill) give us very little grace period.
Known Claude Code bugs this hook tolerates:

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `agents/handover/handover.sh` | calls |
| `.context/handovers/LATEST.md` | reads |
| `.context/working/.session-end-log` | writes |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | invoked_via_fw_hook |
| `agents/context/tests/session-end-stub-test.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-session-end.yaml`*
*Last verified: 2026-04-24*
