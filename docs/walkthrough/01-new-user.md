# Track 1: New User Walkthrough

You've installed the framework. This guide walks you through the core governance cycle — the minimum you need to understand to use it effectively.

**Time:** ~30 minutes
**Prerequisites:** Framework installed, `fw doctor` passes

---

## 1. Task Management — Everything Starts Here

The framework's core principle: **nothing gets done without a task.** This is enforced structurally, not by discipline.

**Try it:**
```bash
fw task create --name "My first task" --type build --owner agent --start
```

This creates a task file in `.tasks/active/`, sets your focus, and unlocks Write/Edit operations. Without a task, the PreToolUse hook blocks code changes.

**Read more:**
- [Deep-dive: Task Gate](../articles/deep-dives/01-task-gate.md)
- [Deep-dive: Task Management](../articles/deep-dives/18-task-management.md)
- [Generated article: Task Management subsystem](../generated/articles/task-management-prompt.md)

**Key concept:** Tasks have acceptance criteria (ACs). Agent ACs are verified automatically. Human ACs require manual verification. The framework won't let you close a task with unchecked ACs.

---

## 2. Git Traceability — Every Commit Has a Purpose

Every commit must reference a task ID. The `commit-msg` hook enforces this.

**Try it:**
```bash
# Make a change, then:
fw git commit -m "T-XXX: describe what you did"
```

The hook checks that `T-XXX` exists as a real task. Commits without task references are rejected.

**Read more:**
- [Deep-dive: Git Traceability](../articles/deep-dives/12-git-traceability.md)
- [Generated article: Git Traceability subsystem](../generated/articles/git-traceability-prompt.md)

**Key concept:** Traceability means you can trace any line of code back to the task that created it, the decision that drove it, and the acceptance criteria it satisfies.

---

## 3. Audit System — Trust but Verify

The audit system checks framework compliance: task structure, commit traceability, learning capture, and more.

**Try it:**
```bash
fw audit
```

You'll see PASS/WARN/FAIL for each check. The `pre-push` hook runs this automatically — pushes with FAILs are blocked.

**Read more:**
- [Deep-dive: Audit](../articles/deep-dives/17-audit.md)
- [Generated article: Audit subsystem](../generated/articles/audit-prompt.md)

**Key concept:** Audits run on a cron (every 30 min), on pre-push, and on demand. They catch drift before it compounds.

---

## 4. Hook Enforcement — The Structural Gates

Hooks are the enforcement mechanism. They run before and after tool invocations (in Claude Code) or git operations.

| Hook | When | What |
|------|------|------|
| PreToolUse: task-gate | Before Write/Edit | Blocks without active task |
| PreToolUse: tier0 | Before destructive Bash | Blocks force-push, rm -rf, etc. |
| PreToolUse: budget-gate | Before Write/Edit/Bash | Blocks at critical context usage |
| PostToolUse: checkpoint | After any tool | Monitors context budget |
| commit-msg | Before git commit | Requires task reference |
| pre-push | Before git push | Runs full audit |

**Read more:**
- [Deep-dive: Tier 0 Protection](../articles/deep-dives/02-tier0-protection.md)
- [Deep-dive: Enforcement](../articles/deep-dives/20-enforcement.md)
- [Generated article: Enforcement subsystem](../generated/articles/enforcement-prompt.md)

---

## 5. Handover System — Session Continuity

AI sessions end. The handover system captures state so the next session can continue seamlessly.

**Try it:**
```bash
fw handover --commit
```

This generates a structured document in `.context/handovers/` with: where we are, work in progress, decisions made, suggested next action.

**Read more:**
- [Deep-dive: Handover](../articles/deep-dives/19-handover.md)
- [Generated article: Handover subsystem](../generated/articles/handover-prompt.md)

**Key concept:** Handovers are the bridge between sessions. Without them, every session starts from scratch.

---

## 6. Healing Loop — Learning from Failures

When something goes wrong, the healing loop captures it as a pattern for future reference.

**Try it:**
```bash
# When a task hits issues:
fw task update T-XXX --status issues --reason "API timeout"
fw healing diagnose T-XXX
# After fixing:
fw healing resolve T-XXX --mitigation "Added retry logic"
```

**Read more:**
- [Deep-dive: Healing Loop](../articles/deep-dives/05-healing-loop.md)
- [Generated article: Healing subsystem](../generated/articles/healing-prompt.md)

**Key concept:** Failures are learning events (Directive 1: Antifragility). The healing loop ensures the same failure doesn't repeat.

---

## What's Next?

You now understand the core governance cycle: **Task → Code → Commit → Audit → Handover → Heal**.

To go deeper:
- [Contributor Track](02-contributor.md) — How subsystems connect internally
- [Agent Implementer Track](03-agent-implementer.md) — Building new agent integrations
- [Component Fabric explorer](http://localhost:3000/fabric) — Interactive topology map
