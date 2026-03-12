# T-455 SPIKE 1: Current fw init Audit — What It Does, What Breaks

## Overview

fw init is the framework's project bootstrap command. It creates the governance directory structure, seeds starter files, installs git hooks, and can auto-create onboarding tasks. This audit documents every step, identifies data isolation gaps, and clarifies what the shared-tooling model requires.

---

## 1. Full Init Workflow (lib/init.sh)

### Step 1: Parse Arguments & Validation
- **File:** `lib/init.sh:13-66`
- **Logic:**
  - Accepts `--provider {claude,cursor,generic}`, `--force`, `--no-first-run`, help
  - Defaults to current directory if no target specified
  - Validates target exists, is absolute path
  - Checks for existing `.framework.yaml` (idempotent guard — unless `--force`)

### Step 2: Directory Structure Creation
- **File:** `lib/init.sh:83-116`
- **Creates 17 directories under `$target_dir`:**
  - `.tasks/{active,completed,templates}` — task storage
  - `.context/{working,project,episodic,handovers,scans,audits/cron,bus/{results,blobs}}` — session + project memory
  - Files: `.context/bypass-log.yaml`, `.context/working/.gitignore`

### Step 3: Copy Task Templates
- **File:** `lib/init.sh:142-153`
- **Logic:**
  - Copies all `*.md` files from `$FRAMEWORK_ROOT/.tasks/templates/` → `$target_dir/.tasks/templates/`
  - Currently only `default.md` exists in framework
  - Non-fatal if source template dir missing

### Step 4: Create `.framework.yaml` Configuration File
- **File:** `lib/init.sh:155-184`
- **Writes to:** `$target_dir/.framework.yaml`
- **Fields:**
  - `project_name` — basename of target directory
  - `framework_path` — absolute path to `$FRAMEWORK_ROOT`
  - `version` — `$FW_VERSION` from bin/fw
  - `provider` — {claude, cursor, generic}
  - `initialized_at` — UTC timestamp
  - `upstream_repo` — auto-detected from framework's git origin (optional)

### Step 5: Seed Project Memory Files (6 files)
- **File:** `lib/init.sh:187-294`
- **Logic:** If file doesn't exist OR `--force=true`, either:
  1. Copy from `$FRAMEWORK_ROOT/lib/seeds/` if available, OR
  2. Generate minimal inline YAML template
- **Files seeded:**

  | File | Source | Contents |
  |------|--------|----------|
  | `.context/project/practices.yaml` | `lib/seeds/practices.yaml` | Graduated practices (3+ applications) — **10 entries from framework** |
  | `.context/project/decisions.yaml` | `lib/seeds/decisions.yaml` | Architectural decisions — **18 entries from framework** |
  | `.context/project/patterns.yaml` | `lib/seeds/patterns.yaml` | Failure/success/workflow patterns — **12 entries from framework** |
  | `.context/project/learnings.yaml` | inline | Empty: `learnings: []` |
  | `.context/project/assumptions.yaml` | inline | Empty: `assumptions: []` |
  | `.context/project/directives.yaml` | inline | 4 constitutional directives (D1-D4) |
  | `.context/project/concerns.yaml` | inline | Empty: `concerns: []` |

### Step 6: Generate Provider-Specific Config
- **File:** `lib/init.sh:299-333`
- **Provider types:**
  - **claude:** Calls `generate_claude_md()` + `generate_claude_code_config()` (10 hooks configured)
  - **cursor:** Calls `generate_cursorrules()` → `.cursorrules` file
  - **generic:** Calls both claude functions (default)

#### Sub-step: Generate CLAUDE.md
- **File:** `lib/init.sh:458-526`
- **Logic:**
  - Reads template from `$FRAMEWORK_ROOT/lib/templates/claude-project.md`
  - Substitutes `__PROJECT_NAME__`, `__FRAMEWORK_ROOT__`
  - Falls back to inline minimal CLAUDE.md if template missing

