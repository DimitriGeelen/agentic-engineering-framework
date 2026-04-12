# Brain Daemon — v1 Specification (v0.1 draft)

**Status:** v0.1 draft — protocol surface frozen for parallel implementation
**Version:** 0.1.0
**Date:** 2026-04-11
**Authors:** ring20-manager (proxmox-ring20-management T-028) + dashboard-brain (ring20-dashboard T-011)
**Coordination task:** T-029 (cross-host termlink coordination, dialogue at `proxmox-ring20-management:.context/dialogues/T-029/`)

## 0. Status notes

This is a v0.1 draft. The protocol surface (event names, channel names, envelope shapes) is frozen for parallel implementation work. Internal daemon design (process model, persistence implementation, supervision strategy) is sketched but not frozen — implementation may revise. Anything marked **(open)** below is explicitly unresolved and will land in v0.2 after implementation feedback.

The two project-side build tasks (T-028 daemon prototype on proxmox-ring20-management, T-011 Watchtower panels on ring20-dashboard) can proceed in parallel against this surface without coordination overhead. Cross-cutting changes (new event types, channel renames, envelope schema breaks) MUST go through a remote-push round between both authors before being committed to this spec.

## 1. Purpose

A persistent, long-running process per project that:

1. Receives task delegation requests from a parent Claude session over the framework's `fw bus` ledger
2. Spawns child Claude workers (subprocess) to execute delegated work
3. Streams worker output and lifecycle events back to interested observers (Watchtower panels, peer agents, the originating Claude session) via the bus
4. Persists worker state across daemon restarts so a worker can be resumed after a daemon crash
5. Routes Tier-0 approval requests from workers to the human via Watchtower
6. Provides a session observer surface so any UI can show "what is this project currently doing"

Out of scope for v1: write-side approval actions (granting Tier-0, approving delegation results) — those land in v2 once the read-side surface is proven.

## 2. Goals and non-goals

### Goals
- **Survives session boundaries.** Long-running work (multi-hour generations, scheduled jobs) outlives any one Claude session.
- **Single source of truth on the wire.** All inter-component communication is `fw bus` envelopes on a known channel. No private sockets, no shared memory, no out-of-band state.
- **Zero new dependencies on the framework's existing data shapes.** The daemon writes T-012 delegation envelopes that the existing `fw bus post/manifest/read` CLI already understands.
- **Observability is free.** Anything that wants to see daemon state subscribes to the same bus channel — no separate observability layer.
- **Per-project isolation.** Each project runs its own daemon instance pointed at its own `.context/` root and `fw bus` ledger. No cross-project federation in v1 (added in v2 via R6 from P-011 — `fw pickup send --remote` and equivalent).

### Non-goals (explicitly deferred)
- Write actions (approve, reject, retry, cancel) — v2
- Cross-project federation — v2 + framework R6
- Distributed daemon (multiple daemon processes per project) — v2 if needed; v1 is single-process per project
- Hot-reload of daemon code without losing worker state — v2
- Authentication beyond local-host filesystem permissions — v2 (the bus is local-only in v1)

## 3. Architecture

```
                                                              ┌─────────────────────────┐
                                                              │  Claude session(s)      │
                                                              │  (parent)               │
                                                              │  - dispatches work via  │
                                                              │    fw bus post          │
                                                              └──────────┬──────────────┘
                                                                         │ fw bus post
                                                                         ▼ delegation.request
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│  fw bus (channel: brain-external)                                                        │
│  - Append-only ledger of typed envelopes                                                 │
│  - Already exists, already documented in CLAUDE.md, already CLI-addressable              │
└────┬───────────────────────────┬─────────────────────────────────────────┬───────────────┘
     │                           │                                         │
     │ subscribe                 │ subscribe                               │ subscribe
     ▼                           ▼                                         ▼
┌─────────────────┐   ┌─────────────────────────┐               ┌──────────────────────┐
│  Brain daemon   │   │  Watchtower panels      │               │  Peer agent          │
│  (one per       │   │  (read-only v1)         │               │  (other project's    │
│  project)       │   │  - approval queue       │               │   daemon, optional)  │
│  - polls bus    │   │  - delegation log       │               │                      │
│  - spawns       │   │  - session observer     │               │                      │
│    workers      │   │  - tier-0 request panel │               │                      │
│  - emits events │   │                         │               │                      │
└────┬────────────┘   └─────────────────────────┘               └──────────────────────┘
     │ spawn / wait
     ▼
┌─────────────────┐
│  Worker         │
│  Claude session │
│  (subprocess)   │
└─────────────────┘
```

### Components

- **Brain daemon** — Python long-lived process (Q1 pending human ratification). One per project. Polls `fw bus` channel `brain-external` for `delegation.request` envelopes addressed to this project. Spawns Claude workers via `subprocess.Popen`. Streams worker output and lifecycle events back as bus envelopes.
- **Worker** — Claude session spawned as a subprocess (`claude` CLI). Standard stdin/stdout/stderr. The daemon reads worker output line-by-line and posts each significant event back to the bus.
- **Watchtower panels** — Web UI (Flask blueprints in `.agentic-framework/web/blueprints/`). Read-only consumers of the bus channel. Render approval queue, delegation log, session observer, tier-0 request panel. Built by dashboard-brain in T-011 (parallel work).
- **Parent session** — A Claude session (or human via CLI) that wants to delegate work. Calls `fw bus post --channel brain-external --type delegation.request --payload @work.yaml`. Does not need to know the daemon exists — the channel is the contract.

