# Deep Dive #3: Context Budget Management

## Title

Unmonitored resource consumption is not a technical problem — it is a governance failure

## Post Body

**Every finite resource requires active management. Context is no exception.**

In programme management, the most dangerous resource is the one nobody tracks. A project that monitors budget and timeline but ignores team capacity will fail — not from lack of money, but from exhaustion that degrades decision quality long before the budget runs out. The degradation is invisible at first. Decisions become slightly worse. Then noticeably worse. Then someone makes a call that contradicts a decision from two weeks earlier, and nobody catches it because the institutional memory has thinned.

The same failure mode appears in AI coding agents, compressed from weeks into minutes. A large language model has a fixed context window — a working memory that holds every message, every file read, every tool result. When the window fills, earlier context is lost. The carefully constructed plan, the acceptance criteria, the architectural decisions — gone. The agent does not know it is degrading. It continues working confidently with corrupted context, producing changes that contradict its own earlier work.

I recognised this as a resource management problem, not a technical limitation. The context window is a battery. It drains with use. **Unmonitored, it fails at the worst possible moment — deep into complex work, with the most to lose.**

### Treating context as a battery

The Agentic Engineering Framework monitors actual token usage in real-time and enforces escalating gates:

```
Token Usage     Level       Response
0-120K          OK          Work normally
120K-150K       WARN        Commit first, only small tasks
150K-170K       URGENT      Wrap up, no new work
170K+           CRITICAL    BLOCKED — only commits and handover
```

This is not a suggestion. A PreToolUse hook blocks Write, Edit, and Bash calls when the budget reaches critical. The agent physically cannot start new work — it can only commit what exists and generate a handover for the next session.

### The safety net

When the budget hits critical, the framework automatically generates a handover document — capturing what was done, what remains, which decisions were made, and what the next session should do first. If the session was started via the `claude-fw` wrapper, it auto-restarts a fresh session with the handover injected as context. The new agent picks up where the previous one left off.

The handover is not a summary. It is a structured document with current git state, acceptance criteria status, active decisions with rationale, and a suggested first action. Explicit handover preserves 95%+ of critical context. The alternative — LLM-based auto-compaction — preserves roughly 60-70%.

### The research behind the design

The first version of context budget management was a tool-call counter. Every 50 tool calls, display a warning. The correlation between tool calls and actual token consumption is weak — a single file read can consume 10K tokens while a simple edit consumes 200. The counter was useless.

I ran a formal research spike (T-138, T-174) comparing three approaches:

| Approach | Accuracy | Overhead |
|----------|----------|----------|
| Tool-call counting | Low | Zero |
| JSONL transcript reading | High | ~50ms per check |
| LLM self-assessment | Unreliable | High |

Decision D-009: monitor via token reading from the JSONL transcript. The agent's session writes every API response to a JSONL file on disk. The budget gate reads this file, counts actual tokens, and enforces based on real data.

The deeper question was whether Claude Code's built-in auto-compaction could replace this entirely. It cannot. Auto-compaction triggers at ~98% capacity and uses LLM summarization — which destroys working memory. The summarizer decides what is important, and it routinely drops acceptance criteria, pending decisions, and architectural context. I disabled auto-compaction (Decision D-027) and built explicit handover instead. The research (T-174, using 3 parallel investigation agents) confirmed: deliberate handover outperforms automatic summarization because the agent writes it with full context, not a summarizer working from lossy compression.

### The commit cadence rule

The budget system also enforces a commit cadence: commit after every meaningful unit of work, not just at session end. Each commit is a checkpoint. If context runs out between commits, everything since the last commit is safe. The framework targets one commit every 15-20 minutes of active work.

This means catastrophic context loss costs at most 15 minutes of work. Without it, a single session failure can lose 45 minutes or more.

**A resource that degrades invisibly requires governance that intervenes structurally. The domain changed from programme budgets to context windows. The principle did not.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# Check current context budget
./agents/context/checkpoint.sh status
# The budget gate runs automatically on every tool call
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with the token counting mechanism and threshold tuning.
**LinkedIn:** Open with "In any system, unmonitored resource consumption leads to degraded output. AI agents are no different."
**Reddit (r/ClaudeAI):** Shorten. Lead with the "agent going incoherent at 45 minutes" scenario.

## Hashtags

#ClaudeCode #AIAgents #ContextWindow #DevTools #OpenSource #LLM
