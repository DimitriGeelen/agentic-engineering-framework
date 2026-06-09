![agentic-engineering-framework](header.svg)
> A governance and continuity harness around AI coding agents. Tasks, memory,
> blast-radius foresight, value scoring, audit, and cross-agent coordination —
> wrapped around any CLI agent you already use. Coordinates, does not execute.

I built this because I recognised a pattern. In 25 years of enterprise IT
governance — transition management at Shell, operational readiness for
infrastructure programmes — the same structural requirements appear every
time a powerful actor operates in a shared environment. Clear direction.
Awareness of context. Awareness of resource constraints. Awareness of impact.
Capable engaged actors. Remove any one and the system degrades.

The domain changed from human operators to AI coding agents. The principle
did not.

## The five requirements, one harness

Each requirement is a layer. Each layer has structural mechanisms behind it.
This is what each looks like in a terminal.

### Clear direction — a task gate that cannot be ignored

Nothing happens without a task. The PreToolUse hook intercepts every file
modification and refuses if no active task is set. Real output, captured this
session when I tried to run a bash command under a task that still had
placeholder acceptance criteria:

```
BLOCKED: Task T-2274 is a build task with placeholder/missing ACs.

Build tasks require real acceptance criteria before editing source files.
This prevents unscoped building. (G-020: Scope-Aware Task Gate)

To unblock:
  1. Edit the task file: replace [First criterion] with real ACs
  2. Or change to inception:
     bin/fw task update T-2274 --type inception

Attempting to modify:
Policy: G-020 (Pickup message governance bypass prevention)
```

The gate is not a convention. It is a wall. The agent that wrote those words
above is the same agent writing this README — it tripped its own gate, fixed
the ACs, and proceeded.

### Awareness of context — three layers of memory that survive

A session that does not remember the last session re-debates every decision.
Three layers carry knowledge forward:

- **Working memory** — what is happening now (`.context/working/`)
- **Project memory** — patterns, decisions, learnings, gaps the project has
  accumulated (`.context/project/`)
- **Episodic memory** — condensed histories of every completed task, generated
  at completion (`.context/episodic/`)

```bash
fw recall "authentication timeout pattern"
# → returns matching learnings, patterns, and episodic entries by meaning,
#   not just keyword.
```
*[ILLUSTRATIVE — exact ranked output varies by project]*

At session end, `fw handover --commit` writes a structured handover that the
next session reads on start. Compaction recovery via `fw resume status` works
when a session is compressed mid-stream.

### Awareness of resource constraints — a budget gate that auto-handovers

Context windows are finite. The budget gate reads the live transcript and
escalates: ok at < 75%, warn at 75–85%, urgent at 85–95%, critical above 95%.
At critical, Write/Edit to source files is blocked and only wrap-up actions
(`git commit`, `fw handover`, `fw task update`) are allowed.

```
══════════════════════════════════════════════════════════
  SESSION WRAPPING UP (~285000 tokens)
══════════════════════════════════════════════════════════

  Context is at ~95% of context window.
  Task files already have all essential state. Time to wrap up.

  ALLOWED: git commit, fw handover, reading files,
           Write/Edit to .context/ .tasks/ .claude/
  BLOCKED: Write/Edit to source files, Bash (except commit/handover)

  Action: Commit your work, then run 'fw handover'
══════════════════════════════════════════════════════════
```

*(Format from `agents/context/budget-gate.sh:132–145`; the token count varies
with the live transcript.)*

A long session ends gracefully with state captured, not abruptly with state
lost.

### Awareness of impact — a structural map of the codebase

Before changing a file, the agent can see what depends on it.

```bash
fw fabric deps agents/git/git.sh         # what depends on this file?
fw fabric blast-radius HEAD              # what does this commit affect downstream?
fw fabric drift                          # unregistered files, orphaned cards
```

Component cards are YAML files in `.fabric/components/`. The dashboard
renders the graph at `/fabric` for interactive exploration. The same signal
feeds Business Value Points (below) as the cost component of every task's
score.

### Capable engaged actors — a tiered authority model

