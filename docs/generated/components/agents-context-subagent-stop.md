# subagent-stop

> SubagentStop hook — captures sub-agent returns. Reads sub-agent transcript from payload.transcript_path, appends telemetry line to .context/working/subagent-returns.jsonl, and if bytes > THRESHOLD posts the full message to fw bus as a blob so later turns can read via R-NNN without re-ingesting. Exits 0 always (capture-and-log, not interceptor).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/subagent-stop.sh`

**Tags:** `hook`, `subagent-stop`, `bus`, `telemetry`, `T-1213`, `T-1209`

## What It Does

SubagentStop hook — capture sub-agent returns, auto-migrate to fw bus (T-1213)
Fires when a Task-tool sub-agent finishes. Reads the sub-agent transcript from
disk (payload.transcript_path), measures the last assistant message in bytes,
and:
1. ALWAYS appends a telemetry JSON line to .context/working/subagent-returns.jsonl
for size-distribution analysis (S2 data stream from T-1209).
2. If bytes > THRESHOLD, posts the full message to `fw bus` as a blob so
subsequent turns can read it via R-NNN without re-ingesting the raw blob.
SubagentStop cannot mutate the orchestrator-visible response (Claude Code docs:
hooks cannot modify subagent behavior; exit 2 only forces re-execution). So this

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |
| `.context/working/subagent-returns.jsonl` | writes |
| `.context/bus/blobs/` | writes |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/context/tests/subagent-stop-stub-test.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-subagent-stop.yaml`*
*Last verified: 2026-04-24*
