# session-end

> SessionEnd hook — S1 reason logger + S2 handover trigger. Always exits 0. S1: appends {ts, session_id, reason} JSON line to .context/working/.session-end-log. S2: if no handover exists for current session_id, runs `fw handover` in the background (fast return, some end-reasons like API 500 give little grace). Fallback: session-silent-scanner via cron every 15 min catches sessions where this hook never fired.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/session-end.sh`

**Tags:** `hook`, `session-end`, `handover`, `T-1212`

## What It Does

REFERENCE ONLY — deliberately NOT registered in .claude/settings.json.
T-1459 reached GO on Option D (reference-only) and set a precondition for ever
re-enabling this: read the G-016 RCA first. G-016 was a handover COMMIT STORM, and
the last action taken on this script cluster was defensive capping (2199ccba), not
decommissioning. Registering this hook without working through that RCA re-opens
the hazard the decision parked. `tests/unit/hook_enable_events.bats` asserts the
absence, so reversing the decision fails loudly rather than quietly.
SessionEnd hook — S1 reason logger + S2 handover trigger (T-1212)
Fires on session termination. Always exits 0.
S1: appends {ts, session_id, reason} JSON line to

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| `.context/handovers/LATEST.md` | reads | — |
| `.context/working/.session-end-log` | writes | — |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | invoked_via_fw_hook | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| `agents/context/tests/session-end-stub-test.sh` | called_by | — |

---
*Auto-generated from Component Fabric. Card: `agents-context-session-end.yaml`*
*Last verified: 2026-04-24*
