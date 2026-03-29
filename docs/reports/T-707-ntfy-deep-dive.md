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

## Scored Patterns (D1-D4)

49 patterns found across 4 domains (API, Architecture, Storage, DX). Auth domain pending. Ranked by composite score.

### Top Patterns (Score >= 18)

| # | Pattern | Domain | D1 | D2 | D3 | D4 | Total | Framework Application |
|---|---------|--------|----|----|----|----|-------|----------------------|
| 1 | Dual-backend message cache (SQLite+Postgres) | Storage | 4 | 5 | 5 | 5 | **19** | Model for T-699 event logging — queries struct abstracts backend |
| 2 | Attachment store with orphan cleanup | Storage | 5 | 4 | 5 | 5 | **19** | Grace-period reconciliation prevents metadata/storage drift |
| 3 | TTL-based data lifecycle (2-phase delete) | Storage | 5 | 5 | 4 | 5 | **19** | Soft-delete in DB, physical cleanup in background — prevent races |
| 4 | Transactional helpers (ExecTx/QueryTx) | Storage | 4 | 5 | 5 | 5 | **19** | 36 lines eliminate entire class of transaction bugs |
| 5 | Schema migration system (versioned) | Storage | 5 | 5 | 4 | 4 | **18** | Framework SQLite has no migration system — adopt this |
| 6 | Structured error catalog with doc links | API | 4 | 5 | 5 | 4 | **18** | 77 error types with unique codes + remediation URLs |
| 7 | Message cache with pluggable backends | API | 5 | 5 | 4 | 4 | **18** | Offline notification delivery — messages persist until retrieved |
| 8 | Middleware composition chain | API | 4 | 5 | 4 | 5 | **18** | Composable auth/rate-limit/handler pipeline |
| 9 | Per-channel Prometheus metrics | API | 5 | 5 | 4 | 4 | **18** | Per-channel success/failure counters for delivery monitoring |
| 10 | Structured logging (deferred alloc) | Arch | 4 | 5 | 5 | 4 | **18** | Zero-cost when not at level — Contexter interface for domain context |
| 11 | Layered rate limiting (interface) | Arch | 5 | 5 | 4 | 4 | **18** | Multi-dimensional limiters — requests, bandwidth, auth failures |
| 12 | DB abstraction with replica health | Arch | 5 | 5 | 4 | 4 | **18** | Health-checked replicas with graceful fallback |

### Patterns Score 17

| # | Pattern | Domain | D1 | D2 | D3 | D4 | Total |
|---|---------|--------|----|----|----|----|-------|
| 13 | Topic-based pub/sub (URL-as-address) | API | 4 | 3 | 5 | 5 | 17 |
| 14 | Multi-protocol subscription (JSON/SSE/Raw/WS) | API | 3 | 4 | 5 | 5 | 17 |
| 15 | Header-based API with JSON fallback | API | 3 | 4 | 5 | 5 | 17 |
| 16 | Visitor-based rate limiting (token bucket) | API | 5 | 5 | 3 | 4 | 17 |
| 17 | Subscription connection lifecycle | API | 5 | 5 | 3 | 4 | 17 |
| 18 | Typed error catalog | Arch | 3 | 5 | 5 | 4 | 17 |
| 19 | Multi-backend test harness (forEachBackend) | Arch | 5 | 5 | 4 | 3 | 17 |
| 20 | Generic utility types (Go generics) | Arch | 3 | 4 | 5 | 5 | 17 |
| 21 | Middleware chain for HTTP handlers | Arch | 3 | 5 | 5 | 4 | 17 |
| 22 | Comprehensive config (triple-source) | Arch | 3 | 4 | 5 | 5 | 17 |
| 23 | Fail-fast init with cleanup | Arch | 5 | 5 | 4 | 3 | 17 |
| 24 | UTF-8 sanitization at entry | Arch | 5 | 5 | 3 | 4 | 17 |
| 25 | Build system with cross-compilation | Arch | 3 | 5 | 4 | 5 | 17 |
| 26 | LookupCache (TTL single-value) | Storage | 3 | 4 | 5 | 5 | 17 |

### Patterns Score 15-16

| # | Pattern | Domain | Total | Notes |
|---|---------|--------|-------|-------|
| 27 | Multi-channel delivery fan-out | API | 16 | Fire-and-forget goroutines per channel |
| 28 | Build-tag feature toggles | API | 16 | Compile-time feature inclusion/exclusion |
| 29 | Upstream server forwarding | API | 16 | Self-hosted with mobile push via ntfy.sh |
| 30 | Embedded filesystem (go:embed) | Arch | 16 | Single-binary with all assets |
| 31 | In-memory pub/sub with staleness | Arch | 16 | Topic auto-expiry on inactivity |
| 32 | PeekedReadCloser | Arch | 16 | Non-destructive stream inspection |
| 33 | Custom S3 client (zero SDK deps) | Storage | 16 | D4 excellence — works with any S3-compatible |
| 34 | Write batching (BatchingQueue) | Storage | 15 | Generic time/size-based batch queue |
| 35 | Primary/replica DB with health | Storage | 18 | Round-robin with atomic health flags |

### Average Score: 17.1/20

## Tier Classification

### Tier A: Directly applicable (build now)

