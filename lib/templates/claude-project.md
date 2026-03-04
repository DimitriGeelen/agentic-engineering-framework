# CLAUDE.md

Claude Code integration for the Agentic Engineering Framework.
For the provider-neutral framework guide, see `FRAMEWORK.md`.

This file is auto-loaded by Claude Code. It contains the full operating guide
plus Claude Code-specific integration notes.

## Project Overview

**Project:** __PROJECT_NAME__

<!-- Add your project description, tech stack, and conventions below -->

## Tech Stack and Conventions

<!-- Define your project's tech stack, coding standards, and conventions here -->

## Project-Specific Rules

<!-- Add any project-specific rules that agents must follow -->

## Core Principle

**Nothing gets done without a task.** This is enforced structurally by the framework, not by agent discipline.

## Four Constitutional Directives (Priority Order)

All architectural decisions must trace back to these directives:

1. **Antifragility** — System strengthens under stress; failures are learning events
2. **Reliability** — Predictable, observable, auditable execution; no silent failures
3. **Usability** — Joy to use/extend/debug; sensible defaults; actionable errors
4. **Portability** — No provider/language/environment lock-in; prefer standards (MCP, LSP, OpenAPI)

## Authority Model

```
Human    →  SOVEREIGNTY  →  Can override anything, is accountable
Framework →  AUTHORITY   →  Enforces rules, checks gates, logs everything
Agent    →  INITIATIVE   →  Can propose, request, suggest — never decides
```

## Instruction Precedence

When multiple instruction sources conflict (CLAUDE.md, plugins, skills, user messages), this resolution order applies:

1. **Framework rules (this file)** — Core Principle, Authority Model, Enforcement Tiers, and Task System rules take absolute precedence. No plugin or skill can override "Nothing gets done without a task."
2. **User instructions** — Direct human instructions can override framework rules via Tier 2 (situational authorization with logging).
3. **Skills/plugins** — Apply AFTER framework gates are satisfied. A skill that says "invoke before any response" means: after verifying an active task exists. Skills enhance workflows; they do not replace framework governance.

**The practical rule:** Before following ANY skill or plugin workflow, first ensure a task exists and focus is set. If a skill's instructions conflict with creating a task first, the task wins.

**Why this matters:** Third-party plugins are not aware of project-specific governance. They will issue instructions like "implement now" or "code first, test first" without checking for task context. The agent must apply framework rules as a pre-filter before deferring to skill workflows.

## Task System

### File Structure

```
.tasks/
  active/      # In-progress tasks (e.g., T-042-add-oauth.md)
  completed/   # Finished tasks
  templates/   # Task templates by workflow type
```

### Task File Format

Tasks are Markdown with YAML frontmatter. Use `default.md` as template.

**Required frontmatter fields:**
- `id`, `name`, `description`, `status`, `workflow_type`, `horizon`, `owner`, `created`, `last_update`

### Horizon (Priority Scheduling)

The `horizon` field controls when a task should be considered for work:

| Value | Meaning | Handover behavior |
|-------|---------|-------------------|
| `now` | Ready to work on (default) | Appears first in Work in Progress, eligible for Suggested First Action |
| `next` | Ready after current work | Appears in Work in Progress, eligible for Suggested First Action |
| `later` | Parked/backlog — not yet | Appears last in Work in Progress, excluded from Suggested First Action |

**Rules:**
- Default horizon is `now` (tasks created via `fw work-on` or `fw task create`)
- Use `--horizon later` for tasks captured for future reference
- Use `fw task update T-XXX --horizon now` to promote a backlog task
- The handover agent sorts tasks by horizon and instructs the enricher to skip `later` tasks in suggestions

**Body sections:**
- Context (brief, link to design docs for substantial tasks)
- Acceptance Criteria (checkboxes — completion gate P-010)
- Verification (shell commands — verification gate P-011, see below)
- Decisions (only when choosing between alternatives; most tasks have none)
- Updates (auto-populated by git mining at completion; manual entries optional)

### Verification Gate (P-011)

The `## Verification` section contains shell commands that **must pass** before `work-completed` is allowed. This is a structural gate — the framework runs the commands mechanically, not the agent self-assessing.

