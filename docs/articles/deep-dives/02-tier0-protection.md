# Deep Dive #2: Tier 0 Protection

## Title

"git push --force" — How I stopped my AI agent from nuking production

## Post Body

It happened on a Tuesday. I told Claude Code to "fix the merge conflict and push." It resolved the conflict, committed, and ran `git push --force origin main`.

Force push to main. The shared branch. With 3 other people's work on it.

I caught it in the terminal output. Reverted with reflog. No permanent damage. But it shouldn't have been possible in the first place.

The problem isn't that the agent is malicious. It's that it treats `git push --force` and `git push` as roughly equivalent — both "push code to remote." It has no structural model for understanding that one of these can destroy other people's work.

### Tiered enforcement

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) classifies every command by risk level:

| Tier | What | Example | Gate |
|------|------|---------|------|
| 0 | **Destructive / irreversible** | `force push`, `rm -rf`, `DROP TABLE`, `git reset --hard` | Human approval required |
| 1 | Standard operations | File edits, normal commits | Active task required |
| 2 | Human-authorized bypasses | Emergency hotfixes | Logged, single-use |
| 3 | Safe reads | `git status`, `fw doctor` | No gate |

Tier 0 is the critical one. A PreToolUse hook intercepts every Bash command before execution and pattern-matches against a list of destructive commands. When it matches:

```
══════════════════════════════════════════════════════════
  TIER 0 BLOCK — Destructive Command Detected
══════════════════════════════════════════════════════════
  Command:  git push --force origin main
  Category: force-push
  Risk:     Overwrites remote history, may destroy others' work

  To approve: fw tier0 approve
  This approval is single-use and will be logged.
══════════════════════════════════════════════════════════
```

The command doesn't execute. The agent can't bypass it. The human reviews, approves (or doesn't), and it's logged either way.

### What gets caught

The detection isn't just exact string matching. It catches:

- **Force push variants:** `--force`, `-f`, `--force-with-lease`
- **Hard resets:** `git reset --hard`, `git checkout .`, `git restore .`
- **Destructive file ops:** `rm -rf`, patterns that could wipe directories
- **Branch deletion:** `git branch -D` (uppercase D = force delete)
- **Database ops:** `DROP TABLE`, `DROP DATABASE`

### Why this matters more for AI agents

A human developer has years of muscle memory around dangerous commands. They hesitate before `--force`. They double-check the branch name.

An AI agent has no hesitation. It executes at the speed of thought. If the plan says "push the changes," it will push — and if it decides `--force` is needed to resolve a rejection, it will add `--force` without the visceral "wait, am I sure?" that a human has.

Structural gates replace that visceral pause with a mechanical one.

### The authority model behind it

This is part of a broader principle:

```
Human    → SOVEREIGNTY  → Can override anything, is accountable
Framework → AUTHORITY   → Enforces rules, checks gates, logs everything
Agent    → INITIATIVE   → Can propose, request, suggest — never decides
```

The agent has initiative — it can decide *what* to do. But it doesn't have authority — it can't execute destructive actions without human sign-off. Even if you tell the agent "proceed as you see fit," that delegates initiative, not authority. Tier 0 gates still fire.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# Now try a force push through Claude Code — it will be blocked
```

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** The force push story is the hook — everyone has a near-miss story. Lead with the incident.
**LinkedIn:** Frame around "AI agents in production teams" — the enterprise risk angle. "Would you give a new hire push --force access on day one?"
**Dev.to:** Expand with the full pattern-matching logic and how to add custom Tier 0 rules.

## Hashtags

#ClaudeCode #AIAgents #DevTools #GitSafety #OpenSource #AISafety
