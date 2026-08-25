---
name: aef-assistant
description: >-
  Expert guide and operational workflows for the Agentic Engineering Framework (AEF).
  Use when interacting with AEF tasks, governance gates (Tier 0, task focus), inceptions,
  BVP scoring, component fabric, memory recall, subagents, and TermLink mesh.
---

# Agentic Engineering Framework (AEF) Antigravity Skill

This skill teaches Antigravity / OpenGravity (AGY) agents and subagents how to navigate and operate within an AEF-governed repository.

## Core Directives & Invariants

1. **P-002: Task-First Structural Enforcement**
   - No source code or configuration modifications without an active task in `started-work` state.
   - Run `bin/fw work-on "<task name>" --type build` or `bin/fw work-on T-XXX` to establish focus.
   - Every git commit MUST reference a task ID: `git commit -m "T-XXX: <summary>"`.

2. **Tier 0 Protection & Human Sovereignty**
   - Destructive commands (`rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`) are gated at Tier 0.
   - Never attempt to approve your own work. Ask the human operator to run `bin/fw tier0 approve` or record decisions.

3. **Inceptions & Architecture Exploration**
   - Use `bin/fw inception start "<name>"` for architecture, spikes, or strategic decisions.
   - Declare open questions (`- **IW-N: <question>**`) with confidence ratings (0-3).
   - Inceptions end in a human decision (`bin/fw inception decide T-XXX go|no-go|defer`).

4. **Component Fabric & Dependency Tracking**
   - View fabric graph: `bin/fw fabric overview`
   - Check architectural drift: `bin/fw fabric drift`
   - Register components: `bin/fw fabric register`

5. **Subagent Delegation & Concurrency**
   - When spawning subagents via `invoke_subagent`, always pass the current Task ID (`T-XXX`) in the initial prompt so the subagent operates within the task boundary.
   - Use branch workspaces for isolated experiments and share workspaces for read-heavy investigations.

6. **TermLink Cross-Terminal & Multi-Agent Mesh**
   - Check status: `termlink list --json`
   - Interact with workers: `termlink interact <session> "<command>" --json`
   - Send PTY inputs: `termlink pty inject <session> "<prompt>" --enter`
   - Post results to AEF Bus: `bin/fw bus post --task T-XXX --agent antigravity --summary "<summary>"`

7. **Project Memory & Continuity**
   - Add learnings: `bin/fw context add-learning "<learning>" --task T-XXX`
   - Add decisions: `bin/fw context add-decision "<decision>" --task T-XXX`
   - Session handover: `bin/fw handover --commit`
