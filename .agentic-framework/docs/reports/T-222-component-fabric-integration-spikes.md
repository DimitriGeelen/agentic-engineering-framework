# T-222: Component Fabric Integration — Spike Results

## Overview

Inception task exploring 3 integration gaps: CLAUDE.md awareness, task-component linking, drift detection.

## Spike 1: CLAUDE.md Section Draft

**Question:** Can we add Component Fabric guidance to CLAUDE.md without bloating it?

### Current State

- CLAUDE.md is 686 lines
- Only mention of "fabric" is "Context Fabric" (memory system) — zero mentions of Component Fabric
- Existing sections cover: Task System, Enforcement, Agents, Context Budget, Sub-Agent Dispatch, Behavioral Rules, Session Protocol
- Natural insertion point: after the Agents section (after Resume Agent, before Context Budget Management)

### Draft Section (35 lines)

```markdown
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
```

### Evaluation

- [x] Fits naturally into doc structure — goes after Agents (which describe the tools) and before Context Budget (which describes operational rules). The fabric is a tool the agent should know about.
- [x] Not bloating — 35 lines (5% of current doc). Adds actionable reference, not prose.
- [x] Actionable guidance — tells the agent WHEN to use each command, not just that they exist.

**Verdict: PASS.** Section is compact, actionable, and fits the existing structure.

## Spike 2: Task-Component Linking Prototype

**Question:** Can we reliably resolve git diff paths to component IDs?

### Method

1. Built a path→component-id lookup from all 99 component YAML files (`location:` field)
2. Tested against files changed in the last 15 non-handover commits
3. Separated source files from metadata (`.context/`, `.tasks/`, `.fabric/` card edits)

### Findings

**Overall resolution (all files):** 8% (2/23 from last 10 commits) — misleadingly low because recent commits were handover/housekeeping.

**Source-only resolution (excluding metadata paths):** 72% (8/11)
- Resolved: `agents/*.sh`, `web/templates/*.html`, `web/blueprints/*.py`
- Missed: `agents/dispatch/preamble.md` (new, unregistered), `web/app.py` (uncovered), `web/shared.py` (uncovered)

**Per-commit breakdown (code-heavy commits):**
- T-208 (fabric agent build): 7/8 source files → 87%
- T-215 (watchtower UI): 4/12 → 33% (many new templates not yet registered at commit time)
- T-216 (P-010 fix): 1/3 → 33%
- T-221 (housekeeping): 1/4 → 25% (mostly metadata)

**Key insight:** Resolution rate depends on how up-to-date `fw fabric scan` has been run. Files created in the SAME commit can't resolve because the component card doesn't exist yet. Post-commit resolution (running after the commit) would raise accuracy significantly.

**False positive rate:** 0% — every resolved path was correct. The lookup is exact-match on `location:` field.

### Category Analysis

Files that DON'T resolve fall into:
1. **Metadata** (`.context/`, `.tasks/`): These aren't "components" — they're runtime artifacts. Not useful to link.
2. **Fabric cards** (`.fabric/components/*.yaml`): Modifying a card is modifying the component's metadata. Could be a second lookup (card path → component ID).
3. **Unregistered source**: `web/app.py`, `web/shared.py`, `preamble.md` — genuinely missing from fabric. Fix: run `fw fabric scan`.

### Template Change

Adding `components: []` to task frontmatter is trivially backward-compatible — old tasks just don't have it. Example:

```yaml
id: T-XXX
name: "..."
components: [agents/context/budget-gate.sh, web/templates/fabric.html]
```

### Evaluation

- [ ] >80% resolution accuracy — **72% currently, estimated 85%+ after running `fw fabric scan` on uncovered files**
- [x] Low false positive rate — **0% false positives**
- [x] Template change is backward-compatible — **Yes, optional field**

**Verdict: CONDITIONAL PASS.** Accuracy is borderline (72%) but improvable by registering 3 missing files. The real question is whether the resolution should be:
- (a) At task completion (post-commit, resolves paths from all task commits)
- (b) At commit time (pre-commit or post-commit hook)
- (c) Manual (agent fills in `components:` by hand based on what it touched)

Recommendation: **(a) At task completion** — `update-task.sh --status work-completed` already runs verification. Adding a path resolution step there is natural.

## Dialogue Log

### Spike 1 reasoning
- Checked CLAUDE.md structure (686 lines, 12+ sections)
- Identified insertion point: after Agents, before Context Budget
- Kept focus on "when to use" rather than "what it is" — the agent needs actionable triggers
- Quick Reference table already has `fw fabric` commands? No — checked, it doesn't. Section fills a real gap.

### Spike 2 reasoning
- Initial 8% resolution was alarming — but caused by metadata-heavy commits (handovers)
- Filtering to source-only changed the picture: 72% with 0% false positives
- The miss pattern is "unregistered files" not "wrong resolution" — solvable by keeping fabric scan current
- Considered: should `.context/` and `.tasks/` files have components? No — they're not structural. They're runtime artifacts. Linking them would be noise.

---
*Research artifact for T-222 inception. Updated incrementally per C-001.*