#### Sub-step: Generate Claude Code Config
- **File:** `lib/init.sh:528-707`
- **Creates:**
  - `.claude/settings.json` — 10 hooks (PreCompact, SessionStart:compact, SessionStart:resume, PreToolUse×4, PostToolUse×3)
  - `.claude/commands/resume.md` — `/resume` slash command implementation

### Step 7: Install Git Hooks (if .git exists)
- **File:** `lib/init.sh:335-348`
- **Logic:**
  - Sets `PROJECT_ROOT="$target_dir"`
  - Calls `$FRAMEWORK_ROOT/agents/git/git.sh install-hooks`
  - Installs 3 hooks: `commit-msg`, `post-commit`, `pre-push`
  - Non-fatal if fails

### Step 8: Ensure fw in PATH
- **File:** `lib/init.sh:350-358`
- **Logic:**
  - Checks if `fw` is already in PATH
  - If not and `/usr/local/bin` writable, symlinks `$FRAMEWORK_ROOT/bin/fw` → `/usr/local/bin/fw`
  - Warns if neither condition met

### Step 9: Post-Init Validation (T-357)
- **File:** `lib/init.sh:360-370`
- **Logic:**
  - Calls `validate-init.sh` (separate agent)
  - Reports validation errors but doesn't block init (idempotent)

### Step 10: Activate Governance — Context Init
- **File:** `lib/init.sh:372-380`
- **Logic:**
  - Sets `PROJECT_ROOT="$target_dir"`
  - Runs `$FRAMEWORK_ROOT/agents/context/context.sh init`
  - Creates working memory for session (non-fatal if fails)

### Step 11: Auto-Create Onboarding Tasks (T-003)
- **File:** `lib/init.sh:382-445`
- **Logic:**
  - Detects if project has existing code (checks for package.json, requirements.txt, etc. + src/ lib/ app/ dirs)
  - **Existing project:** Creates 3 onboarding tasks via create-task.sh:
    1. "Ingest project structure and understand codebase" (build, agent-owned)
    2. "Register key components in fabric" (build, agent-owned)
    3. "Create initial project handover" (build, agent-owned)
  - **New project:** Creates 1 inception task:
    1. "Define project goals and architecture" (inception, human-owned)
  - Sets focus on the first task with `--start`

---

## 2. Path Resolution (lib/paths.sh)

**Key insight:** All agents use `lib/paths.sh` which resolves:

```bash
FRAMEWORK_ROOT  # Always: this file's location (lib/paths.sh → lib/.. → repo root)
PROJECT_ROOT    # Default: git toplevel from FRAMEWORK_ROOT; fallback: FRAMEWORK_ROOT
```

**Shared-tooling model:** Agents accept `PROJECT_ROOT` as environment variable override.

---

## 3. .framework.yaml Configuration

**Created by:** `lib/init.sh:176-184` in each project

**Fields:**
```yaml
project_name: <basename of init target>
framework_path: <FRAMEWORK_ROOT>
version: <FW_VERSION>
provider: <claude|cursor|generic>
initialized_at: <UTC timestamp>
upstream_repo: <optional github URL>  # auto-detected from framework
```

**Read by:** `bin/fw` (resolve_framework function, lines 65-73) to find framework in shared-tooling mode

---

## 4. Data Isolation — WHERE DOES EACH AGENT READ/WRITE?

### Task System (create-task.sh, update-task.sh)
- **Read from:** `$PROJECT_ROOT/.tasks/` (active/completed/templates)
- **Write to:** `$PROJECT_ROOT/.tasks/`
- **Status:** ✓ Correctly scoped to PROJECT_ROOT
- **Pattern:** `source "$FRAMEWORK_ROOT/lib/paths.sh"` → uses paths.sh defaults
- **Evidence:** Line 9 in create-task.sh, lines 17-18 in update-task.sh

