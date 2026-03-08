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

## SUBSYSTEM: component-fabric
Components: 7

### Components
- **fabric** (script) @ `agents/fabric/fabric.sh` — Fabric Agent - Component topology system for codebase self-awareness [6 deps, 2 dependents]
- **drift** (script) @ `agents/fabric/lib/drift.sh` — Fabric Agent - drift detection commands [0 deps, 1 dependents]
- **query** (script) @ `agents/fabric/lib/query.sh` — Fabric Agent - query commands [0 deps, 1 dependents]
- **register** (script) @ `agents/fabric/lib/register.sh` — Fabric Agent - register and scan commands [0 deps, 1 dependents]
- **summary** (script) @ `agents/fabric/lib/summary.sh` — Fabric Agent - summary and onboarding commands [0 deps, 1 dependents]
- **traverse** (script) @ `agents/fabric/lib/traverse.sh` — Fabric Agent - graph traversal commands [0 deps, 1 dependents]
- **ui** (script) @ `agents/fabric/lib/ui.sh` — Fabric Agent - UI query commands [0 deps, 1 dependents]

### Source Code Headers (key components)

**fabric:**
```
Fabric Agent - Component topology system for codebase self-awareness
Commands:
register <path>     Create component card for a file
scan                Batch-create skeleton cards for unregistered files
search <keyword>    Search components by tags, name, purpose
```

**drift:**
```
Fabric Agent - drift detection commands
Implements: fw fabric drift, fw fabric validate
```

**query:**
```
Fabric Agent - query commands
Implements: fw fabric search, fw fabric get, fw fabric deps
```

**register:**
```
Fabric Agent - register and scan commands
Implements: fw fabric register, fw fabric scan
```

**summary:**
```
Fabric Agent - summary and onboarding commands
Implements: fw fabric overview, fw fabric subsystem, fw fabric stats
```

**traverse:**
```
Fabric Agent - graph traversal commands
Implements: fw fabric impact, fw fabric blast-radius
```

### Framework Documentation (CLAUDE.md)
The Component Fabric (`.fabric/`) is a structural topology map of every significant file in the framework. It enables impact analysis, dependency tracking, and onboarding.

### When to Use

- **Before modifying a file:** `fw fabric deps <path>` — see what depends on it and what it depends on
- **Before committing:** `fw fabric blast-radius` — see downstream impact of your changes
- **After creating new files:** `fw fabric register <path>` — create a component card
- **Periodic health check:** `fw fabric drift` — detect unregistered, orphaned, or stale components

### Key Commands

| Command | Purpose |
|---------|---------|
| `fw fabric overview` | Compact subsystem summary (12 subsystems, ~99 components) |
| `fw fabric deps <path>` | Show dependencies for a file |
| `fw fabric impact <path>` | Full transitive downstream chain |
| `fw fabric blast-radius [ref]` | Downstream impact of a commit |
| `fw fabric search <keyword>` | Search by tags, name, purpose |
| `fw fabric drift` | Detect unregistered/orphaned/stale |
| `fw fabric register <path>` | Create component card for a file |

### Component Cards

Each component has a YAML card in `.fabric/components/` with: id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by. Cards are the source of truth for structural relationships.

### Web UI

The Watchtower web UI at `/fabric` provides: subsystem overview, component table with filtering, dependency graph visualization, and component detail pages.

### Task History (episodic memory)
- **T-208**: Component Fabric — agent structure and fw routing — Complete — fabric agent structure, all 12 commands, fw routing. Fix verification SIGPIPE (grep -q → grep -c)
- **T-214**: Component Fabric — batch-register all AEF components — Batch-register 95 AEF components, 12 subsystems, 91% coverage
- **T-361**: Add docs field to Component Fabric cards + Watchtower rendering — Add docs field to 24 fabric cards + Watchtower rendering + traverse.sh safety fix
- **T-369**: Make fabric subsystem inference configurable — Make fabric subsystem inference configurable via subsystem-rules.yaml
- **T-370**: Document depends_on edge format in fabric skeleton card — Document depends_on edge format in fabric skeleton card

---

## INSTRUCTIONS

Write Deep Dive #13: Component Fabric

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