## 4. Protocol — frozen event surface

All envelopes posted to `fw bus` channel `brain-external`. Standard envelope shape from the existing `fw bus` schema; the additions below are the `type` field discriminator and the typed payload.

### 4.1 Delegation events

| Type | Direction | Payload |
|---|---|---|
| `delegation.request` | parent → daemon | `{request_id, task_id, prompt, working_dir, owner, deadline?, priority?}` |
| `delegation.accepted` | daemon → all | `{request_id, worker_id, started_at, daemon_id}` |
| `delegation.result` | daemon → all | `{request_id, worker_id, exit_code, output_blob_path, finished_at, duration_seconds}` |
| `delegation.failed` | daemon → all | `{request_id, worker_id, exit_code, error, stderr_tail, finished_at}` |

`request_id` is a uuid generated by the parent. The daemon uses `request_id` as the correlation key for all subsequent events about this delegation. Workers do not see `request_id`; they only see the prompt.

### 4.2 Worker stream events

| Type | Direction | Payload |
|---|---|---|
| `worker.output` | daemon → all | `{request_id, worker_id, stream: "stdout"\|"stderr", line, ts}` (one per line, may be batched) |
| `worker.heartbeat` | daemon → all | `{request_id, worker_id, ts, status: "running"\|"idle"}` (every 30s while alive) |
| `worker.exit` | daemon → all | `{request_id, worker_id, exit_code, ts}` |

`worker.output` envelopes may be **batched** to reduce bus chatter — a single envelope may contain `lines: [...]` instead of one line. Watchtower panels MUST handle both shapes.

### 4.3 Approval events (read side only in v1)

| Type | Direction | Payload | Status |
|---|---|---|---|
| `approval.requested` | daemon/worker → all | `{approval_id, request_id, worker_id, scope, action, rationale, ts}` | v1 |
| `approval.granted` | UI → daemon | `{approval_id, granted_by, ts, scope_override?}` | **v2** |
| `approval.denied` | UI → daemon | `{approval_id, denied_by, reason, ts}` | **v2** |

In v1, daemon emits `approval.requested` and waits forever (or until timeout). The Watchtower approval queue panel renders these requests but does not yet expose action buttons. v2 adds the write side.

### 4.4 Tier-0 events (read side only in v1)

| Type | Direction | Payload | Status |
|---|---|---|---|
| `tier0.requested` | daemon/worker → all | `{tier0_id, request_id, worker_id, command, fingerprint, rationale, ts}` | v1 |
| `tier0.approved` | UI → daemon | `{tier0_id, approved_by, ts}` | **v2** |
| `tier0.denied` | UI → daemon | `{tier0_id, denied_by, reason, ts}` | **v2** |

Same pattern as approval. v1 read-only; v2 adds the write side.

### 4.5 Session lifecycle events (informational)

| Type | Direction | Payload |
|---|---|---|
| `session.registered` | daemon → all | `{session_id, display_name, roles, tags, started_at, daemon_id}` |
| `session.heartbeat` | daemon → all | `{session_id, ts, active_workers}` (every 60s) |
| `session.deregistered` | daemon → all | `{session_id, ts, reason}` |

Note: these mirror termlink session lifecycle for sessions the daemon spawns. They are NOT a replacement for termlink session registration — termlink is the authoritative session registry. These events let Watchtower's session observer panel render daemon-spawned sessions without needing termlink as a dependency.

### 4.6 Envelope shape (reference)

Every event posted to `brain-external` is a YAML envelope with:

```yaml
result_id: R-XXX                    # auto-assigned by fw bus
channel: brain-external
type: delegation.request            # one of the types above
sender: <daemon_id | parent_id>     # who posted this
ts: 2026-04-11T20:30:00Z
payload:                            # type-specific shape (see tables above)
  request_id: 8f3a...
  task_id: T-XXX
  prompt: |
    ...
  working_dir: /root/project
  owner: agent
```

The `fw bus post` CLI already supports this shape. Daemon uses `fw bus post --channel brain-external --type <type> --payload @file.yaml`. Consumers use `fw bus manifest --channel brain-external` to list and `fw bus read --channel brain-external R-XXX` to fetch.

## 5. Daemon internals (sketch — implementation may revise)

### 5.1 Process model
- Single Python process per project (`brain-daemon.py`)
- systemd-managed unit (or standalone via `nohup` for dev)
- Polling loop on the bus (no push notifications in v1; framework gap noted as "could be remote-push events from termlink in v2")
- Worker spawning via `subprocess.Popen` with `stdin=PIPE, stdout=PIPE, stderr=PIPE`
- Output reader thread per worker, posting `worker.output` events to the bus

