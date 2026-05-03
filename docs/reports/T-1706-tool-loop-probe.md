# T-1706 — Spike A probe (thin tool-loop worker)

**Batch:** `20260503-215307` &nbsp; **N:** 3 &nbsp; **Worker:** `tools/ollama-tool-loop.py`
**Model alias:** `claude-3-5-sonnet-hermes3` → `ollama_chat/hermes3:8b`
**Prompts:** simple-read (hostname / VERSION / os-release), identical to T-1704.

## Bottom line

**Spike A GO:** 100% real tool_use ≥ 90% threshold ✅

Real tool-use rate: **3/3 (100%)**, median latency 1s.

## Comparison with prior probes

| Probe | Path | Model | Real tool_use |
|-------|------|-------|---------------|
| T-1700 | claude -p (wide) | qwen3:14b | 0/10 (0%) |
| T-1700 | claude -p (wide) | gpt-oss:20b | 1/3 (33%) |
| T-1703 | claude -p × 3 catalogues | gemma4:8b | 0/9 (0%) |
| T-1703 | claude -p × 3 catalogues | qwen3.5:9.7b | 0/9 (0%) |
| T-1704 | claude -p × 3 catalogues | hermes3:8b | 0/9 (0%) |
| **T-1706** | **thin tool-loop** | **hermes3:8b** | **3/3 (100%)** |

## Per-dispatch detail

| # | Exit | tool_use | Latency |
|---|------|----------|---------|
| 1 | exit=0 | tool_use=2 | 4s |
| 2 | exit=0 | tool_use=1 | 1s |
| 3 | exit=0 | tool_use=1 | 1s |

## Sample outputs

| Prompt # | tool_use | Result (truncated 180c) |
|----------|----------|--------------------------|
| 1 | 2 | The hostname of this system is dimitrimintdev.  |
| 2 | 1 | The current version number is 1.6.260.  |
| 3 | 1 | The OS family identified from the /etc/os-release file is Linux Mint, which is based on Ubuntu.  |

## Spike A go/no-go evaluation

From T-1705 §Go/No-Go Criteria:

- ≥90% real tool_use on simple-read prompts: **100% — PASS**
- Worker writes wdir contract (result.jsonl/result.md/exit_code/meta.json): **PASS** (verified by this probe)
- Latency ≤2× T-1704 hermes3 figures (7-21s): **1s median — PASS**

Decision: **GO**

_Generated: 2026-05-03T21:53:13Z_
