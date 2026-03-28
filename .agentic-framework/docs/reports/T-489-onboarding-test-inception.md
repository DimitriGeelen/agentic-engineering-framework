# T-489 Spike 1: Complete Onboarding Surface Map

## Executive Summary

The onboarding path from "user has nothing" to "framework working" spans 5 critical steps:
**install.sh** → **fw init** → **preflight/validate-init** → **fw doctor** → **fw serve**

Each step has discrete failure surfaces and integration seams. Testing is PARTIAL at steps 1-2, nearly absent at step 3 (seam), and emerging at step 5.

---

## Step 1: INSTALL — `install.sh` (lines 1-197)

### What It Does
Clones framework repo + links `bin/fw` to system PATH. Intended for one-time setup on developer machine.

### Files Created
- `~/.agentic-framework/` (clone directory, default via `INSTALL_DIR`)
- `/usr/local/bin/fw` OR `~/.local/bin/fw` (symlink)
- Git config: `core.fileMode=false` (macOS HFS+ compatibility)

### Dependencies Checked
- `bash 4.4+` (version string parsed from `--version`)
- `git 2.20+` (version string parsed, checks executable exists)
- `python3 3.8+` (just checks executable exists, NO version check on system python3)
- `PyYAML` (Python module import check)
- Write perms on symlink target

### Platform-Specific Branches
- **macOS**: Handles `core.fileMode false` for HFS+/APFS (line 83-106)
- **Linux**: No special handling (assumes ext4 or similar)
- Symlink strategy: `/usr/local/bin` (needs sudo) → `sudo ln -sf` → fallback `~/.local/bin` with PATH warning

### Update Path (Existing Install Detection)
- Lines 79-108: Checks if `$INSTALL_DIR/.git` exists
- If yes: `git fetch + git reset --hard origin/$BRANCH` (hard reset, matches origin exactly)
- Detects hash mismatch, prints "Updated X → Y"
- **Critical seam:** Hard reset means local changes in framework dir are LOST (but intentional — framework install dir is not user code)

### What Can Fail
1. **Bash < 4.4** — Detection works, error message clear, no fallback
2. **git not found** — Detection works, error message clear
3. **python3 not found** — Detection works BUT no version check (could be 2.7)
4. **PyYAML missing** — Detection works (Python import), suggests `pip install`
5. **No write perms** → symlink fails silently (ln -sf returns 0 even if target not writable on some systems)
6. **PATH lookup fails** → fw not in PATH after symlink; install.sh suggests `source ~/.bashrc` (line 146)
7. **fw doctor runs but framework incomplete** → doctor output shown but not blocking (line 144: `|| true`)
8. **Homebrew Cellar case** — Not handled in install.sh (only handled in fw CLI line 49-60)

### Seam to Next Step
**Output**: `.agentic-framework/bin/fw` in PATH (or user must add to PATH)
**Input for fw init**: Must invoke `fw init /path/to/project`

---

## Step 2: INIT — `fw init` (via `lib/init.sh`, lines 7-418)

### What It Does
Bootstraps a project with framework structure: directories, seed files, config, git hooks. Two paths: greenfield vs existing-project (auto-detected).

### Directories Created (18 total)
- `.tasks/active` (in-progress tasks)
- `.tasks/completed` (archive)
- `.tasks/templates` (task blueprints)
- `.context/working` (session state, volatile)
- `.context/project` (patterns, decisions, learnings)
- `.context/episodic` (task histories)
- `.context/handovers` (session summaries)
- `.context/scans` (codebase scan results)
- `.context/bus/results` (sub-agent result manifests)
- `.context/bus/blobs` (large result payloads)
- `.context/audits/cron` (cron audit results)
- `.context/working/.gitignore` (volatiles list)

### Files Created (22 explicit #@init: tags, plus more)

