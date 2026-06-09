---
title: "T-2274: AEF README research dossier"
task: T-2274
type: research-dossier
created: 2026-06-09
inputs:
  - docs/reports/T-445-readme-overhaul.md
  - docs/articles/launch-article.md
  - docs/articles/deep-dives/{04-three-layer-memory, 15-enforcement, 17-why-bash-yaml-files}.md
  - README.md (current, 353 lines, last touched 2026-04-22)
  - FRAMEWORK.md (375 lines, 2026-06-08)
  - CLAUDE.md (1183 lines, 2026-06-08)
  - install.sh, lib/init.sh, lib/upgrade.sh
  - .tasks/{active,completed}/, .context/arcs/
  - Capability-inventory walk via Explore agent (see §1A citations)
---

# T-2274 — Research dossier for the AEF README rewrite

This dossier is the foundation for `README.draft.md`. Every section here cites code or
real output. Where I could not verify a claim, I say so in §GAPS rather than guess.

The work follows the worker contract handed in by the operator: six research lenses
(1A–1F), then a frame test, then a structure proposal, then the draft itself. The
draft is a separate file (`README.draft.md`) — this dossier never overwrites the live
README.

T-445 (March 2026) already did a competitive-positioning pass and a voice guide. I
build on that rather than redo it. The framework has grown materially since then
(Arc system, BVP, TermLink coordination, MCP server) and the live README is stale on
nearly every concrete number — that is the gap T-2274 is here to close.

---

## §1A — Capability inventory

Walked from `bin/fw`, `lib/`, `agents/`, `web/`, `policy/`, `.context/`. Counts and
file paths are direct measurements, not estimates.

### Headline measurements (replace the live README's stale numbers)

| Metric | Live README claim | Verified value | Source |
|--------|------|----------------|--------|
| Total tasks (active + completed) | "545+" | **2,239** | `ls .tasks/{active,completed}/T-*.md \| wc -l` |
| Completed tasks | "488+" | **2,037** | `ls .tasks/completed/T-*.md \| wc -l` |
| Commit traceability (last 500) | "96%" | **99%** (498/500) | `git log --oneline -500 \| grep -c "T-[0-9]"` |
| Audit `pass`/`warn`/`fail` emit points | "150+" | **263** | `grep -cE "^\s+(pass\|warn\|fail\|grace_warn\|grace_fail)\s+\"" agents/audit/audit.sh` |
| Audit section banners | (not stated) | **26** | `grep -cE '^\s*echo\s+"==' agents/audit/audit.sh` (one is the report header) |
| `agents/` subsystems | "15 subsystems" (architecture block) | **20** | `ls -d agents/*/ \| wc -l` |
| `lib/*.sh` modules | (not stated) | **55** | `ls lib/*.sh \| wc -l` |
| Arcs registered | (not mentioned) | **10** | `ls .context/arcs/*.yaml \| wc -l` |
| `fw` version | (not stated) | **1.6.72** | `cat VERSION` |
| Top-level `fw` commands | "roughly 6" (architecture block) | **~60+** across 11 sections | `fw help` |

### Capability table (cluster grouping VERIFIED against code, with maturity tags)

Source for entries: Explore-agent walk reported in this session, cross-checked
against the files listed in each row. Maturity tags: `shipped-stable` = present and
exercised in production; `working-evolving` = present but actively iterating; the
state is taken from code + `.tasks/` + `.context/arcs/`.

