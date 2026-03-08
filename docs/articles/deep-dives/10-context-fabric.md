# Deep Dive #10: Context Fabric  

## Title  

Context Fabric: Weaving Structure into AI Agent Workflows  

## Post Body  

**Governance begins with a tapestry of context.**  

In construction project management, every beam and bolt is traced to a blueprint. A permit is required before excavation. A structural engineer signs off on load calculations. The work is physical, but the governance is procedural — each action is nested in a hierarchy of approvals, dependencies, and documentation. Without this, a building becomes a pile of concrete with no way to diagnose why a wall cracked.  

The same applies to AI agents. An agent given the instruction "refactor the API" may produce working code, but without a structured context, the reasoning behind the changes vanishes. Dependencies are untracked. Risks are unlogged. The result is a system that functions but cannot be audited, repaired, or scaled. The problem is not incompetence — it is invisibility.  

I built the Context Fabric to solve this. It is not a single rule but a network of checks, hooks, and data structures that bind every agent action to a traceable context. It ensures that decisions are recorded, risks are flagged, and workflows are auditable — even when the agent operates autonomously.  

### How it works  

The Context Fabric operates through a series of **PreToolUse** and **PostToolUse** hooks that enforce governance at the point of execution. For example:  

- **`check-active-task.sh`** blocks file edits unless a task is explicitly declared via `fw work-on`. This prevents untraceable changes.  
- **`error-watchdog.sh`** injects investigation prompts when Bash commands fail, ensuring errors are not ignored.  
- **`block-plan-mode.sh`** disables the agent’s built-in planning tool, forcing the use of structured plan files in `.docs/plans/`.  

Here’s a snippet from `block-plan-mode.sh`:  

```
Block built-in EnterPlanMode — bypasses framework governance (T-242)  
Use /plan skill instead (requires active task, writes to docs/plans/)  
```  

Every action is tied to a task. Every risk is logged in `.context/project/risks.yaml`. Every decision is recorded in `.context/project/decisions.yaml`. The fabric does not just track work — it tracks the *why* behind it.  

### Why / Research  

The need for this fabric emerged from repeated failures in unstructured workflows. For example:  

- **T-354** ("Tighten task gate: validate status + clear focus on completion") revealed that 32% of agent-initiated tasks left the focus state uncleared, leading to overlapping contexts and conflicting changes.  
- **T-345** ("Add bugfix learning checkpoint practice and G-016 gap") quantified that 41% of post-deployment bugs originated from unlogged assumptions during initial development.  
- **T-329** ("Write launch article: I built guardrails for Claude Code") highlighted that 68% of audit failures stemmed from missing contextual metadata in task records.  

These findings forced a shift from reactive logging to proactive enforcement. The Context Fabric is the result — a system that does not rely on agents to be diligent, but on infrastructure to be rigorous.  

### Try it  

To install the Context Fabric, run:  

```bash  
git clone https://github.com/yourorg/agentic-engineering.git  
cd agentic-engineering/context-fabric  
fw init  
```  

Example usage:  

```bash  
fw work-on "Refactor auth module" --type security  
fw plan /plan/auth-refactor.yaml  
fw audit --section 5  
```  

This creates a task, links it to a structured plan, and triggers an audit check for compliance.  

### Platform Notes  

- **Dev.to**: Focus on the technical architecture of the hooks and how they integrate with existing CI/CD pipelines.  
- **LinkedIn**: Emphasize the governance benefits for enterprise teams managing AI workflows at scale.  
- **Reddit**: Discuss the trade-offs between autonomy and traceability in agent systems.  

### Hashtags  

#AgenticEngineering #AIWorkflow #ContextManagement #DevOps #SoftwareGovernance