| Type | File | Purpose |
|------|------|---------|
| YAML | `.framework.yaml` | Project config (name, fw path, version, provider) |
| YAML | `.context/bypass-log.yaml` | Git hook bypass log |
| YAML | `.context/project/practices.yaml` | Graduated learnings |
| YAML | `.context/project/decisions.yaml` | Architectural decisions |
| YAML | `.context/project/patterns.yaml` | Failure/success/workflow patterns |
| YAML | `.context/project/learnings.yaml` | Development learnings |
| YAML | `.context/project/assumptions.yaml` | Tracked assumptions |
| YAML | `.context/project/directives.yaml` | Constitutional directives (D1-D4) |
| YAML | `.context/project/concerns.yaml` | Unified gaps + risks register |
| Markdown | `CLAUDE.md` | AI agent instructions (claude provider only) |
| JSON | `.claude/settings.json` | Claude Code hooks (11 hooks configured) |
| Markdown | `.claude/commands/resume.md` | /resume skill implementation |
| Markdown | `.cursorrules` | Cursor IDE rules (cursor provider only) |
| Tasks | `.tasks/templates/default.md` | Default task template (copied from framework) |
| Tasks | `.tasks/active/T-00X-*.md` | Onboarding tasks (5-6 greenfield, 6-7 existing-project) |

### Seed File Detection & Copying
- Lines 192-201: `practices.yaml` from `lib/seeds/` or generated inline
- Lines 205-214: `decisions.yaml` from `lib/seeds/` or generated inline
- Lines 217-231: `patterns.yaml` from `lib/seeds/` or generated inline
- Lines 146-150: Task templates from `FRAMEWORK_ROOT/.tasks/templates/*.md`
- Lines 383-408: Onboarding tasks from `lib/seeds/tasks/{greenfield,existing-project}/T-*.md` with variable substitution

