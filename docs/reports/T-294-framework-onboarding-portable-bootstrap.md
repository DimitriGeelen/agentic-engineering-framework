# T-294: Framework Onboarding — Portable Project Bootstrap

**Type:** Inception research artifact
**Created:** 2026-03-04
**Status:** DRAFT — under active dialogue

---

## Proposed Task Breakdown (DRAFT)

### Phase 1: Fix Broken Onboarding Path (bugs in existing code)

These are bugs that make the current `fw init` → first task flow fail or confuse users. All are small fixes.

| Task | Source | What To Fix | Scope |
|------|--------|-------------|-------|
| T-A: Fix `fw doctor` env var parsing | O-003 | `bin/fw:392` — `command.split()[0]` grabs `PROJECT_ROOT=...` instead of script path. Should skip env var assignments. | 1 file, ~5 lines |
| T-B: Fix double output bug | O-004, O-006 | `fw` sources or calls functions twice — affects doctor, context init, possibly others. Root cause analysis needed. | 1 file, systemic |
| T-C: Fix `fw context init` exit code | O-005 | Returns exit 1 on success. Scripts/CI interpret as failure. | 1 file, ~1 line |
| T-D: Fix `--start` not setting focus | O-008 | `create-task.sh --start` sets status but doesn't call `context.sh focus T-XXX`. | 1 file, ~3 lines |
| T-E: Fix `fw init` suggested commands | O-007 | "Next steps" recommends `fw task create --name '...'` without `--description`. Should recommend `fw work-on` instead. | 1 file, ~5 lines |

**Dependency:** T-B (double output) may be root cause of several issues — investigate first.

### Phase 2: New Project Baseline (missing artifacts and config)

Things `fw init` should create but doesn't, causing false audit failures on day 1.

| Task | Source | What To Build | Scope |
|------|--------|---------------|-------|
| T-F: Create README.md / QUICKSTART | O-001 | Human-readable entry point. Install deps → clone → init → first task → verify. One page. | 1 new file |
| T-G: Fix audit false positives for new projects | O-009 | Audit should distinguish "new project" (< 5 commits, no handover yet) from "broken project". Grace period or new-project mode. | `audit.sh`, medium |
| T-H: Complete `fw init` generated artifacts | O-009 | Init should create: cron audit dir, bypass-log.yaml, post-compact hook in settings.json. | `lib/init.sh`, small |

### Phase 3: Production-Ready Onboarding (new features)

Features that make onboarding polished and self-guided. Each is independent.

| Task | Source | What To Build | Scope |
|------|--------|---------------|-------|
| T-I: `fw preflight` command | O-002 | Check all deps (python3, pyyaml, git, bash version, write perms) before init. Clear pass/fail with install instructions per platform. | New lib/preflight.sh |
| T-J: `fw deps check` / `fw deps install` | Area 5 | Platform-aware dependency checker and optional installer. Subset of preflight focused on packages. | New lib/deps.sh |
| T-K: First-run experience | Area 6B | After `fw init`, guided "first 5 minutes": create task → change → commit → audit → handover. Each step validates the previous. | New lib/first-run.sh or extend setup.sh |
| T-L: Template drift detection | Area 6C | `fw doctor` check: compare project CLAUDE.md sections against template. `fw upgrade` to re-apply. | Extend bin/fw doctor + new lib/upgrade.sh |
| T-M: Automated onboarding test | Area 6F | `fw test-onboarding /tmp/test` — creates, initializes, runs full cycle, validates, cleans up. CI-friendly. | New test script |
| T-N: `/new-project` skill | Area 6G | Claude Code skill wrapping fw init/setup for in-session guided onboarding. | New .claude/commands/new-project.md |

### Phase 4: Future / Parked

| Item | Why Parked |
|------|-----------|
| Vendored/embedded mode (Approach B) | Needs separate inception — different architecture |
| Package manager distribution (Approach C) | Premature — framework still evolving |
| Git submodule mode (Approach D) | Low demand |
| Cross-project dashboard | Watchtower handles this |
| `fw upgrade` / migration | Depends on template drift detection (T-L) |

---

## Proposed Execution Sequence

```
Phase 1 (bugs):  T-B → T-A → T-C → T-D → T-E    [parallel after T-B]
                      ↓
Phase 2 (baseline): T-F + T-H → T-G               [F and H parallel]
                      ↓
Phase 3 (features): T-I → T-K → T-M               [critical path]
                    T-J, T-L, T-N                   [independent, any order]
                      ↓
Verify:           Run T-M (automated onboarding test) as acceptance gate
```

