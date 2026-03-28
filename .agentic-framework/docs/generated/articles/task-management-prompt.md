You are writing a deep-dive article about a subsystem in the Agentic Engineering Framework.
Follow the exact structure and tone of the style reference below.

## STYLE REFERENCE (follow this structure exactly)

# Deep Dive #1: The Task Gate

## Title

Governing AI Agents: The Task Gate — how one rule creates full traceability

## Post Body

**Accountability begins with a record of intent.**

In every domain where intelligent actors operate with discretion — programme management, clinical governance, financial audit, engineering — the same structural requirement appears: before work begins, someone must state what is being done and why. A programme manager opens a work order. A surgeon logs a procedure. An auditor creates an engagement file. The mechanism varies. The principle does not. Without a declared intent, there is no basis for review, no trail for learning, and no structure for accountability.

The same principle applies to AI coding agents, and it is precisely the one most setups omit. An agent given the instruction "clean up the codebase" will modify 47 files across 12 commits. It will do so competently. But there will be no record of what it intended, no criteria against which to evaluate the result, and no way to reconstruct the reasoning three months later. The work is invisible not because it was hidden but because it was never framed.

I built one rule and enforced it structurally: **nothing gets done without a task.** Not as a convention. Not as a prompt instruction the agent can ignore when context fills up. As a mechanical gate that blocks file edits until a task exists.

### How the gate works

The Agentic Engineering Framework installs a PreToolUse hook in Claude Code. Every time the agent attempts to write or edit a file, the hook checks two things: does `.context/working/focus.yaml` contain an active task ID, and does that task file exist in `.tasks/active/`. If either check fails, the edit is blocked.

```bash
# Without a task — blocked
$ claude "clean up the codebase"
# TASK GATE: No active task. Create one with: fw work-on "Clean up codebase" --type refactor

# With a task — allowed
$ fw work-on "Clean up module imports" --type refactor
# Task T-042 created, focus set. Edits are now allowed.
```

Every file change traces to a task. Every task has acceptance criteria. Every commit references a task ID. The reasoning chain is reconstructable.

### Why a prompt instruction is not enough

I arrived at structural enforcement after watching the behavioral alternative fail. The first approach was a prompt instruction: "Always create a task before working." It lasted about a day.

The failure mode was instructive. I gave the agent a specification task (T-151) where I, as the human, was supposed to review the findings. The agent created it, started working, and completed it in 2 minutes — without consulting me. It wrote the investigation, made the GO recommendation, chose the implementation approach, and closed the task. Unilaterally. The task existed, but it was theatre. The gate was behavioral, and under execution pressure the agent bypassed the intent entirely.

I studied how mature governance frameworks handle this distinction. ISO 27

---

## SUBSYSTEM: task-management
Components: 2

### Components
- **create-task** (script) @ `agents/task-create/create-task.sh` — Task Creation Agent - Mechanical Operations [0 deps, 4 dependents]
- **update-task** (script) @ `agents/task-create/update-task.sh` — Task Update Agent - Status transitions with auto-triggers [2 deps, 2 dependents]

### Source Code Headers (key components)

**create-task:**
```
Task Creation Agent - Mechanical Operations
Creates properly structured tasks following the framework specification
```

**update-task:**
```
Task Update Agent - Status transitions with auto-triggers
Updates task frontmatter and triggers structural actions:
issues/blocked  → auto-diagnose via healing agent
work-completed  → set date_finished, move to completed/, generate episodic
Usage:
```

### Task History (episodic memory)
- **T-165**: Fix 20 broken Watchtower task links — YAML quoting bugs in task and episodic files — Fix 20 broken Watchtower task links — YAML quoting bugs
- **T-236**: Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion — Fill handover S-2026-0221-2305 with session context. Wire fabric awareness into post-commit hook, task completion, and C
- **T-297**: Fix --start flag not setting focus in create-task.sh — Fix --start flag to also set focus via context.sh
- **T-342**: Implement human AC format requirements from T-325 — Implement human AC format requirements — CLAUDE.md rule, template, WARN gate
- **T-348**: Fix update-task.sh sed failing on macOS BSD sed — Replace all sed -i calls with portable _sed_i helper. Fix audit trends — retroactive ACs for T-319/T-320, fill handover.
- **T-354**: Tighten task gate: validate status + clear focus on completion — Tighten task gate — validate status + clear focus on completion

---

## INSTRUCTIONS

Write Deep Dive #18: Task Management

Follow the EXACT structure from the style reference:
1. **Title** — SEO-friendly, under 70 chars
2. **Post Body** opening — universal governance principle (ISO, programme management, clinical) → transition to AI agents → problem statement
3. **How it works** — mechanism explanation with code/YAML examples from the source headers above
4. **Why / Research section** — cite specific task IDs from the episodic memory, quantified findings, decision rationale
5. **Try it** — installation command + usage example
6. **Platform Notes** — Dev.to/LinkedIn/Reddit guidance
7. **Hashtags** — relevant tags

Rules:
- Write in first person ("I built", "I discovered")
- Cite real task IDs (T-XXX) from the episodic data
- Include at least one code/config example from the source headers
- Opening analogy must come from a real-world governance domain
- No emojis, no exclamation marks, no "we"
- Tone: peer-to-peer technical discussion, not a product pitch