### Greenfield vs Existing-Project Detection
Lines 358-381: Checks for presence of:
- Manifest files: `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `setup.py`
- Source directories: `src/`, `lib/`, `app/`
- If found: seed from `lib/seeds/tasks/existing-project/`
- If not: seed from `lib/seeds/tasks/greenfield/`

### Force Mode
Lines 10, 18, 29, 62-66: `--force` flag allows reinit and overwriting existing files.
Lines 191, 205, 219, 235, 246, 256: Each seed file checks `[ ! -f "$target" ] || [ "${force}" = true ]`

### Provider Config Generation
Lines 300-332:
- **claude**: Generates `CLAUDE.md` + `.claude/settings.json` + `.claude/commands/resume.md`
- **cursor**: Generates `.cursorrules`
- **generic**: Same as claude (safest default)

### Validation & Post-Init Activation
Lines 335-410:
1. **Preflight check** (lines 73-81): `lib/preflight.sh --quiet` (non-blocking, warns only)
2. **Validate-init** (lines 338-345): `lib/validate-init.sh` checks all 22+ init artifacts exist + are non-empty
3. **Context init** (lines 347-355): `agents/context/context.sh init` activates governance (creates `.context/working/session.yaml`, `.context/working/focus.yaml`)
4. **Task seeding** (lines 357-409): Copy onboarding tasks with variable substitution (__PROJECT_NAME__, __DATE__)

### What Can Fail

**Seam 2a: Preflight → Init**
- Missing bash/git/python3/PyYAML → init aborts (preflight --quiet returns 1)
- No write perms → init can't create directories

**Seam 2b: Preflight succeeds, validate-init fails**
- Seed files missing from framework (lib/seeds/*.yaml not found) → init generates fallback inline
- Template copy fails → warning printed, continues (line 152)
- Task seed copy fails (wrong path) → silently skipped (no task count increment)
- Validate-init detects missing dirs/files → warnings printed but not blocking (lines 343-344)

**Seam 2c: Validate-init succeeds, context init fails**
- `agents/context/context.sh init` crashes → warning printed (line 354), init completes anyway
- Session context files not created → next `fw` command will reinitialize (line 352)

**Critical: First-Run Onboarding Tasks Not Blocked**
- Tasks are created but `fw` doesn't force user to read them (lines 357-409 just print count)
- User can run `fw doctor` or `fw serve` next without looking at tasks
- **Gap:** No "read onboarding tasks first" gate

---

## Step 2.5: SEAM — Preflight ↔ Validate-Init ↔ Init Success

### The Seam: Unclear Success State
After `fw init` completes:
- User sees "Done! All commands: fw help" (line 413)
- But they DON'T know:
  - Is project actually ready? (maybe validate-init failed silently)
  - What's the first task? (onboarding tasks exist but weren't promoted)
  - Did all hooks install? (preflight only warns)
  - Is there a working `.framework.yaml`? (init creates it but doesn't verify it was read)

### Testing Status: ⚠ PARTIALLY TESTED
- **Unit**: No BATS tests for init.sh itself
- **Integration**: No smoke test that `fw init` → `fw doctor` → `fw serve` works end-to-end
- **Manual**: Has been tested many times in practice; known issue (T-303 preflight added mid-project)

---

## Step 3: PREFLIGHT & VALIDATE-INIT (lib/preflight.sh, lib/validate-init.sh)

### Preflight (lib/preflight.sh, lines 1-249)

**Required Checks:**
- bash >= 4.4 (extracts version, parses major version)
- git >= 2.0 (extracts version, parses major version)
- python3 >= 3.8 (uses subprocess to get version)
- PyYAML (Python import check)
- Write perms on target dir

**Recommended Checks:**
- git identity (name + email configured)
- shellcheck (for fw doctor linting)

**Exit Code:**
- 0 = all checks passed
- 1 = ≥1 required check failed

**Modes:**
- Interactive: Presents results + offers to install missing deps (not implemented yet, all paths use --quiet)
- `--quiet`: Silent mode, only prints failures (lines 207-218)
- `--check-only`: Returns 0/1 without suggestions (lines 27-29)

**What Can Fail:**
1. **Bash detection**: Reads from `$PATH` (not running shell) — may find old bash on macOS
2. **Python version check**: Spawns subprocess — slow, not cached
3. **PyYAML check**: Spawns Python import — fails if pip perms wrong
4. **Write perms**: Checks `[ -w "$target" ]` — doesn't check subdirs (may be RO later)
5. **Package manager detection**: Tries apt, brew, dnf, pacman — skips if none found (no error)

### Validate-Init (lib/validate-init.sh, lines 1-240+)

**Validates 22 Init Artifacts:**
- 11 directories exist (check_type: `dir`)
- 7 files exist + non-empty (check_type: `file`)
- 2 YAML files parse (check_type: `yaml`) [uses python3 -c "import yaml; yaml.safe_load(...)"]
- 1 JSON file parses (check_type: `json`)
- 1 executable check (check_type: `exec`)
- Hook paths resolve (check_type: `hookpaths`)

**Tag Parsing:**
- Extracts `#@init: type-key path [args] [?condition]` from init.sh (line 64)
- Skips if condition doesn't match (provider, git-only, etc)
- Runs check, prints result with color

**What Can Fail:**
1. **Python missing** — YAML/JSON checks skipped (lines 57-58)
2. **Parse errors not shown** — validation runs YAML parse but error output suppressed (stderr → /dev/null)
3. **Hook path resolution** — checks if paths in .claude/settings.json resolve to executable scripts; if not found, warns but continues
4. **Stale conditions** — if init.sh has old tags but validate-init doesn't understand them, validation silently skips them

### Testing Status: ✗ UNTESTED
- **Unit**: Zero BATS tests for preflight.sh or validate-init.sh
- **Integration**: Not tested as part of init flow
- **Manual**: Only validated by eye; known issues (T-303 was gap closure, T-461 was refactor)

---

## Step 4: DOCTOR — `fw doctor` (bin/fw, lines 338-457)

### What It Checks (9 checks)

1. **Framework installation** (lines 345-351)
   - Checks: `$FRAMEWORK_ROOT/agents/` exists + `FRAMEWORK.md` present
   - Fail: "missing agents/ or FRAMEWORK.md"