```
Human     → SOVEREIGNTY  → can override anything, is accountable
Framework → AUTHORITY    → enforces rules, checks gates, logs everything
Agent     → INITIATIVE   → can propose, request, suggest — never decides
```

The agent may choose which task to work on. It may choose an implementation
approach. It may not approve its own work. The verbs that constitute approval
— `fw inception decide`, `fw arc close`, `fw bvp confirm`, `fw tier0 approve`,
`fw enforcement baseline` — refuse to run under agent control and route to a
human via the Watchtower dashboard. Initiative is not authority.

| Tier | Scope | Approval |
|---|---|---|
| **0** | Destructive commands (`--force`, `rm -rf`, `DROP TABLE`, `--no-verify`) | Human must approve via `fw tier0 approve` |
| **1** | All file modifications | Active task required |
| **2** | Situational exceptions | Single-use, logged in `.context/working/.gate-bypass-log.yaml` |
| **3** | Read-only operations | Pre-approved |

Every bypass is logged. Every approval is auditable.

## See it work in five minutes

```bash
# 1. Install the framework globally (one machine, once)
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash

# 2. Initialise a project
mkdir my-project && cd my-project && git init
fw init --provider claude

# 3. Try to edit without a task — the gate refuses
#    (You will see the BLOCKED message from §Clear Direction above.)

# 4. Create a task and start working
fw work-on "Add authentication" --type build

# 5. Run a compliance audit + open the dashboard
fw audit                  # 260+ checks across 26 sections
fw serve                  # Watchtower dashboard
fw watchtower url         # prints the URL to open
```

Five commands. The repo now has task-traced commits, structural enforcement,
continuous audit, persistent memory, and a dashboard. The dashboard does not
auto-start today — `fw serve` is one step. T-1611 is the active task to move
Watchtower to a service model so it surfaces automatically.

## What you actually get

The framework is six layers. Each is a real subsystem with shipped CLI verbs.

<details>
<summary><b>Govern</b> — task gate · Tier 0 · sovereignty · single-gate invariant</summary>

Structural enforcement of "nothing happens without a task." Pre-tool hooks
fire on every file edit and every Bash invocation. Tier 0 intercepts
destructive commands. Sovereignty-bound verbs (approve, decide, close, confirm)
refuse to run under an agent and require a human via Watchtower. The MCP
server facade preserves the same boundary — external callers shell out
through `bin/fw` rather than re-implement gate logic ("single-gate invariant").

</details>

<details>
<summary><b>Remember</b> — three-layer memory · handover · resume · semantic recall</summary>

Working, project, and episodic memory persist across sessions. `fw handover
--commit` bridges sessions; `fw resume status` recovers from compaction; `fw
recall "<query>"` searches across learnings, patterns, decisions, and
episodics by meaning.

```bash
fw context add-decision "Use YAML for configs" --task T-001 \
  --rationale "Human readable, comments supported"
fw context add-learning "Always set connection pool limits" --task T-001
fw decisions      # browse all architectural decisions with rationale
fw learnings      # browse all captured learnings
```
*[ILLUSTRATIVE — output varies by project]*

</details>

<details>
<summary><b>Map</b> — Component Fabric · blast-radius · drift</summary>

A live structural map of every significant file in the project. Each
component is a YAML card recording purpose, interfaces, depends_on, and
depended_by. `fw fabric blast-radius HEAD` computes downstream impact for
the current commit; `fw fabric drift` detects unregistered or orphaned
components.

```bash
fw fabric overview            # subsystem summary
fw fabric impact <path>       # full downstream chain
fw fabric register <path>     # add a new component card
```

The dashboard renders the dependency graph with subsystem filters at `/fabric`.

</details>

<details>
<summary><b>Organize</b> — tasks · arcs · inceptions · horizon</summary>

Tasks are Markdown files with YAML frontmatter — acceptance criteria,
verification commands, decisions, BVP scores. Workflow types: build, test,
refactor, decommission, specification, design, inception.

