# Deep Dive #3: Context Budget Management

## Title

Your AI agent has a memory that degrades. Here's how to manage it like a battery gauge.

## Post Body

There's a failure mode with AI coding agents that nobody warns you about until it happens:

Your agent is 45 minutes into a complex refactoring task. It's made good changes across 8 files. Then it starts repeating itself. Contradicting earlier decisions. Forgetting file names it just read. Eventually it outputs garbage and the session dies.

What happened? **The context window filled up.**

Large language models have a fixed context window — think of it as working memory. Every message, every file read, every tool result consumes tokens. When you hit the limit, the model starts losing earlier context. Your carefully constructed plan, your acceptance criteria, your architectural decisions — gone.

And the worst part: the agent doesn't know it's degrading. It keeps working confidently with corrupted context, producing changes that contradict its own earlier work.

### Treating context as a battery

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) monitors actual token usage in real-time and enforces escalating gates:

```
Token Usage     Level       What Happens
─────────────────────────────────────────────
0-120K          ✅ OK       Work normally
120K-150K       ⚠️ WARN     Commit first, only small tasks
150K-170K       🔴 URGENT   Wrap up, no new work
170K+           ⛔ CRITICAL  BLOCKED — only commits and handover allowed
```

This isn't a suggestion displayed in the terminal. It's a **PreToolUse hook** that literally blocks Write/Edit/Bash calls when you hit critical:

```
⛔ CONTEXT BUDGET: CRITICAL (172K/200K tokens used)
   Blocked: Edit to src/api/handler.ts
   Allowed: git commit, fw handover, fw task update

   Your context is nearly exhausted. Commit your work and
   generate a handover for the next session.
```

### Auto-handover: the safety net

When the budget hits critical, the framework automatically:

1. **Generates a handover document** — captures what was done, what's pending, what decisions were made
2. **Writes a restart signal** — if you're using the `claude-fw` wrapper, it auto-restarts a fresh session
3. **Injects context into the new session** — the new agent picks up where the old one left off

The handover isn't just "task T-042 is in progress." It includes:
- Current git state and uncommitted changes
- Which acceptance criteria are met vs. pending
- Active decisions and their rationale
- Suggested first action for the next session

### The commit cadence rule

The budget system also enforces a commit cadence:

> Commit after every meaningful unit of work — not just at session end.

Each commit is a checkpoint. If context runs out between commits, everything since the last commit is safe. The framework targets at least one commit every 15-20 minutes of active work.

This means even catastrophic context loss costs you at most 15 minutes of work, not 45.

### Why this matters

Without context budget management, you have two bad options:

1. **Short sessions** — waste time on setup/teardown, never tackle big tasks
2. **Long sessions** — risk context corruption destroying hours of work

With it, you get long productive sessions with automatic safety nets. The agent works until it physically can't, then hands off gracefully instead of degrading silently.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# Check current context budget
./agents/context/checkpoint.sh status

# The budget gate runs automatically on every tool call
```

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** The "agent going insane at 45 minutes" is universally relatable. People will have their own horror stories.
**LinkedIn:** Frame as resource management — "In any system, unmonitored resource consumption leads to degraded output. AI agents are no different."
**Dev.to:** Include the actual token counting mechanism and how to tune thresholds.

## Hashtags

#ClaudeCode #AIAgents #ContextWindow #DevTools #OpenSource #LLM