**How it works:**
1. Agent writes verification commands in `## Verification` while working (knows what to check)
2. On `fw task update T-XXX --status work-completed`, update-task.sh extracts and runs each command
3. If any command exits non-zero → completion is **blocked** (same as unchecked AC)
4. `--force` bypasses the gate (with warning, logged)
5. Tasks without `## Verification` pass through (backward compatible)

**What to verify:**
- YAML/JSON files parse correctly: `python3 -c "import yaml; yaml.safe_load(open('file'))"`
- Web pages load: `curl -sf http://localhost:3000/page`
- Commands succeed: `fw doctor`
- Output contains expected content: `grep -q "expected" output.txt`

**Rules:**
- Lines starting with `#` are comments (skipped)
- Empty lines are ignored
- Each non-comment line is executed as a shell command
- First 5 lines of failure output are shown for debugging

### Task Lifecycle

```
Captured → Started Work ↔ Issues → Work Completed
```

### Workflow Types

| Type | Purpose | Typical Agent |
|------|---------|---------------|
| Specification | Define what to build | Specification Agent |
| Design | Determine how to build | Design Agent |
| Build | Create implementation | Coder Agent |
| Test | Verify correctness | Test Agent |
| Refactor | Improve existing code | Coder Agent |
| Decommission | Remove obsolete code | Deployment Agent |
| Inception | Explore problem, validate assumptions, go/no-go | Human / Any Agent |

## Task Sizing Rules

- **One task = one deliverable.** If a task has multiple independent spikes or deliverables, decompose it.
- **One bug = one task.** Never compound multiple independent bugs into a single ticket. Each bug has its own root cause, fix, and regression test. Compounding destroys causality traceability and dilutes episodic memory.
- **One inception = one question.** An inception task should explore one problem and produce one go/no-go decision. "Umbrella inceptions" that bundle independent explorations create all-or-nothing decisions and coarse progress tracking.
- **Target: fits in one session.** If a task's time-box exceeds 4 hours or requires 3+ sessions, it should be split.
- **Decomposition signal:** 3+ spikes in an exploration plan, or 3+ independent problem domains, means the task is too big.

## Enforcement Tiers

| Tier | Description | Bypass | Implementation |
|------|-------------|--------|----------------|
| 0 | Consequential actions (force push, hard reset, rm -rf /, DROP TABLE) | Human approval via `fw tier0 approve` | PreToolUse hook on Bash (`check-tier0.sh`) |
| 1 | All standard operations (default) | Create task or escalate to Tier 2 | PreToolUse hook on Write/Edit (`check-active-task.sh`) |
| 2 | Human situational authorization | Single-use, mandatory logging | Partial (git --no-verify + bypass log) |
| 3 | Pre-approved categories (health checks, status queries, git-status) | Configured | Spec only |

## Working with Tasks

When starting work (**BEFORE reading code, editing files, or invoking skills**):
1. Check for existing task or create new one following `zzz-default.md` template
2. Set status to `started-work`
3. Set focus: `fw context focus T-XXX`
4. THEN proceed with implementation (skills, code changes, etc.)
5. Record decisions in Decisions section ONLY when choosing between alternatives
6. Updates section is auto-populated at completion — manual entries optional

When encountering errors or unexpected behavior (**NEVER silently work around them**):
1. **STOP and investigate** — do not switch to an alternative path without understanding WHY the error occurred
2. Report the error and your investigation findings to the user
3. If the error is in framework tooling: fix it (this is higher priority than the current task)
4. If the error is environmental: document it and inform the user
5. Only after investigation may you proceed with an alternative approach
6. If the error seems minor but you cannot explain it: that is a signal, not noise — investigate anyway

When encountering task-level issues:
1. Set status to `issues`
2. Log error reference and healing loop suggestions
3. Record resolution when fixed for pattern learning

When discovering structural flaws (bugs in framework tooling, spec-reality gaps):
1. **Register first, fix second.** Add the flaw to `gaps.yaml` BEFORE or alongside the fix
2. Gaps persist in the register (visible in Watchtower, checked by audit); completed tasks archive and become invisible
3. Each independent bug gets its own task (see Task Sizing Rules: "One bug = one task")

When completing:
1. Verify all acceptance criteria met
2. If source files were changed: run `fw fabric blast-radius HEAD` to understand downstream impact
3. Record any design choices in the task's `## Decisions` section (auto-captured to context fabric on completion)
4. Set status to `work-completed`
5. Framework auto-generates episodic summary and captures decisions for future reference

