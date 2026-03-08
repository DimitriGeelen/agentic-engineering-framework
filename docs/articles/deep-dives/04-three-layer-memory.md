# Deep Dive #4: Three-Layer Memory

## Title

Every session, my AI agent forgot everything. So I gave it a memory system.

## Post Body

Day 1: "Let's use YAML for config files." Agent writes YAML config.
Day 2: "Let's restructure the config." Agent writes JSON config.
Day 3: Me, staring at two config formats: "We decided YAML on day 1."
Agent: "I have no record of that decision."

This is the fundamental problem with AI coding agents: **every session starts from zero.** The agent doesn't know what it did yesterday. Doesn't know what failed last week. Doesn't know why you chose PostgreSQL over MongoDB.

Prompt instructions help ("always use YAML for configs") but they don't scale. By the time you've enumerated every decision, convention, and lesson learned, your system prompt is 50K tokens of accumulated context that's impossible to maintain.

### Three layers of memory

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) implements three distinct memory layers, each serving a different purpose:

**1. Working Memory — what's happening now**

```yaml
# .context/working/session.yaml
session_id: S-2026-0308-0809
start_time: 2026-03-08T08:09:33Z
focus: T-042
active_tasks: [T-042, T-038]
```

This is the agent's "what am I doing right now" context. Updated continuously. Lost when the session ends — but that's fine, because it's captured into...

**2. Project Memory — what we know**

```yaml
# .context/project/decisions.yaml
- id: D-014
  date: 2026-02-15
  task: T-028
  decision: "Use YAML for all configuration files"
  rationale: "Human-readable, comments supported, existing tooling"
  rejected: ["JSON (no comments)", "TOML (less familiar to team)"]
```

Decisions, patterns, and learnings accumulated across all sessions. When the agent starts a new session, it reads project memory and knows: we use YAML, we've seen this API timeout before, we tried approach X and it failed.

```yaml
# .context/project/learnings.yaml
- id: L-023
  task: T-092
  learning: "Bash quoted arguments inside $() need careful escaping"
  source: P-001
  promoted: true  # Proven valuable enough to become a practice
```

**3. Episodic Memory — what happened**

```yaml
# .context/episodic/T-042.yaml
task: T-042
summary: "Cleaned up module imports across 8 files"
duration_minutes: 45
approach: "AST-based analysis, removed circular dependencies first"
outcome: success
decisions_made: [D-014]
patterns_encountered: [circular-import-resolution]
key_insight: "Start with leaf modules, work inward"
```

Condensed histories of completed tasks. Not the full git log — a distilled summary of what was tried, what worked, what was learned. When a similar task comes up months later, the agent can read the episodic summary instead of repeating trial-and-error.

### How it flows

```
Session starts
  ↓
Read project memory (decisions, patterns, learnings)
  ↓
Restore working memory (what was in progress)
  ↓
Work... make decisions, encounter issues, learn things
  ↓
Continuous capture (decisions → project memory, issues → patterns)
  ↓
Session ends
  ↓
Generate episodic summary (what happened, condensed)
  ↓
Generate handover (state + recommendations for next session)
```

The agent at session start isn't starting from zero. It has access to every decision ever made, every failure pattern ever encountered, and the full history of similar tasks.

### Real example

Session 47 encounters an API timeout. The healing loop fires, searches patterns:

```
🔍 Similar pattern found: P-087 (from T-015, 2 months ago)
   Symptom: API timeout during batch processing
   Root cause: Missing connection pool limit
   Resolution: Set max_connections=10, add retry with backoff
   Success rate since fix: 100% (0 recurrences)
```

The agent doesn't guess. It applies the known fix. Two months of institutional knowledge, available instantly.

### The key insight

Memory isn't one thing. Short-term context (working memory) has different requirements than accumulated knowledge (project memory) and historical reference (episodic memory). By separating them, each can be optimized:

- Working memory is fast, volatile, small
- Project memory is persistent, searchable, growing
- Episodic memory is archival, condensed, referenced on demand

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# See current memory state
fw context status

# Record a decision
fw context add-decision "Use YAML for configs" --task T-042 --rationale "Human readable"

# Record a learning
fw context add-learning "Always set connection pool limits" --task T-042
```

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** The YAML/JSON anecdote is instantly relatable. Focus on the "every session starts from zero" problem.
**LinkedIn:** Frame as knowledge management — "In any organization, undocumented decisions get re-debated. AI agents have the same problem, compressed into hours instead of months."
**Dev.to:** Expand with the full YAML schema for each memory layer and how to build custom queries.

## Hashtags

#ClaudeCode #AIAgents #AIMemory #DevTools #OpenSource #KnowledgeManagement
