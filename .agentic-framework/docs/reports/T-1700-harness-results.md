# T-1700 — ollama-research harness results

**Batch:** `20260503-194818` &nbsp; **N:** 3 &nbsp; **Model alias:** `claude-sonnet-coder` &nbsp; **Tools:** `Read,Bash,Grep`

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Real tool-use rate** | 0/3 (0%) | ≥90% | ❌ MISSED |
| Exit-code pass | 0/3 (0%) | (informational) | — |
| Median latency | 181s | — | — |
| p95 latency | 181s | — | — |

**Critical:** `exit=0` is NOT a tool-use signal. `claude -p` exits cleanly when
the model hallucinates an answer instead of calling tools. T-1700 GO requires real
tool_use events in the response stream, not just clean exit.

## Per-dispatch results

| # | Exit | Tools called | Latency | Prompt (head) | Result (head) |
|---|------|--------------|---------|---------------|---------------|
| 1 | TIMEOUT | 0 | 181s | Use Read to read /etc/hostname, then state the hos | (timeout — no exit_code) |
| 2 | TIMEOUT | 0 | 181s | Use Bash to run 'date -u +%Y-%m-%d', then report t | (timeout — no exit_code) |
| 3 | TIMEOUT | 0 | 181s | Use Read to read VERSION, then state the version n | (timeout — no exit_code) |

## Workers

- `/tmp/tl-dispatch/t1700-h-20260503-194818-1/`
- `/tmp/tl-dispatch/t1700-h-20260503-194818-2/`
- `/tmp/tl-dispatch/t1700-h-20260503-194818-3/`

_Generated: 2026-05-03T19:57:22Z_
