# T-598: Bridge fw dispatch to TermLink — Research Artifact

## Problem Statement

**For whom:** Framework users dispatching work across machines (dev ↔ server, orchestrator ↔ workers).
**Why now:** `fw dispatch send` uses raw SSH pipes with inline JSON envelopes. TermLink already has `file send`, `remote send-file`, `hub` routing, and `remote exec` — but these are completely disconnected from the framework dispatch layer. Two parallel communication systems exist for the same purpose.

## Current Architecture

### fw dispatch (SSH-based)
1. `fw dispatch send --host X --task T-XXX --agent TYPE --summary "..."`
2. Builds JSON envelope (task_id, agent_type, timestamp, source_host, summary, payload)
3. Pipes via `echo "$envelope" | ssh "$host" "fw bus receive"`
4. Remote side parses JSON → writes YAML to `.context/bus/results/T-XXX/R-NNN.yaml`
5. Size-gated at 2048 bytes — larger payloads go to blobs

**Limitations:** Text-only transport, no chunking, no binary support, no async signaling, no discovery.

### TermLink capabilities (unused by framework)
| Command | Purpose | Status |
|---------|---------|--------|
| `termlink file send <target> <path>` | Chunked file transfer between sessions | Available, not wired |
| `termlink remote send-file <hub> <session> <path>` | Cross-machine file transfer via hub | Available, not wired |
| `termlink remote exec <hub> <session> <cmd>` | Remote command execution via hub | Available, not wired |
| `termlink hub start [--tcp ADDR]` | Cross-session/machine routing server | Available, never deployed |

## Spike 1: What Would Bridging Require?

### Option A: TermLink file send for dispatch payloads
Replace SSH pipe with `termlink file send` between registered sessions.

**Steps:** Serialize bus envelope to temp file → `termlink file send $TARGET $FILE` → receiver deserializes.

**Pros:** Chunked transfer, handles large payloads. Uses existing TermLink session registry.
**Cons:** Requires both sides to have registered TermLink sessions. Doesn't work cross-machine without hub.

### Option B: Deploy hub + wire remote commands
Start a `termlink hub` as infrastructure. Replace `fw dispatch send` with `termlink remote send-file` + `termlink remote exec`.

**Steps:** Deploy hub on known host → remote machines register sessions → `fw dispatch` routes through hub instead of SSH.

**Pros:** Native cross-machine routing. Discovery via `termlink discover`. Async event signaling.
**Cons:** Requires hub infrastructure (new process to manage, new failure mode). Requires T-600 (attach-self) for remote session registration.

### Option C: Hybrid — keep SSH for fallback
Keep SSH dispatch for machines without TermLink. Use TermLink dispatch for machines with sessions registered.

**Steps:** `fw dispatch send` checks if target has a TermLink session → uses file send if yes, SSH pipe if no.

**Pros:** Incremental migration, no breaking changes.
**Cons:** Two code paths to maintain indefinitely.

## Spike 2: Infrastructure Reality

- **Hub:** Never deployed. No `.context/.hub/` directory, no running process, no cron lifecycle management.
- **Remote sessions:** T-600 (attach-self) proposed registering existing shells as TermLink endpoints. Still at inception stage (captured, not started).
- **Cross-machine testing:** TermLink hub has been tested in TermLink's own test suite (264 tests) but never deployed in the framework.
- **Current usage:** All dispatch uses SSH pipes. TermLink is only used for local terminal sessions.

## Spike 3: Is This the Right Abstraction?

The deeper question: should `fw dispatch` exist at all, or should it be replaced entirely by TermLink?

**Arguments for replacement:**
- TermLink already solves transport, discovery, signaling, file transfer
- Maintaining two parallel systems violates DRY
- Hub provides natural coordination point for multi-agent workflows

**Arguments against replacement:**
- SSH dispatch works today with zero infrastructure
- Hub adds a new SPOF and lifecycle management burden
- Cross-machine TermLink is untested in production
- Only 2 machines currently communicate (.112 server, .107 Mac)

## Assumption Testing

- **A1:** TermLink file/remote commands work reliably. **NOT VALIDATED** — never used in the framework. TermLink test suite passes but no production evidence.
- **A2:** Hub deployment is feasible. **NOT VALIDATED** — never attempted. Requires process management, crash recovery, port management.
- **A3:** Bridge provides value over SSH dispatch. **PARTIALLY VALIDATED** — TermLink transport is superior (chunked, async, discoverable), but SSH dispatch works adequately for 2-machine topology.
- **A4:** Both sides need to speak TermLink. **VALIDATED** — TermLink must be installed on both machines. Currently only on .112.

## Recommendation: DEFER

**Rationale:**
1. SSH dispatch works for current 2-machine topology (no incidents, adequate throughput)
2. Hub infrastructure doesn't exist and adds operational complexity (new process, new SPOF)
3. T-600 (attach-self) is prerequisite but still at inception stage
4. Only 2 machines communicate — the overhead of hub deployment exceeds the benefit
5. No evidence of dispatch failure or limitation driving this need

**Revisit when:**
- 3+ machines need to communicate regularly
- SSH dispatch hits a concrete limitation (payload size, latency, reliability)
- T-600 (attach-self) is complete and TermLink is deployed on remote machines
- Hub deployment is routine (containerized, health-checked)

**If GO later:** Start with Option C (hybrid) — keep SSH fallback, add TermLink transport for registered sessions. Deploy hub only when >2 machines justify it.