## Context Integration

Tasks feed three memory types:
- **Working Memory** — Active task status and pending actions
- **Project Memory** — Patterns across all tasks (failure modes, effective approaches)
- **Episodic Memory** — Completed task histories for future reference

## Error Escalation Ladder

Graduated response from tactical to structural:
1. **A** — Don't repeat the same failure
2. **B** — Improve technique
3. **C** — Improve tooling
4. **D** — Change ways of working

### Proactive Level D: Operational Reflection

Not all improvement comes from failures. When you notice a practice repeating ad-hoc across 3+ tasks, consider codifying it:

1. **Mine** episodic memory for evidence of the pattern (how often, what worked, what broke)
2. **Assess** codification value — use inception go/no-go criteria
3. **Codify** if warranted: protocol in CLAUDE.md, templates in agents/, guidelines
4. **Record** as learning + decision + workflow pattern

**Trigger:** An organic question about "how we do X" + 3+ instances in episodic memory.

**Canonical example:** T-097 analyzed sub-agent dispatching across 96 tasks → discovered the real problem (result management, not agent specialization) → produced dispatch protocol (T-098) and prompt templates (T-099). The framework used its own episodic memory as the evidence base for an architectural decision.

## fw CLI (Primary Interface)

The `fw` command is the single entry point for all framework operations. It resolves paths, sets environment variables, and routes to agents.

```bash
fw help              # Show all commands
fw version           # Show version and paths
fw doctor            # Check framework health
fw audit             # Run compliance audit
fw context init      # Initialize session
fw git commit -m "T-XXX: description"
fw handover --commit # Generate and commit handover
fw task create --name "Fix bug" --type build --owner human
```

**Path resolution:** `fw` finds the framework via `bin/fw`'s location (inside framework repo) or via `.framework.yaml` in the project root (shared tooling mode).

## Agents

The framework includes agents for common operations. Each agent has a bash script (mechanical) and AGENT.md (intelligence/guidance). All agents can be invoked directly or via `fw`.

### Task Creation Agent

**Location:** `agents/task-create/`

**When to use:** Before starting any new work, create a task.

```bash
# Interactive mode
./agents/task-create/create-task.sh

# With arguments
./agents/task-create/create-task.sh --name "Fix bug" --type build --owner human --start
```

### Task Update (with auto-triggers)

**Location:** `agents/task-create/update-task.sh`

**When to use:** To change task status. Auto-triggers healing diagnosis on `issues`, and finalizes tasks on `work-completed`.

```bash
# Change status (auto-triggers healing if issues)
fw task update T-015 --status issues --reason "API timeout"

# Complete a task (auto: date_finished, move to completed/, generate episodic)
fw task update T-015 --status work-completed

# Change owner
fw task update T-015 --owner human
```

### Audit Agent

**Location:** `agents/audit/`

**When to use:** Periodically check framework compliance. Run after completing work or when suspecting drift.

```bash
./agents/audit/audit.sh
```

**Exit codes:** 0=pass, 1=warnings, 2=failures

### Session Capture Agent

**Location:** `agents/session-capture/`

**When to use:** MANDATORY before ending any session or switching context.

Review the checklist in `agents/session-capture/AGENT.md` and ensure:
- All discussed work has tasks
- All decisions are recorded
- All learnings are captured as practices
- All open questions are tracked

### Git Agent

**Location:** `agents/git/`

**When to use:** For all git operations that involve code changes. Enforces task traceability (P-002).

```bash
# Commit with task reference (required)
./agents/git/git.sh commit -m "T-003: Add bypass log"

# Task-aware status
./agents/git/git.sh status

# Install enforcement hooks (run once per repo)
./agents/git/git.sh install-hooks

# Log a bypass (when --no-verify was used)
./agents/git/git.sh log-bypass --commit abc123 --reason "Emergency hotfix"

# View task-filtered history
./agents/git/git.sh log --task T-003
./agents/git/git.sh log --traceability
```

### Handover Agent

**Location:** `agents/handover/`

**When to use:** MANDATORY at end of every session.

```bash
# Create handover (manual commit)
./agents/handover/handover.sh

# Create handover and auto-commit via git agent
./agents/handover/handover.sh --commit
```