**Estimated total:** 13 tasks across 3 phases. Phase 1 is ~1 session. Phase 2 is ~1 session. Phase 3 is ~2-3 sessions.

---

## Dialogue Log

### User Question (session start)
User wants deep analysis of portability covering 6 areas:
1. Approaches to copy/start framework for a new project
2. What content must remain vs. what's fresh for a new project
3. Sequence of steps + parallel/alternative routes
4. Post-startup initiating steps
5. OS dependencies
6. Other relevant sections for production-ready onboarding

**Purpose:** Discover, identify, and define what onboarding steps and scripts need to be built.

### User Feedback: Simulate deployment
"It's not working correctly yet — simulate a new deployment and take back learnings."
→ Led to live simulation with 9 observations (O-001 through O-009).

### User Direction: Document before building
"Let's draft structure, plan and tasks first. Start documenting, continue our conversation."
→ Shifted to one-by-one walkthrough of each proposed task with human approval.

### User Correction: Governance compliance
"Have we created tasks for this?! WHY are you skipping framework governance?!"
→ Started creating framework tasks for each approved item. All items now have tasks.

### Dialogue Decisions (items 1-13)

| Item | User Decision | Task | Notes |
|------|--------------|------|-------|
| 1. Double output bug | "fix it" — separate task | T-295 | |
| 2. Exit code 1 | "separate task" | T-296 | |
| 3. --start no focus | "separate task" | T-297 | |
| 4. Init suggested commands | "separate task" | T-298 | |
| 5. Doctor env var parsing | "separate task" | T-299 | |
| 6. README.md | "separate task" | T-300 | |
| 7. Audit grace period | "separate task" | T-301 | |
| 8. Complete init artifacts | "separate task" | T-302 | |
| 9. fw preflight | "both — init calls preflight, print + guide user" | T-303 | |
| 10. fw deps install | "auto install is great but keep user in control" — merged into T-303 | T-303 | Sovereignty principle: detect silently, act with consent. Same pattern as Tier 0. Required [Y/n], recommended [y/N]. |
| 11a. First-run experience | "opt-out, runs by default after init" | T-304 | |
| 11b. Deep component walkthrough | "separate inception for scope" | T-305 | horizon: later |
| 12. Template drift / upgrade | User identified bigger issue: split model causes version mingling. Need distribution model inception. | T-306 | Self-hosting constraint: framework develops itself using its own tooling — dev repo must stay. Question is how OTHER projects consume it cleanly. |
| 13. Automated onboarding test | "deterministic script not powerful enough — need stochastic reasoning with structured guidance" | T-307 | Follows CLI/Agent/Skill hierarchy: bash scaffolding + AGENT.md interpretation + /test-onboarding skill. Inception to scope hybrid approach. |

### Key Design Principles Established (from dialogue)

1. **Sovereignty in automation:** Framework proposes, human decides. Auto-install shows exact commands, explains why each dep is needed, asks before executing. Same pattern as Tier 0.
2. **Self-hosting is non-negotiable:** Framework develops itself using its own governance. The dev repo stays. Distribution model for other projects is a separate concern (T-306).
3. **CLI/Agent/Skill hierarchy applies to new features:** Deterministic work in bash, interpretation in AGENT.md, in-session orchestration via skills.
4. **Version mingling is an architectural problem:** The split model (live agents + frozen copies) creates a frankenstein version state in consumer projects. Needs inception (T-306).

### Gap Audit (end of session)

Before wrapping up, audited conversation against captured tasks. Found 5 uncaptured items:

| Item | Task | Horizon | Source |
|------|------|---------|--------|
| `/new-project` Claude Code skill | T-308 | later | Phase 3 item T-N |
| Merge `fw init` + `fw setup` | T-309 | later | DX comparison |
| Auto-run `fw doctor` at end of init | T-310 | later | DX comparison |
| Install script (`curl \| sh`) | T-311 | later | DX comparison |
| Jargon glossary | T-312 | later | New-user-perspective agent |

### Final Task Registry (T-294 children)

**Build tasks (10):** T-295, T-296, T-297, T-298, T-299, T-300, T-301, T-302, T-303, T-304
**Build tasks parked (5):** T-308, T-309, T-310, T-311, T-312
**Inceptions (3):** T-305 (deep walkthrough), T-306 (distribution model), T-307 (hybrid test)
**Total: 18 tasks** spawned from this inception.

