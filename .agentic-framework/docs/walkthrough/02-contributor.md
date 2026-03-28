# Track 2: Contributor Walkthrough

You understand the basics. This guide shows how the subsystems connect internally — essential for contributing features or fixing bugs.

**Time:** ~45 minutes
**Prerequisites:** Completed [New User Track](01-new-user.md) or equivalent understanding

---

## 1. Framework Core — The Entry Point

Everything flows through `bin/fw`. It resolves paths, sets environment variables, and routes to agents.

**Key files:**
- `bin/fw` — CLI entry point, command router
- `lib/init.sh` — Project initialization
- `lib/harvest.sh` — Task completion harvesting
- `metrics.sh` — Project health metrics

**Read more:**
- [Deep-dive: Framework Core](../articles/deep-dives/11-framework-core.md)
- [Generated article: Framework Core](../generated/articles/framework-core-prompt.md)

**Contributor note:** New `fw` subcommands go in `lib/` as shell scripts. The router in `bin/fw` auto-discovers them.

---

## 2. Context Fabric — The Memory System

Three memory types persist across sessions:

| Type | Scope | Storage | Updated |
|------|-------|---------|---------|
| Working Memory | Current session | `.context/working/` | Every tool call |
| Project Memory | All time | `.context/project/` | On learning/decision/pattern capture |
| Episodic Memory | Per task | `.context/episodic/` | On task completion |

**Key files:**
- `agents/context/context.sh` — Main entry point
- `agents/context/lib/learning.sh` — Learning capture
- `agents/context/lib/episodic.sh` — Episodic generation
- `agents/context/lib/status.sh` — Status display

**Read more:**
- [Deep-dive: Three-Layer Memory](../articles/deep-dives/04-three-layer-memory.md)
- [Deep-dive: Context Fabric](../articles/deep-dives/10-context-fabric.md)
- [Generated article: Context Fabric](../generated/articles/context-fabric-prompt.md)

**Contributor note:** Learnings, patterns, and decisions are YAML files in `.context/project/`. Episodic summaries are auto-generated from git history + task file at completion.

---

## 3. Component Fabric — The Topology Map

The Component Fabric (`.fabric/`) maps every significant file's dependencies, purpose, and subsystem.

**Key files:**
- `agents/fabric/fabric.sh` — CLI entry point
- `agents/fabric/lib/register.sh` — Component registration
- `agents/fabric/lib/traverse.sh` — Dependency graph traversal
- `agents/fabric/lib/drift.sh` — Drift detection (unregistered files)

**Try it:**
```bash
fw fabric overview          # Subsystem summary
fw fabric deps bin/fw       # What does bin/fw depend on?
fw fabric blast-radius HEAD # What did the last commit affect?
fw fabric drift             # Any unregistered files?
```

**Read more:**
- [Deep-dive: Component Fabric](../articles/deep-dives/07-component-fabric.md)
- [Generated article: Component Fabric](../generated/articles/component-fabric-prompt.md)

**Contributor note:** When you create a new file, run `fw fabric register <path>` to add it to the topology. The PostToolUse hook reminds you if you forget.

---

## 4. Context Budget Management — The Finite Resource

AI sessions have limited context windows. The budget system tracks usage and enforces gates.

**Key files:**
- `agents/context/budget-gate.sh` — PreToolUse gate (blocks at critical)
- `agents/context/checkpoint.sh` — PostToolUse monitor (warnings + auto-handover)
- `.context/working/.budget-status` — Current level (ok/warn/urgent/critical)

**Thresholds:** 120K ok→warn, 150K warn→urgent, 170K urgent→critical (BLOCK)

**Read more:**
- [Deep-dive: Context Budget](../articles/deep-dives/03-context-budget.md)
- [Deep-dive: Budget Management](../articles/deep-dives/16-budget-management.md)
- [Generated article: Budget Management](../generated/articles/budget-management-prompt.md)

**Contributor note:** The budget gate reads actual token usage from the Claude session JSONL transcript. At critical, only wrap-up paths are allowed (git commit, fw handover, task updates).

---

## 5. Learnings Pipeline — From Experience to Practice

The pipeline captures, stores, and surfaces lessons learned.

**Flow:** Error/insight → `fw context add-learning` → `learnings.yaml` → Watchtower display → Audit check → Promotion to practice

**Key files:**
- `agents/context/lib/learning.sh` — Capture
- `.context/project/learnings.yaml` — Storage
- `watchtower/blueprints/discovery.py` — Web display

**Read more:**
- [Deep-dive: Learnings Pipeline](../articles/deep-dives/14-learnings-pipeline.md)
- [Generated article: Learnings Pipeline](../generated/articles/learnings-pipeline-prompt.md)

**Contributor note:** Learnings with 3+ citations across tasks are candidates for promotion to practices (`fw promote suggest`).

---

## 6. Watchtower — The Web Dashboard

Flask app providing task overview, fabric explorer, metrics, and documentation.

**Key files:**
- `watchtower/app.py` — Flask app entry
- `watchtower/blueprints/` — Route modules (tasks, discovery, graduation, metrics, fabric, docs)
- `watchtower/templates/` — Jinja2 templates with htmx

**Routes:**
| Route | Purpose |
|-------|---------|
| `/` | Dashboard overview |
| `/tasks` | Task list with filtering |
| `/fabric` | Component topology explorer |
| `/docs` | Generated documentation index |
| `/metrics` | Project health metrics |
| `/learnings` | Learning & pattern browser |

**Read more:**
- [Deep-dive: Watchtower](../articles/deep-dives/09-watchtower.md)
- [Deep-dive: Watchtower Web UI](../articles/deep-dives/15-watchtower-web-ui.md)
- [Generated article: Watchtower](../generated/articles/watchtower-prompt.md)

**Contributor note:** Templates use htmx for interactivity. Flask caches templates without `debug=True` — restart server after editing templates in production.

---

## Architecture Patterns

**Every agent follows the same structure:**
```
agents/{name}/
  {name}.sh     # Mechanical script (bash)
  AGENT.md      # Intelligence/guidance (for AI agents)
  lib/          # Helper scripts (optional)
```

**Error escalation ladder:** A (don't repeat) → B (improve technique) → C (improve tooling) → D (change ways of working)

**Enforcement tiers:** Tier 0 (destructive, human approval) → Tier 1 (standard, task required) → Tier 2 (human override, logged) → Tier 3 (pre-approved)

---

## What's Next?

- [Agent Implementer Track](03-agent-implementer.md) — Building new integrations
- Explore the [Component Fabric](http://localhost:3000/fabric) to see real dependency graphs
- Pick a `good-first-issue` from GitHub and submit a PR
