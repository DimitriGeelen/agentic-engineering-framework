# T-707: ntfy Deep-Dive — Pattern Harvest + Enhancement Design

## Method

Path C deep-dive on `github.com/binwiederhier/ntfy` — HTTP-based pub/sub push notification service.
5 discovery agents explored the codebase across 5 domains, scoring patterns against D1-D4.

**Source:** https://github.com/binwiederhier/ntfy
**Clone:** /opt/053-ntfy
**Language:** Go
**License:** Apache 2.0 + GPL 2.0 (dual)

## Project Overview

ntfy is a simple HTTP-based pub-sub notification service. Key characteristics:
- **API simplicity:** `curl -d "message" ntfy.sh/topic` — one HTTP POST sends a push notification
- **Self-hostable:** Single Go binary, SQLite default, optional PostgreSQL
- **Mobile push:** Android (FCM/UnifiedPush), iOS (APNs) apps
- **No account needed:** Topics are anonymous by default, auth optional
- **Attachment support:** Files up to 15MB via PUT, stored locally or S3
- **Web push:** Browser notifications via web app
- **Subscription:** HTTP stream, WebSocket, SSE, polling

## Phase 1: Setup Results

| Check | Result |
|-------|--------|
| Clone | /opt/053-ntfy |
| fw init | 36/40 checks OK |
| fw doctor | 0 failures, 3 warnings |
| Seed tasks | 6 (existing project mode, T-001—T-006) |
| TermLink session | ntfy-dive (active) |

## Phase 2: Execution

Worker dispatched via `fw termlink dispatch --name ntfy-worker --task T-707`.
**Result:** Worker killed by timeout (exit 143/SIGTERM). Result file 0 bytes.
Seed tasks remain uncompleted (all 6 in .tasks/active/).

**Root cause:** Worker prompt may have been too broad, or the Go codebase too large for the worker to navigate within the timeout. The worker timeout orphan issue (T-577) applies — the dispatch watchdog killed the process.

**Mitigation:** Discovery agents dispatched directly from framework session to harvest patterns. Seed tasks are not blocking for pattern extraction — they're governance scaffolding, and the 5 discovery agents perform the actual analysis.

## Discovery Agent Results

### Domain 1: API & HTTP Patterns
*(Agent: ntfy-d1-api)*

[PENDING — agent results will be consolidated here]

### Domain 2: Auth & Security Patterns
*(Agent: ntfy-d2-auth)*

[PENDING — agent results will be consolidated here]

### Domain 3: Architecture & Go Patterns
*(Agent: ntfy-d3-arch)*

[PENDING — agent results will be consolidated here]

### Domain 4: Storage & Persistence Patterns
*(Agent: ntfy-d4-storage)*

[PENDING — agent results will be consolidated here]

### Domain 5: DX & Self-Hosting Patterns
*(Agent: ntfy-d5-dx)*

[PENDING — agent results will be consolidated here]

## Enhancement Design: Framework Notification Surface

### Problem

The framework has no push notification channel. Events that need human attention are only visible in the terminal or Watchtower web UI (if running). The human discovers events only when they look.

### Events That Benefit from Push Notification

| Event | Source | Current Behavior | Push Value |
|-------|--------|-----------------|------------|
| **Tier 0 block** | `check-tier0.sh` | Prints BLOCKED, writes pending YAML | **HIGH** — Agent is fully stopped, waiting for human |
| **Task completion** | `update-task.sh` | Moves file, prints status | MEDIUM — Nice to know, not blocking |
| **Audit FAIL** | `audit.sh` (cron) | Writes to YAML log | **HIGH** — Failures may indicate governance drift |
| **Session handover** | `handover.sh` | Writes LATEST.md | MEDIUM — Signals context budget exhaustion |
| **Budget critical** | `checkpoint.sh` | Auto-handover, prints warning | LOW — Session is already wrapping up |
| **Human AC ready** | `update-task.sh` | Emits review URL | MEDIUM — Human review is needed |

### Integration Architecture

```
Framework Event → notify.sh → curl POST → ntfy server → Mobile/Desktop push
                     ↑
              ntfy.conf (topic, server URL, auth)
```

### Design: `lib/notify.sh`

A single-file notification helper. Framework scripts source it and call `fw_notify`.

```bash
# lib/notify.sh — Framework push notification helper
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/notify.sh"
#   fw_notify "title" "message" [priority] [tags]
#
# Configuration (in .framework.yaml or env):
#   NTFY_TOPIC    — ntfy topic (e.g., "fw-dimitri" or "fw-myproject")
#   NTFY_SERVER   — ntfy server URL (default: https://ntfy.sh)
#   NTFY_TOKEN    — access token (optional, for self-hosted with auth)
#   NTFY_ENABLED  — set to "true" to enable (default: disabled)
#
# Priority levels: min, low, default, high, urgent
# Tags: emoji shortcodes (e.g., "rotating_light" = 🚨, "white_check_mark" = ✅)
```

**Key design decisions:**
1. **Disabled by default** — No surprise network calls. Human opts in via `NTFY_ENABLED=true`
2. **Fire-and-forget** — `curl` runs in background (`&`), never blocks framework operations
3. **No new dependency** — Uses `curl` (already required by framework)
4. **Configurable topic** — Each project gets its own ntfy topic
5. **Self-hosted or public** — Works with ntfy.sh (free) or self-hosted instance
6. **Graceful degradation** — If curl fails, no error. Notifications are advisory, not structural.

### Integration Points

#### 1. Tier 0 Block → Push (HIGH priority)