## Live Simulation Observations (2026-03-04)

Simulated fresh project onboarding at `/tmp/test-onboarding-294/`. Full walkthrough from `git init` through `fw handover`.

| ID | Severity | Finding | Root Cause |
|----|----------|---------|------------|
| O-001 | P1 | **No README, INSTALL, or QUICKSTART at framework root.** New user has no entry point. | Missing file |
| O-002 | P2 | **No `fw preflight` command.** No way to validate deps before init. | Missing feature |
| O-003 | P1 | **`fw doctor` FAILS on fresh project.** Hook validation treats `PROJECT_ROOT=...` env var assignment as script path. | Bug in `bin/fw:392` — `command.split()[0]` grabs env var, not script |
| O-004 | P2 | **`fw doctor` output printed TWICE.** | Systemic — `fw` likely sources/calls function twice |
| O-005 | P2 | **`fw context init` exits code 1 on success.** Misleading for scripts/CI. | Bug — non-zero exit on happy path |
| O-006 | P2 | **`fw context init` output printed TWICE.** Same double-output bug as doctor. | Same root cause as O-004 |
| O-007 | P1 | **`fw task create` without `--description` hangs on stdin.** The "Next steps" from `fw init` doesn't mention `--description` flag. | Missing flag in suggested command + stdin blocking |
| O-008 | P1 | **`--start` flag on task create doesn't set focus.** Tier 1 hook blocks Write/Edit despite task being started-work. | `create-task.sh --start` sets status but doesn't call `context.sh focus` |
| O-009 | P2 | **Audit shows 1 FAIL + 9 WARNs on brand-new project.** Several are false positives (pre-framework commit has no T-XXX, cron dir not created, post-compact hook not generated). | `fw init` doesn't create all expected artifacts; audit doesn't distinguish "new project" from "broken project" |

### What Worked Well
- `fw init` creates correct directory structure, seeds, CLAUDE.md, hooks
- `fw work-on` is the correct shortcut — creates task + sets focus + starts work
- Git commit-msg hook correctly rejects commits without T-XXX
- `fw handover` works end-to-end
- Error messages from commit hook are clear and actionable
- Seed files (practices, decisions, patterns) are copied correctly

### Key Insight
**`fw work-on` is the only path that works correctly end-to-end.** The documented path (`fw task create` → `fw context focus`) has two bugs (O-007, O-008). The "Next steps" printed by `fw init` should recommend `fw work-on` instead.

---

## Multi-Perspective Research Findings (2026-03-04)

### Lens 1: Bug Root Cause Analysis (agent: bug-analysis)
Source: `/tmp/fw-agent-bug-analysis.md`

| Bug | File:Line | Root Cause | Fix |
|-----|-----------|-----------|-----|
| Double output (doctor) | `bin/fw:1687` | Missing `exit $?` after `do_doctor` call | Add `exit $?` |
| Double output (context init) | `agents/context/context.sh:71-72` | Missing `exit $?` after `do_init` call | Add `exit $?` |
| Exit code 1 on success | `agents/context/lib/init.sh:148` | No explicit `return 0` at end of `do_init()` | Add `return 0` |
| --start no focus | `agents/task-create/create-task.sh:268` | No call to `context.sh focus` when `START_WORK=true` | Add focus call after task creation |

**Insight:** `fw work-on` (bin/fw:1100-1146) correctly handles focus at line 1139 — the bug is that `create-task.sh` doesn't replicate this behavior.

### Lens 2: New User Perspective (agent: new-user-perspective)
Source: `/tmp/fw-agent-new-user-perspective.md`

Key findings:
1. **"What IS this?"** — FRAMEWORK.md is clear in 30 seconds, but "governance framework for AI agents" still needs a concrete example
2. **Install gaps:** OneDev credential setup assumes prior knowledge. No "what should fw doctor output?" reference. `fw setup` vs `fw init` difference unclear.
3. **Jargon wall:** horizon, inception, episodic memory, antifragility, healing loop — 10+ framework-specific terms with no glossary
4. **Prior knowledge assumed:** Git, CLI comfort, shell profile editing, Python, YAML
5. **Time to first value:** 5-15 minutes to install, but 30+ minutes before seeing the framework *doing something useful* (audit, handover, pattern capture)

### Lens 4: DX Comparison (agent: dx-comparison)
Source: `/tmp/fw-agent-dx-comparison.md`

