# Mandatory Dispatch Preamble

> Include this text block at the TOP of every sub-agent dispatch prompt.
> This is not optional. Omitting it causes context explosion (T-073: 177K spike).

## The Preamble (copy this into every dispatch prompt)

```
## OUTPUT RULES — MANDATORY, NON-NEGOTIABLE

You are a sub-agent with a STRICT output budget. The orchestrator that spawned
you has limited context. Violating these rules will crash the session.

1. **Write all detailed output to disk** using the Write tool
   - Output file: /tmp/fw-agent-{describe-your-task-briefly}.md
   - Write BEFORE composing your final response

2. **Your final response MUST be ≤ 5 lines:**
   - Line 1: DONE or FAIL
   - Line 2: Output file path
   - Line 3: One-sentence summary of findings
   - Line 4-5: (optional) Critical numbers only (e.g., "Pass: 80 | Fail: 3")

3. **NEVER return in your response:**
   - File contents (even partial)
   - Code blocks longer than 3 lines
   - YAML/JSON data
   - Lists longer than 5 items
   - Full error traces

4. The orchestrator will read your output file if it needs details.

EXAMPLE GOOD RESPONSE:
  DONE
  /tmp/fw-agent-ac-audit.md
  Audited 212 tasks: 126 REAL (59%), 86 problematic (41%)
  Before P-010: 20% REAL | After P-010: 94.5% REAL

EXAMPLE BAD RESPONSE:
  Here are the detailed findings for each task:
  T-001: REAL - has 3 checked ACs...
  T-002: MISSING - no AC section...
  [200 more lines]
```

## Fabric Awareness (T-247)

When your task involves **modifying source files**, follow these rules:

1. **Before editing a registered component**, check its dependents:
   - Run: `fw fabric deps <file-path>` to see what depends on it
   - If it has >5 dependents, mention this in your summary so the orchestrator can run blast-radius

2. **When creating new files**, note them in your summary:
   - The post-commit hook will detect unregistered files and suggest registration
   - Include the file paths in your output so the orchestrator can track them

3. **Do NOT run** `fw fabric register` or `fw fabric blast-radius` yourself — the orchestrator handles these via hooks. Just report what you modified/created.

## Why This Exists

- T-073: 9 agents returned full YAML → 177K token spike → session crash
- Multiple sessions lost to context explosion from agent result ingestion
- The `fw bus` system was built for this but goes unused without this preamble

## Orchestrator-Side Rules

After dispatching agents:
1. Use `run_in_background: true` for any agent expected to produce >500 tokens
2. Read only the final summary from the agent (last 5 lines of output)
3. If you need details, read the output file the agent wrote — don't ask the agent
4. NEVER use `TaskOutput` with `block: true` for background agents (returns full JSONL transcript)
5. Use `Bash: tail -5 /tmp/claude-*/tasks/{agent-id}.output` to get just the summary