2. **.framework.yaml** (lines 353-369)
   - Only checked if `PROJECT_ROOT != FRAMEWORK_ROOT` (shared tooling mode)
   - Checks: file exists + version matches
   - Warn: version mismatch (pinned vs installed)

3. **Task directories** (lines 371-377)
   - Checks: `.tasks/active` + `.tasks/completed` exist
   - Fail: "missing directories"

4. **Context directory** (lines 379-385)
   - Checks: `.context/` exists
   - Warn: if missing (not fatal — created by context init)

5. **Git hooks** (lines 387-401)
   - commit-msg hook: checks file exists + contains "Task Reference"
   - pre-push hook: checks file exists + contains "audit"
   - Warn: if not installed (user can run `fw git install-hooks`)

6. **Tier 0 enforcement hook** (lines 403-415)
   - Checks: `.claude/settings.json` contains "check-tier0.sh" reference
   - Checks: `agents/context/check-tier0.sh` is executable
   - Warn: if not configured or not executable

7. **Agent scripts** (lines 417-428)
   - Checks: 7 agents executable (audit, context, git, handover, healing, resume, task-create)
   - Fail: if any agent not executable

8. **Plugin task-awareness** (lines 430-442)
   - Calls `agents/audit/plugin-audit.sh --doctor-check` (if exists)
   - Returns bypass count
   - Warn: if skills bypass task-first rule

9. **Test infrastructure** (lines 444-457)
   - Checks: bats installed + unit tests present
   - Warn: if bats missing or no tests found

### Exit Code
- 0 = all checks passed
- 1 = ≥1 check failed
- (Actually always 0 because all failures are counted but not returned — **BUG**)

### What Can Fail
1. **Framework symlink broken** — fw resolves correctly (lines 26-28) but checks may use wrong FRAMEWORK_ROOT
2. **Agent perms lost** → doctor fails (agents not executable)
3. **Version mismatch detected** → warns but allows continue
4. **Tests not found** → warns but allows continue
5. **bats not installed** → warns (expected for fresh installs)

### Testing Status: ⚠ PARTIALLY TESTED
- **Unit**: Zero BATS tests for fw doctor itself
- **Integration**: Not tested; T-295 and T-299 were bug fixes suggesting limited test coverage
- **Manual**: Part of install.sh (line 144: `fw doctor || true`)

---

## Step 5: SERVE — `fw serve` / `bin/watchtower.sh start` (lines 1-288)

### What It Does
Starts Flask web app on configurable port (default 3000) with health check loop.

### Files Created
- `.context/working/watchtower.pid` (PID file)
- `.context/working/watchtower.log` (startup/error log)

### Dependencies
- Flask installed (checked line 128: `python3 -c "import flask"`)
- Port available (lines 135-155: try to free it with fuser -k)
- No other process on port (checked via `ss -tlnp`)

### Startup Sequence
1. Check Flask installed (line 128)
2. Check port available; if in use, send TERM × 3 then KILL (lines 135-155)
3. Start: `cd $FRAMEWORK_ROOT && PROJECT_ROOT="$PROJECT_ROOT" python3 -m web.app --port $port` (line 165)
4. Save PID to file (line 167)
5. **Health check loop**: 5 iterations, 1s sleep each (lines 169-198)
   - Check process alive: `kill -0 $pid` (line 176)
   - Check HTTP response: `curl -sf http://localhost:$port/` (line 184)
   - If both OK: return success (line 196)
   - If HTTP fails after 5s: warn but DON'T fail (lines 201-203)

### What Can Fail

**Early Fails (exit 1):**
1. Flask not installed (line 128-131)
2. Port still in use after 3 TERM/KILL attempts (line 150-152)
3. Process exits immediately → health check detects (line 176-180)

**Late Fails (warns but returns 0):**
4. HTTP not responding after 5s → print warning (lines 201-203), but return 0 (implicit)
5. Python import errors → process exits, caught by kill -0 check
6. Missing FRAMEWORK_ROOT → Flask app.py fails to import, process exits

### Smoke Test (web/smoke_test.py)

