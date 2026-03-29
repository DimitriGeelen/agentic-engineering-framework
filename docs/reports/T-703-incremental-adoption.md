# T-703: Incremental Adoption Levels Research

## Problem Statement

`fw init` is all-or-nothing. A new user gets: 13 directories, 10+ YAML files, 4 constitutional directives, CLAUDE.md (1024 lines), settings.json (14 hooks), task templates, onboarding tasks, and governance activation — all at once.

For a developer who just wants to try task-first governance, this is overwhelming. The "5-minute demo" from the README becomes a 15-minute setup that creates 30+ files before any work begins.

**For whom:** New users trying the framework for the first time.
**Why now:** Scored 18/20 in KCP pattern harvest (T-697). As launch approaches (T-334), onboarding friction directly affects adoption.

## Current Init Inventory

`fw init` creates these artifacts (grouped by function):

### Group A: Task System (minimum viable)
- `.tasks/active/`, `.tasks/completed/`, `.tasks/templates/` — directories
- `.tasks/templates/default.md` — task template
- `.framework.yaml` — project config (name, version, provider)

### Group B: Context Fabric
- `.context/working/` — session state
- `.context/project/` — patterns, decisions, learnings, directives, assumptions, concerns, practices
- `.context/episodic/` — task histories
- `.context/handovers/` — session handovers
- `.context/scans/` — codebase scans
- `.context/bus/results/`, `.context/bus/blobs/` — sub-agent result bus
- `.context/audits/cron/` — audit results
- `.context/cron/` — git-tracked cron definitions
- `.context/cron-registry.yaml` — cron registry
- `.context/bypass-log.yaml` — git hook bypass log
- 7 YAML seed files (practices, decisions, patterns, learnings, assumptions, directives, concerns)

### Group C: Enforcement Hooks
- `.claude/settings.json` — 14 hooks across 4 event types
- `CLAUDE.md` — 1024 lines of behavioral rules
- Git hooks (commit-msg, post-commit, pre-push)

### Group D: Vendored Framework
- `.agentic-framework/` — full framework copy (scripts, agents, templates)

## Proposed Levels

### Level 1: "Tasks Only" (~5 files)

What you get:
- `.tasks/active/`, `.tasks/completed/`
- `.tasks/templates/default.md`
- `.framework.yaml` (minimal: name, version, level)
- Minimal CLAUDE.md (~100 lines: just task rules + enforcement tiers)
- `.claude/settings.json` with only: task gate (PreToolUse Write|Edit)

What you DON'T get:
- No context fabric
- No healing loop
- No handovers
- No audit system
- No budget management
- No Tier 0 protection
- No fabric, bus, cron, episodic, learnings

**Value prop:** "Nothing gets done without a task" — enforced with one hook.

### Level 2: "Tasks + Context" (~20 files)

Adds to Level 1:
- `.context/working/`, `.context/project/`, `.context/episodic/`, `.context/handovers/`
- Seed files (learnings, decisions, patterns, directives)
- Handover agent + session continuity
- Budget gate hook
- Plan mode blocker

**Value prop:** Task governance + session memory + context budget protection.

### Level 3: "Full Governance" (current default, ~35 files)

Everything. All hooks, all context, all agents, vendored framework copy, audit system, cron, fabric, bus.

## Analysis

### The Case FOR Levels

1. **Lower barrier to entry** — someone can try "tasks only" in 30 seconds, learn the value, then upgrade
2. **Progressive disclosure** — new users aren't confronted with concepts they don't yet understand (episodic memory, healing loops, concerns register)
3. **Lighter footprint for small projects** — a weekend hackathon project doesn't need 14 hooks
4. **Matches adoption psychology** — "try one thing, if it works, add more" is how tools actually get adopted

### The Case AGAINST Levels

1. **Testing surface explosion** — instead of testing one init path, need to test 3 levels × 2 providers × 2 modes (greenfield/existing). That's 12 combinations. Current: 4
2. **Upgrade complexity** — `fw upgrade --level 2` needs to add exactly the Level 2 files that Level 1 doesn't have. This is a diff operation on file sets, which is fragile
3. **CLAUDE.md splitting** — the biggest challenge. CLAUDE.md is one monolithic file. Level 1 needs a minimal version, Level 2 needs a medium version, Level 3 needs the full version. Maintaining 3 CLAUDE.md templates with overlapping but different content is a maintenance nightmare
4. **Hook interdependencies** — hooks aren't independent. The budget gate references the context fabric. The task gate references `.tasks/`. The audit system references patterns, concerns, and learnings. Removing one layer may create broken references
5. **The task gate alone is weak** — Level 1's single hook ("require a task before editing") is useful but limited. Without budget management, the agent will burn context. Without Tier 0, destructive commands aren't caught. The value of governance is in the combination, not individual hooks
6. **Vendor complexity** — Level 1 would need a minimal vendor (just task scripts), Level 2 a medium vendor, Level 3 the full framework. Three vendor profiles = three things to maintain and test
7. **The actual onboarding friction is NOT file count** — users don't care about 30 files being created in `.context/`. The friction is:
   - Understanding what the framework does (README/docs)
   - Learning `fw` CLI commands
   - Adapting to task-first workflow
   None of these are solved by creating fewer files

### The Real Problem

The hypothesis is "too many files = onboarding friction." But the actual onboarding blockers observed in onboarding cycles (T-104, T-107, T-356, T-551) were:

1. **Understanding the mental model** — what is a task? what are hooks? why can't I just edit?
2. **First interaction confusion** — agent tries to edit, gets blocked by task gate, doesn't understand why
3. **CLAUDE.md cognitive load** — 1024 lines of rules to internalize. This is the real UX problem, and levels don't fix it (the agent still loads the full CLAUDE.md)
4. **Setup path errors** — `fw init` failures from path resolution, missing deps (T-481, T-518)

None of these are solved by creating fewer files on disk.

### Alternative: Better Onboarding UX Without Levels

1. **`fw init --guided`** (current `--no-first-run` inverse) — interactive walkthrough explaining each concept as files are created
2. **Shorter CLAUDE.md for consumer projects** — the consumer CLAUDE.md template is already a subset (~300 lines vs 1024). Could be tighter
3. **Better first-run experience** — the onboarding tasks (T-460) already exist and guide the user through first interactions
4. **Faster init** — `fw init` takes <2 seconds. The time is in understanding, not waiting

## Recommendation

**NO-GO** — the proposed solution (3 init levels) addresses a symptom (file count) not the root cause (cognitive load and mental model confusion). The implementation cost is high (3 CLAUDE.md templates, 12 test paths, upgrade-between-levels logic) and the benefit is low (users don't notice the file count).

### Evidence

- Onboarding observations (T-104, T-107, T-356): zero complaints about file count. All friction was about understanding what hooks do and why tasks are required
- T-316 (layered CLAUDE.md) NO-GO: no include mechanism. Maintaining 3 CLAUDE.md variants amplifies this problem
- `fw init` creates ~35 files in <2 seconds. The user never sees most of them (`.context/` is gitignored working memory)
- Consumer project CLAUDE.md is already a subset (~300 lines). The 1024-line version is the framework's own self-governance document

### What Would Actually Help

If reducing onboarding friction is the goal, these would have more impact:
1. **Interactive tutorial** — `fw tutorial` that walks through creating first task, making an edit, completing it
2. **Shorter consumer CLAUDE.md** — review the template for content that only applies to framework development
3. **Explain-on-block** — when the task gate blocks an edit, include a one-line explanation and `fw work-on` command in the error output (some of this exists, could be improved)
