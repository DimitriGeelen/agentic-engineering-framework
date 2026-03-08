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

## SUBSYSTEM: budget-management
Components: 4

### Components
- **budget-gate-counter** (data) @ `.context/working/.budget-gate-counter` — Text integer tracking tool invocation count between budget rechecks. Read by budget-gate to decide when to re-read the transcript. [0 deps, 1 dependents]
- **budget-gate** (hook) @ `agents/context/budget-gate.sh` — Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. [2 deps, 1 dependents]
- **budget-status** (data) @ `.context/working/.budget-status` — Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call. [0 deps, 3 dependents]
- **checkpoint** (hook) @ `agents/context/checkpoint.sh` — Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. [3 deps, 3 dependents]

### Source Code Headers (key components)

**budget-gate:**
```
Budget Gate — PreToolUse hook that enforces context budget limits
BLOCKS tool execution (exit 2) when context tokens exceed critical threshold.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
```

**checkpoint:**
```
Context Checkpoint Agent — Token-aware context budget monitor
Reads actual token usage from Claude Code JSONL transcript to warn
before automatic compaction causes context loss.
Primary: Token-based warnings from JSONL transcript (checked every 5 calls)
Fallback: Tool call counter (when transcript unavailable)
```

### Framework Documentation (CLAUDE.md)
**Context is a finite, non-renewable resource within a session.** Treat it like a battery gauge.

### Commit Cadence Rule
- **Commit after every meaningful unit of work** (not just at session end)
- A "meaningful unit" = completing a subtask, finishing a file, or making a decision
- Each commit is a checkpoint: if context runs out, work up to the last commit is safe
- Target: at least one commit every 15-20 minutes of active work

### Handover Timing Rule
- **Generate handover AFTER work is done, not before**
- Never generate a skeleton handover "to fill in later" — the session may not survive to fill it
- When generating handover: fill in ALL [TODO] sections immediately in the same operation
- For mid-session checkpoints: `fw handover --checkpoint`

### Agent Output Discipline
- When using Task/Agent tools, request concise output (summaries, not raw data)
- See **Sub-Agent Dispatch Protocol** below for detailed rules on managing sub-agent results
- Prefer `fw resume quick` over `fw resume status` for routine checks
- Prefer `git log --oneline -5` over `git log -5`

### Work Proposal Rule
- **Before proposing the next unit of work, check context budget** (`checkpoint.sh status`)
- Below 60% (120K tokens): proceed normally
- 60-75% (120K-150K): propose only small, bounded tasks; commit first
- Above 75% (150K+): propose only wrap-up actions (commit, learnings, handover)
- Above 85% (170K+): handover immediately, no new work
- **This applies especially in autonomous mode** — without a human to catch the mistake, proposing work that can't complete in remaining context risks losing all uncommitted work

### Task History (episodic memory)
- **T-237**: Add search infrastructure — tantivy BM25 for Watchtower, plan embedding layer — Replace grep search with tantivy BM25 — 831 docs indexed, ranked results with snippets. Register search component, check
- **T-244**: Pre-edit fabric awareness — advisory dependency check on Write/Edit — T-012: Create backlog tasks for T-235 GO follow-ups — fabric awareness + vector DB. Add pre-edit fabric awareness adviso
- **T-245**: sqlite-vec embedding layer — semantic search for project knowledge — T-012: Create backlog tasks for T-235 GO follow-ups — fabric awareness + vector DB. sqlite-vec embedding layer — core mo
- **T-246**: Project memory read-path — query learnings/patterns/decisions at task start — T-012: Create backlog tasks for T-235 GO follow-ups — fabric awareness + vector DB. Memory recall — surface prior knowle
- **T-247**: Dispatch fabric context + auto-registration — close agent blind spots — T-012: Create backlog tasks for T-235 GO follow-ups — fabric awareness + vector DB. Add fabric awareness to dispatch pre
- **T-271**: Fix budget-gate stale critical status trap — Fix budget-gate stale critical status trap
- **T-277**: First deployment — Watchtower to Ring20 production — Fix health endpoint blocking on stale index rebuild. Pre-deploy state sync — context, tasks, audits. First deployment of
- **T-290**: Session housekeeping — fill stale handover, commit cron rotation — Fill handover S-2026-0303-1301 TODOs. Commit cron audit rotation (Feb 19 - Mar 3). Sync working state, episodics, and ta
- **T-293**: Fill stale handover and commit audit rotation — Fill handover S-2026-0304-1508 TODOs. Commit cron audit rotation (Feb 23 - Mar 4). Sync working state and task file. Fil
- **T-324**: Fix OneDev-to-GitHub cascade and exclude buildspec from GitHub — Exclude .onedev-buildspec.yml from git tracking (ring20-specific). Fill handover TODOs to unblock pre-push audit. Re-tra

---

## INSTRUCTIONS

Write Deep Dive #16: Budget Management

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