Arcs group related tasks under a single user-observable mechanic (the
"headline mechanic"). An arc closes only when a wire-level demo artefact
proves the mechanic fires — substrate is not closure. Ten arcs are
registered today: dispatch-safety, embeddings-strategy, orchestrator-rethink,
project-shape-resilience, arc-grooming, value-prioritisation, watchtower-redesign,
inception-review-loop, horizon-axis-hardening, capability-overlay.

Inception is a workflow type for exploring a problem before committing to
build. The agent cannot ship build artefacts under an inception task until a
human records GO / NO-GO / DEFER with rationale.

Horizon (`now` / `next` / `later`) is the priority field; the handover agent
sorts work in progress by it and excludes `later` from suggestions.

```bash
fw work-on "Fix login bug" --type build       # one-step: create + focus + start
fw arc list                                   # ten arcs and their states
fw inception start "Define caching strategy"  # explore before building
fw task update T-XXX --horizon later          # park work without losing it
```

</details>

<details>
<summary><b>Measure</b> — BVP · weighted directives · audit · reviewer · metrics</summary>

Business Value Points: directive-weighted scores
(Σ driver_weight × driver_score) over a composite cost
(0.6 × blast_radius + 0.3 × tier + 0.1 × effort). The four constitutional
directives are the protected drivers (D1 Antifragility, D2 Reliability, D3
Usability, D4 Portability) with weights 9, 7, 5, 3. Projects can add free
drivers and arcs can have arc-scoped drivers, both capped to keep the value
system explicit rather than sprawling.

```bash
fw bvp                           # rank all tasks by directive-weighted value
fw bvp --quadrant hv-lc          # high value, low cost — the actionable list
fw bvp T-XXX                     # per-driver detail for one task
```

Audit runs 260+ checks across 26 sections (structure, task compliance, git
traceability, enforcement, learning capture, episodic completeness, gaps,
graduation, fabric integrity, framework-mcp baseline, and more). Cron fires
every 30 minutes; the pre-push hook fires on every push.

The Reviewer agent performs decorrelated review — an isolated static scan
that flags anti-patterns the producing session cannot catch about itself
(`mock-only-integration`, `swallowed-errors`, `defer-as-hedge`, others).
`fw reviewer T-XXX --dispatch` runs the reviewer in a TermLink worker with
zero parent-session context cost.

</details>

<details>
<summary><b>Coordinate</b> — TermLink · bus · dispatch · pickup · MCP server · Watchtower</summary>

The framework wraps an external TermLink binary for cross-terminal, cross-host
worker sessions. Heavy parallel work runs in isolated processes and survives
parent compaction.

```bash
fw termlink dispatch --task T-XXX --name <worker> --project /opt/... \
  --prompt-file work.md --timeout 1800
fw bus manifest T-XXX               # what results has the worker posted?
fw bus read T-XXX R-001             # inspect a specific result
fw dispatch send --host dev-server  # SSH-route a bus envelope
fw pickup list                      # discover sibling projects
```

The Framework MCP server (just shipped) exposes 22 capabilities to external
agents (Claude Desktop, MCP-aware editors) — 16 read-only verbs plus 6
agent-authority verbs (state-changing, schema-gated on `task_id`). Five
sovereignty-bound verbs are deliberately **never registered** because external
callers bypass in-process enforcement. All agent-authority MCP tools shell
out through `bin/fw` so the same gates fire.

```bash
fw mcp emit-manifest    # write agents/mcp/framework-mcp-manifest.json
fw mcp start            # start the stdio server
fw mcp status           # 22 / gated: 6
```

Watchtower (Flask + 14 KB of vendored htmx, no build step, no node_modules)
is the human-review surface. Task board, BVP rankings, audit reports, fabric
graph, approvals queue, gap register, reviewer verdicts. Currently launched
manually with `fw serve`; auto-start at install is the goal of T-1611.

</details>

## Installation

Hand it to your agent first. The other strategies are there when you need a
different shape.

### Hand it to your agent (lead)

Paste this verbatim into your agent's chat. The agent runs it; the framework
arrives.

