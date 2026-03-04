# T-294: Framework Onboarding — Portable Project Bootstrap

**Type:** Inception research artifact
**Created:** 2026-03-04

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
