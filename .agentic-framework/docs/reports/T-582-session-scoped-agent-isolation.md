# T-582: Session-Scoped Agent Isolation — Session Keys + Crash Recovery

## Problem Statement

Two concurrent agents sharing a project corrupt each other's focus, session state, and working memory. Already hit in practice: fw-agent + openclaw-eval + 150-skills-manager all active simultaneously.

**Current state:** T-560 added session-stamped focus (focus.yaml includes focus_session, check-active-task.sh validates it matches current session). This prevents stale focus from granting a free pass to new sessions, but it's a single-writer lock, not true isolation. Two concurrent sessions still write to the same focus.yaml.

**Concrete failure modes:**
1. Agent A sets focus to T-100, Agent B sets focus to T-200 → last-write-wins, one agent loses gate validation
2. Agent A's checkpoint writes budget status, Agent B reads it → B thinks A's budget applies to B
3. Agent crashes, session.yaml retains stale session ID → T-560 blocks next session

## Current Architecture

### Shared state in `.context/working/`

| File | Purpose | Conflict risk |
|------|---------|---------------|
| `focus.yaml` | Current task + session stamp | HIGH — single-writer, last-write-wins |
| `session.yaml` | Active session ID + metadata | HIGH — one session file, multiple agents |
| `.budget-status` | Token budget level (ok/warn/urgent/critical) | MEDIUM — per-session budget read by all |
| `.tool-counter` | Tool call count since last commit | LOW — advisory only |
| `.compact-log` | Compaction history | LOW — append-only |
| `.edit-counter` | Edit count for new-file limit | MEDIUM — shared gate counter |

### T-560 Session Stamping (current isolation)

`check-active-task.sh:120-152`:
- focus.yaml stores `focus_session` alongside `current_task`
- On Write/Edit, hook compares `focus_session` with `session.yaml:session_id`
- Mismatch → STALE FOCUS block, requires `fw work-on T-XXX` to refresh

**Limitation:** This is a stale-detection mechanism, not isolation. Two concurrent agents in the SAME session still collide. Two agents in DIFFERENT sessions will each block the other via the stale check — a deadlock, not a resolution.

## Design Options

### Option A: Session-Namespaced Working Directory

Each session gets its own working dir: `.context/working/<session-id>/`

```
.context/working/
  S-2026-0327-1900/
    focus.yaml
    session.yaml
    .budget-status
    .tool-counter
  S-2026-0327-1905/
    focus.yaml
    ...
```

**Pro:** True isolation. Each agent reads/writes its own files. Zero conflict.
**Con:** Every script that reads `.context/working/` needs updating (~15 files). Garbage collection needed for old sessions. `fw context status` needs to show all active sessions.

### Option B: Session Key in File Content (OpenClaw pattern)

Adopt OpenClaw's `agent:<agentId>:<scope>` session key format. Each agent writes a session key into focus.yaml, budget status, etc. Scripts read only the entries matching their session key.

**Pro:** Backward-compatible file paths. Session key can be any granularity.
**Con:** Multi-key files are more complex to parse. Still susceptible to race conditions on write.

### Option C: Lock File + Single Active Session (simplest)

Only one agent can be active at a time. Second agent attempting `fw context init` gets blocked with "Session S-XXX is already active."

**Pro:** Zero code changes to working dir readers. Simple. Enforces the discipline.
**Con:** Blocks legitimate parallel work (TermLink workers, multi-agent dispatch).

### Option D: Hybrid — Session Namespace for Hot Path Only

Namespace only the conflict-prone files (focus.yaml, budget-status). Leave advisory files (tool-counter, compact-log) shared.

```
.context/working/
  sessions/
    S-2026-0327-1900.yaml   # focus + budget for this session
  .tool-counter              # shared advisory
  .compact-log               # shared append-only
```

**Pro:** Minimal blast radius. Only 2-3 files change location.
**Con:** Mixed model is confusing. Need clear documentation of what's namespaced.

## Crash Recovery

Regardless of isolation model, crash recovery needs:

1. **Stale session detection:** If a session hasn't written to its files in >5 minutes and has no running PID, mark stale
2. **Cleanup:** Move stale session state to archive, clear focus lock
3. **Integration point:** `fw context init` should detect and clean up stale sessions before creating a new one

**Current crash recovery:** None. If a session crashes, its focus.yaml entry persists until the next session overwrites it (or T-560 blocks on stale check).

## Recommendation

**Option A (Session-Namespaced Working Directory)** is the cleanest long-term solution but has significant blast radius (~15 files). Option D (hybrid) is a practical middle ground.

**Recommended: Option D first, Option A later.** Namespace focus.yaml and budget-status per session. This fixes the two highest-impact conflict modes (focus corruption and budget cross-read) with minimal blast radius. Revisit full namespacing when TermLink multi-agent dispatch becomes common.

**Effort:** ~1 session for Option D. ~3 sessions for Option A.

## Go/No-Go Assessment

**GO criteria:**
- [x] Clear problem with concrete evidence (3+ incidents of concurrent agent conflict)
- [x] Bounded solution (Option D: 2-3 files, session prefix)
- [x] Backward-compatible with T-560 (enhances rather than replaces)

**NO-GO criteria:**
- [ ] Only one agent ever runs per project → not true, TermLink workers exist
- [ ] T-560 is sufficient → not true, deadlocks on concurrent sessions

**Recommendation: GO** with Option D (hybrid session namespace for focus + budget).

## Dialogue Log

- Research conducted by reviewing: check-active-task.sh session stamping, OpenClaw session key pattern (T-549), context init flow
- No human dialogue — agent-driven inception from T-549 findings and observed concurrent agent conflicts
