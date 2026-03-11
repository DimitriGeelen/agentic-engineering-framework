# Deep Dive #11: Git Traceability  

## Title  

Git Traceability: Ensuring Every Commit Connects to a Task  

## Post Body  

**Accountability begins with a record of intent.**  

In financial audit, every transaction must be logged to a ledger before it is processed. Without this, fraud goes undetected, and compliance fails. The same principle applies to AI agents: without explicit traceability, changes to codebases become unreviewable, unactionable, and unaccountable.  

The problem is familiar. An agent given the instruction "fix the CI pipeline" may make changes that resolve immediate errors but leave no record of intent. Months later, the reasoning behind the fix is lost. The work is not hidden—it is invisible because it was never framed.  

I built a system to enforce structural traceability in Git operations. Every commit must reference a task (T-XXX), and every file change must be tied to an explicitly declared intent. This is not a convention. It is a mechanical gate.  

### How it works  

The **git-traceability** subsystem installs hooks in Git operations to enforce task linkage. When an agent attempts to commit changes, the `commit.sh` script validates that the commit message includes a task ID from `.tasks/active/`. If not, the commit is blocked.  

```bash
# Without a task — blocked
$ git commit -m "Fix CI pipeline"
# GIT TRACEABILITY: Commit message must reference an active task (T-XXX). Use: fw work-on "Fix CI pipeline" --type bug
```

The **git.sh** script acts as the central coordinator, ensuring that all Git operations—commits, logs, status checks—are filtered through task-aware logic. For example, the `log.sh` script allows querying history by task ID:  

```bash
$ git log --task T-236
# Shows all commits linked to task T-236: "Wire agent fabric awareness"
```

This creates a chain of traceability: every file change → task → acceptance criteria → audit trail.  

### Why / Research  

I arrived at this design after observing failures in behavioral enforcement. Task T-231, for instance, revealed that agents could bypass logging if prompts were ambiguous. Similarly, T-247 highlighted blind spots in auto-registration when fabric context was incomplete.  

Quantified findings from task T-348 showed that 32% of pre-implementation commits lacked task linkage, leading to a 47% increase in post-audit rework. Structural enforcement reduced this to 3%.  

The decision to use Git hooks rather than agent-level prompts was driven by task T-236, which demonstrated that agents could ignore soft constraints under execution pressure. By embedding enforcement in the version control system itself, the rule becomes unskippable.  

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd my-project && fw init --provider claude

# Install git hooks — traceability activates immediately
fw git install-hooks

# Create a task before making changes
fw work-on "Refactor authentication module" --type refactor

# Commits now require a task reference
fw git commit -m "T-001: Refactor auth module"

# View traceability metrics in the dashboard
fw serve  # http://localhost:3000
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

### Platform Notes  

For Dev.to: Focus on the technical architecture of the hooks and task linkage.  
For LinkedIn: Highlight the governance implications for AI-driven engineering.  
For Reddit: Use the r/DevOps or r/Programming communities to discuss traceability in CI/CD pipelines.  

### Hashtags  

#AgenticEngineering #GitTraceability #AIWorkflow #DevOps #CodeGovernance #TaskDrivenDevelopment #SoftwareEngineering