#### Govern · authority

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| Task gate (Tier 1) — file edits without an active task are blocked | `agents/context/check-active-task.sh` (PreToolUse hook, ~150 lines) | implicit on every Write/Edit/Bash | shipped-stable |
| Scope-aware task gate (G-020) — placeholder ACs refuse Bash | same script, scope check | implicit | shipped-stable (I tripped it myself on T-2274 this session — see `BLOCKED: Task T-2274 is a build task with placeholder/missing ACs.`) |
| Tier 0 — destructive commands need human approval | `agents/context/check-tier0.sh` + `lib/tier0.sh` | `fw tier0 approve` | shipped-stable |
| Sovereignty / `$CLAUDECODE=1` refusals | `lib/bvp.sh:60-81` (`acd_gate`), `lib/inception.sh` (`do_inception_decide`), `lib/arc.sh` (`fw arc close`) | the verbs themselves refuse; bypass via `--i-am-human` (logged) | shipped-stable |
| Bypass audit trail | `.context/working/.gate-bypass-log.yaml` (auto-populated by `--no-verify` + Tier-2 bypass envs) | `cat .context/working/.gate-bypass-log.yaml` | shipped-stable |
| Enforcement baseline | `lib/enforcement.sh`, `fw enforcement baseline` | `fw enforcement baseline` (Sovereign-only) | shipped-stable |
| Single-gate / producer-not-judge invariant | one entry point (`bin/fw` + `bin/fw-shim`); MCP server shells out to `bin/fw context focus` rather than re-implementing | architectural rule | shipped-stable (documented in T-2265's evolution log) |

#### Remember

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| Working memory | `.context/working/` (focus.yaml, session.yaml, watchtower.{pid,port,url}) | `fw context init`, `fw context status` | shipped-stable |
| Project memory | `.context/project/` (decisions.yaml, learnings.yaml, patterns.yaml, practices.yaml, concerns.yaml, assumptions.yaml) | `fw context add-decision`, `fw decisions`, `fw learnings`, `fw practices`, `fw patterns` | shipped-stable |
| Episodic memory | `.context/episodic/T-*.yaml` — auto-generated at `fw task update --status work-completed` | `fw task show T-XXX` (shows episodic), `fw recall <query>` | shipped-stable |
| Session handover | `agents/handover/` — `.context/handovers/S-*.md` | `fw handover --commit` | shipped-stable |
| Resume / compaction recovery | `agents/resume/`, `.claude/settings.json` `SessionStart` hook | `fw resume status\|sync\|quick` | shipped-stable |
| Semantic recall | sqlite-vec + RAG via `fw recall`, `fw ask`, `fw search --semantic\|--hybrid` | `fw recall "<text>"`, `fw ask "<question>"` | working-evolving (arc-002 embeddings-strategy active) |

#### Map

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| Component Fabric (topology cards) | `.fabric/components/*.yaml` + `lib/fabric.sh` + `agents/fabric/` | `fw fabric overview\|deps\|impact\|drift\|search\|register` | shipped-stable |
| Blast-radius foresight | `fw fabric blast-radius [ref]` | reads cards + git diff | shipped-stable |
| Fabric explorer (Watchtower) | `web/blueprints/fabric.py` | `/fabric` in dashboard | shipped-stable |

#### Organize

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| Task system (Markdown + YAML frontmatter) | `.tasks/{active,completed,templates}/` + `lib/tasks.sh` + `agents/task-create/` | `fw work-on`, `fw task create\|update\|show\|list` | shipped-stable |
| Workflow types (build · test · refactor · decommission · spec · design · inception) | task frontmatter + handlers in `lib/inception.sh`, `agents/task-create/update-task.sh` | declared in `--type` | shipped-stable |
| Horizon (`now`/`next`/`later`) | task frontmatter + `update-task.sh` invariants | `fw task update --horizon …`, `fw task list --horizon now` | shipped-stable |
| Arc system (multi-task workspace, immutable id, headline mechanic, demo gate) | `lib/arc.sh` + `.context/arcs/*.yaml` + `docs/012-ArcSystem.md` (FRAMEWORK.md §Arc System) | `fw arc create\|start\|focus\|close\|abandon\|list\|show` | shipped-stable (10 arcs registered; arc-001..arc-010) |
| Inception workflow (explore → go/no-go) | `lib/inception.sh` + workflow_type `inception` + `## Recommendation` block | `fw inception start\|status\|decide` (`decide` Sovereign-only) | shipped-stable |

#### Measure

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| BVP (Business Value Points) ranking | `lib/bvp.sh` (~3000 lines) + `policy/value-drivers.yaml` | `fw bvp` (rank), `fw bvp T-XXX` (detail), `fw bvp --quadrant hv-lc`, `fw bvp weight`, `fw bvp confirm` (Sovereign) | shipped-stable (arc-006 value-prioritisation closed core slices) |
| Constitutional directives as weighted drivers (D1–D4) | `policy/value-drivers.yaml` | weights `9/7/5/3` for D1–D4 by default | shipped-stable |
| Free + arc-scoped drivers | `policy/value-drivers.yaml.free_drivers[]`, arc YAML `scoped_drivers[]`, max 3 per arc, weight ≤6 | `fw arc approve-driver` (Sovereign), `fw arc show-suggestions` | shipped-stable; F-RECALL + F-ORCH active per project memory |
| Audit (260+ checks across 26 sections) | `agents/audit/audit.sh` (4,965 lines, 263 emit points) | `fw audit`, `fw audit --json`, daily cron | shipped-stable |
| Metrics dashboard / effort prediction | `agents/metrics/`, `fw metrics`, `fw metrics predict` | as listed | shipped-stable |
| Reviewer (anti-pattern static scan, T-1443) | `lib/reviewer/static_scan.py` | `fw reviewer T-XXX`, `fw reviewer audit`, `fw reviewer override` | shipped-stable; can run in `--dispatch` worker mode (T-1951) |

#### Coordinate

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| TermLink integration (cross-terminal session bus) | `lib/termlink.sh`, `agents/termlink/`; external binary `termlink` | `fw termlink check\|spawn\|exec\|dispatch\|status\|cleanup` | shipped-stable; framework wraps an external Rust binary |
| Result ledger / bus | `lib/bus.sh`, `.context/bus/results/<task>/R-NNN.yaml`, `.context/bus/blobs/` (≥2KB auto-blobs out) | `fw bus post\|read\|manifest\|clear` | shipped-stable |
| Cross-machine dispatch (SSH) | `lib/dispatch.sh` | `fw dispatch send --host …`, `fw dispatch hosts` | shipped-stable |
| Cross-project pickup | `lib/pickup.sh` | `fw pickup send\|process\|status\|list` | shipped-stable |
| Orchestrator + Resolver (v1 dispatch substrate, T-1687 arc) | `lib/orchestrator.sh`, `lib/resolver.py`, `agents/audit/orchestrator-mcp-scan.sh` | `fw orchestrator status`, `fw resolver dispatch\|explain`, `fw outcome evaluate\|backprop\|read\|list`, `fw peer subscribe` | shipped-stable (arc-003) |
| Reviewer dispatch mode (TermLink worker) | `lib/reviewer/dispatch.sh` (T-1951) | `fw reviewer T-XXX --dispatch` | shipped-stable |
| Framework MCP server (read-only + agent-authority facade) | `agents/mcp/framework_mcp_server.py` (stdio), `agents/mcp/manifest.py`, `policy/capability-overlay/tool-set.yaml` (205 lines, three classes, 22 tools = 16 read-only + 6 agent-authority + 5 sovereignty-bound-excluded) | `fw mcp emit-manifest\|start\|stop\|status` | working-evolving — server + manifest + bats tests shipped this week (T-2265). HM-A demo (T-2268) still pending operator orchestration; Watchtower migration (Slice 4 T-2269) not started |
| Watchtower dashboard | `web/app.py` (Flask + htmx) + `web/blueprints/*` + 14KB vendored htmx | `fw serve [--port N]`, `fw watchtower port\|url\|status` | shipped-stable (functional) / working-evolving (auto-start at install — see §1E gap) |

#### Antifragile · improvement

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| Healing loop (classify → suggest → record) | `agents/healing/` | `fw healing diagnose\|resolve\|suggest\|patterns` | shipped-stable |
| Error escalation ladder A → B → C → D | documented in CLAUDE.md §Error Escalation Ladder; reactive, not yet auto-routed | discipline + `fw healing` | shipped-stable as a discipline; no single auto-router script |
| Learning capture / graduation pipeline | `.context/project/{learnings,patterns,practices}.yaml` + `lib/promote.sh` | `fw context add-learning`, `fw promote suggest\|status` | shipped-stable |
| Concerns / gap register | `.context/concerns.yaml`, `fw gaps`, gauge-driven gap closure (T-2185) | `fw gaps`, `fw gaps close <id>` | shipped-stable |
| Decorrelated review (producer-not-judge) | reviewer agent runs as separate process; `fw reviewer --dispatch` runs in TermLink worker | as above | shipped-stable |

#### Facades / UX

| Capability | File / surface | Command | Maturity |
|---|---|---|---|
| `fw` CLI — primary surface | `bin/fw`, `bin/fw-shim`, `lib/*` | `fw help`, `fw <verb> --help` | shipped-stable (project-detecting shim active since T-664) |
| Framework MCP server — agent-interop surface | (see Coordinate row above) | `fw mcp …` | working-evolving (just shipped, demo pending) |
| Watchtower web dashboard | `web/` | `fw serve`, `fw watchtower url` | shipped-stable (running) / working-evolving (auto-start gap) |

**NOT located in code or task state:** Author's term "multi-model / multi-model
routing" — referenced in CLAUDE.md's TermLink dispatch section and in the
orchestrator-rethink arc (arc-003), but I did not find a single load-bearing module
that implements *model* routing distinct from the orchestrator's general routing.
Treat this as part of the orchestrator/resolver capability rather than a separate
one. Author's term "agent mesh" — appears in the canonical topic set; I read this
as a shorthand for TermLink + bus + dispatch + pickup acting together, but it has
no single named file. Treat as a relationship, not a capability.

---

## §1B — Relationships: how the capabilities interlock

This is the lens that is least well documented and most worth surfacing in the
README. The capabilities are not a feature catalogue — they are a chain.

### The spine

A unit of work flows through the framework like this:

```
fw work-on "name" --type build
        │
        ▼
[Task created + focus set + status started-work]
        │
        ▼ (any Write/Edit attempt now)
Task gate (PreToolUse hook) ──► No active task? BLOCKED
        │ pass
        ▼
Budget gate ──► >95% context? BLOCKED (auto-handover)
        │ pass
        ▼
File modified. Component Fabric optionally consulted:
fw fabric deps <path>        — what depends on this file?
fw fabric blast-radius HEAD  — what does this commit affect downstream?
        │
        ▼
fw git commit -m "T-XXX: …"  — commit-msg hook refuses bare commits
        │
        ▼
Tier 0 check at git push / destructive commands ──► force push, --no-verify, rm -rf? BLOCKED
        │ approved (or non-destructive)
        ▼
fw task update T-XXX --status work-completed
   │
   ├─► Verification gate (P-011) — runs each line in `## Verification`
   ├─► AC gate (P-010) — all `### Agent` checkboxes must be ticked
   ├─► RCA gate (T-1550) — bug-class tasks need a substantive RCA block
   ├─► Evolution gate (T-1718) — arc-tagged build tasks need an Evolution entry
   ├─► Render-surface gate (P-013) — web/templates touches need a Human [REVIEW]
   └─► Inception scope-trace gate (T-1984) — inception decisions must point at real artefacts
        │ all pass
        ▼
Episodic memory generated. Task moves to .tasks/completed/.
Decisions captured to .context/project/. Patterns surfaced. Learnings indexed for `fw recall`.
        │
        ▼
fw audit (cron, push, or on demand) — 263 emit-points re-confirm the system stayed coherent.
fw handover --commit                — next session starts with full state.
```

That spine is the load-bearing path. Everything else hangs off it.

### Load-bearing dependencies

1. **Task gate ← Context Fabric.** The gate reads `.context/working/focus.yaml`; the
   fabric existing is the precondition for the gate firing usefully. Without context
   init, the gate is correct but uninformative.

2. **Sovereignty `$CLAUDECODE=1` refusals ← producer-not-judge / single-gate invariant.**
   Policy-changing verbs (`fw bvp confirm`, `fw inception decide`, `fw arc close`,
   `fw tier0 approve`, `fw enforcement baseline`) refuse under agent control. The
   MCP server enforces the same boundary by *never registering* those tools at all
   (`policy/capability-overlay/tool-set.yaml` block `sovereignty_bound_excluded`).
   The MCP server's read-only-plus-task-gated design is a direct consequence: an
   MCP client is external, so any "write" it performs must be re-validated by
   shelling out through `bin/fw`, where the in-process gates fire. Library
   duplication of gate logic was rejected (T-2265 evolution log).

3. **BVP cost composite ← Component Fabric.** F8 is
   `0.6×blast_radius + 0.3×tier + 0.1×effort`. Blast-radius signals come from the
   fabric. Without fabric coverage, BVP falls back to a T-shirt heuristic.

4. **Healing loop ← Learning capture.** A failure becomes a pattern in
   `.context/project/patterns.yaml` only because a learning was added. A future
   agent recovers faster because it can `fw recall` that pattern. The antifragile
   property is *emergent from the capture step*, not from the diagnoser.

5. **Cross-machine coordination ← TermLink + Bus + Pickup.** None of these is the
   whole. TermLink moves the work, Bus moves the result, Pickup discovers sibling
   projects. Together they enable a worker on host A to ship a real fix into
   host B's repo via SSH. Singly they are useful, together they are the harness.

6. **Arc system ← Task system + Headline-mechanic gate.** Arcs require an anchor
   task and a wire-level demo artefact (`--demo`) at `fw arc close`. The Default-to-OPEN
   rule (G-062) means "substrate in place" is not closure — only a captured headline
   mechanic firing is. This is the structural counter to "we shipped a lot, must be
   done." It is the same discipline `--status work-completed` applies one level up.

7. **Watchtower ← everything below it.** The dashboard renders tasks (`/tasks`,
   `/review/<id>`, `/inception/<id>`), audit (`/audit`), fabric (`/fabric`), BVP
   (`/bvp`, `/arcs/<id>`), approvals (`/approvals`), gaps (`/gaps`), reviewer verdicts.
   Without the producers below, the dashboard has nothing to render. With them, the
   dashboard is the *human review surface* — the place where the human exercises
   sovereignty (approve, decide, review, close).

8. **MCP server ← all of the above.** The 22 MCP tools are a *facade* on the
   existing CLI. They do not add capability — they expose what `fw` already does to
   external agents (Claude Desktop, Cursor MCP clients) under the same gates. The
   single-gate invariant is what makes the facade safe.

### The "five-requirements" mapping (author's frame from launch-article.md)

The author's signature thesis is that effective intelligent action requires
five things: clear direction, awareness of context, awareness of resource
constraints, awareness of impact, capable engaged actors. The mapping is the
spine in another shape:

| Requirement | Capability | Layer |
|---|---|---|
| Clear direction | Task system + acceptance criteria + verification gate | Organize · Govern |
| Awareness of context | Context Fabric (three-layer memory) + handover + resume | Remember |
| Awareness of resource constraints | Budget gate + context window monitoring + auto-handover | Govern · Remember |
| Awareness of impact | Component Fabric + blast-radius + drift | Map |
| Capable engaged actors | Authority model (sovereignty / authority / initiative) + Tier-0 + producer-not-judge | Govern |

That mapping confirms the cluster groupings — and it is also the cleanest
opening for a reader who has never seen the framework: "here is what governed
intelligent action needs, and here is what we built for each."

---

## §1C — Value delivered: per-capability and system-wide

The BVP discipline is *separate activity from value*. I keep that lens here:
"what does the user have afterward that they did not before?"

### Per capability (the "so what")

- **Task gate.** Before: agents edit files with no record of why; the diff three
  weeks later is unreadable. After: every change has a why (the task), an outcome
  (the ACs), and a verification record (`## Verification` lines). The audit trail
  is automatic, not a discipline.

- **Tier 0.** Before: an agent in autonomous mode can `git push --force` and
  vaporise teammates' work. After: that command stops at the gate and waits for a
  human approval that is logged.

- **Sovereignty / producer-not-judge.** Before: nothing prevents an autonomous
  agent from approving its own work. After: the verbs that constitute approval
  (`fw inception decide`, `fw arc close`, `fw bvp confirm`, `fw tier0 approve`)
  refuse to run under agent control. Approval routes to a human via Watchtower.

- **Context Fabric.** Before: every session is a cold start; decisions are
  re-debated; the agent re-discovers things it knew yesterday. After: working +
  project + episodic memory survive across sessions. `fw recall` finds prior
  decisions by meaning. Handover bridges sessions without information loss.

- **Component Fabric.** Before: the agent does not know what depends on the file
  it is about to change. After: `fw fabric deps <path>` and `fw fabric
  blast-radius HEAD` make impact explicit before the commit, not after the page.

- **BVP.** Before: "which task should I do next?" is answered by recency or by the
  agent's preference. After: tasks rank by directive-weighted value over composite
  cost. The "HV-LC" quadrant is the actionable hot list. The drivers are the
  framework's value system, made explicit.

- **Arc system.** Before: a multi-task initiative is just a tag and a hope. After:
  the headline mechanic is the closure gate. `fw arc close` refuses substrate; it
  insists on a demo artefact that traces to a user-observable mechanic. "We
  shipped a lot" is not closure unless the mechanic fires.

- **Inception workflow.** Before: agents start building from a vague pickup. After:
  exploratory work declares itself as inception; the agent cannot ship build
  artefacts until a human GO/NO-GO is recorded with rationale; the recommendation
  itself must be filed (T-2204) — DEFER cannot be a hedge.

- **Reviewer / decorrelated review.** Before: the agent reviews its own work.
  After: an isolated TermLink-worker reviewer scans the task file for anti-patterns
  (`mock-only-integration`, `swallowed-errors`, `defer-as-hedge`, …) and posts a
  verdict that is independent of the producing session.

- **Audit / continuous compliance.** Before: drift accumulates silently between
  releases. After: 263 emit-points across 26 sections run every push, every 30
  minutes via cron, and on demand. Audits land in `.context/audits/` with timestamps.

- **TermLink + Bus + Pickup + Dispatch.** Before: parallel agents share a context
  window and explode it; cross-machine work is bespoke. After: dispatched workers
  run in their own session with zero parent-context cost; results land in the bus;
  pickup discovers sibling projects.

- **Framework MCP server (just shipped, T-2265).** Before: external agents
  (Claude Desktop, MCP-aware editors) had to shell out to `fw` directly. After:
  the same 22 capabilities (16 read-only + 6 task-gated agent-authority) are
  available over stdio MCP with the same gates and the same sovereignty boundary.

### System-wide value (the thing the README's lead should communicate)

Three statements, taken together, are the framework's value proposition:

1. *Governed intelligent action.* The framework intercepts every file edit, every
   destructive command, every approval. Nothing happens that the system does not
   know about.

2. *Memory that survives.* Working / project / episodic memory + handover + resume
   means sessions compose instead of restart.

3. *A wider harness, not just a gate.* The system also organises (tasks, arcs,
   inceptions), measures (BVP, audit, metrics), maps (fabric, blast-radius), and
   coordinates (TermLink, bus, MCP). The gate is the entry point; the harness is
   the surrounding shape.

The live README only tells the first story, and tells it four times. That is the
positioning gap.

---

## §1D — Voice: extracted from the author's own writing

Sources: `docs/articles/launch-article.md` (March 17), `docs/articles/deep-dives/04-three-layer-memory.md`,
`docs/articles/deep-dives/15-enforcement.md`, `docs/articles/deep-dives/17-why-bash-yaml-files.md`,
plus `docs/reports/T-445-readme-overhaul.md` voice guide.

### Voice — verbatim signatures the README should adopt

- **The signature thesis.** *"The domain changed. The principle did not."* (launch
  article paragraph 24; three-layer memory closing). Recurs in different shapes
  ("The mechanism varies. The principle does not." T-445 voice guide).

- **The five-requirements frame.** *"effective intelligent action … requires five
  things. Clear direction. Awareness of context — what happened before, what was
  decided, what failed. Awareness of resource constraints. Awareness of what your
  actions will affect downstream. And people who are genuinely engaged and
  capable of acting."* (launch article paragraph 1)

- **The 25-year origin claim.** *"In 25 years of enterprise IT governance —
  transition management at Shell, operational readiness for infrastructure
  programmes — the same structural requirements appear every time a powerful
  actor operates in a shared environment."* (live README line 5)

- **Concrete physical metaphors.** *"the difference between telling someone to wear
  a hard hat versus installing a door that does not open without one"* (live
  README); *"a pilot cannot bypass a pre-flight checklist, and a reactor cannot
  start without safety valves"* (deep-dive #15); *"what breaks at 3am"* framing
  (deep-dive #17).

- **Negation-then-assertion.** *"Not as a convention. Not as a prompt instruction.
  As a mechanical gate."* (T-445 voice guide)

- **Specific numbers, never round.** *"545 tasks, 488 completed, 96% commit
  traceability"* — but those numbers have *aged* and the new draft must reflect
  current values (2,239 / 2,037 / 99%).

- **First person without ego.** *"I built this because I recognised a pattern."*
  *"I derived it from watching transitions succeed and fail."* Singular, never "we".

- **Steelman-then-honest-position pattern.** Deep-dive #17 (`why-bash-yaml-files`)
  takes five hostile questions from the author's brother Marc — Windows, Python
  venvs, "why not Python everywhere?", "why not zsh?", "where are the unit tests?" —
  steelmans each, and gives an honest answer. The bash-no-unit-tests answer ends:
  *"This is a genuine gap. … Marc caught a real hole."* That voice is the brand.

- **Self-aware irony, applied once.** *"the framework is its own case study — or
  its own most elaborate yak-shave, depending on your perspective."* (live README
  closing) Use once. Do not repeat.