Creates a forward-looking context document in `.context/handovers/` to enable the next session to continue seamlessly.

### Context Agent

**Location:** `agents/context/`

**When to use:** To manage the Context Fabric (persistent memory system).

```bash
# Initialize session (start of session)
./agents/context/context.sh init

# Show context state
./agents/context/context.sh status

# Set/show current focus
./agents/context/context.sh focus T-005
./agents/context/context.sh focus

# Record a learning
./agents/context/context.sh add-learning "Always validate inputs" --task T-014 --source P-001

# Record a pattern (failure/success/workflow)
./agents/context/context.sh add-pattern failure "API timeout" --task T-015 --mitigation "Add retry"

# Record a decision
./agents/context/context.sh add-decision "Use YAML" --task T-005 --rationale "Human readable"

# Generate episodic summary for completed task
./agents/context/context.sh generate-episodic T-014
```

Manages three memory types:
- **Working Memory** — Session state, current focus, priorities
- **Project Memory** — Patterns, decisions, learnings
- **Episodic Memory** — Condensed task histories

### Healing Agent

**Location:** `agents/healing/`

**When to use:** When a task encounters issues (status = `issues`). Implements the antifragile healing loop.

```bash
# Diagnose task issues and get recovery suggestions
./agents/healing/healing.sh diagnose T-015

# After fixing, record the resolution (adds pattern + learning)
./agents/healing/healing.sh resolve T-015 --mitigation "Added retry logic"

# Show all known failure patterns
./agents/healing/healing.sh patterns

# Check all tasks with issues
./agents/healing/healing.sh suggest
```

The healing loop:
1. **Classify** — Identifies failure type (code, dependency, environment, design, external)
2. **Lookup** — Searches for similar patterns in patterns.yaml
3. **Suggest** — Recommends recovery using Error Escalation Ladder
4. **Log** — Records resolution as pattern for future learning

### Resume Agent

**Location:** `agents/resume/`

**When to use:** After context compaction, returning from breaks, or when feeling lost about current state.

```bash
# Full state synthesis (use after compaction)
./agents/resume/resume.sh status

# Fix stale working memory
./agents/resume/resume.sh sync

# One-line summary
./agents/resume/resume.sh quick
```

Synthesizes current state from:
- **Handover** — "Where We Are" and suggested action
- **Working Memory** — Session, focus, may be stale
- **Git State** — Uncommitted changes, recent commits
- **Tasks** — Active tasks with status

## Component Fabric

The Component Fabric (`.fabric/`) is a structural topology map of every significant file in the framework. It enables impact analysis, dependency tracking, and onboarding.

### When to Use

- **Before modifying a file:** `fw fabric deps <path>` — see what depends on it and what it depends on
- **Before committing:** `fw fabric blast-radius` — see downstream impact of your changes
- **After creating new files:** `fw fabric register <path>` — create a component card
- **Periodic health check:** `fw fabric drift` — detect unregistered, orphaned, or stale components

### Key Commands

| Command | Purpose |
|---------|---------|
| `fw fabric overview` | Compact subsystem summary |
| `fw fabric deps <path>` | Show dependencies for a file |
| `fw fabric impact <path>` | Full transitive downstream chain |
| `fw fabric blast-radius [ref]` | Downstream impact of a commit |
| `fw fabric search <keyword>` | Search by tags, name, purpose |
| `fw fabric drift` | Detect unregistered/orphaned/stale |
| `fw fabric register <path>` | Create component card for a file |

### Component Cards

Each component has a YAML card in `.fabric/components/` with: id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by. Cards are the source of truth for structural relationships.

## Context Budget Management (P-009)

**Context is a finite, non-renewable resource within a session.** Treat it like a battery gauge.

### Commit Cadence Rule
- **Commit after every meaningful unit of work** (not just at session end)
- A "meaningful unit" = completing a subtask, finishing a file, or making a decision
- Each commit is a checkpoint: if context runs out, work up to the last commit is safe
- Target: at least one commit every 15-20 minutes of active work

### Handover Timing Rule
- **Generate handover AFTER work is done, not before**
- Never generate a skeleton handover "to fill in later" — the session may not survive to fill it
- When generating handover: fill in ALL [TODO] sections immediately in the same operation
- For mid-session checkpoints: `fw handover --checkpoint`

