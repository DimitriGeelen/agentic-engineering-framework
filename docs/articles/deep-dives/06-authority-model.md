# Deep Dive #6: The Authority Model

## Title

"Do whatever you think is best" — the most dangerous thing you can say to an AI agent

## Post Body

You're busy. The agent is mid-task. It asks a question. You reply:

> "Proceed as you see fit."

45 minutes later you discover it force-pushed to main, deleted a feature branch, and restructured the database schema. It was doing what it thought was best. You gave it permission.

...Did you?

There's a subtle but critical distinction most people miss when working with AI agents: **initiative is not authority.**

### The three-tier model

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) defines three distinct roles:

```
Human    → SOVEREIGNTY  → Can override anything, is accountable
Framework → AUTHORITY   → Enforces rules, checks gates, logs everything
Agent    → INITIATIVE   → Can propose, request, suggest — never decides
```

When you say "proceed as you see fit," you're delegating **initiative** — the agent can choose what to work on, which approach to take, what order to do things. That's fine.

But you're NOT delegating **authority** — the agent still can't:
- Execute destructive commands (Tier 0 gate)
- Bypass verification gates (structural enforcement)
- Complete human-owned tasks (sovereignty)
- Skip task creation (Tier 1 gate)

Even under the broadest possible delegation, structural gates remain active.

### Why this matters

Most AI agent frameworks (or lack thereof) operate on a binary model: either the agent has permission, or it doesn't. This creates a false choice:

- **Too restrictive:** Agent asks permission for everything → you spend more time approving than coding
- **Too permissive:** Agent does whatever → you find surprises in your codebase

The framework's model adds a middle layer. The agent has broad initiative for safe operations (reading files, writing code, running tests) while authority for risky operations (force push, database changes, deployment) stays with the human.

### How it's enforced

This isn't just a prompt instruction. It's structural:

**Tier 0 hooks** intercept destructive commands and require explicit approval:

```bash
# Agent runs this autonomously → BLOCKED
$ git push --force origin main

# Human must explicitly approve
$ fw tier0 approve
# NOW it executes (and the approval is logged)
```

**Task gates** prevent work without accountability:

```bash
# Agent tries to edit files without a task → BLOCKED
# Even with "do whatever you think is best" active
```

**Ownership gates** prevent the agent from self-completing human-owned tasks:

```yaml
# Task with owner: human
# Agent marks all its ACs as done, but cannot set work-completed
# Human must review and finalize
```

### The practical result

You CAN say "proceed as you see fit" safely. The agent will:

- Choose which task to work on next ✅
- Choose an implementation approach ✅
- Run tests and audits ✅
- Commit completed work ✅

The agent will NOT (even with broad delegation):

- Force push, hard reset, or delete branches ❌
- Bypass verification gates ❌
- Complete tasks that need your review ❌
- Modify code without a task ❌

You get autonomy where it's safe, control where it matters.

### The deeper principle

This maps directly to how effective organizations work. A manager who says "handle this however you think is best" is delegating initiative. They're NOT saying "ignore all company policies" or "skip the approval process for purchases over $10K."

AI agents need the same structure. Broad delegation within clear boundaries isn't a contradiction — it's how capable systems actually operate.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# See the authority model in action:
fw work-on "Test authority boundaries" --type build

# Agent can work freely on safe operations
# But destructive commands will be intercepted
```

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** The "proceed as you see fit" hook is strong — everyone has said this to an agent. The realization that it's dangerous is the insight.
**LinkedIn:** This is the strongest LinkedIn post of the series. Frame as leadership/management — "Delegation without guardrails isn't empowerment, it's abdication."
**Dev.to:** Expand with the full enforcement matrix (what's delegated at each autonomy level).

## Hashtags

#ClaudeCode #AIAgents #AISafety #DevTools #OpenSource #Leadership #Governance