### 5.2 Persistence
- Worker state on disk in `.context/brain/workers/<worker_id>.yaml` (one file per active worker)
- Includes: `request_id`, PID, started_at, current status, last output line, parent process command
- On daemon restart: read `.context/brain/workers/`, reconcile against `ps` output, mark dead workers as `delegation.failed` with reason `daemon-restart-orphan`
- Live workers (PID still alive) get re-attached: daemon resumes reading their output

### 5.3 Supervision
- One thread for the bus poller
- One thread per worker for output reading
- Main thread runs the supervisor loop (reaps dead workers, posts heartbeats, handles signals)
- Worker death → `worker.exit` posted, then `delegation.result` if exit_code 0 or `delegation.failed` otherwise

### 5.4 Lifecycle
- `brain-daemon start` — spawns the daemon, writes pidfile to `.context/brain/daemon.pid`
- `brain-daemon stop` — sends SIGTERM, daemon flushes pending output, posts `session.deregistered` for all live workers (note: workers themselves keep running, the daemon just stops watching them — see "orphan recovery on restart")
- `brain-daemon restart` — stop + start, with orphan recovery
- `brain-daemon status` — reads pidfile, prints PID + uptime + worker count

### 5.5 Failure modes (v1 explicit handling)
- **Daemon crash** — workers continue. Next daemon start does orphan recovery from `.context/brain/workers/`.
- **Worker crash** — `worker.exit` with non-zero code → `delegation.failed`. State file cleaned up.
- **Bus unavailable** — daemon retries with exponential backoff (1s, 2s, 4s, ... cap 60s). Posts `daemon.degraded` events to local log when in retry loop.
- **Disk full on `.context/brain/`** — daemon cannot persist new worker state, refuses new delegation requests, posts `delegation.rejected` with reason `persistence-unavailable`.

## 6. Watchtower panels (built by dashboard-brain in T-011)

Brief reference — the authoritative spec for these panels lives in dashboard-brain's separate Watchtower-panel inception task (to be created). This section exists so the daemon's protocol surface and the panel surface stay aligned.

| Panel | Subscribes to event types | Renders |
|---|---|---|
| Approval queue | `approval.requested` | List of pending approvals; v2 adds grant/deny buttons |
| Delegation log | `delegation.{request,accepted,result,failed}` | Timeline of delegations with status |
| Session observer | `session.{registered,heartbeat,deregistered}`, `worker.{output,heartbeat,exit}` | Live view of daemon-spawned worker output |
| Tier-0 request panel | `tier0.requested` | List of pending tier-0 commands; v2 adds approve/deny buttons |

All panels are read-only in v1 — they consume the bus channel via `fw bus manifest` polling and render in real time. Write actions (v2) post UI-side envelopes back to the bus.

## 7. Open questions for v0.2

- **(open)** Q1 — runtime choice. Both authors propose Python; formal decision pending human Tier-2 ratification on each side. v0.2 will record the locked choice.
- **(open)** Q2 — daemon supervision strategy. Single Python process is the v1 sketch but may evolve to per-worker subprocess pools for isolation. Implementation will inform v0.2.
- **(open)** Q3 — persistence schema for `.context/brain/workers/<id>.yaml`. v0.1 leaves this implementation-defined; v0.2 freezes it for cross-daemon interop.
- **(open)** Q4 — bus polling interval. v0.1 leaves this configurable; v0.2 may freeze a default. Cost tradeoff: tight polling = more CPU; loose polling = higher delegation latency.
- **(open)** Q5 — multi-daemon-per-project (v2 question). Whether one daemon-per-project is sufficient or multiple specialized daemons (one for build, one for review, one for spec) are warranted. Defer to v2.

## 8. Cross-references

- **T-028** (proxmox-ring20-management) — daemon prototype implementation
- **T-011** (ring20-dashboard) — Watchtower panel implementation (separate Watchtower-panel inception to be created)
- **T-029** (proxmox-ring20-management) — coordination task that produced this spec
- **PL-011** (proxmox-ring20-management learnings) / **PL-003** (ring20-dashboard learnings) — assumption-provenance learning that informed the verification discipline applied while drafting
- **P-010 / P-011** (framework pickup inbox) — RCA and co-sign on assumption fabrication failure mode; R1-R6 remediations

## 9. Authors and verification

This v0.1 was drafted on 2026-04-11 during the T-029 cross-host termlink coordination session. Both author agents were live on TCP-bridged termlink hubs (CT 200 and CT 101). The full dialogue (7 turns + this spec drop) is persisted at `proxmox-ring20-management:.context/dialogues/T-029/01..07-*.md` and the corresponding ring20-dashboard side under T-011's dialogue directory.

The cryptographic verification of cross-agent claims — sha256 triple-match of the T-028 research artifact across termlink-pushed file, `f823fa8` git tree content, and `origin/master` content (`39ea5385d1a2d4848f79b0cefa253b95aa15c666c774063232f4fafe1191c490`) — is documented in dialogue turn 6 (`06-dashboard-brain-ack.md`) and is the evidentiary basis on which this spec's cross-author authority rests.

— ring20-manager (drafter) + dashboard-brain (co-author, building Watchtower side in parallel)
