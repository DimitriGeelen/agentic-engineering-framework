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

## SUBSYSTEM: framework-core
Components: 16

### Components
- **preamble** (template) @ `agents/dispatch/preamble.md` — Mandatory dispatch preamble — output rules for sub-agents to prevent context explosion (T-073). Requires disk writes, <=5 line responses. [0 deps, 1 dependents]
- **test-onboarding** (script) @ `agents/onboarding-test/test-onboarding.sh` — End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. [2 deps, 0 dependents]
- **claude-fw** (script) @ `bin/claude-fw` — Claude Code wrapper with auto-restart support. Runs claude normally, then checks for a restart signal file written by checkpoint.sh when auto-handover fires at critical budget. If found and fresh, auto-restarts with claude -c to continue seamlessly. [1 deps, 0 dependents]
- **fw** (script) @ `bin/fw` — Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. [21 deps, 0 dependents]
- **ask** (script) @ `lib/ask.sh` — fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection. [1 deps, 0 dependents]
- **assumption** (script) @ `lib/assumption.sh` — fw assumption - Assumption tracking [0 deps, 1 dependents]
- **bus** (script) @ `lib/bus.sh` — fw bus - Task-scoped result ledger for sub-agent communication [0 deps, 1 dependents]
- **first-run** (script) @ `lib/first-run.sh` — First-run experience walkthrough after fw init. Guides new users through governance cycle: create task, make commit, run audit. Auto-triggered when TTY detected. [1 deps, 0 dependents]
- **harvest** (script) @ `lib/harvest.sh` — fw harvest - Collect learnings from projects back into the framework [0 deps, 1 dependents]
- **inception** (script) @ `lib/inception.sh` — fw inception - Inception phase workflow [0 deps, 1 dependents]
- **init** (script) @ `lib/init.sh` — fw init - Bootstrap a new project with the Agentic Engineering Framework [2 deps, 3 dependents]
- **preflight** (script) @ `lib/preflight.sh` — fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. [1 deps, 0 dependents]
- **promote** (script) @ `lib/promote.sh` — Graduation Pipeline — fw promote [0 deps, 1 dependents]
- **setup** (script) @ `lib/setup.sh` — fw setup - Guided onboarding wizard for new projects [4 deps, 1 dependents]
- **upgrade** (script) @ `lib/upgrade.sh` — fw upgrade - Sync framework improvements to a consumer project [1 deps, 1 dependents]
- **validate-init** (script) @ `lib/validate-init.sh` — Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. [1 deps, 0 dependents]

### Source Code Headers (key components)

**preamble:**
```
Mandatory Dispatch Preamble
```

**test-onboarding:**
```
Test Onboarding — End-to-End Flow Test for New Projects
Exercises the full onboarding path: init → first task → commit → audit → handover
Runs 8 checkpoints and reports PASS/WARN/FAIL for each.
Usage:
agents/onboarding-test/test-onboarding.sh              # Use temp dir (auto-cleanup)
```

**claude-fw:**
```
claude-fw — Claude Code wrapper with auto-restart support
Runs claude normally, then checks for a restart signal file
written by checkpoint.sh when auto-handover fires at critical budget.
If found (and fresh), auto-restarts with `claude -c` to continue.
Usage:
```

**fw:**
```
fw - Agentic Engineering Framework CLI
Single entry point for all framework operations.
Reads .framework.yaml from the project directory to resolve
FRAMEWORK_ROOT, then routes commands to the appropriate agent.
When run from a project that uses the framework as shared tooling,
```

**ask:**
```
fw ask — synchronous RAG+LLM wrapper (T-264)
Usage:
fw ask "How do I create a task?"
fw ask --json "What is the healing loop?"
fw ask --concise "List enforcement tiers"
```

**assumption:**
```
fw assumption - Assumption tracking
Manages project assumptions: register, validate, invalidate, list
```

### Task History (episodic memory)
- **T-348**: Fix update-task.sh sed failing on macOS BSD sed — Replace all sed -i calls with portable _sed_i helper. Fix audit trends — retroactive ACs for T-319/T-320, fill handover.
- **T-349**: Streamline fw init output for new users — WIP — quiet preflight + condensed init output. Streamline fw init to ~14 lines of clean output
- **T-352**: Fix hook path resolution in fw init for Homebrew installs — Fix hook path resolution in fw init for Homebrew installs
- **T-355**: Fix Homebrew Cellar path hardcoding in fw init — use opt symlink — Use Homebrew opt symlink instead of Cellar path in fw init
- **T-357**: Implement post-init validation with #@init: tags — Create build task for post-init validation with #@init: tags. Implement post-init validation with #@init: tags
- **T-359**: Rename Homebrew formula to avoid brocode/fw collision — Rename Homebrew formula from fw to agentic-fw — avoid brocode/fw collision. Bump version to 1.2.6, fix Cellar path detec
- **T-360**: Build fw test-onboarding: 8-checkpoint hybrid onboarding test — >
- **T-364**: Layer 1: Component reference doc generator — Build component reference doc generator — 127 docs from fabric cards
- **T-366**: Layer 2: AI-assisted subsystem article generator — Build AI-assisted subsystem article generator with Ollama integration
- **T-367**: Auto-generate watch-patterns.yaml on fw context init — Auto-generate watch-patterns.yaml on fw context init

---

## INSTRUCTIONS

Write Deep Dive #11: Framework Core

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