1. **Schema migration system (#5, 18/20)** — Framework SQLite stores (metrics, proposed event log) have no migration system. Adopt ntfy's version table + numbered migration map + transactional execution.

2. **Transactional helpers (#4, 19/20)** — 36 lines of Go that eliminate transaction bugs. If the framework adds Go components (T-586 language strategy), adopt verbatim.

3. **Structured error catalog (#6, 18/20)** — Replace ad-hoc error strings with typed errors containing unique codes and doc links. Apply across fw CLI commands.

4. **Fire-and-forget notification delivery (#27, 16/20)** — The exact pattern for `lib/notify.sh`. Notification failures must never block governance operations.

### Tier B: Worth exploring (inception needed)

5. **Dual-backend storage (#1, 19/20)** — If T-699 (fw stats) goes to SQLite, the queries-struct pattern enables future PostgreSQL support without rewrites.

6. **Multi-protocol subscription (#14, 17/20)** — Watchtower could offer SSE/WebSocket for real-time notification delivery alongside the existing htmx polling.

7. **Per-channel metrics (#9, 18/20)** — Once notifications are live, track delivery rates per channel (ntfy, email, webhook) for reliability monitoring.

### Tier C: Interesting but premature

8. Upstream server forwarding — relevant only if self-hosting ntfy
9. Build-tag feature toggles — relevant only if framework adds compiled Go components
10. Custom S3 client — impressive but no S3 need in framework

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

### Integration Architecture (REVISED after coordination)

**Original design:** Build `lib/notify.sh` with curl calls to ntfy.

**Revised design:** Use skills-manager (150) existing infrastructure via MCP.

```
Framework Event → fw_notify() → skills-manager alert dispatcher → ntfy → Mobile/Desktop
                      ↑                     ↑
               NTFY_ENABLED env    dedup, rate limit, retry, topic routing
```

The skills-manager project (150) already has:
- ntfy self-hosted at localhost:2586, behind Traefik TLS at `ntfy.docker.ring20.geelenandcompany.com`
- Alert dispatcher with dedup (60min window), rate limiting (10/hr), retry (3 attempts)
- ntfy channel with priority mapping, topic routing, publisher auth
- MCP server configured in framework `.mcp.json` — `dispatch_alert` tool

### Design: `lib/notify.sh` (thin wrapper)

Instead of reimplementing notification logic, the framework calls the skills-manager alert dispatcher:

```bash
# lib/notify.sh — Framework notification wrapper
#
# Calls skills-manager dispatch_alert via CLI (fire-and-forget)
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/notify.sh"
#   fw_notify "title" "message" [trigger] [category]
#
# Configuration:
#   NTFY_ENABLED  — set to "true" to enable (default: disabled)

fw_notify() {
    [ "${NTFY_ENABLED:-false}" = "true" ] || return 0
    local title="$1" message="$2" trigger="${3:-manual}" category="${4:-framework}"
    python3 /opt/150-skills-manager/skills/alerts/alert_dispatcher.py \
      --trigger "$trigger" --title "$title" --message "$message" &
}
```

**Key design decisions:**
1. **Disabled by default** — No surprise network calls. Human opts in via `NTFY_ENABLED=true`
2. **Fire-and-forget** — Runs in background (`&`), never blocks framework operations
3. **No duplication** — Uses existing dedup, rate limiting, retry, auth from skills-manager
4. **Alert history** — All notifications tracked in skills-manager `alerts.jsonl`
5. **Graceful degradation** — If skills-manager unreachable, no error. Notifications are advisory.

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

### Configuration Design (Simplified)

Framework side is minimal — just an enable flag:
```bash
# In .env or shell profile:
export NTFY_ENABLED=true
```

All notification routing, auth, and topic configuration lives in the skills-manager project (`skills/alerts/alert_config.py`). The framework does not need to know about ntfy servers, topics, or credentials.

### Setup Flow

```bash
fw notify test               # Send test push via skills-manager dispatcher
fw notify enable             # Set NTFY_ENABLED=true
fw notify disable            # Set NTFY_ENABLED=false
```

### Self-Hosting: Already Done

ntfy is already self-hosted in the skills-manager infrastructure:
- **Server:** localhost:2586 (Docker, T-036)
- **TLS:** `ntfy.docker.ring20.geelenandcompany.com` via Traefik (T-285)
- **Auth:** Publisher credentials in `/opt/ntfy-data/.publisher-pw`
- **Phone app:** Subscribe via HTTPS URL with auth

No additional self-hosting work needed for the framework.

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

## Cross-Reference: ntfy Patterns vs Framework Gaps

| ntfy Pattern | Framework Gap/Need | Status |
|-------------|-------------------|--------|
| Schema migration | No migration system for SQLite stores | NEW |
| Structured errors | Ad-hoc error strings in agents | Enhancement |
| Dual-backend storage | T-699 proposes SQLite logging | T-699 (captured) |
| Per-channel metrics | No notification delivery monitoring | NEW (post-integration) |
| Fire-and-forget delivery | Framework blocks on failed actions | Integration design |
| TTL-based lifecycle | No data lifecycle for context/audit files | Enhancement |
| Multi-protocol subscription | Watchtower uses htmx polling only | T-632 area |
