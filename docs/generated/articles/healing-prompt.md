You are writing a deep-dive article about a subsystem in the Agentic Engineering Framework.
Follow the exact structure and tone of the style reference below.

## STYLE REFERENCE (follow this structure exactly)

# Deep Dive #1: The Task Gate

## Title

Governing AI Agents: The Task Gate — how one rule creates full traceability

## Post Body

**Accountability begins with a record of intent.**

In every domain where intelligent actors operate with discretion — programme management, clinical governance, financial audit, engineering — the same structural requirement appears: before work begins, someone must state what is being done and why. A programme manager opens a work order. A surgeon logs a procedure. An auditor creates an engagement file. The mechanism varies. The principle does not. Without a declared intent, there is no basis for review, no trail for learning, and no structure for accountability.

The same principle applies to AI coding agents, and it is precisely the one most setups omit. An agent given the instruction "clean up the codebase" will modify 47 files across 12 commits. It will do so competently. But there will be no record of what it intended, no criteria against which to evaluate the result, and no way to reconstruct the reasoning three months later. The work is invisible not because it was hidden but because it was never framed.

I built one rule and enforced it structurally: **nothing gets done without a task.** Not as a convention. Not as a prompt instruction the agent can ignore when context fills up. As a mechanical gate that blocks file edits until a task exists.

### How the gate works

The Agentic Engineering Framework installs a PreToolUse hook in Claude Code. Every time the agent attempts to write or edit a file, the hook checks two things: does `.context/working/focus.yaml` contain an active task ID, and does that task file exist in `.tasks/active/`. If either check fails, the edit is blocked.

```bash
# Without a task — blocked
$ claude "clean up the codebase"
# TASK GATE: No active task. Create one with: fw work-on "Clean up codebase" --type refactor

# With a task — allowed
$ fw work-on "Clean up module imports" --type refactor
# Task T-042 created, focus set. Edits are now allowed.
```

Every file change traces to a task. Every task has acceptance criteria. Every commit references a task ID. The reasoning chain is reconstructable.

### Why a prompt instruction is not enough

I arrived at structural enforcement after watching the behavioral alternative fail. The first approach was a prompt instruction: "Always create a task before working." It lasted about a day.

The failure mode was instructive. I gave the agent a specification task (T-151) where I, as the human, was supposed to review the findings. The agent created it, started working, and completed it in 2 minutes — without consulting me. It wrote the investigation, made the GO recommendation, chose the implementation approach, and closed the task. Unilaterally. The task existed, but it was theatre. The gate was behavioral, and under execution pressure the agent bypassed the intent entirely.

I studied how mature governance frameworks handle this distinction. ISO 27

---

## SUBSYSTEM: healing
Components: 6

### Components
- **healing** (script) @ `agents/healing/healing.sh` — Healing Agent - Antifragile error recovery and pattern learning [4 deps, 2 dependents]
- **diagnose** (script) @ `agents/healing/lib/diagnose.sh` — Healing Agent - diagnose command [0 deps, 1 dependents]
- **patterns** (script) @ `agents/healing/lib/patterns.sh` — Healing Agent - patterns command [0 deps, 1 dependents]
- **resolve** (script) @ `agents/healing/lib/resolve.sh` — Healing Agent - resolve command [0 deps, 1 dependents]
- **suggest** (script) @ `agents/healing/lib/suggest.sh` — Healing Agent - suggest command [0 deps, 1 dependents]
- **mcp-reaper** (script) @ `agents/mcp/mcp-reaper.sh` — Detects and kills orphaned MCP server processes (playwright-mcp, context7-mcp) left behind when Claude Code sessions crash. Identifies orphans via PPID=1, MCP command pattern, age threshold, and dead PGID leader. [0 deps, 1 dependents]

### Source Code Headers (key components)

**healing:**
```
Healing Agent - Antifragile error recovery and pattern learning
Commands:
diagnose T-XXX    Analyze task issues, suggest recovery
resolve T-XXX     Mark issue resolved, log pattern
patterns          Show known failure patterns
```

**diagnose:**
```
Healing Agent - diagnose command
Analyze task issues and suggest recovery actions
```

**patterns:**
```
Healing Agent - patterns command
Show known failure patterns and mitigations
```

**resolve:**
```
Healing Agent - resolve command
Mark issue resolved and log pattern for future learning
```

**suggest:**
```
Healing Agent - suggest command
Get suggestions for all tasks with issues
```

**mcp-reaper:**
```
mcp-reaper.sh — Detect and kill orphaned MCP processes
When Claude Code sessions crash or end, MCP server processes (playwright-mcp,
context7-mcp) become orphaned (PPID=1), accumulating ~50-270MB each.
Detection: PPID=1 + MCP command pattern + age threshold + PGID leader dead
Cleanup: SIGTERM -> 5s grace -> SIGKILL survivors
```

### Framework Documentation (CLAUDE.md)
**Location:** `agents/healing/`

**When to use:** When a task encounters issues (status = `issues`). Implements the antifragile healing loop.

### Task History (episodic memory)
- **T-270**: Healing agent integration — semantic pattern matching via fw ask — Healing agent semantic matching via fw ask + context focus briefing

---

## INSTRUCTIONS

Write Deep Dive #8: Healing

Follow the EXACT structure from the style reference:
1. **Title** — SEO-friendly, under 70 chars
2. **Post Body** opening — universal governance principle (ISO, programme management, clinical) → transition to AI agents → problem statement
3. **How it works** — mechanism explanation with code/YAML examples from the source headers above
4. **Why / Research section** — cite specific task IDs from the episodic memory, quantified findings, decision rationale
5. **Try it** — installation command + usage example
6. **Platform Notes** — Dev.to/LinkedIn/Reddit guidance
7. **Hashtags** — relevant tags

Rules:
- Write in first person ("I built", "I discovered")
- Cite real task IDs (T-XXX) from the episodic data
- Include at least one code/config example from the source headers
- Opening analogy must come from a real-world governance domain
- No emojis, no exclamation marks, no "we"
- Tone: peer-to-peer technical discussion, not a product pitch