### Context Agent (context.sh)
- **Read from:** `$PROJECT_ROOT/.context/` (all subdirs)
- **Write to:** `$PROJECT_ROOT/.context/` (working, project, episodic, etc.)
- **Status:** ✓ Correctly scoped to PROJECT_ROOT
- **Pattern:** sources `lib/paths.sh`
- **Evidence:** Lines 25-26, directories initialized at line 33

### Audit Agent (audit.sh)
- **Read from:** `$PROJECT_ROOT/.context/` (all files), `$PROJECT_ROOT/.tasks/`, `.git/`
- **Write to:** `$PROJECT_ROOT/.context/audits/cron/` (reports)
- **Status:** ✓ Correctly scoped to PROJECT_ROOT
- **Pattern:** Line 19 sources paths.sh
- **Evidence:** Lines 20, 34 use `$CONTEXT_DIR` = `$PROJECT_ROOT/.context`

### Healing Agent (healing.sh)
- **Read from:** `$PROJECT_ROOT/.context/project/patterns.yaml`, learnings
- **Write to:** `$PROJECT_ROOT/.context/project/learnings.yaml`
- **Status:** ✓ Correctly scoped to PROJECT_ROOT

### Handover Agent (handover.sh)
- **Read from:** `$PROJECT_ROOT/.tasks/active/`, `.context/handovers/`, git history
- **Write to:** `$PROJECT_ROOT/.context/handovers/LATEST.md`
- **Status:** ✓ Correctly scoped to PROJECT_ROOT