### Agent Output Discipline
- When using Task/Agent tools, request concise output (summaries, not raw data)
- See **Sub-Agent Dispatch Protocol** below for detailed rules on managing sub-agent results
- Prefer `fw resume quick` over `fw resume status` for routine checks
- Prefer `git log --oneline -5` over `git log -5`

### Work Proposal Rule
- **Before proposing the next unit of work, check context budget** (`checkpoint.sh status`)
- Below 60% (120K tokens): proceed normally
- 60-75% (120K-150K): propose only small, bounded tasks; commit first
- Above 75% (150K+): propose only wrap-up actions (commit, learnings, handover)
- Above 85% (170K+): handover immediately, no new work
- **This applies especially in autonomous mode** — without a human to catch the mistake, proposing work that can't complete in remaining context risks losing all uncommitted work

### Automated Monitoring (Claude Code)
- **Primary enforcement:** A PreToolUse hook runs `budget-gate.sh` which reads **actual token usage** from the session JSONL transcript and **blocks** Write/Edit/Bash at critical level (exit code 2)
- **Fallback:** A PostToolUse hook runs `checkpoint.sh` for warnings and auto-handover (T-136)
- Escalation ladder: **120K** ok→warn (note), **150K** warn→urgent (warning), **170K** urgent→critical (**BLOCK**)
- At critical, allowed: git commit/add, fw handover/task, reading files, Write/Edit to `.context/` `.tasks/` `.claude/` (wrap-up paths). Blocked: Write/Edit to source files, general Bash
- Status cached in `.context/working/.budget-status` (JSON: level, tokens, timestamp)
- Check current usage: `./agents/context/checkpoint.sh status`
- If no transcript is available, fails open (PostToolUse fallback handles it)

### Critical Protocol
- If you see a SESSION WRAPPING UP block: the session is wrapping up. Only wrap-up work is allowed.
- **Allowed:** git commit/add, fw handover, fw task update, Write/Edit to .context/.tasks/.claude/, reading files
- **Blocked:** Write/Edit to source files, general Bash commands
- Wrap up calmly — task files already have all essential state from continuous capture

## Sub-Agent Dispatch Protocol

When using Claude Code's Task tool to dispatch sub-agents (Explore, Plan, Code, etc.), follow these rules to manage context budget.

### Result Management Rules

**Content generators** (enrichment, file creation, report writing):
- Sub-agent MUST write output to disk (Write tool), NOT return full content
- Return only: file path + one-line summary
- This prevents context explosion from agents returning full file contents

**Investigators/researchers** (codebase exploration, root cause analysis):
- Return structured summaries with findings, NOT raw file contents
- Format: numbered findings with file:line references
- Keep return under 2K tokens per agent

**Auditors/reviewers** (compliance checks, code review):
- Write detailed report to file if >1K tokens
- Return summary + file path to orchestrator
- Include pass/warn/fail counts in summary

### Dispatch Guidelines

| Factor | Rule |
|--------|------|
| Max parallel agents | **5** |
| Token headroom | Leave **40K tokens** free for result ingestion before dispatching |
| When parallel | Tasks are independent, no shared files, no sequential dependency |
| When sequential | Tasks depend on prior results, or editing same files |
| Background agents | Use `run_in_background: true` for agents >2K tokens expected output |

### Prompt Template Structure

When dispatching sub-agents, include in the prompt:

1. **Scope**: Exactly what to investigate/produce (one clear deliverable)
2. **Framework context**: Relevant framework structure (task format, episodic template, etc.)
3. **Output format**: How to return results (write to file vs. return summary)
4. **Constraints**: Don't modify files outside scope, don't return raw data
5. **Token hint**: "Keep your response concise — the orchestrator has limited context budget"

### Result Ledger (`fw bus`)

The result ledger formalizes the "write to disk, return path + summary" convention into a protocol with typed YAML envelopes and automatic size gating. Use it for sub-agent dispatch:

```bash
# Sub-agent posts result (instead of returning full content)
fw bus post --task T-XXX --agent explore --summary "Found 3 issues" --result "inline data"
fw bus post --task T-XXX --agent code --summary "Wrote file" --blob /path/to/output

# Orchestrator reads manifest (5 lines instead of 25KB)
fw bus manifest T-XXX

# Orchestrator reads specific result if needed
fw bus read T-XXX R-001

# Cleanup after task completion
fw bus clear T-XXX
```

