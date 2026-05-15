# T-1703 — gemma4 + qwen3.5 curated-catalogue probe

**Batch:** `20260503-194022` &nbsp; **N per cell:** 3 &nbsp; **Total dispatches:** 18
**Task class:** simple-read (Read tool sufficient for all prompts)

## Bottom line

**Pivot:** No cell hit 90%. Best: 0%. Pivot path: claude-code-router OR pull tool-use-tuned model (hermes-3:8b, xlam:7b) OR system-prompt forcing.

The cheapest paths (already-loaded models × catalogue restriction) do not clear the
90% bar on simple-read. Open-weight 8-9B generalist models hallucinate text answers
even when the tool catalogue is restricted to a single tool — describe-instead-of-call
is a model-tuning issue, not a catalogue-size issue.

## Probe matrix

| Cell | Model | Tool catalogue | Real tool-use | Exit-code pass | Median latency |
|------|-------|----------------|---------------|----------------|----------------|
| 1 | gemma4 | `WIDE` | 0% ❌ | 100% | 22s |
| 2 | gemma4 | `Read,Bash,Grep` | 0% ❌ | 100% | 17s |
| 3 | gemma4 | `Read` | 0% ❌ | 100% | 24s |
| 4 | qwen3.5 | `WIDE` | 0% ❌ | 100% | 22s |
| 5 | qwen3.5 | `Read,Bash,Grep` | 0% ❌ | 100% | 14s |
| 6 | qwen3.5 | `Read` | 0% ❌ | 100% | 23s |

## Per-dispatch detail

| Cell | Model | Tools | # | Exit | Tool calls | Latency |
|------|-------|-------|---|------|------------|---------|
| 1 | gemma4 | `WIDE` | 1 | 0 | 0 | 22s |
| 1 | gemma4 | `WIDE` | 2 | 0 | 0 | 21s |
| 1 | gemma4 | `WIDE` | 3 | 0 | 0 | 22s |
| 2 | gemma4 | `Read,Bash,Grep` | 1 | 0 | 0 | 17s |
| 2 | gemma4 | `Read,Bash,Grep` | 2 | 0 | 0 | 17s |
| 2 | gemma4 | `Read,Bash,Grep` | 3 | 0 | 0 | 17s |
| 3 | gemma4 | `Read` | 1 | 0 | 0 | 23s |
| 3 | gemma4 | `Read` | 2 | 0 | 0 | 24s |
| 3 | gemma4 | `Read` | 3 | 0 | 0 | 31s |
| 4 | qwen3.5 | `WIDE` | 1 | 0 | 0 | 22s |
| 4 | qwen3.5 | `WIDE` | 2 | 0 | 0 | 19s |
| 4 | qwen3.5 | `WIDE` | 3 | 0 | 0 | 41s |
| 5 | qwen3.5 | `Read,Bash,Grep` | 1 | 0 | 0 | 14s |
| 5 | qwen3.5 | `Read,Bash,Grep` | 2 | 0 | 0 | 35s |
| 5 | qwen3.5 | `Read,Bash,Grep` | 3 | 0 | 0 | 14s |
| 6 | qwen3.5 | `Read` | 1 | 0 | 0 | 23s |
| 6 | qwen3.5 | `Read` | 2 | 0 | 0 | 29s |
| 6 | qwen3.5 | `Read` | 3 | 0 | 0 | 13s |

## Failure-mode RCA — what the models actually emit

Spot-check of `result.md` across cells reveals the failure is structural, not catalogue-related:

| Model | Catalogue | Sample output (prompt: "Use Read to read /etc/hostname...") |
|-------|-----------|-----|
| gemma4:8b | WIDE | "The hostname is not accessible with the provided tools." (refuses — knows tools exist, doesn't call) |
| gemma4:8b | Read-only | "The hostname is `localhost`." (hallucinates — invents an answer) |
| qwen3.5:9.7b | WIDE | ` ```bash / cat /etc/hostname / ``` ` (emits bash code inside a markdown fence) |
| qwen3.5:9.7b | Read-only | ` ```bash / hostname=$(cat /etc/hostname...) / ``` ` (same — code-block answer) |

**Root cause:** these generalist 8-10B models are trained to "answer" by emitting prose
or code-blocks. They are not function-calling-tuned. claude -p / Anthropic protocol
requires the model to emit a structured `tool_use` content block in JSON; gemma4 and
qwen3.5:9.7b simply don't produce that format regardless of prompt or catalogue size.

**Disproven v2 path:** restricted `allowed_tools` (path c from T-1700 recommendation).
Catalogue size is irrelevant when the model never emits the function-call format at all.

**Remaining viable v2 paths (in order of cheapness):**
1. **Pull a function-calling-tuned model** — `hermes-3:8b`, `xlam:7b`,
   `qwen2.5-coder:14b-instruct` (coder-instruct variants follow tool-call format more
   rigidly than base instruct).
2. **claude-code-router** — different proxy that may rewrite prompts to coax tool calls.
3. ~~Larger model already loaded — `qwen2.5-coder-32b:IQ2_M`~~ — **disproven** in bonus
   run after the matrix completed. N=3 with `--tools "Read,Bash,Grep"` produced 3/3
   timeouts at 180s (per-worker timeout) — IQ2 quant + 32B params on 16GB is unusably
   slow on this ollama backend. Kept loaded for future heavy use; not a v1/v2 candidate.
4. Accept ollama-research as text-only narrow workflow (no tool use) and document.

## Bonus: qwen2.5-coder-32b:IQ2_M timeout result

Re-ran the harness with `claude-sonnet-coder` alias (mapped to `qwen2.5-coder-32b:IQ2_M`)
and narrow catalogue:

| Metric | Value |
|--------|-------|
| Real tool-use rate | 0/3 (0%) |
| Exit-code pass | 0/3 (all timeouts) |
| Median latency | 181s (= per-worker timeout) |

The model never returned a response within 180s on any of the 3 simple-read prompts.
Killed by latency, not function-calling capability — IQ2 quant is too aggressive for
fast inference on this hardware.

## Method

- Simple-read prompts only — Read tool sufficient for every prompt, so a Read-only
  catalogue is not unfairly penalised.
- Real tool-use metric: `exit=0 AND tool_use events ≥ 1` (parsed from `result.jsonl`
  assistant content blocks). Per L-346, `exit=0` alone is not a tool-use signal.
- Sequential dispatch (ollama serializes anyway). Per-worker timeout 120s.
- Litellm proxy translates `claude-3-5-sonnet-{gemma4,qwen35}` → `ollama_chat/{gemma4:latest,qwen3.5:latest}`.

_Generated: 2026-05-03T19:47:08Z_
