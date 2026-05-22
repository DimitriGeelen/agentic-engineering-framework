# CLAUDE.md

Claude Code integration for the Agentic Engineering Framework.
For the provider-neutral framework guide, see `FRAMEWORK.md`.

This file is auto-loaded by Claude Code. It contains the full operating guide
plus Claude Code-specific integration notes.

## Project Overview

The **Agentic Engineering Framework** is a governance framework for systematizing how AI agents work within engineering projects. This is not a traditional code library—it's a set of structural rules, patterns, and enforcement mechanisms for agentic workflows.

**Primary Environment:** Any file-based, CLI-capable AI agent (see FRAMEWORK.md)
**Claude Code Integration:** This file is auto-loaded by Claude Code.

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

**Initiative ≠ Authority.** Broad directives ("proceed as you see fit") delegate initiative, not authority. When a structural gate blocks an action, the gate wins — always ask, never force. See §Autonomous Mode Boundaries.

## Instruction Precedence

When multiple instruction sources conflict (CLAUDE.md, plugins, skills, user messages), this resolution order applies:

1. **Framework rules (this file)** — Core Principle, Authority Model, Enforcement Tiers, and Task System rules take absolute precedence. No plugin or skill can override "Nothing gets done without a task."
2. **User instructions** — Direct human instructions can override framework rules via Tier 2 (situational authorization with logging).
3. **Skills/plugins** — Apply AFTER framework gates are satisfied. A skill that says "invoke before any response" means: after verifying an active task exists. Skills enhance workflows; they do not replace framework governance.

**The practical rule:** Before following ANY skill or plugin workflow, first ensure a task exists and focus is set. If a skill's instructions conflict with creating a task first, the task wins.

**Why this matters:** Third-party plugins are not aware of project-specific governance. They will issue instructions like "implement now" or "code first, test first" without checking for task context. The agent must apply framework rules as a pre-filter before deferring to skill workflows.

## Watchtower Port (read this FIRST, before any `curl localhost:3000`)

**Watchtower's port is per-project, not hard-coded to `3000`.** Two consumer projects on one host would collide if the framework assumed 3000 everywhere.

Resolution order (T-885, T-1287, T-1376):

1. **`.context/working/watchtower.url`** — triple-file source of truth, written by `bin/watchtower.sh` on start. Read this file, don't guess.
2. **`bin/fw config get PORT`** — per-project `FW_PORT` config when no Watchtower is currently running.
3. **`3000`** — default ONLY when neither of the above is available (fresh project, no config, no running instance).

**How to check:**
- Current port: `bin/fw watchtower port` (triple-file → fw_config → 3000 fallback)
- Current URL: `bin/fw watchtower url` (triple-file → fw_config → `http://localhost:PORT` fallback)
- Raw files: `cat .context/working/watchtower.port` / `cat .context/working/watchtower.url`
- Diagnostics: `bin/fw doctor` (surfaces all three triple-file states)

**How NOT to check:**
- Do not write `curl http://localhost:3000/...` in instructions, verification examples, or cron scripts. That literal hard-code is an anti-pattern (T-1376) and has caused agents to kill or mis-target live sessions across projects.
- Fallback to `3000` is fine in shell when `fw_config PORT` and the triple file both return empty — that is a defensive default, not a hard-code.

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

**Optional frontmatter fields:**
- `arc_id` (T-1849) — single arc reference. Accepts either form:
  - **slug** form: `arc_id: dispatch-safety` (filename stem of `.context/arcs/<slug>.yaml`)
  - **arc-NNN** form: `arc_id: arc-001` (canonical immutable id from T-1848 D-Immutability axiom)
  - Empty/missing/null → task is unassigned to any arc (allowed; arcs are optional)
  - PreToolUse hook `check-arc-id` (Write|Edit on `.tasks/{active,completed}/T-*.md`) refuses saves under agent control when `arc_id` is non-empty and does **not** resolve to an existing arc YAML. Override: `FW_ALLOW_ARC_ID_DRIFT=1` (logged Tier-2 in `.gate-bypass-log.yaml`).
  - Coexists with the legacy `tags: [arc:<slug>, ...]` form (T-NEW-3 / T-1850 will migrate `arc:*` tags into `arc_id`).
- **Inception GO-scope traceability** (T-1984, G-066 prevention) — Two optional fields that make inception GO scope machine-readable and gate-enforced:
  - `inception_decisions:` (on `workflow_type: inception`) — list of `{id: <kebab-slug>, text: <one-liner>, ships_in: <referent>}` entries. Each `ships_in:` accepts five shapes: (1) `path/to/file.ext` (file exists at PROJECT_ROOT), (2) `module.function` (symbol grepped in lib/agents/bin), (3) `tests/path/test.py::test_func` (file+function), (4) `T-XXX` (task in `.tasks/completed/`), (5) `deferred:T-YYYY` (task in `.tasks/{active,completed}/`). PreToolUse hook `check-inception-decisions` blocks Write|Edit when entries are structurally invalid. Close gate in `update-task.sh --status work-completed` validates reachability of every `ships_in:` referent. Override: `--skip-inception-scope-trace "rationale"` (direct invocations) or `FW_SKIP_INCEPTION_SCOPE_TRACE=1` (git/wrapper invocations) — both log Tier-2. Grandfathered: empty/missing field skips the gate entirely.
  - `unlocks_inception_decision:` (on `workflow_type: build`) — list of `T-XXX:decision-id` strings declaring which inception decisions this build child ships. PreToolUse hook validates each reference (inception exists + has that decision id). Example: `unlocks_inception_decision: [T-1983:my-decision]`. Override: `FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1`.
- `bvp_scores`, `bvp_scores_proposed`, `cost_estimate` (T-1918, arc-006) — Business Value Points scoring fields.
  - `bvp_scores:` (map) — confirmed per-driver scores 0-5, set only by `fw bvp confirm` (T-1924). Sovereignty boundary. Shape `{D1: <0-5>, D2: <0-5>, D3: <0-5>, D4: <0-5>, [<free-driver-id>: <0-5>]…}`.
  - `bvp_scores_proposed:` (list of timestamped entries) — estimator-proposed scores written by the TermLink BVP estimator worker (T-1922). Persists only when the proposal differs from `bvp_scores:` by ≥2 on any driver (M3 v2-delta semantics).
  - `cost_estimate:` (map) — F8 composite `0.6×blast_radius + 0.3×tier + 0.1×effort`. Q2 fallback: T-shirt `S/M/L/XL` mapped to `2/4/6/8` when `blast_radius` is not computable yet. Read by auto-promote (T-1931) and `fw bvp rank` (T-1919).
  - Audit (`fw audit`) treats unknown frontmatter fields as silent additions (A2). Documented in `policy/value-drivers.yaml` and `docs/reports/T-1915-bvp-inception.md`.

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

