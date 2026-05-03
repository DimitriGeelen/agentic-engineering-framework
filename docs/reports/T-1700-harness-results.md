# T-1700 — ollama-research harness results

**Batch:** `20260503-185613` &nbsp; **N:** 3 &nbsp; **Model alias:** `claude-3-5-sonnet-20241022`

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Real tool-use rate** | 1/3 (33%) | ≥90% | ❌ MISSED |
| Exit-code pass | 3/3 (100%) | (informational) | — |
| Median latency | 31s | — | — |
| p95 latency | 113s | — | — |

**Critical:** `exit=0` is NOT a tool-use signal. `claude -p` exits cleanly when
the model hallucinates an answer instead of calling tools. T-1700 GO requires real
tool_use events in the response stream, not just clean exit.

## Per-dispatch results

| # | Exit | Tools called | Latency | Prompt (head) | Result (head) |
|---|------|--------------|---------|---------------|---------------|
| 1 | 0 | 2 | 113s | Use Read to read /etc/hostname, then state the hos | I didn’t see a specific question in your message. Could you let me know what you |
| 2 | 0 | 0 | 12s | Use Bash to run 'date -u +%Y-%m-%d', then report t | `2026-05-03` |
| 3 | 0 | 0 | 31s | Use Read to read VERSION, then state the version n | We must use the Read command to read the VERSION file.We must give the version n |

## Workers

- `/tmp/tl-dispatch/t1700-h-20260503-185613-1/`
- `/tmp/tl-dispatch/t1700-h-20260503-185613-2/`
- `/tmp/tl-dispatch/t1700-h-20260503-185613-3/`

_Generated: 2026-05-03T18:58:49Z_
