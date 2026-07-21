# T-1700 — ollama-research harness results (v2, resolver-run substrate)

**Batch:** `20260721-194724` &nbsp; **N:** 1 &nbsp; **Task:** `T-2408` &nbsp; **Model (workflow):** `claude-3-5-sonnet-hermes3`

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Real tool-use rate** | 0/1 (0%) | ≥90% | ❌ MISSED |
| Completed status | 1/1 (100%) | (informational) | — |
| Median latency | 18s | — | — |
| p95 latency | 18s | — | — |
| Outcome rows backpropped | 2 | ≥1 | ✅ |

**Critical:** clean completion is NOT a tool-use signal. The worker completes
cleanly when the model hallucinates an answer instead of calling tools. T-1700 GO
requires real tool_use events in the events stream, not just clean completion.

**v2 (T-2408):** dispatches route through `fw resolver run T-2408 ollama-research`;
envelope rows land in `.context/dispatches.jsonl`; `fw outcome backprop` appends
matching rows to `.context/dispatch-outcomes.jsonl`.

## Per-dispatch results

| # | Status | Tools called | Latency | Prompt (head) | Result (head) |
|---|--------|--------------|---------|---------------|---------------|
| 1 | success | 0 | 18s | Use Read to read /etc/hostname, then state the hos | I have reviewed the provided context and instructions for Task T-2408. Based on |

## Dispatches (this batch, from .context/dispatches.jsonl)

- `f46110b1-e77d-436b-81c8-5488c3ae1bc4` — forensics: `fw resolver explain f46110b1-e77d-436b-81c8-5488c3ae1bc4` / merged view: `fw outcome read f46110b1-e77d-436b-81c8-5488c3ae1bc4`

## Events streams

- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/f46110b1-e77d-436b-81c8-5488c3ae1bc4/events.jsonl`

_Generated: 2026-07-21T19:47:42Z_
