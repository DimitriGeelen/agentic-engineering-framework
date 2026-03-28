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

## SUBSYSTEM: audit
Components: 3

### Components
- **plugin-audit** (script) @ `agents/audit/plugin-audit.sh` — Scans enabled Claude Code plugins for task-system awareness. Classifies each skill/agent/command as TASK-AWARE, TASK-SILENT, or TASK-OVERRIDING based on framework governance integration. [0 deps, 1 dependents]
- **self-audit** (script) @ `agents/audit/self-audit.sh` — Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. [10 deps, 0 dependents]
- **audit-yaml-validator** (script) @ `agents/audit/audit.sh` — Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. [5 deps, 3 dependents]

### Source Code Headers (key components)

**plugin-audit:**
```
Plugin Task-Awareness Audit
T-067: Scans enabled Claude Code plugins for task-system awareness
Classifies each skill/agent/command as:
TASK-AWARE    — References task system (task, fw work-on, TaskCreate, etc.)
TASK-SILENT   — No task references, no authority claims (informational)
```

**self-audit:**
```
Self-Audit — Standalone Framework Integrity Check
Verifies Layers 1-4 of the Agentic Engineering Framework
without depending on fw CLI (solves chicken-and-egg problem).
Usage:
agents/audit/self-audit.sh                 # Run from framework root
```

**audit-yaml-validator:**
```
Audit Agent - Mechanical Compliance Checks
Evaluates framework compliance against specifications
Usage:
audit.sh                              # Full audit with terminal output
audit.sh --section structure,quality   # Run only specified sections
```

### Framework Documentation (CLAUDE.md)
**Location:** `agents/audit/`

**When to use:** Periodically check framework compliance. Run after completing work or when suspecting drift.

```bash
./agents/audit/audit.sh
```

**Exit codes:** 0=pass, 1=warnings, 2=failures

### Task History (episodic memory)
- **T-241**: Wire discovery findings into session-start and Watchtower — T-200: Create 4 build tasks with rich context from discovery research. Wire discovery findings into session-start and Wa
- **T-248**: Implement remaining discovery jobs D6 D9 D10 D11 D12 — Implement D6 D9 D10 D11 D12 — complete 12/12 discovery catalog
- **T-249**: Refine D5 lifecycle anomaly detection to reduce false positive rate — Refine D5 lifecycle anomaly detection — 8 FPs to 1 with commit+type filters
- **T-275**: Pre-deploy quality gate — audit section + gated fw deploy — Pre-deploy quality gate — audit section + gated fw deploy
- **T-285**: Write framework self-audit prompt for cross-project deployment — Framework self-audit & remediation prompt for cross-project deployment. Enrich self-audit prompt with context, bootstrap
- **T-286**: Build fw self-audit CLI command and standalone script — Add standalone self-audit script + fw self-audit CLI route. Register self-audit.sh component card
- **T-301**: Add audit grace period for new projects — Add audit grace period for new projects (grace_warn/grace_fail)
- **T-346**: Add bugfix-learning coverage ratio to audit section 5 — T-346, T-347: Add bugfix-learning audit check and fw fix-learned shortcut
- **T-347**: Build fw fix-learned shortcut for fast learning capture — T-346, T-347: Add bugfix-learning audit check and fw fix-learned shortcut
- **T-368**: Add fabric drift check to fw audit — Add fabric drift check to audit structure section

---

## INSTRUCTIONS

Write Deep Dive #17: Audit

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