Compared fw to Cargo, Next.js, Rails, Terraform, Claude Code:
- **fw strengths:** `fw doctor` is best-in-class (13 checks). `fw setup` wizard well-designed. Post-init cheat sheet thorough.
- **"cargo run" gap:** Other tools produce runnable output in 1-3 commands. fw needs 5-7 before doing anything useful.
- **Two entry points:** `fw init` vs `fw setup` is confusing. Every other tool has ONE command.
- **Adoptable patterns:** Merge init+setup, add `--demo` mode, auto-run doctor, single "try next" command.

### Lens 3: Historical Lessons (agent: episodic-lessons)
Source: `/tmp/fw-agent-episodic-lessons.md`

T-124 sprechloop experiment found 11 observations across 6 cycles. Key lessons for T-294:
- **O-009 (template drift)** is PARTIALLY RESOLVED — manual sync works, no automated diff yet
- **L-027:** Setup sentinels must use explicit flags, not file existence
- **L-029:** Always dry-run onboarding on a clean project before shipping
- **Budget gate deadlock (L-049):** Stale .budget-status blocks fw context init after compaction — init must be on the allowlist
- **Task enforcement stale focus (G-013/T-232):** Already resolved but critical for new projects

---

## Current State of Onboarding Machinery

### What Already Exists

| Component | Location | What It Does |
|-----------|----------|--------------|
| `fw init` | `lib/init.sh` | Creates dirs, copies templates, generates CLAUDE.md/.cursorrules, installs git hooks, symlinks fw |
| `fw setup` | `lib/setup.sh` | 6-step guided wizard wrapping fw init (identity, provider, tech stack, enforcement, first task, verify) |
| `fw doctor` | `bin/fw` | 13+ health checks (dirs, hooks, agents, enforcement, tests, plugins, MCP) |
| Seed files | `lib/seeds/` | Universal practices (10), decisions (18), patterns (12) copied to new projects |
| CLAUDE.md template | `lib/templates/claude-project.md` | Full governance guide with `__PROJECT_NAME__` / `__FRAMEWORK_ROOT__` placeholders |
| `/resume` command | `.claude/commands/resume.md` | Copied to new projects for context recovery |
| T-124 validation | Completed | 6-cycle live experiment on sprechloop — GO decision, 12+ bugs fixed |

### What Does NOT Exist Yet

| Gap | Impact |
|-----|--------|
| Dependency checker/installer | User discovers missing python3/pyyaml at runtime |
| Pre-flight validation | No "can this system run the framework?" check before init |
| Post-init smoke test | `fw doctor` exists but no automated "first 5 minutes" verification |
| Upgrade/migration script | `git pull` works but no schema migration for .framework.yaml changes |
| Uninstall/cleanup | No way to remove framework from a project cleanly |
| Multi-project dashboard | Each project is isolated — no cross-project view (except Watchtower) |
| Offline/vendored mode | Framework requires shared tooling reference — no self-contained option |
| `/new-project` skill | No Claude Code skill for guided onboarding (only CLI) |

---

## Area 1: Approaches to Start a New Project

### Approach A: Shared Tooling (Current Model)
```
/opt/framework/  ← single clone, shared by all projects
/opt/project-a/  ← .framework.yaml → framework_path: /opt/framework
/opt/project-b/  ← .framework.yaml → framework_path: /opt/framework
```
- **Pros:** Single source of truth, `git pull` updates all projects, small project footprint
- **Cons:** Framework must be accessible at runtime, breaks if moved/deleted, path coupling

### Approach B: Vendored/Embedded
```
/opt/project-a/
  .framework/    ← full or partial framework copy inside project
  .framework.yaml → framework_path: ./.framework
```
- **Pros:** Self-contained, portable, works offline, no external dependency
- **Cons:** Larger project size, updates require per-project action, divergence risk

### Approach C: Package Manager (Future)
```
pip install agentic-framework  # or npm, brew, etc.
fw init /path/to/project
```
- **Pros:** Standard install flow, version pinning, dependency resolution
- **Cons:** Significant packaging effort, provider-specific (pip vs npm)

### Approach D: Git Submodule
```
git submodule add <framework-url> .framework
```
- **Pros:** Version-locked, familiar git workflow, updatable
- **Cons:** Submodule complexity, requires git, extra clone step

**Current recommendation:** Keep Approach A as primary, add Approach B as option for air-gapped/portable deployments.

---

## Area 2: Content — What Stays vs. What's Fresh