### Context Budget Gate (budget-gate.sh)
- **Issue identified:** **G-007 (gap)** — Fixed in T-149
- **Problem was:** Used `$FRAMEWORK_ROOT` for project-specific data
- **What broke:** Transcript discovery (read wrong project), status reset (framework's counter), context injection (framework context into project)
- **Resolution:** T-149 fixed all 4 bugs by using PROJECT_ROOT correctly
- **Status:** ✓ Fixed

### Self-Audit Agent (self-audit.sh)
- **Read from:** `$PROJECT_ROOT/.context/project/` (decisions, learnings, patterns, practices, gaps, assumptions)
- **Status:** Line 226 iterates over these files
- **Pattern:** Uses both direct file checks and find commands
- **Status:** ✓ Correctly scoped

---

## 5. Data Seeding — THE ISOLATION RISK

**Critical Finding:** Init seeds project memory files from FRAMEWORK_ROOT. This creates a **shared-defaults vs. isolated-data ambiguity**:

### What Gets Copied (lib/init.sh:192-207):
- `lib/seeds/practices.yaml` → `.context/project/practices.yaml` (10 framework practices)
- `lib/seeds/decisions.yaml` → `.context/project/decisions.yaml` (18 framework decisions)
- `lib/seeds/patterns.yaml` → `.context/project/patterns.yaml` (12 framework patterns)

### The Problem:
1. **Knowledge leakage:** Framework's architectural decisions (D-001 through D-050) appear in every new project's initial memory
2. **Update skew:** If framework's seed files change, projects initialized earlier don't get updates (no migration)
3. **Shared-tooling confusion:** When PROJECT_ROOT != FRAMEWORK_ROOT, agents should read from PROJECT_ROOT, not FRAMEWORK_ROOT
4. **Idempotency gap:** If `.force=true`, existing project memory is WIPED and replaced with framework seeds

**Example problem state:**
- Init a project at `/opt/my-project/`
- It gets `.context/project/decisions.yaml` with 18 framework decisions
- Agent at `/opt/999-Agentic-Engineering-Framework/` later updates framework decisions
- `/opt/my-project/` keeps old 18 decisions forever
- No agent flags this as a divergence

---

## 6. Git Hooks — HOW PATH SETUP HAPPENS

**File:** `agents/git/git.sh install-hooks` (called by init.sh:343)

**Setup pattern:**
```bash
PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks
```

This sets PROJECT_ROOT before invoking git agent, which:
1. Reads hooks from `.git/hooks/{commit-msg,post-commit,pre-push}`
2. Each hook script starts with path setup (via lib/paths.sh)
3. Hooks then validate/enforce rules

**Isolation:** ✓ Correct — hooks use PROJECT_ROOT from environment

---

## 7. Onboarding Task Auto-Creation (T-003)

**File:** `lib/init.sh:382-445`

**Task creation pattern:**
```bash
PROJECT_ROOT="$target_dir" "$create_task" \
    --name "..." --type build --owner agent --start \
    --description "..." --tags "onboarding"
```

**Issues found:** None with path isolation. create-task.sh correctly reads from PROJECT_ROOT.

**Behavior notes:**
- If `.tasks/active/` has files already, skip task creation (idempotent)
- `--start` flag sets focus via context agent (also PROJECT_ROOT-aware)
- Tasks get tags "onboarding" for later filtering

---

## 8. Claude Code Integration — Settings.json Hooks

**File:** `lib/init.sh:535-638` (generate_claude_code_config function)

### Hook Configuration Pattern:
Each hook has:
```bash
"command": "PROJECT_ROOT=$dir $FRAMEWORK_ROOT/agents/context/check-active-task.sh"
```

**Hooks wired (10 total):**
1. PreCompact — pre-compact.sh
2. SessionStart:compact — post-compact-resume.sh
3. SessionStart:resume — post-compact-resume.sh
4. PreToolUse EnterPlanMode — block-plan-mode.sh
5. PreToolUse Write|Edit — check-active-task.sh
6. PreToolUse Bash — check-tier0.sh
7. PreToolUse Write|Edit|Bash — budget-gate.sh
8. PostToolUse all — checkpoint.sh
9. PostToolUse Bash — error-watchdog.sh
10. PostToolUse Task|TaskOutput — check-dispatch.sh

**Isolation:** ✓ Correct — each hook hardcodes `PROJECT_ROOT=$dir` before invocation

---

## 9. Onboarding Test Results (agents/onboarding-test/test-onboarding.sh)

**Status:** T-360 completed, all 8 checkpoints PASS

**Checkpoints verified:**
1. ✓ Project scaffold (directories, files)
2. ✓ Git hooks installed
3. ✓ First task creation and focus
4. ✓ Governance gate (task requirement)
5. ✓ Commit gate
6. ✓ Audit execution
7. ✓ Self-audit
8. ✓ Handover generation

**Known issues from T-294-T-307 inception:**
- Double output bug (O-004/O-006) — Fixed T-295
- Context init exit code (O-005) — Fixed T-296
- --start not setting focus (O-008) — Fixed T-297
- Init suggested commands (O-007) — Fixed T-298
- Doctor hook validation parsing (O-003) — Fixed T-299
- README quickstart (O-001) — Fixed T-300
- Audit grace period for new projects (O-009) — Fixed T-301
- All major artifacts complete (O-009) — Fixed T-302
- Preflight + init integration (O-002) — Fixed T-303

**Status:** ✓ All 9 findings fixed; onboarding flow is solid

---

## 10. Existing Decisions About Init/Initialization

**From `.context/project/decisions.yaml`:**
- **D-032:** "Refactor agents to accept PROJECT_ROOT externally" (T-032, Feb 2026)
  - All agents now use `PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"` pattern
  - Backward compatible (falls back to ../../ when PROJECT_ROOT not set)
  - Shared tooling model fully enabled

---

## 11. Issues & Gaps Related to Init

### Confirmed in concerns.yaml:

**G-007 (gap, closed):** "Budget gate non-functional for shared-tooling projects"
- **Issue:** budget-gate.sh, pre-compact.sh, post-compact-resume.sh used FRAMEWORK_ROOT for project paths
- **Impact:** Transcript discovery, counter reset, context injection all broke in shared-tooling mode
- **Resolution:** T-149 fixed all 4 bugs by using PROJECT_ROOT correctly
- **Status:** CLOSED

**G-012 (gap, closed):** "NotebookEdit not covered by task gate"
- **Accepted risk** — no Jupyter notebooks used

**G-013 (gap, closed):** "Task gate accepts completed task IDs"
- **Issue:** check-active-task.sh only checked focus.yaml, didn't validate file exists
- **Resolution:** T-232 added active-file validation
- **Status:** CLOSED

---

## 12. Knowledge Separation Modes

### Current Architecture:
1. **Framework-internal mode:** Running agents from inside `/opt/999-Agentic-Engineering-Framework/`
   - PROJECT_ROOT defaults to git toplevel (which is FRAMEWORK_ROOT)
   - All reads/writes are framework-scoped

2. **Shared-tooling mode:** Framework at A, project at B (A ≠ B)
   - `.framework.yaml` in B contains path to A
   - `bin/fw` reads .framework.yaml to find A
   - Agents receive `PROJECT_ROOT=B` via environment
   - All reads/writes should be B-scoped ✓

### Missing Modes (T-455 scope):
- **Onboarding mode:** First session after init — should guide human through initial decisions
- **Knowledge transfer mode:** Moving framework from one installation to another, or migrating projects
- **Multi-project mode:** Single user managing multiple projects with one framework install

---

## Summary of Findings

### What fw init Does (Correctly):
1. ✓ Creates 17 directories in project root
2. ✓ Seeds 6 project memory files
3. ✓ Generates provider-specific config (CLAUDE.md, .cursorrules, .claude/settings.json)
4. ✓ Installs 3 git hooks
5. ✓ Adds fw to PATH if needed
6. ✓ Auto-creates 3-4 onboarding tasks
7. ✓ Activates governance (context init)

### What Breaks (Isolation Issues):
1. **Knowledge leakage from seeds:** Framework practices/decisions copied to project (ambiguous if this is a feature or bug)
2. **--force wipes project memory:** If re-running init with --force, existing decisions/learnings are lost
3. **No onboarding interaction:** Auto-created tasks have no guided walkthrough
4. **Hook configuration hardcodes paths:** Each hook in settings.json has `PROJECT_ROOT=$dir` — correct but verbose
5. **No knowledge update strategy:** Projects don't get new framework learnings if seeded files change later

### Path Isolation Status:
- ✓ **All agents** correctly use PROJECT_ROOT by default
- ✓ **All hooks** correctly set PROJECT_ROOT before invocation
- ✓ **Budget gate bugs** (G-007) fixed in T-149
- ✗ **Data seeding** is ambiguous — framework knowledge baked into every project

---

## Data Files Involved

### Framework Files Read/Written:
- `lib/init.sh` — main bootstrap script
- `lib/paths.sh` — path resolution (sourced by all agents)
- `lib/seeds/{decisions,patterns,practices}.yaml` — initial knowledge copied to projects
- `lib/templates/claude-project.md` — CLAUDE.md template
- `agents/task-create/{create-task,update-task}.sh` — task management
- `agents/context/context.sh` — working memory
- `agents/git/git.sh` — hook installation
- `.context/project/{decisions,practices,patterns,learnings,assumptions,directives,concerns}.yaml` — knowledge base

### Project Files Created:
- `.framework.yaml` — project configuration
- `.tasks/{active,completed,templates}/` — task storage
- `.context/{working,project,episodic,handovers,audits,scans,bus}/` — session + knowledge memory
- `.claude/settings.json` — Claude Code hooks
- `.claude/commands/resume.md` — slash command

---

## Recommendations for T-455

1. **Clarify seeding intent:** Is framework knowledge meant to transfer to projects, or should projects start blank?
2. **Add onboarding modes:** Distinguish first-run initialization from re-initialization
3. **Implement knowledge migration:** When framework updates, provide migration path for existing projects
4. **Formalize data isolation:** Document which data flows from framework → project vs. project-only
5. **Standardize hook setup:** Consider centralizing hook configuration to avoid path hardcoding in settings.json

