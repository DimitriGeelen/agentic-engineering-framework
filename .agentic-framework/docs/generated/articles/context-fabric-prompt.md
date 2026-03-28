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

## SUBSYSTEM: context-fabric
Components: 26

### Components
- **block-plan-mode** (script) @ `agents/context/block-plan-mode.sh` — PreToolUse hook that blocks EnterPlanMode tool calls. Enforces D-027 (plan mode prohibition) by returning exit code 2 when agent attempts to use built-in plan mode. [1 deps, 0 dependents]
- **bus-handler** (script) @ `agents/context/bus-handler.sh` — Processes incoming bus messages from the inbox directory. Triggered by systemd.path when files appear in .context/bus/inbox/. Routes typed YAML envelopes to appropriate handlers for sub-agent result management. [1 deps, 0 dependents]
- **check-active-task** (script) @ `agents/context/check-active-task.sh` — Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools [0 deps, 2 dependents]
- **check-dispatch** (script) @ `agents/context/check-dispatch.sh` — Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). [1 deps, 2 dependents]
- **check-tier0** (script) @ `agents/context/check-tier0.sh` — Tier 0 Enforcement Hook — PreToolUse gate for Bash tool [0 deps, 1 dependents]
- **error-watchdog** (script) @ `agents/context/error-watchdog.sh` — Error Watchdog — PostToolUse hook for Bash error detection [0 deps, 1 dependents]
- **decision** (script) @ `agents/context/lib/decision.sh` — Context Agent - add-decision command [0 deps, 1 dependents]
- **episodic** (script) @ `agents/context/lib/episodic.sh` — Context Agent - generate-episodic command [0 deps, 1 dependents]
- **focus** (script) @ `agents/context/lib/focus.sh` — Context Agent - focus command [0 deps, 1 dependents]
- **init** (script) @ `agents/context/lib/init.sh` — Context Agent - init command [0 deps, 1 dependents]
- **pattern** (script) @ `agents/context/lib/pattern.sh` — Context Agent - add-pattern command [0 deps, 1 dependents]
- **status** (script) @ `agents/context/lib/status.sh` — Context Agent - status command [0 deps, 1 dependents]
- **post-compact-resume** (script) @ `agents/context/post-compact-resume.sh` — Session Resume Hook — Reinject structured context on session recovery [1 deps, 0 dependents]
- **pre-compact** (script) @ `agents/context/pre-compact.sh` — Pre-Compaction Hook — Save structured context before lossy compaction [1 deps, 0 dependents]
- **observe** (script) @ `agents/observe/observe.sh` — Observe Agent - Lightweight observation capture [1 deps, 1 dependents]
- **resume** (script) @ `agents/resume/resume.sh` — Resume Agent - Post-compaction recovery and state synchronization [0 deps, 1 dependents]
- **context-dispatcher** (script) @ `agents/context/context.sh` — Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) [9 deps, 4 dependents]
- **assumptions** (data) @ `.context/project/assumptions.yaml` — Project assumption register. Tracks assumptions made during inception and build tasks, with validation status and evidence. [0 deps, 0 dependents]
- **controls** (data) @ `.context/project/controls.yaml` — Control register tracking framework enforcement mechanisms (gates, hooks, checks) and their implementation status. [0 deps, 0 dependents]
- **decisions** (data) @ `.context/project/decisions.yaml` — Decision log recording architectural and process decisions with rationale and rejected alternatives. [0 deps, 0 dependents]
- **directives** (data) @ `.context/project/directives.yaml` — Constitutional directives defining framework priorities: antifragility, reliability, usability, portability. [0 deps, 0 dependents]
- **gaps** (data) @ `.context/project/gaps.yaml` — Spec-reality gap register tracking structural flaws between documented behavior and actual implementation. [0 deps, 0 dependents]
- **issues** (data) @ `.context/project/issues.yaml` — Issue tracker for known problems and their resolution status. [0 deps, 0 dependents]
- **metrics-history** (data) @ `.context/project/metrics-history.yaml` — Historical metrics snapshots tracking task completion rates, commit velocity, and project health over time. [0 deps, 0 dependents]
- **practices** (data) @ `.context/project/practices.yaml` — Graduated practices promoted from learnings. Codified ways of working that have proven effective across multiple tasks. [0 deps, 0 dependents]
- **risks** (data) @ `.context/project/risks.yaml` — Risk register tracking identified risks with severity, mitigation plans, and current status. [0 deps, 0 dependents]

### Source Code Headers (key components)

**block-plan-mode:**
```
Block built-in EnterPlanMode — bypasses framework governance (T-242)
Use /plan skill instead (requires active task, writes to docs/plans/)
```

**bus-handler:**
```
bus-handler.sh — Process incoming bus messages from inbox
Triggered by systemd.path when files appear in .context/bus/inbox/
Part of: Agentic Engineering Framework (T-110 spike)
```

**check-active-task:**
```
Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools
Blocks file modifications when no active task is set in focus.yaml.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
```

**check-dispatch:**
```
Dispatch Guard — PostToolUse hook for Task/TaskOutput result size
Warns when sub-agent results exceed safe thresholds (G-008 enforcement)
Three incidents (T-073, T-158, T-170) proved that unbounded tool output
crashes sessions. This hook provides a structural warning layer.
Detection:
```

**check-tier0:**
```
Tier 0 Enforcement Hook — PreToolUse gate for Bash tool
Detects destructive commands and blocks them unless explicitly approved.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
```

**error-watchdog:**
```
Error Watchdog — PostToolUse hook for Bash error detection
Detects failed Bash commands and injects investigation reminder (L-037/FP-007)
When a Bash command fails with a high-confidence error pattern, this hook
outputs JSON with additionalContext telling the agent to investigate the
root cause before proceeding — structural enforcement of CLAUDE.md §Error Protocol.
```

### Task History (episodic memory)
- **T-298**: Fix fw init suggested commands to recommend fw work-on — Recommend fw work-on in first-session welcome message
- **T-323**: Add timeout to focus.sh semantic search calls — Add timeout to focus.sh semantic search calls (10s recall, 15s briefing)
- **T-324**: Fix OneDev-to-GitHub cascade and exclude buildspec from GitHub — Exclude .onedev-buildspec.yml from git tracking (ring20-specific). Fill handover TODOs to unblock pre-push audit. Re-tra
- **T-329**: Write launch article: I built guardrails for Claude Code — Draft launch article — I built guardrails for Claude Code. Rewrite article in author voice — Shell governance framing. A
- **T-345**: Add bugfix learning checkpoint practice and G-016 gap — Add Bug-Fix Learning Checkpoint practice and register G-016. Update ACs and verification commands. Task completed — prac
- **T-346**: Add bugfix-learning coverage ratio to audit section 5 — T-346, T-347: Add bugfix-learning audit check and fw fix-learned shortcut
- **T-347**: Build fw fix-learned shortcut for fast learning capture — T-346, T-347: Add bugfix-learning audit check and fw fix-learned shortcut
- **T-348**: Fix update-task.sh sed failing on macOS BSD sed — Replace all sed -i calls with portable _sed_i helper. Fix audit trends — retroactive ACs for T-319/T-320, fill handover.
- **T-354**: Tighten task gate: validate status + clear focus on completion — Tighten task gate — validate status + clear focus on completion
- **T-367**: Auto-generate watch-patterns.yaml on fw context init — Auto-generate watch-patterns.yaml on fw context init

---

## INSTRUCTIONS

Write Deep Dive #10: Context Fabric

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