**Size gating:** Payloads < 2KB are inline. Payloads >= 2KB are auto-moved to `.context/bus/blobs/` and referenced.

### Dispatch Patterns (from project history)

**Parallel Investigation** (T-059, T-061, T-086): 3-5 Explore agents scan different aspects. Each returns structured findings. Orchestrator synthesizes.

**Parallel Audit** (T-072): 3 agents review different artifact categories. Each returns pass/warn/fail summary. Combined into report.

**Parallel Enrichment** (T-073): N agents each produce one file. MUST write to disk, return only path+summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.

**Sequential TDD** (T-058): Fresh agent per implementation task with review between.

## Agent Behavioral Rules

These rules govern agent behavior during work. They are structural expectations, not suggestions.

### Choice Presentation
Always present choices as a **numbered or lettered list** so the user can reply with just the identifier (e.g., "1" or "b"). Never present options as prose paragraphs.

### Autonomous Mode Boundaries
When the human says "proceed as you see fit", "go ahead", "do what you think is best", or similar broad directives, this delegates **initiative** (choosing what to work on), NOT **authority** (approving, completing, or bypassing). Specifically:

**Delegated (agent may do autonomously):**
- Choose which task to work on next
- Choose implementation approach within a task
- Run verification, tests, audits
- Commit completed work and report back

**NOT delegated (requires explicit human approval per action):**
- Completing human-owned tasks (`owner: human`)
- Using `--force` to bypass any gate (sovereignty, AC, verification)
- Changing task ownership away from human
- Destructive actions (Tier 0)
- Any action the sovereignty gate or structural enforcement blocks

**The rule:** If a structural gate blocks you, that gate exists precisely for moments like this. A broad directive does not override structural enforcement. Stop and ask.

### Commit Cadence and Check-In
After **every commit**, briefly report what was done and ask if the user wants to continue. Do not chain multiple commits without user interaction.

**Structural enforcement (T-139):** The `budget-gate.sh` PreToolUse hook reads actual token usage from the session transcript and **blocks** Write/Edit/Bash tool calls when context reaches critical level (>=150K tokens, ~75%). At critical, only git commit, fw handover, and read operations are allowed. The hook writes `.context/working/.budget-status` with current level (ok/warn/urgent/critical) for fast caching. PostToolUse `checkpoint.sh` remains as fallback for warnings and auto-handover.

### Inception Discipline
When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
3. **Do not write build artifacts** (production code, full apps) before `fw inception decide T-XXX go`
4. **The commit-msg hook enforces this** — after 2 exploration commits, further commits are blocked until a decision is recorded
5. After a GO decision, **create separate build tasks** for implementation — do not continue building under the inception task ID
6. **Research artifact first (C-001)** — When starting inception work, create `docs/reports/T-XXX-*.md` BEFORE conducting research. Update the file incrementally as dialogue produces findings. Commit after each dialogue segment. The thinking trail IS the artifact — conversations are ephemeral, files are permanent.
7. **Dialogue log (C-001 extension)** — For phases involving human dialogue, include a `## Dialogue Log` section in the research artifact. Record: questions the human posed, answers given, course corrections, and the outcome/decision that resulted.

### Web App Startup
When building a web application:
1. **Check port availability** before starting (`ss -tlnp | grep :PORT`)
2. **Start the app** and report the URL to the user
3. **Report access options** — localhost, LAN IP (for other devices), internet (if applicable)
4. Never leave a built web app unstarted without informing the user

### Constraint Discovery
For tasks involving hardware APIs (microphone, camera, GPS, Bluetooth):
1. **Research platform constraints first** before building (e.g., getUserMedia requires HTTPS or localhost)
2. **List constraints in the exploration plan** before writing code
3. **Test the API access path** in a minimal spike before building the full app

### Agent/Human AC Split (T-193)
Tasks may have `### Agent` and `### Human` sections under `## Acceptance Criteria`:
- **Agent ACs:** Criteria the agent can verify (code, tests, commands). P-010 gates on these.
- **Human ACs:** Criteria requiring human verification (UI behavior, subjective quality). Not blocking.
- **NEVER check a `### Human` AC.** Only the human may verify and check these boxes.
- When agent ACs pass but human ACs remain unchecked, the task enters **partial-complete**: stays in `active/` with `owner: human`.
- The human finalizes by checking their ACs and running `fw task update T-XXX --status work-completed`.

