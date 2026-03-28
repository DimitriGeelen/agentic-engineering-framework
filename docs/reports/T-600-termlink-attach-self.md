# T-600: TermLink Attach-Self — Research Artifact

## Problem Statement

**For whom:** Agents on remote machines that need to be reachable by local agents.
**Why now:** Currently TermLink sessions can connect outward but remote agents can't be connected to. Need a way to register an existing shell as a TermLink endpoint.

## Critical Finding: `termlink register --self` Already Exists

`termlink register --self` registers the current process as an **event-only endpoint** (no PTY). This means:
- A remote agent's shell can register itself: `termlink register --name remote-agent --self --tags "task:T-XXX"`
- It becomes discoverable via `termlink discover`
- It can receive events via `termlink event wait`
- It can emit events via `termlink event emit`

For full PTY access (bidirectional terminal I/O), use `--shell` instead of `--self`.

## What Already Works

| Capability | Command | Available |
|-----------|---------|-----------|
| Register current process | `termlink register --self --name X` | Yes |
| Register as PTY session | `termlink register --shell --name X` | Yes |
| Add tags/roles | `--tags "task:T-XXX" --roles "worker"` | Yes |
| Discovery by remote agents | `termlink discover --tag task:T-XXX` | Yes (same machine) |
| Cross-machine discovery | `termlink discover` via hub | Yes (with hub running) |
| Event communication | `termlink event emit/wait` | Yes |

## What's Missing

1. **Cross-machine hub deployment** — `termlink hub start --tcp ADDR` is available but never deployed in the framework. Required for remote agents to discover each other across machines.
2. **Framework wrapper** — No `fw termlink attach` command. Would need to add to `termlink.sh`.
3. **Auto-cleanup** — Self-registered sessions need deregistration on shell exit (trap handler).
4. **SSH session integration** — Registering an SSH session as a TermLink endpoint requires the remote machine to have TermLink installed.

## Analysis

### Minimal viable implementation
```bash
# On remote machine (in SSH session):
termlink register --self --name "remote-$(hostname)" --tags "task:T-XXX,role:worker"
# Now discoverable and can exchange events

# On local machine:
termlink discover --tag "task:T-XXX" --json
# Finds the remote agent
termlink event emit remote-hostname "task.assigned" -p '{"prompt":"do work"}'
```

### What this enables
- Bidirectional agent-to-agent signaling across machines
- Task coordination without SSH pipes (events replace `fw dispatch send`)
- Worker registration for supervisor event loop (T-571)

### What this doesn't enable (without hub)
- Cross-machine session discovery (hub required)
- Cross-machine file transfer (hub required)
- Cross-machine PTY attach (hub required)

## Assumption Testing

- A1: TermLink can register existing shells (VALIDATED — `--self` and `--shell` flags exist)
- A2: Cross-machine discovery works (NOT VALIDATED — requires hub deployment, untested)
- A3: Event communication works across registered sessions (VALIDATED — same-machine proven)
- A4: Auto-cleanup on exit is needed (VALID — orphaned registrations would pollute discovery)

## Recommendation: DEFER

**Rationale:**
1. The TermLink primitives (`--self`, `--shell`) already exist — no code needed in TermLink
2. But cross-machine usage requires hub deployment (T-598 deferred)
3. Same-machine attach-self has limited value (TermLink spawn already works locally)
4. Only 2 machines communicate (.112, .107) — full attach-self adds complexity without proportional value
5. T-598 (dispatch-TermLink bridge) is the prerequisite — if that's deferred, this is too

**Revisit when:**
- Hub is deployed for cross-machine coordination
- 3+ machines need agent-to-agent communication
- T-571 (supervisor event loop) is built and needs remote worker registration