```
Install the Agentic Engineering Framework into this project. Steps:

1. Verify prerequisites:
     bash --version       # need 4.4 or newer
     git --version        # need 2.20 or newer
     python3 --version    # need 3.8 or newer

2. Install the framework globally (one machine, once):
     curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash

3. Initialise this project (run inside the project root):
     fw init                  # auto-detects provider; pass --provider claude|cursor|generic to force

4. Surface the dashboard URL (Watchtower does not auto-start today):
     fw serve &               # background the dashboard
     fw watchtower url        # print the URL to open

5. Report back to me:
     - the project path
     - the dashboard URL
     - how many onboarding tasks were created
     - any warnings from `fw doctor`

Then create the first task with `fw work-on "name" --type build` and stop —
the rest is mine to decide.
```

*[ILLUSTRATIVE — this block has not been end-to-end tested against a fresh
machine in this session; the first agent or human to run it should capture the
real output and confirm or correct it.]*

Use this when: you already have Claude Code, Cursor, Aider, or another CLI
agent open and want to try AEF on a real project without leaving the editor.

### Curl-pipe-bash (single-user)

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
```

This clones to `~/.agentic-framework`, installs `fw-shim` to `~/.local/bin/fw`
(the project-detecting router), links `claude-fw`, and runs `fw doctor`.

Use this when: you are installing for yourself and trust the pipe-bash idiom.

### Local-clone install

```bash
git clone https://github.com/DimitriGeelen/agentic-engineering-framework.git ~/.agentic-framework
bash ~/.agentic-framework/install.sh --local ~/.agentic-framework
```

Use this when: you want to read the install script before running it, or you
are offline.

### `fw init` per-project (after global install)

```bash
cd existing-project
fw init                              # auto-detect provider
fw init --provider claude            # or: cursor, generic
fw work-on "First task" --type build
```

Use this when: every project. This is the per-project verb after the
framework is on PATH.

### Vendored isolation (no global at all)

`fw init` copies `bin/`, `lib/`, `agents/`, `web/`, `docs/`, FRAMEWORK.md, and
the metric helpers into `.agentic-framework/` inside your project. The shim
at `~/.local/bin/fw` walks up from your CWD to find the project-local copy.
Each project pins its own framework version.

Use this when: you are working in a shared repo or production project and
want predictable version pinning per project.

### `fw upgrade` from inside a consumer

```bash
fw upgrade                           # syncs the consumer to the framework's current version
fw upgrade --dry-run                 # preview only
```

Use this when: routine version uplift. The framework retains backward
compatibility on the wire; the upgrade refreshes hooks and vendored scripts.

### Recover a legacy consumer (pre-T-2232 vendoring)

```bash
fw consumer-recover <host> [path] --apply [--via {ssh,termlink}]
```

Use this when: an older consumer was vendored before the durable in-consumer
upgrade landed and cannot self-upgrade in place.

### CI / GitHub Action

```yaml
# .github/workflows/audit.yml
- uses: DimitriGeelen/agentic-engineering-framework@v1
  with:
    fail-on-warnings: 'false'        # block PRs only on FAIL; warnings advisory
