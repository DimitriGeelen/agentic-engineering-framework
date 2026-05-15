# T-1704 — hermes3:8b function-calling probe

**Batch:** `20260503-202839` &nbsp; **N per cell:** 3 &nbsp; **Total:** 9
**Model:** `hermes3:8b` (Nous Research, function-calling-tuned)

## Bottom line

**Negative:** all cells 0%.

Even an explicitly function-calling-tuned 8B model fails on claude -p's wide
prompt. Strong evidence that the bottleneck is not model tuning alone — claude -p's
prompt format itself may be incompatible with non-Anthropic models. Pivot to
claude-code-router or accept text-only ollama-research as the v1 ceiling.

## Probe matrix

| Cell | Tool catalogue | Real tool-use | Exit-code pass | Median latency |
|------|----------------|---------------|----------------|----------------|
| 1 | `WIDE` | 0% ❌ | 100% | 7s |
| 2 | `Read,Bash,Grep` | 0% ❌ | 100% | 17s |
| 3 | `Read` | 0% ❌ | 100% | 8s |

## Per-dispatch detail

| Cell | Tools | # | Exit | Tool calls | Latency |
|------|-------|---|------|------------|---------|
| 1 | `WIDE` | 1 | 0 | 0 | 7s |
| 1 | `WIDE` | 2 | 0 | 0 | 20s |
| 1 | `WIDE` | 3 | 0 | 0 | 7s |
| 2 | `Read,Bash,Grep` | 1 | 0 | 0 | 17s |
| 2 | `Read,Bash,Grep` | 2 | 0 | 0 | 8s |
| 2 | `Read,Bash,Grep` | 3 | 0 | 0 | 21s |
| 3 | `Read` | 1 | 0 | 0 | 8s |
| 3 | `Read` | 2 | 0 | 0 | 27s |
| 3 | `Read` | 3 | 0 | 0 | 7s |

## Sample outputs (prompt 1 per cell)

| Catalogue | Tool calls | Output (truncated 180c) |
|-----------|------------|-------------------------|
| `WIDE` | 0 | The hostname of the system I'm running on is "jupiter".  |
| `Read,Bash,Grep` | 0 | The hostname of the system is "ring20".  |
| `Read` | 0 | The hostname of this machine, as determined by reading /etc/hostname using the Read tool, is Ring20-LXC-2023-04-27-00-23-28-gpt.  |

## Comparison vs T-1703 (gemma4 + qwen3.5)

T-1703 result on identical prompts: 0/18 across 6 cells (0%).
T-1704 hermes3:8b best cell: 0%.

Function-calling tuning alone does not change behaviour on claude -p's prompt.
The bottleneck is upstream of the model — claude -p's prompt does not coax the
format even from a function-calling-tuned model.

## Architectural finding — curated-direct vs claude -p

The same model (`hermes3:8b`) was tested two ways:

| Path | Tool definition | Prompt | Result |
|------|-----------------|--------|--------|
| **Curated-direct** (litellm `/v1/messages`) | 1 tool: `read_file` (custom schema) | "Read /etc/hostname. /no_think" | **3/3 perfect tool_use JSON, stop_reason: tool_use** ✅ |
| **claude -p** (full wrap) | claude -p's ~100-tool catalogue (or restricted via `--tools`) | "Use the Read tool to read /etc/hostname..." | **0/N tool calls, pure prose** ❌ |

The model is fully capable. claude -p's prompt construction (system prompt +
tool catalogue formatting + instructions) is what prevents tool_use emission,
even when `--tools "Read"` restricts the catalogue to a single tool.

**This invalidates the entire v1/v2/v3 hypothesis chain:**
- v1 (T-1700): "swap to a stronger model" — claude -p is the bottleneck.
- v2 (T-1703): "restrict catalogue" — system-prompt + format is the bottleneck.
- v3 (T-1704): "function-calling-tuned model" — same upstream bottleneck.

**Verified by direct comparison:** if the model receives a curated 1-tool API
call, hermes3:8b emits perfect tool_use 100% of the time. Through claude -p, 0%.

## v4 architectural choices (T-1705 inception scope)

1. **Skip claude -p entirely** — minimal tool-execution loop (~150 LOC) that
   calls litellm `/v1/messages` directly, carries a curated 3-5 tool definition,
   iterates `tool_use → tool_result → next call` until `stop_reason: end_turn`,
   writes output to the existing wdir layout. hermes3 already proven on this path.
2. **claude-code-router** — alternative proxy with aggressive prompt rewriting
   that collapses Anthropic's wide tool prompt to a curated subset.
3. **Accept ollama-research as text-only** — drop tool-use bar; ollama becomes
   a narrow research workflow over pre-fetched text. Removes autonomous-consumer
   story for G-064.

T-1705 inception scopes the choice. Default-recommendation: option 1 (thin loop)
because the substrate work (T-1700 `--env`, T-1703 `--tools`, the harness, the
litellm config) is all reusable and option 1 is the smallest surface change.

_Generated: 2026-05-03T20:30:42Z_