**Invariants (T-1068):** `update-task.sh` enforces consistency between status and horizon:
- `--status started-work` → auto-sets `horizon: now` (starting work means it's active now)
- `--horizon next/later` on a `started-work` task → auto-demotes `status: captured` (shelving means you stopped)
- Both produce an info message. No override needed — if you want to start work, it's `now`; if you shelve it, it's not `started-work`.

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
- Web pages load: `curl -sf "$(bin/fw watchtower url)/page"` (never hard-code `:3000` — see §Watchtower Port above)
- Commands succeed: `fw doctor`
- Output contains expected content: `grep -q "expected" output.txt`

**Rules:**
- Lines starting with `#` are comments (skipped)
- Empty lines are ignored
- Each non-comment line is executed as a shell command
- First 5 lines of failure output are shown for debugging

**Toolchain build commands (L-291, T-1501):** If your task touched compileable artifacts, the matching build command MUST be in `## Verification`. The framework is toolchain-agnostic by design — it runs only what you write, so a forgotten `dotnet build` ships broken DLLs to master (origin: 003-NTB-ATC-Plugin T-077, 5 days undetected).

| You edited | Add to `## Verification` |
|------------|--------------------------|
| `*.vbproj` / `*.csproj` / `*.xaml` | `dotnet build` |
| `*.go` | `go build ./...` |
| `Cargo.toml` / `*.rs` | `cargo check` |
| `tsconfig.json` / `*.ts` | `tsc --noEmit` |
| `pom.xml` / `*.java` | `mvn -q compile` |

If the toolchain is not installed on the gate-running host, scope the command (e.g. `command -v dotnet >/dev/null && dotnet build`). Don't omit the check.

**Cron-touching tasks (L-364, T-1771, T-1942, T-1943):** If your task edited `.context/cron-registry.yaml`, anything under `.context/cron/`, or any cron generator code (`bin/fw cron generate|install`, `agents/audit/audit.sh` cron schedule helpers), `## Verification` MUST include:

```
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
```

The chain is registry → generated → deployed — three transitions, three drift classes (T-1942):

1. **registry → generated** — `fw cron generate` not run after registry edit. Doctor emits `WARN Cron registry edited but not generated`. Audit emits FAIL (T-1943).
2. **generated → deployed** — `fw cron install` not run after regenerate. Doctor emits `WARN Cron registry drift`. Audit emits FAIL (T-1771).
3. **deployed → executable** — cron line is on disk but fails at exec time (cwd / env / missing module). L-365 advisory; no automated gate yet.

Each transition is a separate state — "wired" is not "deployed", "deployed" is not "executable". The verification command above checks BOTH the "in sync" PASS (generated↔deployed) AND the absence of the new "edited but not generated" WARN (registry↔generated). Without both clauses, a registry-edited-but-never-regenerated state passes the gate because the in-sync line still fires (origin: T-1935 — 3+ days of silent drift before T-1941 cleared it).

T-1942 + T-1943 close the registry→generated leg at both surfaces (doctor WARN, audit FAIL). T-1771 covers generated→deployed. Task-close is the earliest gate; audit's daily cron catches anything that slips past.

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

When discovering structural flaws (bugs in framework tooling, spec-reality gaps):
1. **Register first, fix second.** Add the flaw to `concerns.yaml` BEFORE or alongside the fix
2. Gaps persist in the register (visible in Watchtower, checked by audit); completed tasks archive and become invisible
3. Each independent bug gets its own task (see Task Sizing Rules: "One bug = one task")

When encountering task-level issues:
1. Set status to `issues`
2. Log error reference and healing loop suggestions
3. Record resolution when fixed for pattern learning

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

### Gap Homing (T-1333)

**A gap belongs in the register where the FIX lives, not where it was HIT.** When a concern's root cause is in another repo or project, file it there — filing it locally creates a zombie entry nobody who could fix it will ever read. If cross-cutting, cross-link, but home the entry where the fix lands. Worked example: G-045 (fleet cert co-rotation) — framework hit the symptom, TermLink owns the fix, so the register entry here points at TermLink's `T-1054` rather than describing the fix ourselves.

## fw CLI (Primary Interface)

`fw` is the single entry point for all framework operations — it resolves paths, sets env vars, and routes to agents. Discover commands via `fw help`, `fw <cmd> --help`, or the Quick Reference section below.

**Path resolution:** `fw` finds the framework via `bin/fw`'s location (inside framework repo) or via `.framework.yaml` in the project root (shared tooling mode).

**`fw upgrade` (canonical onboarding):** Syncs governance to a consumer project — refreshes shims (bin/fw, .claude/settings.json hooks), updates the version pin in `.framework.yaml`, syncs vendored scripts. It does NOT copy framework source into the consumer — agents and libraries stay in the framework repo, accessed via the shim. Run from the framework repo (`fw upgrade /path/to/project`) or from inside the consumer (`fw upgrade`).

## Agents

Agents are mechanical scripts in `agents/<name>/` paired with an `AGENT.md` intelligence file. Invoke via `fw` (see Quick Reference) or directly via `./agents/<name>/<name>.sh`. Most agents have a one-liner already catalogued in Quick Reference — this section only describes behavior and when to invoke.

- **task-create** — Before ANY new work. `fw work-on "name" --type build` is the one-step entry. `fw task update --status issues` auto-triggers healing diagnosis; `--status work-completed` auto-finalizes (date_finished, move to completed/, generate episodic).
- **audit** — Periodic compliance check. Exit codes: 0=pass, 1=warnings, 2=failures. Run after completing work or on suspected drift.
- **session-capture** — MANDATORY before ending any session or switching context. Review `agents/session-capture/AGENT.md`: all work captured as tasks, all decisions recorded, all learnings stored, all open questions tracked.
- **git** — Enforces task traceability (P-002). Every commit must reference `T-XXX`. `fw git install-hooks` installs commit-msg, post-commit, pre-push. Use `--no-verify` only for emergencies and log via Tier 2.
- **handover** — MANDATORY at end of every session. `fw handover --commit` generates, commits, and pushes. Never end a session with unpushed commits.
- **context** — Context Fabric management (working/project/episodic memory). Session init via `fw context init`; focus via `fw context focus T-XXX`; capture via `fw context add-learning|add-pattern|add-decision|generate-episodic`.
- **healing** — Triggered on `status: issues`. Antifragile loop: classify failure → lookup matching patterns → suggest recovery via Error Escalation Ladder → log resolution for future learning.
- **resume** — Post-compaction recovery. `fw resume status` for full synthesis (handover + working memory + git + tasks); `sync` to fix stale working memory; `quick` for one-line summary.

## Component Fabric

The Component Fabric (`.fabric/`) is a structural topology map of every significant file — each component has a YAML card in `.fabric/components/` with id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by.

**When to use:** before modifying a file → `fw fabric deps <path>`; before committing → `fw fabric blast-radius [ref]`; after creating a new file → `fw fabric register <path>`; periodic health → `fw fabric drift` (detects unregistered/orphaned/stale). Also: `fw fabric overview` for the subsystem summary, `fw fabric impact <path>` for the full downstream chain, `fw fabric search <keyword>` to find by tag/name/purpose.

Watchtower `/fabric` surfaces the subsystem overview, filterable component table, dependency graph, and per-component detail pages.

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
- Below 75% (<225K tokens): proceed normally
- 75-85% (225K-255K): propose only small, bounded tasks; commit first
- Above 85% (255K+): propose only wrap-up actions (commit, learnings, handover)
- Above 95% (285K+): handover immediately, no new work
- **This applies especially in autonomous mode** — without a human to catch the mistake, proposing work that can't complete in remaining context risks losing all uncommitted work

### Automated Monitoring and Critical Protocol

- **Primary enforcement:** PreToolUse `budget-gate.sh` reads actual token usage from the session JSONL and blocks Write/Edit/Bash at critical (exit code 2). Fallback: PostToolUse `checkpoint.sh` (warnings + auto-handover, T-136).
- **Escalation ladder:** 225K ok→warn, 255K warn→urgent, 285K urgent→critical (BLOCK). Context window 300K default (`FW_CONTEXT_WINDOW`).
- **At critical (or if you see a SESSION WRAPPING UP block):** only wrap-up is allowed. Allowed: git commit/add, `fw handover`, `fw task update`, reading files, Write/Edit to `.context/` `.tasks/` `.claude/`. Blocked: Write/Edit to source files, general Bash.
- Status cached in `.context/working/.budget-status` (JSON: level, tokens, timestamp). Check via `./agents/context/checkpoint.sh status`. If no transcript available, fails open (PostToolUse fallback handles it).
- Wrap up calmly — task files already carry all essential state from continuous capture.

## Configuration (T-819, T-891)

4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default. Persistent per-project config: `fw config set KEY VALUE` writes to `.framework.yaml`.

Agent-relevant settings:
- `FW_CONTEXT_WINDOW` (300000) — budget enforcement ceiling
- `FW_PORT` (3000) — Watchtower listen port (also resolved via triple-file; see Watchtower Port section)
- `FW_SAFE_MODE` (0) — bypass task gate (escape hatch)
- `FW_DISPATCH_LIMIT` (2) — Agent tool cap before TermLink gate
- `FW_STALE_ARC_DAYS` (30) — T-1855: stale-arc audit WARN threshold. In-progress arcs whose constituent tasks (matched by `arc_id:`) have no commit in the last N days surface a WARN. Silent on draft/closed/abandoned arcs and on zero-population arcs.
- `FW_ALLOW_ARC_ID_DRIFT` (0) — T-1849: single-use bypass for the `arc_id:` validation hook when the field doesn't resolve to an existing arc YAML. Logged Tier-2 to `.context/working/.gate-bypass-log.yaml`.

Full reference (handover timeouts, bash timeout, stale-task days, call-level fallbacks, inception commit limit, etc.): `fw config list`, `env | grep FW_`, or Watchtower `/config`. `fw doctor` warns on out-of-range values.

## Sub-Agent Dispatch Protocol

When using Claude Code's Task tool to dispatch sub-agents (Explore, Plan, Code, etc.), follow these rules. Based on evidence from 96 tasks where 8 used sub-agents.

### Result Management Rules

**Content generators** (enrichment, file creation, report writing):
- Sub-agent MUST write output to disk (Write tool), NOT return full content
- Return only: file path + one-line summary (e.g., "Wrote .context/episodic/T-073.yaml — enriched from skeleton")
- This prevents context explosion (T-073: 9 agents returning full YAML spiked context by 30K+ tokens)

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
| Max parallel agents | **5** (T-073 used 9 → context explosion; T-061 used 4, T-086 used 5 → fine) |
| Token headroom | Leave **40K tokens** free for result ingestion before dispatching |
| When parallel | Tasks are independent, no shared files, no sequential dependency |
| When sequential | Tasks depend on prior results, or editing same files |
| Background agents | Use `run_in_background: true` for agents >2K tokens expected output |

### Task Tool vs TermLink Dispatch

The Task tool and TermLink dispatch are two different mechanisms for parallel work. **Choose based on the work type:**

| Factor | Task tool agent | TermLink dispatch (`fw termlink dispatch`) |
|--------|----------------|---------------------------------------------|
| Edit/Write tools | Yes (sub-agent) | Yes (spawns full `claude -p` worker) |
| Context isolation | No (shares parent context window) | Yes (independent process, zero context cost) |
| Max parallel | 5 (hard limit) | Unlimited (real OS processes) |
| Observable from outside | No | Yes (attach, stream, output) |
| Survives context pressure | No (compressed with parent) | Yes (independent session) |

**Use Task tool agents when:**
- Quick research or codebase exploration (<2K token results)
- Single-file edits within the current session
- Lightweight sub-tasks that benefit from shared context

**Use TermLink dispatch when:**
- Heavy parallel work (>3 agents, or agents doing multi-file edits)
- E2E testing or command execution requiring terminal isolation
- Work that should survive parent context compaction
- Tasks where you want to observe progress remotely

**The rule:** If you're about to dispatch 3+ Task tool agents that will each produce >1K tokens or edit files, use TermLink dispatch instead. The context savings are significant — Task agents share the parent's context budget, TermLink workers do not.

**Evidence:** T-522 session — 3 evaluation agents dispatched via Task tool consumed ~25K parent context tokens. Same work via TermLink dispatch would cost zero parent context.

**TermLink output rule (T-818):** TermLink workers MUST write directly to target files in the repo (e.g., `docs/reports/T-XXX-analysis.md`), NOT to `/tmp/fw-agent-*`. If the parent session hits budget critical before integrating `/tmp/` results, outputs are lost. The `/tmp/` convention is for Task tool agents only (consumed immediately). See `agents/dispatch/preamble.md` for full instructions.

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

**Size gating:** Payloads < 2KB are inline. Payloads >= 2KB are auto-moved to `.context/bus/blobs/` and referenced. This prevents T-073-class context explosions (~97% context savings in simulation).

### Cross-Machine Dispatch (`fw dispatch`)

For cross-machine communication without TermLink, use SSH-based dispatch:

```bash
# Send result to remote machine
fw dispatch send --host dev-server --task T-XXX --agent explore --summary "Found issues"

# Or use --remote flag with bus post
fw bus post --remote dev-server --task T-XXX --agent explore --summary "Found issues"

# List available SSH hosts
fw dispatch hosts
```

**Requirements:**
- SSH access to remote host (configured in `~/.ssh/config`)
- Agentic Framework installed on remote host
- Remote user has write access to `.context/bus/`

**How it works:** The local machine serializes the bus envelope as JSON and pipes it via SSH to `fw bus receive` on the remote machine, which stores it in the remote bus channel.

### Dispatch Patterns

- **Parallel investigation / audit / enrichment:** 3-5 Task agents scan independent aspects; each writes findings to disk, returns path + summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.
- **Sequential TDD:** Fresh agent per implementation task with review between.
- **TermLink parallel workers:** Spawn TermLink sessions for isolated heavy work. `termlink interact --json` for sync commands, `termlink pty inject/output` for interactive control. Cleanup with `termlink signal SIGTERM` + `termlink clean`. Preferred over Task agents when context isolation matters.

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
- **Suggesting** `--force` or batch-completion of human-owned tasks without first listing each task's unchecked Human ACs
- Changing task ownership away from human
- Destructive actions (Tier 0)
- Any action the sovereignty gate or structural enforcement blocks

**The rule:** If a structural gate blocks you, that gate exists precisely for moments like this. A broad directive does not override structural enforcement. Stop and ask.

### Pickup Message Handling (G-020, T-469)
Pickup messages from other sessions are **PROPOSALS, not build instructions.** A detailed spec with file lists and implementation steps is a suggestion, not authorization.

Before acting on a pickup message:
1. **Assess scope** — if it describes >3 new files, a new subsystem, a new CLI route, or a new Watchtower page, create an **inception** task (not build)
2. **Write real ACs** before editing any source file — the build readiness gate (G-020) will block tasks with placeholder ACs
3. **Never treat detailed specs as authorization to skip scoping** — the more detailed a pickup message is, the more likely it needs inception, not less

**Why this rule exists:** A pickup message from session 010-termlink caused complete governance bypass. The agent created a build task with placeholder ACs and immediately started editing `bin/fw` and building a Watchtower page. Human intervened 3 times. Root cause: imperative tone ("Create a PR", "Files to Include") caused the agent to internalize the spec as a build instruction rather than a proposal requiring scoping.

### Human Task Completion Rule (T-372, T-373)
Human ACs represent real verification steps. Unvalidated deliverables carry downstream risk. A clean task list is not progress — validated deliverables are progress.

**You MAY suggest closing a human-owned task IF you provide evidence that the Human ACs are already satisfied:**
- Cite specific evidence (file exists, endpoint responds, output matches expected, config is in place)
- Explain why no further human action is needed
- Example: "T-371 hook is registered in settings.json:100-108 and running (tool counter = 3). Evidence suggests the AC is met — want to close it?"

**You MAY suggest the human prioritize verification when there's a reason:**
- "T-289 pipeline setup is blocking deployment. Could you test it? Here are the steps..."
- "T-366 articles are building on each other — quality review now catches tone issues before they compound."

**You MUST NOT suggest closing without evidence:**
- No "batch-close stale tasks" — each task needs individual evidence
- No "just use `--force`" — that skips the verification the AC exists to perform
- No treating Human ACs as administrative overhead — they catch real problems

**Use `fw task verify`** to see what Human ACs are unchecked before suggesting anything.

**The test:** "Can I cite specific evidence that this task's Human ACs are satisfied?" If yes, suggest closing with that evidence. If no, either help the human execute the verification steps, or move on.

### Commit Cadence and Check-In
After **every commit**, briefly report what was done and ask if the user wants to continue. Do not chain multiple commits without user interaction.

**Structural enforcement (T-139, T-478, T-596):** The `budget-gate.sh` PreToolUse hook reads actual token usage from the session transcript and **blocks** Write/Edit/Bash tool calls when context reaches critical level (>=285K tokens, ~95% of 300K window). At critical, only git commit, fw handover, and read operations are allowed. The hook writes `.context/working/.budget-status` with current level (ok/warn/urgent/critical) for fast caching. PostToolUse `checkpoint.sh` remains as fallback for warnings and auto-handover. Context window size is configurable via `FW_CONTEXT_WINDOW` env var (default: 300K).

### Copy-Pasteable Commands (T-609, T-1257)
When giving the human a command to run (Tier 0 approvals, inception decisions, verification steps, Human AC instructions), the command MUST be:

1. **Single-line, copy-pasteable** — works when pasted into any terminal, from any directory
2. **Prefixed with `cd`** — always include `cd /path/to/project &&` so directory context is explicit
3. **Use the right `fw` path for the project's context (T-1257):**
   - **Framework repo** (contains `FRAMEWORK.md` + `bin/fw` at its root — e.g. `/opt/999-Agentic-Engineering-Framework`): use `bin/fw`
   - **Consumer project** (contains `.agentic-framework/bin/fw` — any project initialised via `fw init`): use `.agentic-framework/bin/fw`
   - Bare `fw` only when you know the shim at `~/.local/bin/fw` is installed and routing works — otherwise it may resolve to a stale global install
4. **Verify before suggesting** — before pasting a `fw` command into chat, confirm the chosen path exists in the target project (check for `bin/fw` OR `.agentic-framework/bin/fw`). Don't apply the framework-repo pattern to a consumer.
5. **No bare multi-line** — if multiple commands are needed, chain with `&&` on one line. Never rely on the human copy-pasting multiple separate lines (line breaks cause partial execution errors)

**Good — framework repo:**
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && bin/fw inception decide T-608 go --rationale "approved"
```

**Good — consumer project:**
```
cd /003-NTB-ATC-Plugin && .agentic-framework/bin/fw inception decide T-006 go --rationale "approved"
```

**Bad — applies framework-repo pattern to a consumer project:**
```
cd /003-NTB-ATC-Plugin && bin/fw inception decide T-006 go
# → bash: bin/fw: No such file or directory   (consumer has NO bin/ at root)
```

**Bad — bare, no cd:**
```
fw tier0 approve
fw inception decide T-608 go --rationale "approved"
```

**Why this exists:**
- **T-609:** User ran `fw inception decide` from `/home/dimitri-mint-dev/` — got "No framework project detected". Three errors from one missing `cd`.
- **T-1257:** Agent on `/003-NTB-ATC-Plugin` (consumer) told user to run `bin/fw` — consumer has no `bin/` at root, only `.agentic-framework/bin/fw`. The generic rule "use `bin/fw`" was correct for the framework repo but wrong for consumers.

### Inception Discipline
When the active task has `workflow_type: inception`:
1. **State the phase** — Say "This is an inception/exploration task" before doing any work
2. **Present the filled template** for review before executing any spikes or prototypes
3. **Do not write build artifacts** (production code, full apps) before `fw inception decide T-XXX go`
4. **The commit-msg hook enforces this** — after 2 exploration commits, further commits are blocked until a decision is recorded
5. After a GO decision, **create separate build tasks** for implementation — do not continue building under the inception task ID
6. **Research artifact first (C-001)** — When starting inception work, create `docs/reports/T-XXX-*.md` BEFORE conducting research. Update the file incrementally as dialogue produces findings. Commit after each dialogue segment. The thinking trail IS the artifact — conversations are ephemeral, files are permanent. (Origin: T-194 — 7 existing controls for research persistence all failed because none enforced capture at the point research happens.)
7. **Dialogue log (C-001 extension)** — For phases involving human dialogue, include a `## Dialogue Log` section in the research artifact. Record: questions the human posed, answers given, course corrections ("we are not doing X, we are doing Y"), and the outcome/decision that resulted. Structured findings capture WHAT was decided; the dialogue log captures WHY and HOW the reasoning evolved. (Origin: T-194 experiment — 95% of findings captured but conversational reasoning only captured when explicitly logged in Phase 2a.)
8. **Exploratory Conversation Guard (C-002)** — If a substantive conversation on an untracked topic reaches 3+ exchanges without an active task, STOP and:
   1. Create an inception task for the topic
   2. Invoke `/capture` to save the prior dialogue to disk
   3. Continue the conversation under the new task
   Trigger: 3 substantive exchanges (exclude greetings, one-word replies, status checks). Enforcement: agent self-governs; no hook coverage (G-005).

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

### AC Classification Guidance (T-954)

When writing acceptance criteria, use this risk matrix to decide Human vs Agent:

**Make it a Human AC if ANY apply:**
1. **Strategic authority** — go/no-go decisions, architecture choices, priority calls
2. **Subjective judgment** — quality, tone, UX feel, "is this good enough?"
3. **Irreversible external action** — publishing, deploying to production, sending communications
4. **Cross-project blast radius** — changes affecting multiple consumer projects or external users
5. **Touches a rendering surface** — `web/templates/`, `web/static/` (CSS/JS), `web/blueprints/`, `web/shared.py`, `web/app.py`. Visual layout/typography/spacing cannot be settled by curl/grep; the render-surface gate (T-1766, P-013) refuses `--status work-completed` on a render-touching build task without at least one `[REVIEW]` Human AC. Bypass: `--skip-render-review "rationale"` (logged Tier-2). Origin: T-1763/T-1764/T-1765 — three render fixes shipped with zero Human ACs.

**Make it an Agent AC (with verification command) if ALL apply:**
1. **Deterministic outcome** — binary pass/fail with clear expected result
2. **Reversible** — can be undone if wrong (git revert, config change)
3. **Internal scope** — affects only development tooling, not external users
4. **Mechanical execution** — no judgment needed, just "run X, check Y"

**When in doubt, make it Human** — false negatives (missing a broken thing) are worse than false positives (asking the human unnecessarily).

**RUBBER-STAMP conversion rule:** If a Human AC has `[RUBBER-STAMP]` prefix and its Steps section contains only deterministic shell commands with clear expected output, it SHOULD be an Agent AC with verification commands in `## Verification` instead. The machine is more reliable than a human for pass/fail checks.

**Author-time default (T-1878):** When you are *writing* a Human AC and your Expected clause is grep-able / file-exists / structural (deterministic shell check), default to `[REVIEWER]` and move the AC to `### Agent` with the reviewer command in `## Verification`. Only keep `[REVIEW]` if verification genuinely needs human taste (tone, layout rhythm, blast-radius judgment). T-1878 found a 412:7 `[REVIEW]:[REVIEWER]` adoption gap and 13% mis-classification rate on partial-completes — the prefix existed, the author-time nudge didn't. T-1894 manually re-classed 4 such ACs across arc-grooming; T-1896 (the static-scan catch) closes the gap structurally for the next round. Reasoning: `docs/reports/T-1878-routing-default-bias.md`.

**Three Human-AC prefixes (T-1811):** The classification above is binary at the Agent/Human level, but Human ACs themselves have three sub-classes by who *can* verify them:

| Prefix | When to use | Verifier |
|--------|-------------|----------|
| `[RUBBER-STAMP]` | Mechanical step with deterministic shell-command verification | Shell (Tier 1/2/3) — convert to Agent AC + `## Verification` |
| `[REVIEWER]` | Pattern / wording / convention check that the static-scan reviewer agent handles (anti-pattern detection, block-message conformance, naming consistency) | `fw reviewer T-XXX` — convert to Agent AC + Verification command `bin/fw reviewer T-XXX 2>&1 \| grep -q "Overall:.*PASS"` |
| `[REVIEW]` | Genuine human judgment — quality, tone, UX feel, strategic call, blast-radius assessment | Human only |

**REVIEWER conversion rule (T-1811):** If a Human AC has `[REVIEW]` prefix but its check would be satisfied by `fw reviewer T-XXX` returning PASS + needs_human=no, it SHOULD be re-classified as `[REVIEWER]` and converted to an Agent AC with the reviewer command in `## Verification`. The reviewer agent (T-1443) is a static-scan surface — pattern conformance, anti-pattern detection, block-message presence — that complements but does not replace `[REVIEW]` for taste/judgment calls.

**Test:** "Could a deterministic static scan of the task file (or referenced source) answer the AC's yes/no?" If yes → `[REVIEWER]`. If no → `[REVIEW]`.

**`[REVIEWER]` does not cover prose quality (T-1947, L-409):** The reviewer agent checks structural patterns only — it does not read prose for tone, clarity, or rhythm. If your AC asks "does this read clearly?" or "is the tone right?", use `[REVIEW]`, not `[REVIEWER]`. Otherwise the scanner skips your AC silently and still emits a verdict on the task's other ACs — which looks identical to success.

**Signal vocabulary** (any of these in the Expected clause means `[REVIEW]`, not `[REVIEWER]`): *reads clearly, tone, voice, rhythm, intuitive, feels right, cohesive, cleanly, unambiguous, actionable, layout reads clean.*

The detector `reviewer-prose-mismatch` (T-1947) flags `[REVIEWER]` ACs that contain this vocabulary and emits CONCERN at task close.

**Worked example (origin: T-1811):** The Human AC *"Confirm focus-drift block message is actionable"* on T-1730 was filed as `[REVIEW]`. The Reviewer agent's static scan (`fw reviewer T-1730`) returned CONCERN on `mock-only-integration` — a finding the AC text would never have caught. The AC should have been `[REVIEWER]` with `fw reviewer T-1730` in Verification, *plus* a separate `[REVIEW]` AC only if the wording's *feel* genuinely needed human judgment.

**Reviewer auto-tick (v1.5, T-1985):** `[REVIEWER]`-prefixed Agent ACs are automatically ticked by the reviewer scanner when all five evidence conditions hold: (1) overall verdict PASS, (2) zero per-AC findings for that AC's index, (3) AC is currently unticked, (4) no active suppress override targets that AC index, (5) `[REVIEWER]` prefix present. The tick and verdict block are written in a single atomic `os.replace` pass. **Sovereignty rail:** every auto-tick writes a digest-keyed entry `auto_tick:<task_id>:<ac_index>:<digest>` to `.context/working/feedback-stream.yaml`. If a human manually un-ticks the AC (changes `[x]` back to `[ ]`), the feedback-stream entry blocks re-ticking — the reviewer will NOT re-tick it unless the AC text itself changes (new digest = fresh consent). Note: wildcard pattern overrides (`ac_index=None`) suppress findings for a pattern but do NOT block auto-tick of unrelated ACs. Auto-tick only runs on `active/` tasks; `completed/` files are never mutated.

**Verification tiers for Agent ACs:**
- **Tier 1 (programmatic):** Shell commands, curl, grep, file checks — for deterministic, reversible checks
- **Tier 2 (TermLink E2E):** Spawn process, inject commands, check output — for integration/CLI workflows
- **Tier 3 (Playwright):** Browser automation via `tests/playwright/` — for interactive UI verification. Run with `fw test playwright`.

**UI AC split:** When verifying UI features, split into two criteria:
- Agent AC for functional check: "page returns HTTP 200 and contains key element" (Tier 1)
- Human AC only if aesthetic judgment is genuinely needed: "layout is clean and intuitive" (`[REVIEW]`)

**Playwright test generation rule (T-971):** When writing an Agent AC for a UI feature (Tier 3), also write or update a Playwright test in `tests/playwright/`. The AC verifies the feature once; the test guards it forever. Pattern:

| AC pattern | Test pattern |
|------------|-------------|
| `curl -sf URL` → 200 | `page.goto(url)` + `assert resp.status == 200` |
| `curl URL \| grep -q "X"` | `page.goto(url)` + `assert "X" in page.content()` |
| "page shows element X" | `expect(page.locator("X")).to_be_visible()` |
| "click X, verify Y appears" | `page.click("X")` + `expect(page.locator("Y")).to_be_visible()` |
| `[RUBBER-STAMP]` with deterministic steps | Convert to Agent AC + Playwright test |
| `[REVIEWER]` with reviewer-verifiable pattern | Convert to Agent AC + `fw reviewer T-XXX` in Verification |
| `[REVIEW]` with subjective judgment | Keep as Human AC (not automatable) |

### Human AC Format Requirements (T-325)
When writing `### Human` acceptance criteria, each criterion MUST include:
- **Steps:** block with numbered, copy-pasteable instructions (no placeholders the human must figure out)
- **Expected:** what success looks like (exact text, status code, or observable outcome)
- **If not:** diagnostic steps or fallback action

Optionally prefix the criterion with a confidence marker:
- `[RUBBER-STAMP]` — mechanical action, no judgment needed (publish, deploy, click) — convert to Agent AC + `## Verification`
- `[REVIEWER]` — static-scan-verifiable (pattern / wording / convention) — convert to Agent AC + `bin/fw reviewer T-XXX` in `## Verification` (T-1811, T-1878)
- `[REVIEW]` — genuine human judgment required (tone, UX, architecture decisions, blast-radius)

**Example:** `- [ ] [REVIEW] Voice/tone matches writing style` with **Steps:** (read N paragraphs, compare to reference, check anti-patterns), **Expected:** (reads like peer discussion, not product pitch), **If not:** (note paragraphs for revision).

**Prerequisite awareness (T-358):** Steps must start from the human's actual environment, not the agent's dev context. If the feature requires deployment, upgrade, or setup before testing (e.g., `brew upgrade fw`, restart a service, push config), include those steps first. Ask: "What must the human do before step 1 is possible?" If the answer isn't "nothing," add prerequisite steps.

**Full-path commands (T-609, T-1257):** Every command in Steps MUST be copy-pasteable from any directory. Include `cd /path/to/project &&` prefix. Use the project-appropriate `fw` path: `bin/fw` in the framework repo, `.agentic-framework/bin/fw` in consumer projects, bare `fw` only when the shim is confirmed. Chain multiple commands with `&&` on one line — never assume the human will paste lines separately. See §Copy-Pasteable Commands.

If a human AC cannot be made specific (e.g., "code quality is acceptable"), replace it with a measurable proxy or remove it. Vague ACs that nobody acts on are worse than no AC.

**Rendered-content guarantees (T-1575):** the framework's Markdown renderer (`web/blueprints/tasks.py:_render_md_inline` / `_render_md_block`, `web/shared.py:render_markdown_safe`) emits clickable anchors for *every* URL — bare, in `[md](url)` syntax, OR wrapped in `\`backticks\``. Rule: **any URL appearing in rendered task content (AC Steps, Expected, If-not, Recommendation, Rationale, Evidence) is clickable, regardless of how the agent wrote it.** This is the rendering contract — agent need not remember to avoid backticks around URLs. Pinned by `tests/unit/test_extract_recommendation.py:test_render_markdown_safe_makes_backticked_urls_clickable`. Same guarantee applies to bare `T-NNNN` references → `/tasks/T-NNNN`.

### Verification Before Completion
Before setting any task to `work-completed`:
1. Run all commands in the task's `## Verification` section
2. Check every `### Agent` acceptance criterion checkbox (or all ACs if no split headers)
3. If tests exist for the changed code, run them
4. Report results to user with pass/fail evidence
5. Do NOT call `fw task update --status work-completed` until all agent ACs pass
6. The verification gate (P-011) enforces this structurally — this rule makes you check BEFORE hitting the gate

**Progressive AC ticking (T-1831 C-4):** Tick each Agent AC checkbox `- [ ]` → `- [x]` **as soon as the corresponding content/work is in place**, NOT after-the-fact when the gate fires. The completion gate (P-010) and the inception-decide preflight count `[x]` markers — they cannot read body content. Writing the RCA/candidates/recommendation in the body does NOT tick the boxes; you have to do it explicitly. After-the-fact ticking (only after the gate refuses) is the exact pattern the gate exists to prevent — and the user has caught it. Treat each AC as a milestone: when you complete the work for AC #N, your very next edit ticks that box. Origin: S-2026-0514 errors 1-3 in fw-upgrade-incident-2026-05-14 cluster — same antifragility class as T-1828 (gate measures proxy that diverged from reality).

### Consumer-Facing Command Hygiene (T-1633, T-1635)

Any change to `fw upgrade`, `fw vendor`, or `fw init` (the three consumer-facing setup commands) MUST keep `tests/unit/upgrade_fresh_machine_simulation.bats` green. The simulation builds a synthetic consumer (vendored `.agentic-framework/` + `file://` upstream) and runs the consumer's vendored fw under `env -i` with minimal PATH — catching the class where a command silently depends on the framework developer's local filesystem layout.

**Why this rule exists:** T-1633 origin — `fw upgrade` worked on the framework developer's `/opt/999-Agentic-Engineering-Framework` but crashed on every consumer in the wild because path knowledge was implicitly hard-coded. Every consumer-facing flow must run from a clean environment with no developer artifacts; the bats simulation is the cheapest enforcement (no docker dependency, runs in any CI/dev environment). A docker-container variant remains a release-gate follow-up for higher-confidence "true fresh machine" coverage.

### Hook Bypass Contract Parity (T-1890, L-399)

When a PreToolUse hook introduces a bypass contract — e.g. "append `--switch-focus`" or "prefix `FW_X=1`" — the downstream consumers of **every command pattern the hook gates** must honour that contract. A hook that recommends a flag whose downstream parser rejects it as "Unknown option" is a silent governance failure: the agent's workaround (direct-invoke, env-strip, or a different command shape) escapes the regex and bypasses the gate with no audit trail.

**Authoring rule** — when adding a bypass mechanism to a hook:

1. **Identify every command pattern the hook gates.** Each pattern routes to a different downstream consumer (a fw sub-script, an external tool like `git`, etc.).
2. **For each consumer under our control** (fw sub-scripts), add a silent no-op branch that consumes the flag without rejection.
3. **For consumers NOT under our control** (`git commit`, third-party CLIs) — flags fundamentally cannot work, because the external parser rejects unknown options. Use an **env-var prefix** mechanism (`FW_X=1 <command>`) which is invisible to downstream parsers.
4. **Ship both mechanisms when the hook gates a mix of internal + external patterns** (the focus-drift gate is the canonical case: fw commands work with the flag, `git commit` only with the env var).
5. **Pin the contract with an end-to-end bats test** that exercises hook-allow → consumer-accepts → log-entry-written, **per mechanism, per gated pattern**. Unit-testing the hook in isolation is not sufficient; the bug lives at the join, not in either side alone.
6. **Block message must name every mechanism** with one-line guidance on when to pick which, so the agent doesn't fall back to a workaround.

**Why this rule exists:** T-1890 origin — T-1730 shipped the `--switch-focus` bypass contract for the focus-drift gate, but `update-task.sh`, `lib/{learning,pattern,decision}.sh`, and `git commit` all rejected the flag. The agent worked around via direct-invoke `bash agents/task-create/update-task.sh` — a path the hook's regex didn't match. Result: the gate was silently circumvented for ~3 weeks across multiple sessions, with the bypass log showing entries for command lines that never actually completed (the flag-rejection happened *after* the hook logged). Producer/consumer split: the contract shipped on one side only. See L-399 for the broader class.

**The test:** when adding a bypass mechanism, ask: "Can I reach the post-mechanism path *end-to-end* in a real session?" If the answer is "only after I patch four other files and add the env-var fallback", do all of that in the same task. If you can't ship end-to-end in one commit, the contract is incomplete.

### Presenting Work for Human Review (T-679)
When agent ACs are complete and human ACs remain:

1. **Write your recommendation into the task file** — Add a `## Recommendation` section (Watchtower reads this) with:
   - **Recommendation:** GO / NO-GO / DEFER
   - **Rationale:** Why (cite evidence: what was fixed, what was proven, what remains)
   - **Evidence:** Bullet list of concrete proof (test results, file paths, metrics)
   You are the advisory. The human is the decision-maker. Never present a blank decision for them to fill in — always tell them what you recommend and why.

2. **Present via the standardized review command:**
   ```bash
   fw task review T-XXX
   ```
   This emits the Watchtower URL, QR code, and links to research artifacts. **NEVER** give raw CLI commands (`fw inception decide`, `fw task update --status work-completed --force`) for human approvals.

**Why this rule exists:** The agent defaults to (a) pasting CLI commands instead of using Watchtower, and (b) leaving the rationale blank for the human to figure out. Both were corrected 3 times in the same session (T-679). The agent has all the evidence — the human needs a recommendation to confirm or override, not a blank form.

**Structural enforcement (T-1259, T-1260):** `lib/inception.sh do_inception_decide` refuses when `$CLAUDECODE=1` and points agents at `fw task review T-XXX`. Override flag `--i-am-human` exists for script/test contexts; `--from-watchtower` is the Flask-backend exemption.

### Hypothesis-Driven Debugging
When encountering errors or unexpected behavior:
1. **State the symptom** in one sentence
2. **Form one hypothesis** for the root cause
3. **Design one test** to prove or disprove it (a command, a log check, a code read)
4. Run the test and report the result
5. If disproved, form the next hypothesis — max **3 hypotheses** before escalating to user
6. Never shotgun-debug (trying random fixes without understanding the cause)
7. After resolution, record the pattern: `fw healing resolve T-XXX --mitigation "what fixed it"`

### Bug-Fix Learning Checkpoint
When fixing a bug discovered through real-world usage (user testing, production incident, cross-platform failure):
1. **Classify the bug** — Is this a new failure class, or a repeat of a known pattern?
2. **Check learnings.yaml** — Does a learning already exist for this class?
3. If new class: `fw context add-learning "description" --task T-XXX --source P-001`
4. If systemic (same class hit 2+ times): register in `concerns.yaml`, consider tooling fix (Level C/D)

**Trigger:** Any fix cycle addressing a bug found by someone other than the agent (user report, CI failure, production monitoring, cross-platform testing).

**Not triggered by:** Fixes for bugs found during development (pre-commit). Those are normal development, not field discoveries.

**The test:** "If another agent encounters this same class of bug in 6 months, would a learning entry help them fix it faster?" If yes, capture it now.

**Evidence:** 72% of bugfix tasks (31/43) produced zero learnings. T-030 (portability fix) and T-344 (same class, 23 days later) had no learning connecting them. See G-016.

### Post-Fix Root Cause Escalation (G-019)
After fixing any problem discovered by the human (not found during development):
1. **Fix the symptom** — make it work (Level A/B/C)
2. **Ask: "Why did the framework allow this?"** — not "why did the code break" but "what structural omission let this go undetected?"
3. **If the framework was blind for >7 days:** register a gap in `concerns.yaml` — even if it's a single incident, sustained blindness reveals a systemic flaw
4. **Do not close the gap until prevention exists** — mitigation (cleaned up the mess) is not prevention (can't happen again). Ask: "Did I fix the symptom, or did I fix the reason the framework couldn't detect it?"
5. **The human test:** If you're about to close a gap or complete a fix, and you can't explain what structural change prevents recurrence, the gap is not closed.

**Trigger:** Human corrects the agent's escalation level, or agent discovers a problem that existed undetected for >7 days.

**Evidence:** G-018 required 3 human corrections to escalate from symptom (handover TODOs) to root cause (no guard against silent quality decay). See G-019.

**Structural enforcement (T-1550):** Bug-class tasks (workflow_type ∉ {inception, specification, design} AND tag/title matches bug/fix/error/regression/etc.) cannot reach `--status work-completed` without a substantive `## RCA` section. `--skip-rca` bypasses with logged Tier-2 entry. Origin: T-1549 spike showed 99% of bug-class tasks (315/317) shipped without RCA capture — this rule was advisory text for months while the template never asked.

### Arc Completion Discipline (G-062)

Enforced structurally. `fw arc create` requires `--headline-mechanic "<who> <does what> <observes what user-visible result>"` and rejects substrate-only phrasing. `fw arc close` requires `--demo <path|url|none>` — a wire-level artefact (meta.json, stream-json, screencast, live URL) traceable to the arc, or `none` with a `--justification` logged to `.context/audits/arc-bypass.jsonl`. The gates fire before any closure narrative; substrate-vs-deliverable conflation cannot bypass them.

**Trigger:** any time you are about to write `## Recommendation` on an arc-parent task or run `fw arc close`. The mandatory question is whether the captured `--demo` artefact shows the `headline_mechanic` firing — not whether substrate / tests / AC checkboxes ship. The phrases "forward work, not a closure blocker" and "substrate is in place" are §ACD violations in plain text.

**Default-to-OPEN:** if ≥2 human pushbacks on the same arc have not been resolved by a captured headline-mechanic instance, the arc is OPEN regardless of new evidence filed since. The pattern is the signal. **Gated structurally (T-1671):** `fw arc close` refuses under `$CLAUDECODE=1`; closure belongs to the human via `fw task review <anchor>` + Watchtower (overrides: `--i-am-human`, `--from-watchtower`).

**Evidence:** T-1626, T-1633, T-1641 (origin); T-1667 (3rd-incident RCA → demo+headline-mechanic gates); T-1670 (4th-incident agent auto-close → T-1671 closure-decision gate).

### Arc-Scoped Driver Suggestion Workflow (T-1925, arc-006)

When a new arc is created (via `fw arc create` or `fw work-on` of an arc anchor task), the primary agent runs this 5-step workflow **after the arc's anchor-task body is filled** but **before any driver is approved**. The goal is to surface arc-specific drivers that would distinguish the arc from the global D1-D4 directives. Approval stays with the human (M6, D8).

**Steps (D5 — timing matters):**

1. **Read the arc anchor-task body in full** (Problem Statement, Scope Fence, Risks, Decisions). Do **not** propose drivers from the arc name alone.
2. **List 2-3 candidate drivers**, each with a one-line rationale of what the driver distinguishes that the four constitutional directives (D1-D4) do not. If you cannot articulate the distinction in one line, the candidate is not worth proposing.
3. **Write the candidates to `proposed_scoped_drivers:` in the arc YAML** (each as `{name, rationale, source: agent, ts}`). This is a *proposal*, not an assignment — `scoped_drivers:` only mutates via `fw arc approve-driver` (T-1926, §ACD-gated).
4. **Surface the proposals to the human via `fw arc show-suggestions <arc-id>`** (T-1926; D7-reframe — this is a workflow verb the human runs when focus shifts to an arc, not a debug verb). The human reviews, approves up to 3 with `fw arc approve-driver` or runs `--none --justification "..."` to indicate the arc has no scoped drivers worth tracking separately.
5. **If the human approves zero drivers, that is a valid outcome.** Arcs without scoped drivers rank by global D1-D4 only.

**R5 mitigation — the verbatim rule:**

> Manufacturing drivers to look thorough is worse than proposing zero and recommending --none.

Why this matters: every approved scoped driver costs interpretive bandwidth (humans must reason about it, the estimator must score every member task against it). Drivers that don't distinguish the arc are noise that drowns out signal.

**D6 quality criterion:**

> Rationale must explain what each driver distinguishes that globals don't.

A rationale of "this arc is about reliability" does not meet D6 — that's already D2. A rationale of "this arc trades short-term reliability for long-term observability; we want to score tasks that improve the *observability* dimension separately" does meet D6.

**Asymmetric caps:**
- `proposed_scoped_drivers:` — uncapped (D7-reframe: persists for reuse not audit).
- `scoped_drivers:` — max **3** entries, each with weight **≤6** (M2). Approved entries only.

**Worked example.** Consider a hypothetical arc `replay-debug` ("agent replays a failed dispatch from `dispatches.jsonl` and observes the same outcome → confirms determinism"). Plausible candidate drivers:
- `determinism` (weight 5) — *distinguishes from D1: this arc tests that the framework's reasoning is reproducible, not that it strengthens under stress.*
- `replay-fidelity` (weight 4) — *distinguishes from D2: not just "no silent failures" but "outcome under identical inputs is bit-identical".*
- `forensic-detail` (weight 3) — *distinguishes from D3: usability for the developer doing the replay, not the agent doing the work.*

A bad set of candidates (don't do this): `reliability`, `usability`, `correctness` — these duplicate global drivers and would dilute scoring.

**Surfaced through:** `fw arc show-suggestions <arc-id>` (T-1926); Watchtower `/arcs/<id>` shows proposed drivers with Approve buttons (T-1930).

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

## Built-in Task Tool Ban (T-1115/T-1117)

**NEVER use `TodoWrite`, `TaskCreate`, `TaskUpdate`, `TaskList`, or `TaskGet` tools.** They create a parallel, ungoverned task system outside framework governance:
- Items appear in the Claude Code UI status line ("X tasks"), visually identical to framework tasks
- No task gate, no horizon enforcement, no episodic memory, no handover capture
- Creates confusion about whether the agent is running a parallel ungoverned system
- Human caught this in session and asked "are you bypassing framework governance?"

**Structural enforcement:** A PreToolUse hook (`block-task-tools.sh`) blocks all five tools with exit 2 and a redirect message. The hook matches `TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet`.

**Use `bin/fw work-on "task name" --type build`** to create real framework tasks.
Use `bin/fw task create --name "task name"` for more options.

If you need a scratchpad during complex multi-step work, use conversation text or write notes to `.context/working/` — never use Claude Code's built-in todo system.

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

Full command catalogue: `fw help` (or `fw <cmd> --help`). This section lists the governance-critical verbs the agent uses reflexively — not every subcommand.

**Starting and managing work:**
- `fw work-on "name" --type build` — create task + set focus + start (the one-step task gate)
- `fw work-on T-XXX` — resume existing task
- `fw task create` / `fw task update T-XXX --status ...` / `fw task show T-XXX` / `fw task list`
- `fw task update T-XXX --add-tag "ui"` / `--horizon later`
- `fw task stale [--days N]` — list stale tasks
- `fw task review T-XXX` — hand a task to the human via Watchtower (T-679, MANDATORY for human approvals)
- `fw review-queue` — list active tasks awaiting human review, sorted GO-first (T-1536, CLI companion to /approvals)
- `fw verify-acs [T-XXX] [--auto-check|--execute]` — check Human ACs
- `fw pause list` / `fw pause resolve <dispatch_id> --answer "..."` — paused-dispatch chain (dispatch-safety arc slice 5: operator answers worker's `pause_requested`, retry envelope linked via `retry_of_dispatch_id`)

**Inceptions and decisions:**
- `fw inception start "name"` / `fw inception status` / `fw inception decide T-XXX go|no-go|defer --rationale "..."`
- `fw assumption add "..." --task T-XXX` / `fw assumption validate A-XXX --evidence "..."` / `fw assumption list`

**Context and memory:**
- `fw context init` (session start) / `fw context focus T-XXX` / `fw context status`
- `fw context add-learning "..." --task T-XXX --source P-001`
- `fw resume status|sync|quick` — post-compaction recovery
- `fw healing diagnose|resolve T-XXX` / `fw healing patterns`

**Commits, audits, health:**
- `fw git commit -m "T-XXX: ..."` / `fw git status` / `fw git install-hooks`
- `fw audit` / `fw doctor` / `fw gaps` / `fw metrics [predict --type build]`
- `fw test all|unit|integration|web|playwright|lint`

**Handovers and session end:**
- `fw handover [--commit]` / `fw handover --checkpoint` (mid-session)
- `fw push` — push to all remotes
- `fw costs [session|current]` — token usage
- `fw mirror sync|status` — auto-recover lagging github mirror (T-1594, runs every 15 min via cron)

**Fabric (before modifying source):**
- `fw fabric deps <path>` / `fw fabric impact <path>` / `fw fabric blast-radius [ref]`
- `fw fabric overview` / `fw fabric drift` / `fw fabric register <path>`

**Dispatch and cross-project:**
- `fw termlink check|spawn|exec|dispatch|status|cleanup|wait|result` (see TermLink section)
- `fw bus post|read|manifest|clear --task T-XXX [--remote HOST]`
- `fw dispatch send --host HOST ...` / `fw dispatch hosts`
- `fw pickup send|process|status|list`
- `fw pending register|list|resolve|remind` — blocked cross-project actions

**Tier 0, approvals, notifications:**
- `fw tier0 approve` / `fw tier0 status`
- `fw approvals` — approval queue
- `fw notify setup|status|enable|disable|test`

**Scheduling and config:**
- `fw cron generate|status|list|run|pause|resume <job-id>`
- `fw config set|get|list|overrides` — persistent `.framework.yaml` settings

**Orchestrator and resolver (v1 dispatch substrate, T-1687 arc):**
- `fw orchestrator status [--json]` — substrate observability: dispatch counts, outcome enrichment ratio, recent dispatches
- `fw orchestrator improve` — namespace stub for v2 self-improvement (not yet implemented)
- `fw resolver workflows` — list configured workflow files
- `fw resolver dispatch <task_id> <task_type> [--dry-run] [--json]` — build dispatch envelope (workflow → assemble → telemetry)
- `fw resolver explain <dispatch_id>` — forensics for a captured dispatch (reads `.context/dispatches.jsonl`)
- `fw outcome evaluate <task_id> [--json]` — run default evaluator (Verification + Agent ACs)
- `fw outcome backprop <task_id>` — append outcome rows to `dispatch-outcomes.jsonl` for matching dispatches (best-effort hook also fires from `update-task.sh` on `--status work-completed`)
- `fw outcome read <dispatch_id>` — merged dispatch + latest outcome (joins both JSONL files)
- `fw outcome list <task_id>` — all outcome events for a task
- `fw peer subscribe [--once]` — long-poll inbox.queued events + spawn responders (v2 peer-consult subscriber + responder spawn-bridge; cron mode)

**Reviewer (anti-pattern static scan, T-1443):**
- `fw reviewer T-XXX` — scan one task; writes verdict to `## Reviewer Verdict` block
- `fw reviewer T-XXX --dispatch [--timeout N] [--json]` — isolated TermLink worker mode (T-1951, G-066 prong 3)
- `fw reviewer audit` — Layer 3 daily Pass-B re-scan of all completed tasks
- `fw reviewer override add T-XXX --pattern X [--ac N] --reason '...' [--ttl 90]` — TTL'd FP suppression
- `fw reviewer override list|prune|remove OV-XXXX`

**Reviewer dispatch mode (`--dispatch`, T-1951):** Use `fw reviewer T-XXX --dispatch` when reviewing multiple tasks in parallel, when the parent session is budget-pressured, or when you want the reviewer to run in an isolated process with zero context cost to the parent. The worker spawns a TermLink session (`reviewer-{task_id}-{suffix}`, observable via `termlink list`), runs the same `static_scan.py` inline reviewer, and posts the full JSON verdict to the fw bus (`fw bus manifest T-XXX` → `fw bus read T-XXX R-NNN`). Use inline `fw reviewer T-XXX` for single-task quick checks where blocking is fine. Guard: `FW_REVIEWER_IN_DISPATCH=1` is set inside the worker — recursive `--dispatch` is refused (exit 3).

**Knowledge and navigation:**
- `fw decisions` / `fw learnings` / `fw practices` / `fw timeline`
- `fw ask "query"` / `fw recall "query"` / `fw search "term"` / `fw docs`

**Setup and upgrade:**
- `fw init [dir]` / `fw upgrade [dir]` / `fw update` / `fw vendor`
- `fw serve [--port N]` — start Watchtower
- `fw watchtower port|url|status`

**Auto-restart wrapper:** `claude-fw [args...]` (auto-restarts on handover signal) / `claude-fw --no-restart` to opt out.

For rarely-used commands (harvest, promote, consolidate, release, self-test, validate-init, plugin-audit, upstream, enforcement, deploy, prompt, note, scan, mcp, build, fix-learned, onboarding, self-audit, test-onboarding, traceability, hook, hook-enable, patterns, preflight, setup, gpu), run `fw help` or `fw <cmd>`.

## TermLink Integration (T-503)

TermLink is an optional cross-terminal session communication tool (Rust, 26 commands, 264 tests).
The framework provides a thin wrapper via `fw termlink` that adds task-tagging, budget checks,
and cleanup tracking while delegating all real work to the `termlink` binary.

**Distribution model contrast:** TermLink is intentionally machine-wide (installed via Homebrew/cargo, single binary on PATH). This is the deliberate inverse of the framework's per-project isolation model. Reason: TermLink's session discovery uses Unix sockets at system paths — per-project vendoring would defeat cross-session, cross-project communication. Do not propose per-project TermLink installs; use the system binary.

- **Repo:** `https://github.com/DimitriGeelen/termlink` (mirrored from OneDev)
- **Install (macOS):** `brew install DimitriGeelen/termlink/termlink`
- **Install (from source):** `cargo install --path crates/termlink-cli`
- **Check:** `fw termlink check` (also in `fw doctor` as WARN)

### Key Primitives

| Command | Purpose |
|---------|---------|
| `termlink interact <session> <cmd> --json` | Run command, get structured output (star primitive) |
| `termlink pty inject <session> --enter` | Send input, fire-and-forget (long-running commands) |
| `termlink event emit/wait/poll` | Inter-session signaling |
| `termlink discover --json` | Find sessions by tag/role/name |

### Timeout Orphan Warning (T-577)

**Do NOT use `termlink run --timeout` for long-running tasks.** When `termlink run` times out, it deregisters the session but does NOT kill the process. The process becomes orphaned — invisible to TermLink, unmonitorable, still consuming resources. Discovered when a `claude -p` agent wrote output 65 minutes after a 900s timeout.

**Use `fw termlink dispatch` instead** — it has its own kill watchdog that properly terminates the process on timeout. If you must use `termlink run` directly, add your own kill logic.

`fw termlink cleanup` detects and terminates orphaned dispatch processes.

### MCP Task Governance (T-1063)

When `TERMLINK_TASK_GOVERNANCE=1` is set (configured in `.mcp.json`), TermLink MCP tools require a `task_id` parameter. **Always pass the current task ID** when calling TermLink MCP tools:

- `termlink_exec`: `{"command": "...", "session": "...", "task_id": "T-XXX"}`
- `termlink_spawn`: `{"name": "...", "task_id": "T-XXX"}`
- `termlink_interact`: `{"session": "...", "command": "...", "task_id": "T-XXX"}`
- `termlink_dispatch`: `{"name": "...", "prompt": "...", "task_id": "T-XXX"}`

The task_id is the current task from `focus.yaml`. When task_id is passed, it propagates to session tags as `task:T-XXX` for observability.

### Cross-Agent Communication Protocol (T-1126)

When communicating with agents on other machines via TermLink remote, choose the tool based on whether you need a response:

| Need | Tool | Why |
|------|------|-----|
| Ask a question, request action, get feedback | `termlink remote inject <session> --enter "message"` | Direct PTY input — agent processes immediately |
| Deliver files/pickups (no response needed) | `termlink remote push` | Async inbox — processed on schedule |
| Execute a command and get structured output | `termlink remote exec <session> "command"` | Synchronous, returns stdout |
| Send a file to a specific session | `termlink remote send-file` | **Caveat: ok:true = hub accepted, NOT delivered.** Files silently lost to event-only sessions. Always verify receipt. |

**The rule:** If you need a response, use `inject`. If you're delivering and don't need confirmation, use `push`. Never use `push` for questions — the receiving agent won't see it until their next cron or prompt.

**Evidence:** Session S-2026-0412 sent 2 push messages to ring20-manager — zero response. Switched to inject — immediate response + file resend within seconds.

### Budget Rules

- **Do not spawn new sessions when context > 60%** — spawning is expensive, respect budget
- **Always cleanup before session end** — `fw termlink cleanup`
- **Max 5 parallel workers** — same limit as sub-agent dispatch protocol
- **Leave 40K tokens headroom** before dispatching workers

## Auto-Restart (T-179)

When context budget hits critical, `checkpoint.sh` auto-generates a handover and writes `.context/working/.restart-requested`. If the user started their session via `claude-fw` (instead of `claude`), the wrapper detects this signal on exit and auto-restarts with `claude -c`. The `SessionStart:resume` hook then injects handover context into the fresh session.

**Flow:** Budget critical → auto-handover → signal file → claude exits → wrapper detects → `sleep 3` → `claude -c` → context injected → `/resume` ready.

**Safety:** 5-minute TTL on signal files, max 5 consecutive restarts, 3-second cancel window, opt-out via `--no-restart`.

## Remote Session Access (TermLink)

Launch with TermLink wrapping for remote observation and control:

```bash
claude-fw --termlink          # Register session for remote access
TL_CLAUDE_ENABLED=1 claude-fw # Same via env var
```

From another terminal:

```bash
termlink list                              # See the session
termlink attach claude-master-<PID>        # Full TUI mirror (bidirectional)
termlink pty output claude-master-<PID> --strip-ansi  # Read recent output
```

TermLink is optional. Without it installed, `--termlink` prints a warning and falls back to direct mode. The PTY session persists across auto-restarts — the same session is reused when `claude -c` re-launches.

## Session End Protocol

**Before ending any session:**
1. Run session capture checklist (`agents/session-capture/AGENT.md`)
2. Create tasks for all uncaptured work
3. Update practices with learnings
4. Generate handover: `fw handover --commit` (auto-commits AND pushes to all remotes)
5. If push fails: warn the user — unpushed commits are a data loss risk
6. Run `fw metrics` to verify state

**Do not end a session without generating a handover.**
**Do not end a session with unpushed commits** — `fw handover --commit` pushes automatically (T-1144). If push fails (divergence, auth), flag it to the user before ending.
