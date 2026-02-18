# T-158 Crash Investigation: Sub-Agent Dispatch Context Explosion

**Date:** 2026-02-18
**Related:** L-053, G-008, T-158

## Symptom
Session appeared to crash/hang for ~12 minutes 40 seconds after dispatching 4 background Explore agents for T-158 testing strategy analysis.

## Timeline
- **12:52:34** — Launched 4 background Task agents (bash audit, web audit, hooks audit, bug history)
- **12:52:54** — Called TaskOutput() on all 4 to wait for results
- **12:53:28–12:54:19** — All 4 results returned, each **30,156 chars** (max truncation limit)
- **120K+ characters** of raw JSONL transcript hit the context window simultaneously
- **12:54:19–13:06:59** — 12 minute 40 second gap. Model produced `stop_reason: stop_sequence` with `output_tokens: 0`
- **13:07:21** — User reported crash

## Root Cause
Three protocol violations stacked:

### 1. Prompts said "return" instead of "write to file"
Each prompt ended with "Return a structured summary. Keep under 2K tokens." but the Sub-Agent Dispatch Protocol (CLAUDE.md line 464-467) requires investigators to write to disk, not return content.

### 2. TaskOutput returns raw JSONL, not agent summaries
`run_in_background: true` + `TaskOutput` doesn't give the agent's final answer — it returns the full execution transcript including all tool calls, hook progress messages, and intermediate results. Even if agents kept their final messages under 2K tokens, TaskOutput returned ~30K chars of raw transcript per agent.

### 3. No structural enforcement of the protocol
CLAUDE.md defines clear rules for sub-agent dispatch but nothing prevents violation. No hook checks prompt content, no gate limits TaskOutput size.

## Exact Prompts Sent (evidence)
All 4 prompts followed the same anti-pattern:
```
"Very thorough exploration of /opt/999-Agentic-Engineering-Framework...
[detailed instructions]...
Return a structured summary. Keep it under 2K tokens."
```
None included:
- "Write results to /path/to/file"
- "Use fw bus post"
- "Do NOT return full content"

## Correct Pattern
```
"Write your findings to /tmp/T-158-bash-audit.md using the Write tool.
Return ONLY a one-line summary like 'Wrote /tmp/T-158-bash-audit.md — X scripts found'."
```

## Resolution
- **L-053** registered: Always include write-to-file output instructions in sub-agent prompts
- **G-008** registered: Sub-agent dispatch protocol has no structural enforcement (watching)
- Re-ran analysis with correct pattern — 3 agents, all wrote to files, orchestrator read files. Worked perfectly.

## Prior Art
- T-073: 9 agents returning full YAML spiked context by 30K+ tokens (first instance)
- This was the **second instance** despite the protocol being documented after T-073
- Conclusion: discipline alone is insufficient for this pattern — structural enforcement needed