### Verification Before Completion
Before setting any task to `work-completed`:
1. Run all commands in the task's `## Verification` section
2. Check every `### Agent` acceptance criterion checkbox (or all ACs if no split headers)
3. If tests exist for the changed code, run them
4. Report results to user with pass/fail evidence
5. Do NOT call `fw task update --status work-completed` until all pass
6. The verification gate (P-011) enforces this structurally — this rule makes you check BEFORE hitting the gate

### Hypothesis-Driven Debugging
When encountering errors or unexpected behavior:
1. **State the symptom** in one sentence
2. **Form one hypothesis** for the root cause
3. **Design one test** to prove or disprove it (a command, a log check, a code read)
4. Run the test and report the result
5. If disproved, form the next hypothesis — max **3 hypotheses** before escalating to user
6. Never shotgun-debug (trying random fixes without understanding the cause)
7. After resolution, record the pattern: `fw healing resolve T-XXX --mitigation "what fixed it"`

## Plan Mode Prohibition

**NEVER use the built-in `EnterPlanMode` tool.** It bypasses all framework governance:
- No task gate — planning starts without a task
- No session init — Session Start Protocol is skipped entirely
- No research artifacts — plan files go to `.claude/plans/` (untracked, ephemeral)
- Its system prompt says "This supercedes any other instructions" — overriding CLAUDE.md
- Post-plan execution skips commit cadence, task updates, and check-ins

**Use `/plan` instead** — the framework's governance-aware planning skill that:
- Requires an active task (verified in Step 1)
- Writes to `docs/plans/` (tracked, committed)
- Respects instruction precedence

If you need to explore before planning, use the Explore agent or `/explore` skill.
If you need to plan implementation, create a task first, then use `/plan`.

## Session Start Protocol

