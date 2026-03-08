# Deep Dive #6: The Authority Model

## Title

Delegation without boundaries is not empowerment — it is abdication

## Post Body

**Initiative is not authority.**

In every domain I have worked in — IT programme governance, transition management, engineering leadership — the same failure mode appears when intelligent actors are given broad direction without clear constraints. A programme manager tells a workstream lead "handle this however you think is best." A hospital administrator tells a department head to "sort it out." A ship captain delegates watch duty with "you know what to do." In each case the intent is trust. The effect is the removal of structural accountability. The dynamics of complex work are too varied to oversee every possibility — which is precisely why organisations build structures that do not depend on individual judgment holding up under pressure.

The same failure mode has arrived in software engineering, carried by a new class of actor. The agent is mid-task. It asks a question. You reply: "Proceed as you see fit." Forty-five minutes later you discover it force-pushed to main, deleted a feature branch, and restructured the database schema. It was doing what it thought was best. You gave it permission — or at least, you thought you did. But there is a distinction most people miss when working with AI agents, and it is the same distinction that separates effective delegation from dangerous abdication in any organisation: **initiative is not authority.**

I arrived at this distinction not from AI theory but from watching real programmes succeed and fail over 25 years. The teams that operated well were not the ones with the most autonomy and not the ones with the least. They were the ones where it was structurally clear what an actor could decide on their own and what required someone else's approval. That structural clarity is exactly what is missing from most AI agent setups today.

### The three-tier model

The Agentic Engineering Framework defines three distinct roles:

```
Human     SOVEREIGNTY   Can override anything, is accountable
Framework  AUTHORITY    Enforces rules, checks gates, logs everything
Agent     INITIATIVE    Can propose, request, suggest — never decides
```

When you say "proceed as you see fit," you are delegating initiative — the agent can choose what to work on, which approach to take, what order to do things. You are not delegating authority — the agent still cannot execute destructive commands, bypass verification gates, complete human-owned tasks, or skip task creation.

Even under the broadest possible delegation, structural gates remain active.

### How it is enforced

This is not a prompt instruction. It is structural.

**Tier 0 hooks** intercept destructive commands and require explicit approval. **Task gates** prevent work without accountability. **Ownership gates** prevent the agent from self-completing human-owned tasks — the agent marks its acceptance criteria as done, but the human must review and finalise.

```yaml
# Task with owner: human
# Agent completes all its ACs
# But cannot set work-completed
# Human reviews and finalises
```

The practical result: the agent works freely within safe operations (reading files, writing code, running tests, committing). Destructive or governance-significant actions require human sign-off. Autonomy where it is safe. Control where it matters.

### The research behind the design

This model was forged by a specific incident. Task T-151 was a specification task — meaning I, as the human, was supposed to review the findings before any decision was made. The agent created the task, immediately started working, and completed it in 2 minutes. It wrote the investigation findings, made the GO recommendation, chose between implementation approaches, and closed the task. Without consulting me.

The task existed. The status transitions were logged. From a structural perspective, everything looked correct. But the intent — that a human was supposed to validate the specification — was completely bypassed. The governance was theatre.

That incident triggered a deep review (T-194) where I mapped the entire governance model against ISO 27001's four-level assurance framework. The findings were instructive:

- Human sovereignty (Risk R-010, score 16) was the highest-scoring risk in the register
- It had 4 controls, all warn-only — breadth without depth
- One related risk (R-033) had no control at all

The authority model was the response. I formalised three tiers — sovereignty, authority, initiative — and mapped every action to a tier. The critical design choice was Decision D-004: Tier 0 violations are FAIL, not WARN. The alternative was rejected because behavioural rules do not hold under pressure. An agent 45 minutes into a task that encounters a warning will acknowledge it and proceed.

Validation across the framework's 312-task history confirmed the pattern: structural gates (FAIL/BLOCK) have near-100% effectiveness. Behavioural rules (WARN + trust the agent) degrade as context fills up or the agent operates autonomously.

### The deeper principle

Effective intelligent action — whether by a person, a team, or an AI agent — requires clear direction, context awareness, awareness of constraints and impact, and capable engaged actors. A manager who says "handle this however you think is best" is delegating initiative. They are not saying "ignore all company policies" or "skip the approval process for purchases over $10K."

AI agents need the same structure. Broad delegation within clear boundaries is not a contradiction. It is how capable systems actually operate.

**The domain changed from human teams to AI agents. The principle did not.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# See the authority model in action
fw work-on "Test authority boundaries" --type build
# Agent can work freely on safe operations
# Destructive commands will be intercepted
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with the full enforcement matrix per autonomy level.
**LinkedIn:** Open with "Delegation without guardrails is not empowerment. It is abdication. This applies to AI agents as much as it does to teams."
**Reddit (r/ClaudeAI):** Shorten. Lead with the "proceed as you see fit" scenario and the 2-minute completion incident.

## Hashtags

#ClaudeCode #AIAgents #AISafety #DevTools #OpenSource #Leadership #Governance