### Content That STAYS (framework-side, never copied)
| Item | Location | Why |
|------|----------|-----|
| Agent scripts | `agents/*/` | Executed in-place via FRAMEWORK_ROOT |
| Agent AGENT.md guides | `agents/*/AGENT.md` | Intelligence layer for agents |
| fw CLI | `bin/fw` | Symlinked or PATH'd |
| Lib modules | `lib/*.sh` | Sourced by fw at runtime |
| Watchtower web app | `web/` | Separate deployment |
| Framework CLAUDE.md | `CLAUDE.md` | Framework's own governance |
| Framework tasks | `.tasks/` | Framework's own task history |

### Content COPIED to New Project (seeds)
| Item | Destination | Source |
|------|-------------|--------|
| Directory structure | `.tasks/`, `.context/` | Created by init.sh |
| Task templates | `.tasks/templates/*.md` | Copied from framework `.tasks/templates/` |
| CLAUDE.md | `CLAUDE.md` | Generated from `lib/templates/claude-project.md` |
| .claude/settings.json | `.claude/settings.json` | Generated with path substitution |
| .claude/commands/resume.md | `.claude/commands/resume.md` | Copied verbatim |
| Seed practices | `.context/project/practices.yaml` | From `lib/seeds/practices.yaml` |
| Seed decisions | `.context/project/decisions.yaml` | From `lib/seeds/decisions.yaml` |
| Seed patterns | `.context/project/patterns.yaml` | From `lib/seeds/patterns.yaml` |
| Empty learnings | `.context/project/learnings.yaml` | Created empty |
| Empty assumptions | `.context/project/assumptions.yaml` | Created empty |
| Directives | `.context/project/directives.yaml` | Created with 4 constitutional directives |
| Gaps register | `.context/project/gaps.yaml` | Created empty |
| .framework.yaml | `.framework.yaml` | Created with project config |
| Git hooks | `.git/hooks/` | Installed by git agent |
| .gitignore (working) | `.context/working/.gitignore` | Volatile files excluded |

### Content GENERATED Fresh (project-specific)
| Item | When | How |
|------|------|-----|
| Session state | `fw context init` | Working memory initialized |
| First task | `fw task create` or setup step 5 | User-driven |
| First handover | `fw handover` | End of first session |
| Episodic memory | Task completion | Auto-generated |
| Custom learnings | During work | `fw context add-learning` |
| Custom patterns | Error resolution | `fw healing resolve` |

---

## Area 3: Sequence of Steps

### Critical Path (Sequential — Must Be In Order)
```
1. Install OS dependencies (python3, git, bash)
   ↓
2. Clone framework repo
   ↓
3. Add fw to PATH (symlink or shell profile)
   ↓
4. Verify: fw version && fw doctor
   ↓
5. Initialize project: fw init /path/to/project --provider claude
   (or: fw setup /path/to/project for guided wizard)
   ↓
6. cd /path/to/project
   ↓
7. fw doctor (verify project-level health)
   ↓
8. fw context init (start first session)
   ↓
9. fw work-on "First task" --type build
```

### Parallel Routes (Steps That Can Happen Independently)

```
After step 2 (clone), these are independent:
  ├── 3a. Add fw to PATH
  ├── 3b. Install python3 dependencies (pyyaml)
  └── 3c. Configure git identity (if not already set)

After step 5 (fw init), these are independent:
  ├── 6a. Customize CLAUDE.md (tech stack, project rules)
  ├── 6b. Set up CI/CD integration
  ├── 6c. Configure Watchtower (if using web dashboard)
  └── 6d. Set up cron audits
```

### Alternative Routes

| Route | When | Steps |
|-------|------|-------|
| **Quick start** | Experienced user | `fw init . --provider claude && fw doctor && fw context init` |
| **Guided wizard** | First-time user | `fw setup .` (walks through all 6 steps) |
| **Non-interactive** | CI/automation | `fw setup . --non-interactive` (defaults for everything) |
| **Existing project** | Adding framework to existing repo | Same as above — fw init is additive, doesn't touch existing files |
| **Provider switch** | Moving from Cursor to Claude | `fw init . --provider claude --force` (regenerates config) |

---

## Area 4: Post-Startup Steps

After `fw init` / `fw setup` completes:

