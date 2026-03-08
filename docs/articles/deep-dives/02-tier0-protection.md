# Deep Dive #2: Tier 0 Protection

## Title

Governing AI Agents: Tier 0 Protection — stopping destructive commands before they execute

## Post Body

**Irreversible actions require explicit approval. In every domain. Without exception.**

A programme manager authorises a contract termination. A hospital pharmacist double-checks a high-risk prescription. A nuclear plant operator confirms a reactor shutdown sequence with a second officer. The pattern is universal: when the consequence of an action cannot be undone, the system requires a deliberate pause — a structural checkpoint that forces a human to confirm intent before execution proceeds.

The same requirement exists in software engineering, but it is rarely enforced for AI agents. An agent told to "fix the merge conflict and push" may resolve the conflict, commit, and run `git push --force origin main`. Force push to the shared branch. With three other contributors' work on it. The agent treats `git push --force` and `git push` as roughly equivalent — both "push code to remote." It has no structural model for understanding that one of these can destroy other people's work.

I caught one such incident in terminal output. Reverted with reflog. No permanent damage. But the question was not whether I was fast enough. The question was: **why was the action possible in the first place?**

### Tiered enforcement

The Agentic Engineering Framework classifies every command by risk level:

| Tier | Scope | Example | Gate |
|------|-------|---------|------|
| 0 | Destructive or irreversible | `force push`, `rm -rf`, `DROP TABLE`, `git reset --hard` | Human approval required |
| 1 | Standard operations | File edits, normal commits | Active task required |
| 2 | Human-authorized bypass | Emergency hotfixes | Logged, single-use |
| 3 | Safe reads | `git status`, `fw doctor` | No gate |

A PreToolUse hook intercepts every Bash command before execution and pattern-matches against destructive commands. When it matches, the command does not execute. The agent cannot bypass it. The human reviews, approves or denies, and the decision is logged.

```
TIER 0 BLOCK — Destructive Command Detected
  Command:  git push --force origin main
  Category: force-push
  Risk:     Overwrites remote history, may destroy others' work

  To approve: fw tier0 approve
  This approval is single-use and will be logged.
```

### The research behind the design

I arrived at this model by cataloging risks formally. The framework maintains a risk register — 38 risks across 9 categories, structured after ISO 27001's four-level assurance model. The highest-scoring risk was R-010: human sovereignty violation — an agent making irreversible decisions without human approval.

A systematic bypass analysis (T-228) then found 13 bypass vectors across three enforcement layers. Two were HIGH severity: `--no-verify` on git commits (skips all hooks, completely invisible) and the agent modifying its own hook configuration (delayed-action bypass — change settings.json, restart session, hooks disappear).

The Tier 0 system went through three generations. The first version was keyword matching — "force" in command triggers a block. It missed `find / -delete`, `> important-file.txt` (truncation via redirect), and `dd if=/dev/zero of=/dev/sda`. The current version uses a pre-filter for speed plus deeper pattern analysis for edge cases. It is not perfect — 6+ patterns still bypass it — but it catches the destructive commands that agents actually attempt in practice.

The critical design choice was Decision D-004: Tier 0 violations are FAIL, not WARN. The alternative — warning the agent — was rejected after observing that agents under execution pressure acknowledge warnings and proceed anyway. A FAIL physically blocks execution. **Structural enforcement does not degrade.**

### The authority model

This is part of a broader principle:

```
Human    SOVEREIGNTY   Can override anything, is accountable
Framework AUTHORITY    Enforces rules, checks gates, logs everything
Agent    INITIATIVE    Can propose, request, suggest — never decides
```

The agent has initiative — it can decide what to do. It does not have authority — it cannot execute destructive actions without human sign-off. Even when told "proceed as you see fit," that phrase delegates initiative, not authority. Tier 0 gates still fire.

A human developer has years of muscle memory around dangerous commands. They hesitate before `--force`. An AI agent has no hesitation. It executes at the speed of inference. If the plan says "push the changes" and the remote rejects, it will add `--force` without the visceral pause that experience gives a human. Structural gates replace that visceral pause with a mechanical one.

**Initiative is not authority. The domain changed. The principle did not.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd your-project && fw init
# Destructive commands through Claude Code will now be intercepted
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with the full pattern-matching logic and custom Tier 0 rules.
**LinkedIn:** Open with "Would you give a new hire force-push access on day one? Then why give it to an AI agent?"
**Reddit (r/ClaudeAI):** Shorten. Lead with the force-push incident, then the tiered model.

## Hashtags

#ClaudeCode #AIAgents #DevTools #GitSafety #OpenSource #AISafety
