# session-silent-scanner

> Silent-session scanner — S3 antifragility fallback for SessionEnd. Cron-invoked every 15 min. Walks $HOME/.claude/projects/*/<session>.jsonl, finds sessions older than SESSION_SILENT_THRESHOLD_MIN (default 30) whose session_id does NOT appear under .context/handovers/. For matches runs `fw handover` with RECOVERED=1. Closes SessionEnd gap (/exit skips hook, API 500 kills before hook fires). T-1222 cap prevents commit storms.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/session-silent-scanner.sh`

**Tags:** `cron`, `handover`, `recovery`, `T-1212`, `G-016`

## What It Does

Silent-session scanner — S3 antifragility fallback for SessionEnd (T-1212)
Invoked via cron every 15 min. Walks $HOME/.claude/projects/*/<session>.jsonl,
finds session transcripts whose mtime is older than SESSION_SILENT_THRESHOLD_MIN
(default 30 min) AND whose session_id does NOT appear in any file under
.context/handovers/. For matches, runs `fw handover` with RECOVERED=1 so the
generated handover carries a `[recovered, no agent context]` banner.
Together with session-end.sh this closes the SessionEnd gap for:
- Claude Code #17885 (/exit skips SessionEnd)
- Claude Code #20197 (API 500 kills before hook fires)
- SIGKILL / laptop sleep / network drops

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `agents/handover/handover.sh` | calls |
| `.context/handovers/` | reads |
| `.context/working/.session-silent-scanner.log` | writes |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `/etc/cron.d/agentic-framework` | scheduled_by |
| `agents/context/tests/session-silent-scanner-stub-test.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-session-silent-scanner.yaml`*
*Last verified: 2026-04-24*