**What it tests:** 
- Discovers all 69 Flask routes via url_map (lines 42-60)
- Skips: parameterized routes, static routes, streaming routes
- Tests each route for HTTP 200 (or 400-499 if expected)
- Validates content markers on 10 critical routes (lines 25-36):
  - `/` contains "Watchtower"
  - `/tasks` contains "Tasks"
  - `/search` contains "Search"
  - `/fabric` contains "Component Fabric"
  - `/quality` contains "Quality"
  - `/settings/` contains "Settings"
  - `/directives` contains "Directives"
  - `/enforcement` contains "Enforcement"
  - `/metrics` contains "Metrics"
  - `/health` contains `"app"`

**Exit Code:** 0 if all passed, 1 if any failed

**Two Modes:**
- `--port 3000` (default): HTTP test against running server
- `--test-client`: Use Flask test client (no server needed)

### Testing Status: ⚠ PARTIALLY TESTED
- **Unit**: Zero BATS tests for watchtower.sh
- **Integration**: smoke_test.py exists but not called from CI
- **Manual**: Developers run `fw serve` locally; not validated in CI

---

## Step 6: SEAM — Doctor → Serve Integration

### The Gap
After `fw doctor` completes successfully:
- User still doesn't know if Watchtower can start
- doctor doesn't call `fw serve` to validate Flask
- No check that `.context/` was created by context init
- No check that Flask dependencies installed (Flask is only checked in watchtower.sh)

### What's Missing
- `fw doctor` should run `fw serve --test-client --test` to validate web UI startup
- smoke_test.py should be called as part of `fw doctor`
- doctor should check Flask + Jinja2 + Markdown packages installed

---

## Failure Point Inventory