| Step | Required? | Command | Purpose |
|------|-----------|---------|---------|
| First `fw context init` | Yes | `fw context init` | Creates session state |
| Set git identity | Yes (if not set) | `git config user.name/email` | Commits require identity |
| Create first task | Yes | `fw work-on "..." --type build` | Nothing works without a task |
| First commit | Yes | `fw git commit -m "T-001: ..."` | Validates hook chain |
| First handover | Yes | `fw handover --commit` | Validates handover pipeline |
| First audit | Recommended | `fw audit` | Baseline compliance check |
| Customize CLAUDE.md | Recommended | Edit CLAUDE.md | Add tech stack, project rules |
| Set up cron audit | Optional | `crontab -e` | Periodic compliance monitoring |
| Deploy Watchtower | Optional | See deployment-runbook.md | Web dashboard |
| Initial commit | Recommended | `git add . && git commit` | Snapshot clean state |

---

## Area 5: OS Dependencies

### Required (Framework Won't Function Without)
| Dependency | Min Version | Used By | Check Command |
|------------|-------------|---------|---------------|
| bash | 4.0+ | All agents, fw CLI | `bash --version` |
| python3 | 3.8+ | YAML parsing, audit, hooks, metrics | `python3 --version` |
| PyYAML | 6.0+ | All YAML operations | `python3 -c "import yaml"` |
| git | 2.0+ | Git agent, hooks, traceability | `git --version` |
| coreutils | any | date, sha256sum, realpath, mktemp | `date --version` |
| grep/sed/awk | any | All shell scripts | `grep --version` |
| curl | any | Health checks, Watchtower API | `curl --version` |

### Recommended (Framework Degrades Without)
| Dependency | Used By | Impact If Missing |
|------------|---------|-------------------|
| shellcheck | `fw doctor` | WARN in health check, no lint |
| bats | Test infrastructure | Cannot run framework tests |
| jq | JSON processing in some agents | Falls back to python3 |
| cron/systemd-timer | Periodic audits | Manual audit only |

### Watchtower-Specific (Only If Using Web Dashboard)
| Dependency | Version |
|------------|---------|
| Flask | >=3.0 |
| Gunicorn | >=22.0 |
| Ruamel.yaml | >=0.18 |
| Markdown2 | >=2.4 |
| Bleach | >=6.0 |
| Ollama | >=0.4 (for embeddings) |
| sqlite-vec | >=0.1.3 |
| Tantivy | >=0.22 |

### Platform Compatibility
| Platform | Status | Notes |
|----------|--------|-------|
| Linux (Ubuntu/Debian) | Fully tested | Primary dev environment |
| macOS | Expected to work | `date` flags differ (GNU vs BSD) — untested |
| Windows/WSL | Expected to work | WSL2 with bash — untested |
| Alpine/minimal | Partial | May need `bash`, `coreutils` packages |

---

## Area 6: Additional Sections for Production-Ready Onboarding

### A. Pre-Flight Check Script
A `fw preflight` command that validates ALL dependencies before init:
- Checks python3, pyyaml, git, bash version
- Validates write permissions to target directory
- Checks git identity configuration
- Reports clear pass/fail with install instructions per platform

### B. First-Run Experience (FRE)
After `fw init`, a guided "first 5 minutes" experience:
- Create a sample task
- Make a change
- Commit with task reference
- Run audit
- Generate handover
- Each step validates the previous one succeeded

### C. Template Drift Prevention
Mechanism to keep project CLAUDE.md in sync with framework template:
- `fw doctor` check: compare project CLAUDE.md hash vs template
- `fw upgrade` command to re-apply template changes
- Semantic versioning of template to track breaking changes

### D. Dependency Installer
Platform-aware dependency installation:
```bash
fw deps install    # Install all required dependencies
fw deps check      # Check what's missing
fw deps --minimal  # Only required deps
fw deps --full     # Required + recommended + Watchtower
```

### E. Migration/Upgrade Path
When framework evolves:
- `fw upgrade` — re-apply template, update hooks, migrate .framework.yaml schema
- Version-stamped .framework.yaml to detect stale projects
- Changelog per version for human review

### F. Onboarding Verification Test
Automated end-to-end test of onboarding:
```bash
fw test-onboarding /tmp/test-project  # Creates, initializes, verifies, cleans up
```
This is what T-124 did manually — automate it.

### G. `/new-project` Skill for Claude Code
A skill that wraps fw init/setup for in-session onboarding:
- Human says `/new-project`
- Skill guides through setup interactively within Claude Code
- Validates each step before proceeding

### H. Quick Start Guide
One-page document covering:
1. Install (3 commands)
2. Initialize (2 commands)
3. First task (3 commands)
4. Verification (1 command)
Target: working framework in under 5 minutes.
