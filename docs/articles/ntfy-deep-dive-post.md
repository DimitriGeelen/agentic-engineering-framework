# The Deep-Dive That Found the Answer Next Door

The third Path C experiment started with a simple premise: the framework has no way to reach the human when the human is not watching. A Tier 0 approval blocks the agent completely. The agent prints a message, writes a file, and waits. If the human stepped away, the session burns context doing nothing. Push notifications solve this. ntfy is the simplest possible implementation — `curl -d "message" ntfy.sh/topic`.

I cloned the repository, initialised framework governance, and dispatched discovery agents. What I found was not what I expected.

## The Target

ntfy is Philipp Heckel's HTTP-based pub/sub notification service. No accounts needed. Self-hostable. Mobile apps for Android and iOS. The API is one HTTP POST: send a message body to a topic URL, and every subscriber gets a push notification. Priority, tags, attachments, scheduled delivery — all optional, all via HTTP headers.

The codebase is Go, roughly 18,000 lines in the server package, with 550 tests. Dual storage backends (SQLite and PostgreSQL), a custom S3 client with zero SDK dependencies, and a visitor-based rate limiting system with seven independent limiters per connection.

## 49 Patterns, Four Directives

Four discovery agents explored the codebase across API design, architecture, storage, and developer experience. Each pattern scored against the framework's constitutional directives: Antifragility, Reliability, Usability, Portability. Maximum 20 per pattern.

Average score: 17.1 out of 20.

The top tier — 19/20 — included four patterns:

**Dual-backend message cache.** A `queries` struct holds SQL strings. SQLite and PostgreSQL each supply different query sets through separate files. The `Cache` struct references the queries struct but never contains SQL. A conditional mutex — real for SQLite (single-writer), nil for PostgreSQL (concurrent) — is the only behavioral difference. The framework's proposed event logging (T-699) could adopt this pattern directly.

**Two-phase deletion lifecycle.** Messages expire after 12 hours. The manager soft-deletes in the database first, then a background sync loop physically removes files. A grace period prevents races between cleanup and active downloads. The batch-limited pruning (30,000 per cycle) prevents long transactions. Both patterns apply to any framework data store that accumulates over time.

**Transactional helpers.** Thirty-six lines of Go that eliminate an entire class of transaction bugs: forgotten rollback, forgotten commit, error-path resource leaks. `ExecTx` and `QueryTx` accept a `Beginner` interface that works with both raw `*sql.DB` and the wrapper type. If the framework adopts Go components, these helpers are worth taking verbatim.

**Attachment store with orphan cleanup.** A backend interface — five methods — wraps local filesystem and S3-compatible storage. A reconciliation loop runs every 15 minutes, comparing stored objects against database records. Orphaned files older than the grace period are deleted. The interface is minimal enough to implement for any storage backend in an afternoon.

## The Plot Twist

The enhancement design was straightforward. Five framework events map to push notifications: Tier 0 blocks (agent stopped, human not watching), task completions, audit failures, session handovers, and human review readiness. A `lib/notify.sh` wrapper, five insertion points in existing scripts, disabled by default. Bounded work, maybe two hours.

Then the coordination step.

The framework's `.mcp.json` already registers a skills-manager MCP server. The skills-manager project — a separate codebase governing infrastructure automation — had been running ntfy for months. Self-hosted on a Docker container. Behind Traefik with TLS. An alert dispatcher with deduplication, rate limiting, exponential retry, publisher authentication. Topic routing for different notification categories. All exposed as MCP tools.

The framework was about to build what already existed thirty centimetres to the left.

## What Changed

The original design — `lib/notify.sh` calling ntfy via curl — became a five-line wrapper calling the skills-manager's alert dispatcher:

```bash
fw_notify() {
    [ "${NTFY_ENABLED:-false}" = "true" ] || return 0
    python3 /opt/150-skills-manager/skills/alerts/alert_dispatcher.py \
        --trigger "$trigger" --title "$title" --message "$message" &
}
```

Fire-and-forget. Backgrounded. Disabled by default. No new dependencies. No duplicated deduplication logic. No reinvented rate limiting. No credential management.

The skills-manager handles routing (which topic gets which alert), delivery (retry with backoff), deduplication (60-minute window), and rate limiting (10 per hour). The framework handles deciding when to notify and what to say. Clean separation.

Five hooks were wired: the Tier 0 gate sends an urgent notification when a destructive command is blocked. The task updater notifies on completion and on partial-complete (human review needed). The audit script notifies on failures. The handover script notifies when a session ends.

## What the Process Revealed

This was the third Path C deep-dive. The first (vnx-orchestration) produced the workflow and eight friction points. The second (KCP) produced 33 patterns and validated the template. The third produced 49 patterns — and an architectural insight the template did not anticipate.

The template says: harvest patterns, design enhancement, build. It does not say: check whether the enhancement already exists in a sibling project. A learning was captured — L-128: before building new infrastructure, check the skills-manager MCP server. It exposes 126 operations across 27 skills.

The deeper lesson is about boundaries. The framework governs agent behaviour. The skills-manager governs infrastructure operations. When the framework needed a notification channel, the correct answer was not "build one" but "use the one that already exists, through the integration protocol (MCP) that already connects them."

Pattern extraction is valuable. But coordination across project boundaries — discovering that the answer exists before building it — is more valuable still.

---

*The Agentic Engineering Framework is an open governance layer for AI agent workflows. ntfy is developed by Philipp Heckel. Both projects are open source.*
