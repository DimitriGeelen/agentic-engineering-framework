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

I studied how mature governance frameworks handle this distinction. ISO 27001 separates **control design** (the rule exists) from **operational effectiveness** (the rule works in practice). A prompt instruction is control design. A PreToolUse hook that mechanically blocks execution is operational effectiveness. Across 312 completed tasks, hook-based enforcement maintained near-100% effectiveness while behavioral rules degraded as context filled up. A formal bypass analysis (T-228) cataloged 13 bypass vectors and confirmed the pattern: structural gates hold, behavioral rules do not.

### What the gate produces

```
T-042: Clean up module imports
  Acceptance Criteria: No circular imports, All unused imports removed
  Commits: 3 (all prefixed T-042:)
  Decisions: Kept lodash — tree-shaking handles unused methods
```

Across 312 completed tasks, the framework achieved 96% commit traceability — every commit links to a task, and every task records the decisions behind the work. Three months later, any file change can be traced back to a stated intent.

**The difference between telling someone to wear a hard hat and installing a door that will not open without one.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd my-project && fw init --provider claude

# The gate activates immediately — the agent cannot touch a file without a task
fw work-on "My first governed task" --type build

# Start the dashboard to see your tasks
fw serve  # http://localhost:3000
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with how to build a custom PreToolUse gate.
**LinkedIn:** Open with "In programme management, no one modifies a deliverable without a work order. In AI-assisted engineering, the same principle applies — and almost no one enforces it."
**Reddit (r/ClaudeAI):** Shorten. Lead with the 47-files incident, then the principle.

## Hashtags

#ClaudeCode #AIAgents #DevTools #CodingWithAI #OpenSource #Governance
