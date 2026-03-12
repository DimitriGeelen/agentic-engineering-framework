# Reddit r/ClaudeAI Post Draft

## Title

I built a governance framework for Claude Code — task gates, session memory, and audit trails

## Post Body

I've been using Claude Code daily for months and kept running into the same problems:

- **No traceability.** Files change with no record of why. Three weeks later I'm reading a diff with no way to reconstruct the reasoning.
- **No memory.** Every session starts from zero. The agent doesn't know what it did yesterday, what decisions were made, what failed.
- **No risk awareness.** Force push? Hard reset? Nothing prevents it structurally. The agent may ask, but there's no model for understanding *why* that action is risky.

Over 25 years of working on complex IT programmes I arrived at a principle: effective intelligent action — whether by a person, a team, or an AI agent — requires clear direction, context awareness, awareness of constraints and impact, and capable engaged actors. When I started using agentic coding tools, I recognised the same failure modes I had seen in every ungoverned programme. So I applied the same governance principle to a new domain.

**What it does:**

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) adds structural governance to Claude Code:

- **Task-first enforcement** — file edits are blocked by a PreToolUse hook unless an active task exists. Not a convention — a gate.
- **Three-layer memory** — working memory (session), project memory (patterns + decisions), episodic memory (task histories). The agent recalls what happened across sessions.
- **Tiered approval** — destructive commands (force push, rm -rf) are intercepted and require human sign-off.
- **Context budget management** — monitors actual token usage and auto-generates a handover before the agent loses coherence.
- **Continuous audit** — 90+ compliance checks run every 30 minutes, on push, and on demand.
- **Healing loop** — failures are diagnosed, recorded as patterns, and surfaced when similar issues recur.

**What it looks like:**

![Watchtower Dashboard](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-dashboard.png)
*Dashboard surfaces tasks, audit results, and work direction in one view.*

![Task Board](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-tasks-board.png)
*Tasks flow through Captured → In Progress → Issues → Completed — visible and auditable.*

![Dependency Graph](https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/docs/screenshots/watchtower-fabric-graph.png)
*Interactive dependency graph — before changing a file, the agent knows what depends on it.*

**Quick demo:**

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash

# Or via Homebrew (macOS/Linux)
brew install DimitriGeelen/agentic-fw/agentic-fw

# Initialize in your project
cd your-project && fw init

# Start governed work
fw work-on "Add JWT validation" --type build

# Agent tries to force push → blocked
$ git push --force
══════════════════════════════════════════════════════════
  TIER 0 BLOCK — Destructive Command Detected
══════════════════════════════════════════════════════════
```

I used the framework to build the framework — 441 tasks completed, 98% commit traceability. Every architectural decision is recorded with rationale.

It's open source (Apache 2.0) and works with Claude Code out of the box. Also supports Cursor and any CLI agent, though Claude Code gets the deepest enforcement via hooks.

**Longer write-up:** [I built guardrails for AI coding agents — same governance principle, new domain](https://dev.to/irrindar/i-built-guardrails-for-ai-coding-agents-same-governance-principle-new-domain-28j3)

Would love to hear how others are handling governance with Claude Code. Are you using any structure, or just vibing?

---

## Suggested Flair

Project Showcase / Claude Code

## Notes

- Post during weekday morning US time for visibility
- Reply to early comments quickly (first hour matters for Reddit algorithm)
- Don't be defensive about feedback — genuine engagement wins