```

Use this when: you want CI to gate PRs on `fw audit` results.

### Homebrew (macOS / Linux)

```bash
brew install DimitriGeelen/agentic-fw/agentic-fw
```

Use this when: you prefer brew over curl-pipe-bash.

### Prerequisites

The installer checks these:

- **bash 4.4+** — macOS ships 3.2 by default; `brew install bash` gets a
  current version.
- **git 2.20+**
- **python3 3.8+** (PyYAML is optional; needed only for `fw serve` and a
  small number of helper scripts).
- **Node.js** is optional — recommended for TypeScript hooks; Python is the
  fallback.

## Maturity — shipped versus evolving

This is alpha software the author uses daily. Some pieces are stable. Some
are actively iterating. The maturity table is honest in both directions.

| Capability | Status |
|---|---|
| Task gate, Tier 0, sovereignty refusals, single-gate invariant | shipped, exercised daily |
| Three-layer memory, handover, resume, semantic recall | shipped, stable |
| Component Fabric, blast-radius, drift | shipped, stable |
| Task system, arcs, inceptions, horizon | shipped, stable (10 arcs registered) |
| BVP, weighted directives, audit (260+ checks), reviewer | shipped, stable |
| TermLink integration, bus, dispatch, pickup | shipped, stable |
| Watchtower dashboard | shipped (functional) |
| Framework MCP server (read-only + agent-authority facade) | shipped this week (T-2265); 22 tools registered; HM-A demo and Watchtower migration in flight |
| Embeddings strategy maturation (arc-002) | working, evolving |
| Watchtower auto-start at install (T-1611) | designed, not yet shipped |
| Multi-provider validation (Cursor, Aider, Devin) | designed, not validated — Claude Code is the tested provider |

A separate gap worth naming: deep-dive #17 (`why-bash-yaml-files.md`) flags
the bash enforcement layer as the part most needing structured bats
coverage. That is a real hole the author is open about.

## What this is not

The framework coordinates agents. It does not execute them.

It is not a chatbot, an agent runtime, a multi-app personal assistant, or a
multi-agent pipeline. Run OpenClaw for multi-app automation. Run LangGraph
for stateful agent orchestration. Run CrewAI for multi-agent pipelines. Run
Claude Code, Cursor, Aider, Devin, or any CLI-capable agent as your model
runtime. Run this inside the repos those agents touch — so nothing gets
committed without traceability and nothing gets destroyed without approval.

The model lives in your agent. The governance lives here.

## Self-governing

This framework develops itself under its own governance using Claude Code:
2,239 tasks created, 2,037 completed, 99% commit traceability across the
most recent 500 commits, every architectural decision recorded with
rationale, 263 audit emit-points across 26 sections firing on every push
and every 30 minutes. The framework is its own case study — or its own
most elaborate yak-shave, depending on your perspective.

A recent commit log line:

```
cca38ab8a T-077: Checkpoint handover S-2026-0609-0851
26bf03178 T-2200+T-2202: backfill OBS-053/054/055 text bodies (fw note "add" silent-swallow)
d4fcd724c T-2265: t9 — pin name-level parity between live MCP server and manifest
6d2fbb7f7 T-1687: fabric enrich — +2 edges across 2 cards
a74aad9bd T-2268: evidence README — add Operator Quickstart (3-step demo path)
043e3abcf T-2200+T-2202: workers exit 0; outcomes integrated + surfaced
```

Every commit traces to a task. Every task has acceptance criteria that were
verified. Every decision is recorded with rationale. The framework is the
evidence.

## Key commands

| Command | Purpose |
|---|---|
| `fw work-on "name" --type build` | one-step: create task, set focus, start work |
| `fw work-on T-XXX` | resume an existing task |
| `fw task update T-XXX --status work-completed` | close task (runs verification gate, AC gate, RCA gate where applicable) |
| `fw arc create <slug> --headline-mechanic "..." --anchor T-XXXX` | create a multi-task arc |
| `fw bvp` | rank all tasks by directive-weighted value over composite cost |
| `fw bvp --quadrant hv-lc` | high-value, low-cost shortlist |
| `fw recall "<query>"` | semantic search across project memory |
| `fw fabric blast-radius HEAD` | downstream impact of the current commit |
| `fw audit` | run all 260+ checks |
| `fw reviewer T-XXX [--dispatch]` | decorrelated static-scan review |
| `fw handover --commit` | end-of-session context handover |
| `fw resume status` | post-compaction recovery |
| `fw serve` | start Watchtower dashboard |
| `fw watchtower url` | print the dashboard URL |
| `fw inception decide T-XXX go --rationale "..."` | record an inception go/no-go (human-only) |
| `fw tier0 approve` | approve a blocked destructive command (human-only) |
| `fw mcp start \| status \| emit-manifest` | framework MCP server lifecycle |
| `fw help` | full command catalogue (≈ 60 verbs across 11 sections) |

For everything else: `fw <verb> --help` and FRAMEWORK.md.

## Documentation

- **[FRAMEWORK.md](FRAMEWORK.md)** — provider-neutral operating guide
- **[CLAUDE.md](CLAUDE.md)** — Claude Code integration and the full reference
- **[docs/articles/](docs/articles/)** — launch article and 19 deep-dive
  posts, each on one capability
- **Watchtower** — `fw serve`, then `fw watchtower url`

## Team usage

- Per-repo enforcement: `fw git install-hooks` installs the commit-msg and
  pre-push hooks per repo
- Shared dashboard: deploy Watchtower for team-wide visibility
- CI gating: see the GitHub Action snippet under §Installation
- Cross-machine coordination: TermLink + bus + dispatch (see §Coordinate)

## When to use, when not to

Use this when:

- AI agents work on your codebase regularly
- You need audit trails for agent actions
- Sessions span days and context is otherwise lost
- You want destructive actions to wait for human approval
- You want value-driven prioritisation rather than recency-driven backlog
- You want a wider harness — memory, structural awareness, audit, coordination —
  not just a gate

Skip this when:

- One-off prototypes
- Solo projects under a week
- You do not use AI coding agents

## Architecture and principles (contributor-facing)

<details>
<summary><b>Architecture</b></summary>

The framework runs as a CLI (`fw`) that routes to specialised agents.
Internally organised into 20 agent subsystems and 55 lib modules; you
interact with about 60 top-level commands and a dashboard.

```
bin/fw                  CLI entry point
bin/fw-shim             project-detecting router (~/.local/bin/fw)
agents/                 20 subsystems
  audit/                governance checks (260+, 26 sections)
  context/              memory, focus, budget gates
  fabric/               component topology, blast-radius
  git/                  task-traced git operations + hooks
  handover/             session handover generation
  healing/              error recovery, pattern recording
  mcp/                  framework MCP server (T-2265)
  metrics/              project metrics dashboard
  resume/               compaction recovery
  reviewer/             decorrelated static-scan review
  task-create/          task creation + update + verification
  termlink/             cross-terminal worker integration
  ... (and 8 others)