**File:** `agents/context/check-tier0.sh` (line ~355-400)
**When:** Destructive command detected and blocked
**Insert after:** The `TIER 0 BLOCK` stderr output and pending YAML write
**Notification:**
```
Title: "🚨 Tier 0 Approval Needed"
Body: "$DESCRIPTION\nCommand: ${COMMAND:0:80}\nApprove: ${WT_URL}/approvals"
Priority: urgent
Tags: rotating_light
```

#### 2. Task Completion → Push (default priority)

**File:** `agents/task-create/update-task.sh` (line ~588)
**When:** Status transitions to `work-completed`
**Insert after:** Finalization (date_finished set, file moved)
**Notification:**
```
Title: "✅ Task Complete: $TASK_ID"
Body: "$TASK_NAME"
Priority: default
Tags: white_check_mark
```

#### 3. Audit FAIL → Push (HIGH priority)

**File:** `agents/audit/audit.sh` (end of script)
**When:** `FAIL_COUNT > 0` at end of audit run
**Insert after:** Summary output
**Notification:**
```
Title: "⚠️ Audit Failures: $FAIL_COUNT"
Body: "Pass: $PASS_COUNT | Warn: $WARN_COUNT | Fail: $FAIL_COUNT"
Priority: high
Tags: warning
```

#### 4. Session Handover → Push (low priority)

**File:** `agents/handover/handover.sh` (end of script)
**When:** Handover document created
**Notification:**
```
Title: "📋 Session Ended: $SESSION_ID"
Body: "Handover created. Active tasks: $ACTIVE_COUNT"
Priority: low
Tags: clipboard
```

#### 5. Human AC Ready → Push (default priority)

**File:** `agents/task-create/update-task.sh` (line ~151, `_emit_partial_complete`)
**When:** Agent ACs complete, human ACs remain
**Insert after:** Review URL emission
**Notification:**
```
Title: "👀 Review Needed: $TASK_ID"
Body: "$TASK_NAME\nReview: ${WT_URL}/tasks/$TASK_ID"
Priority: default
Tags: eyes
```

### Configuration Design

Add to `.framework.yaml`:
```yaml
notifications:
  enabled: false          # Opt-in only
  provider: ntfy          # Future: could support others
  server: https://ntfy.sh # Or self-hosted URL
  topic: fw-{project}     # Auto-derived from project_name
  token: ""               # Optional auth token
  events:
    tier0: true           # Push on Tier 0 blocks
    task_complete: true   # Push on task completion
    audit_fail: true      # Push on audit failures
    handover: false       # Push on session handover
    human_ac: true        # Push when human review needed
```

### Setup Flow

```bash
fw notify setup              # Interactive: configure topic, test notification
fw notify test               # Send test push to verify delivery
fw notify enable             # Enable notifications
fw notify disable            # Disable notifications
```

### Self-Hosting Evaluation

ntfy self-hosting is straightforward:
- **Docker:** `docker run -p 80:80 binwiederhier/ntfy serve`
- **Binary:** Single binary, `ntfy serve` starts the server
- **Storage:** SQLite by default (no external DB needed)
- **Resource usage:** Minimal — runs on a Raspberry Pi

For the framework, self-hosting is optional. The public ntfy.sh instance works for basic usage. Topics are unguessable if named with a project-specific random suffix.

### Security Considerations

1. **Topic privacy:** Topics on ntfy.sh are public if someone guesses the name. Use random suffixes (e.g., `fw-999-aef-a8f3c2`) or self-host.
2. **No sensitive data in notifications:** Message body should contain task IDs and descriptions, never code or credentials.
3. **Auth tokens:** Self-hosted instances can require authentication. The token goes in `.framework.yaml` (which is gitignored for consumer projects) or env vars.

## Go/No-Go Assessment

**GO criteria check:**
- [x] ntfy integration is simple (HTTP POST, no complex auth) — YES, one `curl` command
- [x] Clear framework events that benefit from push — YES, 5 events identified, 2 HIGH priority
- [x] Self-hosting is straightforward — YES, single binary or Docker
- [x] Enhancement is bounded — YES, `lib/notify.sh` + 5 insertion points, < 1 session

**NO-GO criteria check:**
- [ ] Complex setup — NO, it's `curl -d "msg" ntfy.sh/topic`
- [ ] Events don't map — NO, Tier 0 and audit failures are clear fits
- [ ] Watchtower polling sufficient — PARTIALLY, but Watchtower requires the human to be watching

## Recommendation

**GO** — Build `lib/notify.sh` and wire into 5 framework integration points.

**Rationale:**
1. The Tier 0 approval use case alone justifies integration — the agent is completely blocked, the human may not be watching, and a phone notification fixes this
2. Zero new dependencies (uses curl)
3. Disabled by default — no behavior change for existing users
4. Bounded scope — one library file + 5 small insertions into existing scripts
5. Graceful degradation — if ntfy is unreachable, nothing breaks

**Build tasks to create:**
1. `lib/notify.sh` — notification helper with config loading
2. Wire Tier 0 block notification into `check-tier0.sh`
3. Wire task completion notification into `update-task.sh`
4. Wire audit failure notification into `audit.sh`
5. Wire handover/human-AC notifications
6. `fw notify setup/test/enable/disable` CLI commands
7. Documentation update

## Friction Log

| # | Issue | Severity | Category | Notes |
|---|-------|----------|----------|-------|
| F-1 | Worker killed by timeout (exit 143), 0 bytes result | High | TermLink | Worker prompt too broad for large Go codebase within default timeout |
| F-2 | TermLink interact timeouts with queued command backlog | Medium | TermLink | Multiple interact calls queue up in PTY, causing cascading timeouts |
| F-3 | Seed tasks not completed due to worker failure | Medium | Workflow | Discovery agents compensate, but formal governance scaffolding incomplete |

## Patterns Scored Against D1-D4

[Will be populated from discovery agent results]