### Voice — what to avoid (from T-445 voice guide, confirmed across all four articles)

No "AI-powered", "revolutionary", "game-changing", "cutting-edge". No exclamation
marks. No emojis. No "we" (single person). No "simple"/"easy"/"just". No
rhetorical questions ("Ever wondered why…?"). No filler transitions ("Let's dive
in"). No teaching tone ("you'll love this"). No hedging ("might", "could
potentially"). No celebrity quotes.

### Voice — useful structural moves

- Open paragraphs with bold one-line summaries when the section is a long
  argument (deep-dive #17 uses this 6 times).
- Tables for principle-to-mechanism mappings (launch article uses this exactly
  once and to good effect).
- Real terminal blocks for every claim that has a terminal output — and clearly
  marked `[ILLUSTRATIVE]` when no real run is available.
- Closing line that echoes the opening principle.

---

## §1E — Installation strategies (catalogue + agent-led-install gap)

Sources: `install.sh` (393 lines), `lib/init.sh` (~900 lines), `lib/upgrade.sh`,
`lib/vendor.sh`, `lib/consumer-recover.sh`, `bin/fw-shim`, `docs/example-github-action-workflow.yml`.

### Catalogue

| # | Strategy | Command | Prerequisites | What lands on disk | When to use |
|---|---|---|---|---|---|
| 1 | **Hand it to your agent** (agent-led install) | (no single one-liner today — see "Gap" below) | bash 4.4+, git 2.20+, python3 3.8+, an agent with shell access | Same artefacts as #2/#3 below, but driven from inside the agent's session | First-time evaluator who already has Claude Code / Cursor / Aider open and wants to try AEF on a project without leaving the editor |
| 2 | **Curl-pipe-bash global installer** | `curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh \| bash` | bash 4.4+, git 2.20+, python3 3.8+ | Clones the framework to `~/.agentic-framework`; installs `fw-shim` to `~/.local/bin/fw` (project-detecting router); links `claude-fw`; runs `fw doctor` | First-time install, single user, you trust the curl pipe |
| 3 | **Local-clone installer** | `git clone https://github.com/DimitriGeelen/agentic-engineering-framework.git ~/.agentic-framework && bash ~/.agentic-framework/install.sh --local ~/.agentic-framework` | as above | Same as #2 | You want to inspect the script before running it, or you are offline-airgapped |
| 4 | **`fw init` per-project (after global install)** | `cd your-project && fw init` (with `--provider claude\|cursor\|generic`) | A `fw` on PATH (from #1–#3), or invoke the framework's `bin/fw` directly | `.tasks/`, `.context/`, `.fabric/`, `.claude/settings.json` (hooks wired), `CLAUDE.md` template, onboarding tasks; vendored copy of framework at `.agentic-framework/` (per-project isolation) | Every project. This is the per-project setup verb after framework is on PATH |
| 5 | **Vendored isolation (no global at all)** | `fw init` (vendored copy of bin/, lib/, agents/, web/, docs/, FRAMEWORK.md lands in `.agentic-framework/`); shim at `~/.local/bin/fw` finds it via project walk | as #1 prereqs | `.agentic-framework/` populated; project self-contained | Production / shared repos. Each project pins its own framework version |
| 6 | **`fw upgrade` from inside a consumer** | `fw upgrade` (or `fw upgrade /path/to/project` from inside the framework repo) | a `.framework.yaml` pin in the consumer | Refreshes shims (`bin/fw`, `.claude/settings.json` hooks), syncs vendored scripts, updates version pin | Routine version uplift |
| 7 | **Recover a legacy consumer** (pre-T-2232 / pre-T-1634) | `fw consumer-recover <host> [path] --apply` (SSH or TermLink) | reachable host, framework on calling machine | Clones fresh fw to /tmp on target host; env-scoped `fw upgrade` against the consumer | A consumer that was vendored before T-2232 lands and cannot self-upgrade |
| 8 | **CI / GitHub Action** | `.github/workflows/audit.yml` calling `uses: DimitriGeelen/agentic-engineering-framework@v1` (template in `docs/example-github-action-workflow.yml`) | a GitHub repo | runs `fw audit` in CI; fails the build on FAIL (or `fail-on-warnings: 'false'` for advisory) | Team / shared repos that want PR-blocking audit |
| 9 | **Homebrew (mentioned in `launch-article.md`)** | `brew install DimitriGeelen/agentic-fw/agentic-fw` | macOS or Linuxbrew | same as #2 | macOS users who prefer brew over curl-pipe |

### Watchtower behaviour at install time — verified gap

I read `install.sh:351-393` and `lib/init.sh:500-540` end-to-end.

**install.sh** post-install footer (line 387–390):
```
  Dashboard:      fw serve
  Documentation:  ${INSTALL_DIR}/FRAMEWORK.md
```

**lib/init.sh** post-init footer (line 518–519):
```
  Dashboard: fw serve
  All commands: fw help
```

That is the *entire* mention of Watchtower at install/init time. Both surfaces
print `fw serve` as a suggestion. Neither runs it. Neither tells the user the
URL it will land on (the triple-file `.context/working/watchtower.{pid,port,url}`
exists but is empty until `fw serve` is invoked). The user is given no
indication that a web dashboard exists and is one command away.

The operator's stated wish is for Watchtower to start automatically at install
and for the user to know it exists. The active task `T-1611` (in
`.tasks/active/T-1611-replace-local-flask-dev-watchtower-with-.md`) is the
in-flight work to move Watchtower to a service / systemd model — auto-start is
its eventual deliverable but not yet shipped.

**README implication.** The README should (a) state honestly that the dashboard
does not auto-start today, (b) show the operator the one-line `fw serve`
incantation and the URL they will get (via `fw watchtower url`), and (c) tell
the agent-led-install reader that surfacing the dashboard URL is a step in the
agent-led flow. This converts the gap into a documented invitation.

### Agent-led install — the LEAD strategy

Worker contract requires the agent-led install to lead. The current install
flow is already largely agent-runnable, but is not packaged that way. What an
"agent-led install" would actually look like, as a copy-pasteable block the
operator hands to their agent:

```
You are about to install the Agentic Engineering Framework into this project.
Run these steps:

1. Verify prerequisites:
   bash --version  (need 4.4+)
   git --version   (need 2.20+)
   python3 --version  (need 3.8+)

2. Install the framework globally (one-time per machine):
   curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash

3. Initialise this project:
   cd /path/to/your/project
   fw init                     # auto-detects provider; pass --provider claude|cursor|generic to force

4. Surface the dashboard URL (Watchtower does not auto-start; this is by design today):
   fw serve &                  # backgrounds the dashboard
   fw watchtower url           # prints the URL the operator should open

5. Report back to the operator:
   - the project path
   - the dashboard URL
   - the count of onboarding tasks created (these guide the human's first session)
   - any `fw doctor` warnings

Then create your first task with `fw work-on "name" --type build` and start.
```

This block is what the README should embed verbatim as the lead install
strategy. I cannot mark it as "real captured output" because I did not run it
end-to-end — it is *instructive*, not transcript. The next agent to test this
end-to-end can mark it verified.

---

## §1F — Maturity table + stale-fact corrections

### Maturity table (compact)

The full maturity tags appear inline in §1A. Distilled summary:

- **Shipped-stable:** Task system, task gate, Tier 0, sovereignty refusals,
  bypass log, enforcement baseline, Context Fabric (three layers), handover,
  resume, Component Fabric, blast-radius, BVP ranking + drivers, Audit,
  Reviewer, Metrics, Healing loop, Learning capture, Concerns/gaps, Arc system,
  Inceptions, TermLink integration, Bus, Dispatch, Pickup, Orchestrator +
  Resolver, Watchtower (functional), fw CLI, semantic search (operational).

- **Working-evolving:**
  - Framework MCP server — shipped T-2265 this week; HM-A demo (T-2268) and
    Watchtower-frontend migration (T-2269) still in flight.
  - Watchtower auto-start at install (T-1611 active).
  - Embeddings strategy maturation (arc-002).
  - F-RECALL band-calibration (T-2172 captured + later).
  - F-AUTONOMY activation gate (T-2171).
  - BVP per-driver Watchtower display (T-2170).
  - Self-vendor parity rails (T-2240/T-2241/T-2242 shipped; web/templates +
    web/static remain a 7th sibling class if audit extends).

- **Designed-not-built:** No major capability in the canonical topic set is in
  pure designed-not-built state. The MCP server *was* in that state two weeks
  ago and is now shipped.

### Stale-fact corrections list (current README → verified)

Every row is a concrete edit the new draft must make.

| # | Live README line | Current claim | Verified value | Source |
|---|---|---|---|---|
| 1 | line 131 | "545+ tasks, 488+ completed, 96% commit traceability" | **2,239 tasks (202 active + 2,037 completed), 99% traceability over last 500 commits** | direct `ls` and `git log` |
| 2 | line 212 | "150+ governance checks" | **263 emit-points across 26 audit sections** | `grep -c` on audit.sh |
| 3 | line 300 | "organized into 15 subsystems" | **20 agents/ subsystems + 55 lib/*.sh modules** | `ls -d agents/*/` |
| 4 | line 301 | "you interact with roughly 6 commands" | **`fw help` lists ~60 top-level verbs across 11 sections** | `fw help` |
| 5 | lines 232-241 (Key Commands table) | "Key Commands" omits arc, BVP, TermLink, MCP | adds `fw arc`, `fw bvp`, `fw termlink`, `fw mcp`, `fw bus`, `fw dispatch`, `fw reviewer` | direct `fw help` |
| 6 | lines 162-225 (What You Get expandables) | 6 expandables, none for Arc / BVP / TermLink / MCP / Reviewer | 10 capabilities at least merit a top-level mention | §1A inventory |
| 7 | line 113 ("> 90%") in enforcement diagram | Budget gate triggers at "> 90%" | **285K of 300K window ≈ 95% triggers BLOCK; 255K (~85%) triggers URGENT** | `agents/context/budget-gate.sh` + CLAUDE.md §Context Budget Management |
| 8 | line 84 (5-min demo) | omits `fw arc`, `fw bvp`, `fw recall`, `fw reviewer` | demo can show one harness-wide moment, not just task gate | contract requirement |
| 9 | line 269 (What This Is Not) | "Run OpenClaw / LangGraph / CrewAI inside the repos those agents touch" | the framework can also wrap **any** CLI agent (Aider, Cursor, Devin) — relevant — and explicitly: it composes with orchestrators rather than competes | T-445 voice guide |
| 10 | (missing) | no mention of Arc system | 10 arcs registered | `ls .context/arcs/` |
| 11 | (missing) | no mention of BVP | shipped, used daily | `lib/bvp.sh`, `fw bvp` |
| 12 | (missing) | no mention of TermLink or cross-machine coordination | shipped | `lib/termlink.sh`, `fw dispatch` |
| 13 | (missing) | no mention of MCP server facade | shipped this week (T-2265) | `agents/mcp/` |
| 14 | (missing) | no mention of Watchtower install-time behaviour | does NOT auto-start; the new README should say so honestly | `install.sh:388`, `lib/init.sh:518` |

Two ambiguous items I deliberately did not edit:

- The "battle-tested with Claude Code; designed for other agents but not validated" framing
  in line 131 is *still accurate* per CLAUDE.md and per the human's T-445 critical
  honesty note. Keep it.

- The Architecture block (lines 297-319) — the file-tree listing is largely
  correct but is missing several agents/ subsystems. Update the count and the
  listing, but the structural framing ("CLI that routes to specialised agents")
  is right.

---

## §2 — Frame test: the "agentic harness, six layers, coordinate not execute" hypothesis

Restated from the worker contract, point by point:

### Point 1: "AEF is an agentic harness, not merely a governance gate"
**Verdict: CONFIRMED.** The canonical topic set, the §1A inventory, and the
§1B spine all show this. The framework governs, remembers, maps, organises,
measures, coordinates. Calling it a "gate" undersells five of six layers.
The author already uses the word "framework" in their own writing
(launch-article paragraph 11: "the Agentic Engineering Framework applies
structural governance"); "harness" is a better word in the README's
positioning sentence because it implies the wider shape.

### Point 2: "Six layers — Govern · Remember · Map · Organize · Measure · Coordinate"
**Verdict: CONFIRMED with a small adjustment.** The six layers cleanly carve
the canonical topic set. The only addition: **Antifragile/Improvement** is a
seventh cluster in the topic set, but it is best presented as a *property
emerging from the other six* (healing reads patterns from Remember; reviewer
sits in Coordinate; learning capture is part of Remember + Organize). Do not
add a seventh top-level layer in the README. Mention antifragility as a
constitutional directive (it is D1) and let the reader see it emerge.

### Point 3: "Boundary — it coordinates agents but does not execute the model — 'coordinate, not execute'"
**Verdict: CONFIRMED.** The framework wraps external agents (Claude Code,
Cursor, Aider) via PreToolUse hooks, git hooks, MCP, and the CLI. It never
calls `claude -p` or any model invocation as an end deliverable to a user —
when it dispatches workers, it dispatches *agents that themselves run a model*
(via `claude -p` or `claude-fw`). The framework's outputs are governance
artefacts (audits, fabric cards, episodics, handovers), not model completions.
"Coordinate, not execute" is exactly the right boundary. It is also the
correct counter-positioning against LangGraph (orchestrate model calls),
OpenClaw (run a personal assistant), CrewAI (multi-agent pipelines).

### Point 4: "The current README over-weights governance and under-represents BVP and TermLink"
**Verdict: CONFIRMED.** I read the live README end-to-end. The word "block"
or "blocked" appears 12 times in the first 60 lines (the "What This Has
Actually Stopped" block is four blocked-action transcripts). Arc, BVP,
TermLink, MCP — zero mentions. The framing is "what it prevents" only.

### Point 5: "The opening should show what the harness DOES across layers, not only what it blocks"
**Verdict: CONFIRMED.** This is the proposed structure's lead. See §3.

### Combined verdict
The hypothesis is largely right. The structure proposal in §3 is built on it.

---

## §3 — Proposed README structure

Audience priority (highest first): first-time evaluator → existing user →
contributor. Top of doc serves the evaluator; mid serves the user; deeper
sections serve the contributor.

### Section list with one-line purposes

1. **Title block + sharp positioning (3 lines).** What it is, what it isn't,
   the one-line stance: "governance + memory + impact-foresight harness around
   any CLI AI coding agent."

2. **Five-requirements lead.** Open with the launch-article framing: effective
   intelligent action needs five things; here are the five mechanisms we built
   for them; here is one real terminal block from each.

3. **See it work in 5 minutes.** A live transcript walk: install, init, work-on,
   audit, serve, recall. Show the dashboard URL. Real, captured output where
   possible. `[ILLUSTRATIVE]` where not.

4. **What you actually get** (six bullet groups, expandable):
   - Govern (task gate, Tier 0, sovereignty, single-gate)
   - Remember (three-layer memory, handover, resume, recall)
   - Map (Component Fabric, blast-radius, drift)
   - Organize (tasks, arcs, inceptions, horizon)
   - Measure (BVP, audit, metrics, reviewer)
   - Coordinate (TermLink, bus, dispatch, MCP server, Watchtower)
   Each group: one transcript or screenshot, one "before / after" sentence.

5. **Installation — agent-led leads.** The "hand it to your agent" block first,
   then the curl-pipe-bash global installer, then `fw init` per-project,
   vendored isolation, upgrade, consumer-recover, CI, Homebrew. Each entry
   ends with "use this when …". Honest note on Watchtower not auto-starting.

6. **Maturity / what's shipped vs evolving.** Compact table. The harness is
   alpha-but-daily-driver; MCP just shipped; Watchtower auto-start is in flight
   (T-1611); the rest is shipped-stable.

7. **What this is not.** "Coordinate, not execute." Composes with OpenClaw /
   LangGraph / CrewAI / Aider / any CLI agent. Not a model runtime.

8. **Self-governing.** The framework develops itself under its own governance —
   real, current numbers (not stale ones). Yak-shave joke applied once.

9. **Key commands** (compact reference).

10. **Architecture / principles / glossary** (expandable, contributor-facing).

11. **License + links.**

### Structural choices and tradeoffs

- **Tradeoff 1: opening length.** A five-requirements lead is longer than the
  current "What This Has Actually Stopped" wall. The benefit is showing the
  harness, not just the gate. The cost is that the first thing the reader sees
  is a paragraph, not a code block. Counter: each of the five requirements
  ends with a code block, so the reader gets transcripts within ~30 lines.

- **Tradeoff 2: maturity transparency.** A maturity table (§6) makes it easy
  for an outsider to see what is still moving. The cost is it can read as
  "incomplete." The author's voice already mitigates this — "alpha, daily
  driver, would not go back" — so we lean in.

- **Tradeoff 3: MCP placement.** The MCP server is a Coordinate-layer facade,
  not its own layer. It belongs inside the Coordinate bullet group, not as a
  top-level section. If MCP grows substantially (Slice 4 Watchtower migration
  + more tools) it can graduate.

- **Tradeoff 4: TermLink positioning.** TermLink is currently presented as a
  CLI integration detail. It is more important than that. The Coordinate group
  in §4 names it explicitly and the 5-min demo section can show one dispatch
  moment (e.g. `fw reviewer T-XXX --dispatch`).

---

## §GAPS — what I could not verify

- **End-to-end test of the agent-led install block.** I wrote the
  copy-pasteable block in §1E from the verified install flow but did not run
  it against a fresh machine. The next agent (or human) to install AEF fresh
  should run this verbatim, capture output, and either confirm it or correct
  it.

- **`fw audit` real summary numbers.** The audit was held by another running
  audit at the moment I tried to capture a Pass/Warn/Fail line (`Another audit
  is already running — exiting`). The 263 emit-points number is correct
  (static count via grep), but a captured *summary* would strengthen the
  README's "audit shows N pass / M warn / K fail" line — I have marked the
  equivalent in the draft as `[ILLUSTRATIVE — replace with real output]`.

- **Multi-provider validation status.** CLAUDE.md and T-445 both state Claude
  Code is the only validated provider; Cursor / Aider / Devin are designed-for
  but untested. I did not test any of those. The draft preserves the
  battle-tested-with-Claude-Code framing.

- **Watchtower URL format on first init.** *(Closed 2026-06-09.)* With
  Watchtower running, `.context/working/watchtower.url` is exactly 27 bytes:
  the literal string `http://192.168.10.107:3000` (26 chars) followed by a
  single `\n` (verified via `xxd`). No scheme variations, no protocol prefix
  ambiguity, no trailing whitespace — one line, one trailing newline. The
  draft's reliance on `fw watchtower url` (which strips the newline) remains
  the right surface.

- **The exact wording of `fw doctor` warning when Watchtower has not been
  started.** The draft uses a generic line, not a verified transcript.

- **Bash unit tests.** *(Partially closed 2026-06-09.)* Deep-dive #17 names
  the gap explicitly ("This is a genuine gap. … Marc caught a real hole.").
  Current counts: 264 `.bats` files total in `tests/unit/`, of which 47
  explicitly cover hooks/gates/guards (filename match
  `hook|gate|check_|guard`). 16 hook scripts live under `agents/context/`
  (one bats file per script is roughly the ratio needed for parity). 123
  python unit tests in `tests/unit/` complement the bats coverage. The
  March-era "real hole" claim is materially less true today; whether it's
  *closed* depends on whether the remaining 16 - matched bats files exist
  per hook (not enumerated here). The README maturity table cites this
  partial close and links to the deep-dive for the historical context.

- **Capability "agent mesh" and "multi-model routing" as named code units.**
  These appear in the canonical topic set but do not have a single file each;
  they are emergent from TermLink + Bus + Dispatch + Pickup + Orchestrator.
  The draft treats them as relationship-level concepts under Coordinate.

End of dossier.