lib/                    55 shell modules (init, upgrade, vendor,
                        bvp, arc, inception, bus, dispatch,
                        consumer-recover, paths, ...)
web/                    Watchtower (Flask + htmx, no build step)
policy/                 value-drivers, capability-overlay tool-set
.tasks/                 task files (Markdown + YAML frontmatter)
.context/               working, project, episodic memory; arcs; audits
.fabric/                component topology cards
.claude/                provider config and hook wiring
```

</details>

<details>
<summary><b>Constitutional directives (in priority order)</b></summary>

1. **Antifragility** — the system strengthens under stress; failures are
   learning events
2. **Reliability** — predictable, observable, auditable execution; no
   silent failures
3. **Usability** — sensible defaults, actionable errors, minimal ceremony
4. **Portability** — no provider, language, or environment lock-in

Every architectural decision traces back to these four. They are also the
default value drivers in the BVP scoring rubric (weights 9, 7, 5, 3).

</details>

<details>
<summary><b>Authority model</b></summary>

```
Human     → SOVEREIGNTY  → can override anything, is accountable
Framework → AUTHORITY    → enforces rules, checks gates, logs everything
Agent     → INITIATIVE   → can propose, request, suggest — never decides
```

Initiative is not authority. A broad directive ("proceed as you see fit")
delegates initiative, not approval. When a structural gate blocks an action,
the gate wins.

</details>

<details>
<summary><b>The stack and why</b></summary>

Bash, YAML, plain files, Flask, cron, 14 KB of vendored htmx, no build step,
no database. Each choice traces to one of the four directives, especially
Reliability and Portability. The full argument — including the questions
this stack invites from experienced engineers — is in
[docs/articles/deep-dives/17-why-bash-yaml-files.md](docs/articles/deep-dives/17-why-bash-yaml-files.md).

The short version: governance infrastructure should be the simplest
technology that works, not the most sophisticated technology available.
Every layer of abstraction is a place where enforcement can silently fail.
Plain text files in git cannot silently lose data.

</details>

## License

Apache 2.0 — see [LICENSE](LICENSE).

Copyright 2025–2026 Geelen & Company

---

The principle holds: effective intelligent action requires clear direction,
context awareness, awareness of constraints and impact, and capable engaged
actors. This was true for Shell's global transitions. It is true for AI
coding agents. The domain changed. The principle did not.
