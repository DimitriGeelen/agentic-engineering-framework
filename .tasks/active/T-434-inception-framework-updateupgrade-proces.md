---
id: T-434
name: "Inception: Framework update/upgrade process for field installations"
description: >
  Investigate what is needed to update or upgrade existing framework installations
  in the field. High-risk undertaking: installations at varying versions, version drift
  from local changes, blast radius on live project data. Requires thorough investigation,
  layered testing, and incremental development. Must design the research approach itself
  before executing — scope analysis, blast radius mapping, upgrade strategy, migration
  tooling, test plan.

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [governance, portability, upgrade, risk, architecture]
components: [bin/fw, lib/init.sh, CLAUDE.md, FRAMEWORK.md]
related_tasks: [T-316]
created: 2026-03-10T21:13:36Z
last_update: 2026-03-10T21:25:00Z
date_finished: null
---

# T-434: Inception: Framework update/upgrade process for field installations

## Problem Statement

There is no process to update or upgrade an existing installation of the Agentic Engineering
Framework. When we release improvements, users with existing installations have no path to adopt
them. This is a fundamental gap in the framework's portability story (D4).

**Why this is hard:**
1. **Version drift:** Installations may be at varying versions with no tracking mechanism
2. **Local modifications:** Users incorporate their own changes to CLAUDE.md, settings, agents,
   templates. These are intentional adaptations, not bugs — they must be preserved.
3. **Live project data:** `.context/`, `.tasks/`, `.fabric/` contain irreplaceable project memory.
   A botched upgrade could destroy episodic memory, task history, or learned patterns.
4. **Schema evolution:** If `.context/project/concerns.yaml` schema changes between versions
   (e.g., T-397's risks→concerns migration), existing installations need migration paths.
5. **Blast radius:** An upgrade touches `bin/fw`, `lib/`, `agents/`, `CLAUDE.md`, hooks,
   templates — nearly everything. A naive `git pull` could overwrite local customizations.

**Why now:** The framework is approaching external adoption (T-334 launch sequence). External
users will need upgrade paths. Building this after users are stuck on old versions is harder
than building it before.

**Relationship to T-316 (layered CLAUDE.md):** T-316 explored separating framework base from
project overrides. That's one piece of the upgrade puzzle — if CLAUDE.md is layered, framework
updates don't overwrite project customizations. But upgrade is much broader than just CLAUDE.md.

## Assumptions

- A1: Git is the distribution mechanism (users clone/fork the framework repo)
- A2: Users modify framework files (CLAUDE.md, settings.json, agents/) — not just project files
- A3: A "framework layer" vs "project layer" separation is feasible and necessary for safe upgrades
- A4: Semantic versioning + migration scripts can handle schema evolution
- A5: Dry-run mode is essential — users need to preview upgrade impact before applying
- A6: Rollback must be possible — failed upgrades cannot leave installations in a broken state
- A7: The upgrade process itself should be framework-governed (task, audit trail, verification)

## Exploration Plan

This inception is deliberately meta — we first design HOW to investigate, then execute.

| # | Spike | Time-box | Deliverable |
|---|-------|----------|-------------|
| 1 | **Scope analysis:** What files are framework vs project? | 30min | Classification matrix (framework/project/hybrid for every top-level path) |
| 2 | **Blast radius mapping:** What breaks if each framework file changes? | 30min | Impact analysis using `fw fabric` for each upgradeable component |
| 3 | **Version drift detection:** How to detect what a user has changed? | 20min | Prototype: diff local install against release tag, classify changes |
| 4 | **Upgrade strategy design:** Git-based, script-based, or hybrid? | 30min | Options with trade-offs: git merge, cherry-pick, overlay, migration scripts |
| 5 | **Migration path design:** How to handle schema changes? | 20min | Migration script pattern, version manifest, data transformation approach |
| 6 | **Safety mechanisms:** Dry-run, rollback, pre-upgrade validation | 20min | Design for each safety mechanism |
| 7 | **Test plan:** How to validate upgrades across version combinations? | 20min | Test matrix: clean install, 1-version-behind, N-versions-behind, heavy customization |
| 8 | **Decomposition:** Carve research into agent-executable build tasks | 15min | Task list with dependencies |
| 9 | **Present to human** | 10min | Go/No-Go decision |

**Agent decomposition for spikes 1-7:**
- Agent 1 (Explore): Scope analysis — classify every file/directory
- Agent 2 (Explore): Blast radius — use fabric impact analysis
- Agent 3 (Explore): Prior art — how do other CLI frameworks handle upgrades? (Homebrew, Oh My Zsh, Spacemacs, etc.)
- Agent 4 (Plan): Upgrade strategy options with directive scoring
- Agent 5 (Plan): Safety mechanism design

## Technical Constraints

- Framework distributed via git clone (not package manager — Homebrew is a wrapper, not the source)
- `.framework.yaml` in project root enables shared-tooling mode (framework separate from project)
- Git hooks are installed per-repo — upgrade must re-install if hook format changes
- CLAUDE.md is auto-loaded by Claude Code — format changes affect all sessions immediately
- Settings.json hooks have nested structure that changed over time (T-139, T-188)
- No database — all state is YAML/Markdown files in `.context/` and `.tasks/`

## Scope Fence

**IN scope:** Upgrade detection, version tracking, migration tooling design, safety mechanisms,
file classification (framework vs project), rollback design, test approach

**OUT of scope:** Implementing the full upgrade system (that's build tasks from this inception),
auto-update (this is manual/commanded upgrade only), cloud distribution, plugin marketplace

## Acceptance Criteria

### Agent
- [ ] File classification matrix (framework/project/hybrid) produced
- [ ] Blast radius analysis for framework file changes
- [ ] Prior art research on CLI framework upgrade patterns
- [ ] Upgrade strategy options presented with directive scoring
- [ ] Safety mechanism design (dry-run, rollback, validation)
- [ ] Research artifact written to docs/reports/
- [ ] Go/No-Go decision recorded
- [ ] Build tasks created for approved approach

### Human
- [ ] [REVIEW] Review upgrade strategy and approve approach
  **Steps:**
  1. Read `docs/reports/T-434-upgrade-process-inception.md`
  2. Review file classification and upgrade strategy options
  3. Assess risk tolerance for the chosen approach
  4. Decide: approve, narrow scope, or defer
  **Expected:** Clear direction on upgrade approach and phase plan
  **If not:** Discuss specific risk concerns or scope adjustments

## Go/No-Go Criteria

**GO if:**
- File classification reveals a clean framework/project boundary
- At least one upgrade strategy scores well on all four directives
- Safety mechanisms (dry-run, rollback) are feasible
- The work can be phased into ≤5 build tasks with clear dependencies

**NO-GO if:**
- Framework and project files are too entangled for safe separation
- No upgrade strategy preserves local customizations safely
- The blast radius is too large for incremental implementation
- External adoption timeline doesn't justify the investment yet

## Verification

test -f docs/reports/T-434-upgrade-process-inception.md

## Decisions

<!-- Pending exploration -->

## Decision

<!-- Filled at completion via: fw inception decide T-434 go|no-go --rationale "..." -->

## Updates

### 2026-03-10T21:13:36Z — task-created [task-create-agent]
- **Action:** Created inception task from human request
- **Context:** Human identified upgrade process as key gap for external adoption. Emphasized
  thorough investigation, layered testing, and careful decomposition before any build work.
  Specifically requested thinking about the investigation approach itself before executing.