| Step | Substep | Failure Mode | Detection | Test Status |
|------|---------|--------------|-----------|-------------|
| 1 | Install | Bash < 4.4 | install.sh checks | ✓ tested |
| 1 | Install | git not found | install.sh checks | ✓ tested |
| 1 | Install | python3 not found | install.sh checks | ✓ tested |
| 1 | Install | PyYAML missing | install.sh checks | ✓ tested |
| 1 | Install | fw not in PATH | User needs to source bashrc | ⚠ manual only |
| 1 | Install | symlink fails (no sudo) | Silent (ln -sf may succeed even if can't write) | ✗ untested |
| 2 | Init | Missing seed files | init.sh generates fallback | ⚠ partial |
| 2 | Init | Onboarding tasks not read | No gate, tasks just created | ✗ untested |
| 2.5 | Seam | Context init fails | Warning printed, init completes | ✗ untested |
| 3 | Preflight | Old bash found in PATH | Checked against $PATH, not running shell | ⚠ edge case |
| 3 | Preflight | Python version slow to detect | Spawns subprocess | ⚠ performance |
| 3 | Validate-init | Parse errors suppressed | stderr redirected to /dev/null | ✗ untested |
| 3 | Validate-init | Hook paths not resolved | Validator skips missing hooks | ✗ untested |
| 4 | Doctor | Exit code always 0 | Failures counted but not returned | ✗ critical bug |
| 4 | Doctor | Flask dependency not checked | Only checked in watchtower.sh | ✗ untested |
| 5 | Serve | Flask import fails | Process exits, health check fails (after 5s) | ⚠ slow |
| 5 | Serve | Jinja2 missing | Flask starts, template render fails on first route | ✗ untested |
| 5.5 | Seam | doctor → serve not linked | doctor completes, user manually runs serve | ✗ untested |

---

## Critical Integration Seams (Most Likely Failure Sites)

1. **Install → Init (PATH issue)**
   - After install, fw may not be in PATH
   - User must manually edit shell config
   - No validation that symlink works before exiting
   - **Fix needed:** Try `fw --version` after symlinking; if not in PATH, give explicit export command

2. **Preflight → Init Success (silent validation failures)**
   - init.sh calls preflight --quiet (non-blocking)
   - If preflight fails, init continues anyway
   - User sees "Done!" but may not have git/python3 in context
   - **Fix needed:** Preflight should be blocking in init, or init should check result code

3. **Init → Context Init (governance activation fails silently)**
   - If context init fails (line 352), init continues
   - User's `.context/working/` may be empty
   - Next `fw` command will try to reinitialize
   - **Fix needed:** Make context init blocking; fail init if it fails

4. **Validate-Init → Doctor (no hand-off)**
   - validate-init runs at end of init (lines 340-345)
   - But doctor doesn't know validation already ran
   - doctor re-checks everything (some checks are duplicative)
   - **Fix needed:** Write validation results to `.context/working/init-validated.json`; doctor reads it

5. **Doctor → Serve (web stack not validated)**
   - doctor checks Flask import (NO — it doesn't)
   - watchtower.sh checks Flask import (YES — line 128)
   - If Flask missing, doctor passes, serve fails
   - **Fix needed:** doctor should call smoke_test.py --test-client

---

## Recommendations for T-489 Spike 1

### High Priority (Integration)
1. **Create end-to-end test**: `fw init /tmp/test-proj && fw doctor && fw serve --test-client`
2. **Fix doctor exit code**: Failures should return 1, not 0
3. **Link doctor → smoke test**: doctor should validate web stack (or move smoke test to doctor)
4. **Make preflight blocking in init**: If required deps missing, init should fail

### Medium Priority (Validation)
5. **Create init.bats tests**: Validate all 22 artifacts created correctly
6. **Create preflight.bats tests**: Test all check functions (bash, git, python3, pyyaml)
7. **Create validate-init.bats tests**: Test tag parsing + condition logic
8. **Enhance validate-init**: Show parse errors (don't suppress stderr)

### Low Priority (UX)
9. **Test symlink writability**: install.sh should verify symlink works before exiting
10. **Promote onboarding tasks**: After init, print "Run: fw work-on T-001" to surface first task
11. **Create handover on init**: Generate `.context/handovers/init-success.md` with next steps

---

## Files Referenced

| File | Type | Lines | Purpose |
|------|------|-------|---------|
| `install.sh` | Bash | 1-197 | Install script |
| `lib/init.sh` | Bash | 7-418 | Project initialization |
| `lib/preflight.sh` | Bash | 1-249 | Dependency checking |
| `lib/validate-init.sh` | Bash | 1-240+ | Init artifact validation |
| `bin/fw` | Bash | 338-457 | doctor command |
| `bin/watchtower.sh` | Bash | 1-288 | Web server startup |
| `web/smoke_test.py` | Python | 1-197 | Route + content validation |
| `web/app.py` | Python | (not read) | Flask app |

---

## Test Coverage Summary

| Component | Unit | Integration | Manual | Status |
|-----------|------|-------------|--------|--------|
| install.sh | ✗ | ✗ | ✓ | ⚠ partial |
| fw init | ✗ | ✗ | ✓ | ⚠ partial |
| preflight.sh | ✗ | ✗ | ✓ | ⚠ partial |
| validate-init.sh | ✗ | ✗ | ✓ | ⚠ partial |
| fw doctor | ✗ | ✗ | ✓ | ⚠ partial |
| watchtower.sh | ✗ | ✗ | ✓ | ⚠ partial |
| smoke_test.py | ✗ | ✗ | ✓ | ⚠ partial |
| **End-to-end path** | ✗ | ✗ | ✓ | **✗ untested** |

---

## Key Insights

1. **No end-to-end testing**: Developers run each step manually; automation tests exist only for individual commands (git, context, healing)
2. **Silent failures**: Validation runs but doesn't block (preflight --quiet, validate-init warnings only, doctor exit code bug)
3. **Integration gaps**: doctor doesn't know what validate-init did; doctor doesn't test web stack; smoke_test.py not called from anywhere
4. **Seam vulnerabilities**: PATH issues, context init failure, Flask missing — all have partial/missing detection
5. **Documentation gap**: No single artifact listing what needs to be true after each step (would catch silent failures)