**Before beginning any work:**
1. Initialize context: `fw context init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `fw context focus T-XXX`
5. Run `fw metrics` to see project status
6. If handover feedback section exists, fill it in

**Before ANY implementation (even if a skill says "start now"):**
1. Verify a task exists for the work: `fw work-on "name" --type build` or `fw work-on T-XXX`
2. Confirm focus is set in `.context/working/focus.yaml`
3. THEN proceed with implementation

This gate is non-negotiable. The PreToolUse hook will block Write/Edit without an active task. Use `/start-work` if unsure.

**Manual compaction (`/compact`):**
- Auto-compaction is disabled by design (D-027 — compaction destroys working memory)
- `/compact` is available for manual use when context is high and you want a clean slate
- The PreCompact hook automatically generates a handover before compaction
- The SessionStart:compact hook reinjects structured context into the fresh session
- After compaction, follow the recovery steps below

**After context compaction (mid-session recovery):**
1. Run resume: `fw resume status`
2. Sync working memory: `fw resume sync`
3. Continue from recommendations

## Quick Reference

| Action | fw command | Direct |
|--------|-----------|--------|
| **Start work** | **`fw work-on "name" --type build`** | Creates task + sets focus + starts work |
| Resume task | `fw work-on T-XXX` | Sets focus + status to started-work |
| Create task | `fw task create` | `./agents/task-create/create-task.sh` |
| Create with tags | `fw task create --tags "ui,api"` | `create-task.sh --tags "..."` |
| Update task | `fw task update T-XXX --status ...` | `./agents/task-create/update-task.sh T-XXX ...` |
| Add tags | `fw task update T-XXX --add-tag "ui"` | `update-task.sh T-XXX --add-tag "..."` |
| Set horizon | `fw task update T-XXX --horizon later` | `update-task.sh T-XXX --horizon later` |
| Commit changes | `fw git commit -m "T-XXX: ..."` | `./agents/git/git.sh commit -m "T-XXX: ..."` |
| Task-aware status | `fw git status` | `./agents/git/git.sh status` |
| Install git hooks | `fw git install-hooks` | `./agents/git/git.sh install-hooks` |
| Run audit | `fw audit` | `./agents/audit/audit.sh` |
| Show gaps | `fw gaps` | _(fw only)_ |
| Health check | `fw doctor` | _(fw only)_ |
| View metrics | `fw metrics` | `./metrics.sh` |
| Predict effort | `fw metrics predict --type build` | _(fw only)_ |
| Promotion candidates | `fw promote suggest` | _(fw only)_ |
| Promote learning | `fw promote L-XXX --name "..." --directive D1` | _(fw only)_ |
| Graduation status | `fw promote status` | _(fw only)_ |
| Initialize session | `fw context init` | `./agents/context/context.sh init` |
| Set focus | `fw context focus T-XXX` | `./agents/context/context.sh focus T-XXX` |
| Context status | `fw context status` | `./agents/context/context.sh status` |
| Add learning | `fw context add-learning "..."` | `./agents/context/context.sh add-learning "..."` |
| Diagnose issue | `fw healing diagnose T-XXX` | `./agents/healing/healing.sh diagnose T-XXX` |
| Resolve issue | `fw healing resolve T-XXX` | `./agents/healing/healing.sh resolve T-XXX` |
| Show patterns | `fw healing patterns` | `./agents/healing/healing.sh patterns` |
| Resume state | `fw resume status` | `./agents/resume/resume.sh status` |
| Sync working memory | `fw resume sync` | `./agents/resume/resume.sh sync` |
| Session capture | Review `agents/session-capture/AGENT.md` checklist | |
| Post bus result | `fw bus post --task T-XXX --agent TYPE --summary "..."` | |
| Read bus results | `fw bus read T-XXX [R-NNN]` | |
| Bus manifest | `fw bus manifest [T-XXX]` | |
| Clear bus channel | `fw bus clear T-XXX` | |
| Generate handover | `fw handover` | `./agents/handover/handover.sh` |
| Handover + commit | `fw handover --commit` | `./agents/handover/handover.sh --commit` |
| Read last handover | `cat .context/handovers/LATEST.md` | |
| **Start inception** | **`fw inception start "name"`** | Creates inception task + sets focus |
| Inception status | `fw inception status` | Lists active inception tasks |
| Inception decide | `fw inception decide T-XXX go` | Records go/no-go with rationale |
| Add assumption | `fw assumption add "..." --task T-XXX` | Register assumption |
| Validate assumption | `fw assumption validate A-XXX --evidence "..."` | Mark validated |
| List assumptions | `fw assumption list` | Show all by status |
| Tier 0 approve | `fw tier0 approve` | Approve a blocked destructive command |
| Tier 0 status | `fw tier0 status` | Show Tier 0 enforcement status |
| Fabric overview | `fw fabric overview` | `./agents/fabric/fabric.sh overview` |
| Fabric deps | `fw fabric deps <path>` | `./agents/fabric/fabric.sh deps <path>` |
| Fabric impact | `fw fabric impact <path>` | `./agents/fabric/fabric.sh impact <path>` |
| Blast radius | `fw fabric blast-radius [ref]` | `./agents/fabric/fabric.sh blast-radius [ref]` |
| Fabric drift | `fw fabric drift` | `./agents/fabric/fabric.sh drift` |
| Register component | `fw fabric register <path>` | `./agents/fabric/fabric.sh register <path>` |
| **Auto-restart** | **`claude-fw [args...]`** | Wrapper: runs claude, auto-restarts on handover signal |

## Auto-Restart (T-179)

When context budget hits critical, `checkpoint.sh` auto-generates a handover and writes `.context/working/.restart-requested`. If the user started their session via `claude-fw` (instead of `claude`), the wrapper detects this signal on exit and auto-restarts with `claude -c`. The `SessionStart:resume` hook then injects handover context into the fresh session.

**Flow:** Budget critical → auto-handover → signal file → claude exits → wrapper detects → `sleep 3` → `claude -c` → context injected → `/resume` ready.

**Safety:** 5-minute TTL on signal files, max 5 consecutive restarts, 3-second cancel window, opt-out via `--no-restart`.

## Session End Protocol

**Before ending any session:**
1. Run session capture checklist (`agents/session-capture/AGENT.md`)
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Generate handover: `fw handover`
5. Fill in the [TODO] sections in the handover document
6. Commit all changes with task references
7. Run `fw metrics` to verify state

**Do not end a session without generating a handover.**
