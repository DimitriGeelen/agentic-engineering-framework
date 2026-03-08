# Deep Dive #1: The Task Gate

## Title

My AI agent changed 47 files with no record of why. Here's the one rule that fixed it.

## Post Body

I've been using Claude Code for months. One morning I came back to a project and found 47 files modified across 12 commits. No context. No reasoning. No way to figure out *why* any of it happened.

The agent wasn't broken. It was doing exactly what I asked — "clean up the codebase." But it had no structure. No boundaries. No accountability.

So I built one rule and enforced it structurally:

**Nothing gets done without a task.**

Not as a convention. Not as a prompt instruction the agent can ignore. As an actual gate that blocks file edits.

### How it works

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) installs a PreToolUse hook in Claude Code. Every time the agent tries to write or edit a file, the hook fires and checks:

1. Does `.context/working/focus.yaml` contain an active task ID?
2. Does that task file actually exist in `.tasks/active/`?

If either check fails, the edit is **blocked**. Not warned — blocked. The agent literally cannot modify your codebase without first creating a task that says what it's doing and why.

```bash
# This gets blocked:
$ claude "clean up the codebase"
→ ⛔ TASK GATE: No active task. Create one with: fw work-on "Clean up codebase" --type refactor

# This works:
$ fw work-on "Clean up module imports" --type refactor
→ ✅ Task T-042 created, focus set
# Now edits are allowed — and every commit traces back to T-042
```

### The thinking behind this

This wasn't the first idea. The first idea was a prompt instruction: "Always create a task before working." It lasted about a day.

Here's the failure mode we observed: I gave the agent a specification task (T-151) — a task where I, as the human, was supposed to review the findings. The agent created it, immediately started working, and completed it in **2 minutes** — without consulting me at all. It wrote the investigation, made the GO recommendation, chose the implementation approach, and closed the task. Unilaterally.

That was a governance failure. The task existed, but it was theater — the gate wasn't structural, it was behavioral. The agent "knew" it should consult the human but under execution pressure it just... didn't.

So I studied how frameworks like ISO 27001 handle this. They distinguish between **control design** (the rule exists) and **operational effectiveness** (the rule actually works in practice). A prompt instruction is control design. A PreToolUse hook that mechanically blocks execution is operational effectiveness.

We eventually cataloged **23 controls** across the framework (we'd assumed there were 11 — the inventory was incomplete without a formal register). Of those, we found that **hook-based enforcement has a ~100% effectiveness rate** while behavioral rules (prompt instructions) degrade as context fills up. This was validated across 312 completed tasks.

The task gate was Decision D-001 in our project. We debated putting it in a pre-commit hook, but chose PreToolUse because pre-commit fires too late — the agent has already done the work, you're just blocking the commit. PreToolUse blocks the *attempt to edit*, which is the right intervention point.

### Why not just prompt it?

Because prompt instructions fail under pressure. When the context window fills up, when the agent is deep in a complex task, when it's been running autonomously for 20 minutes — that's exactly when "please always create a task first" gets forgotten.

We proved this empirically. We tracked 13 bypass vectors across the framework (T-228), and the pattern was consistent: behavioral rules fail when the agent is under cognitive load, while structural hooks don't degrade.

It's the difference between telling someone to wear a hard hat and installing a door that won't open without one.

### What you get

Every file change traces to a task. Every task has acceptance criteria. Every commit references a task ID. Three months later, you can pick any file, run `git log`, and reconstruct the full reasoning chain.

Across 312 completed tasks, we achieved **96% commit traceability** — every commit links to a task, and every task records the decisions and reasoning behind the work.

```
T-042: Clean up module imports
├── Acceptance Criteria: ✅ No circular imports, ✅ All unused imports removed
├── Commits: 3 (all prefixed T-042:)
└── Decisions: Kept lodash — tree-shaking handles unused methods
```

This isn't about bureaucracy. It's about not waking up to 47 mystery changes.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init
fw work-on "My first governed task" --type build
```

The gate activates immediately. Your agent can't touch a file without a task.

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** Use as-is. The "47 files" hook is relatable. Flair: Project Showcase.
**LinkedIn:** Add the governance framing — "In traditional programme management, we'd never let someone modify deliverables without a work order. Why do we let AI agents do it?"
**Dev.to:** Can expand with more code examples and a "how to build your own gate" section.

## Hashtags

#ClaudeCode #AIAgents #DevTools #CodingWithAI #OpenSource #Governance
