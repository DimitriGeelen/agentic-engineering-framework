# T-482: Install Model Inception — Full Isolation via Project-Local Vendoring

## Current State

### Topology

```
~/.agentic-framework/          ← Global install (174MB, 2897 files)
  bin/fw                       ← The CLI
  agents/, lib/, templates/    ← Framework code
  .tasks/, .context/, .fabric/ ← Framework's OWN governance data (not needed by consumers)
  .git/                        ← 81MB of git history

/usr/local/bin/fw → ~/.agentic-framework/bin/fw  (symlink)

Consumer projects:
  /opt/3021-Bilderkarte/  → framework_path: ~/.agentic-framework  (v1.2.6)
  /opt/001-sprechloop/    → framework_path: /opt/999-...          (v1.0.0!)
```

### Known problems (why full isolation is needed)

| Problem | Severity | Evidence |
|---------|----------|----------|
| Absolute paths in `.framework.yaml` | High | G-021 — breaks on clone/move |
| All projects forced to same version | Medium | Sprechloop at 1.0.0 while global at 1.2.6 |
| Global dirty state breaks all projects | High | T-496: manual `cp` needed to sync changes |
| 174MB global install bloat | Low | .git (81MB) + .context (83MB) = framework's own data |
| Cross-project bleeding | High | Human decision: "too much bleeding, accidents have taken place" |

## Decision: Option B — Project-Local Vendoring

Human directed: full isolation. No shared global runtime.

## Spike Results

### Spike 1: Vendorable file set

The minimum vendor set is **~1.2MB** (103 files):

| Directory | Size | Contents |
|-----------|------|----------|
| `bin/` | 112K | `fw` CLI, `watchtower.sh` |
| `lib/` | 272K | init, upgrade, paths, compat, yaml, etc. |
| `agents/` | 808K | All hooks, context, healing, handover, etc. |
| `.tasks/templates/` | 12K | `default.md`, `inception.md` |
| `lib/seeds/` | 28K | practices, patterns, decisions seeds |
| Top-level | ~20K | `FRAMEWORK.md`, `metrics.sh` |
| **Total** | **~1.2MB** | **103 files** |

**Not vendored (stays in global install only):**
- `.git/` (81MB) — git history
- `.context/` (83MB) — framework's own governance data
- `.tasks/active/`, `.tasks/completed/` — framework's own tasks
- `.fabric/` (648K) — framework's own component cards
- `docs/` (3.9MB) — framework documentation
- `watchtower/` — web UI (separate concern)
- `install.sh` — only needed for bootstrap

### Spike 2: Resolution model — nvm/rbenv shim pattern

```
User runs 'fw <cmd>'
  │
  ▼
Global fw (shim in PATH)
  │
  ├─ Walk up from cwd looking for .agentic-framework/bin/fw
  │
  ├─ FOUND → exec .agentic-framework/bin/fw <cmd>  (FULL ISOLATION)
  │
  └─ NOT FOUND → run global fw  (bootstrap only: init, help, version)
```

**Commands that work without local copy:** `fw init`, `fw version`, `fw help`
**Everything else:** delegates to project-local copy

**Hook resolution:** `fw hook <name>` in settings.json → global shim → detects local copy → delegates. Settings.json stays portable (just `fw hook <name>`, no paths).

### Spike 3: Project structure after vendor

```
my-project/
  .agentic-framework/       ← Vendored framework (1.2MB)
    bin/fw                   ← Local fw CLI
    lib/                     ← Runtime libraries
    agents/                  ← Hooks, context, healing, etc.
    .tasks/templates/        ← Task templates
    FRAMEWORK.md             ← Version marker
    VERSION                  ← Pinned version (e.g., "1.2.6")
  .tasks/                    ← Project's tasks
  .context/                  ← Project's context
  .claude/settings.json      ← Hooks call 'fw hook <name>'
  .framework.yaml            ← Simplified: just project_name, version, provider
  src/                       ← Project code
```

**`.framework.yaml` simplified** — no more `framework_path:` field. `fw` finds the framework from its own location.

### Spike 4: Multi-version scenario

```
Project A: .agentic-framework/ at v1.2.6
Project B: .agentic-framework/ at v1.3.0
Global fw: v1.3.0

cd /opt/project-a && fw doctor  → uses local v1.2.6 ✓
cd /opt/project-b && fw doctor  → uses local v1.3.0 ✓
fw init /opt/project-c          → uses global v1.3.0 (bootstrap) ✓
```

Zero version coupling between projects. Each project is a self-contained unit.

## Build Tasks

### Task 1: Global fw shim (local-first resolution)

Modify `bin/fw` to detect `.agentic-framework/bin/fw` in cwd ancestors. If found, `exec` into it.

~20 lines added to top of `bin/fw`, before any command routing.

```bash
# Local-first resolution: if project has vendored framework, use it
_local_fw=""
_search_dir="$PWD"
while [ "$_search_dir" != "/" ]; do
    if [ -x "$_search_dir/.agentic-framework/bin/fw" ] && \
       [ "$_search_dir/.agentic-framework/bin/fw" != "$FW_REAL_PATH" ]; then
        _local_fw="$_search_dir/.agentic-framework/bin/fw"
        break
    fi
    _search_dir="$(dirname "$_search_dir")"
done
if [ -n "$_local_fw" ]; then
    exec "$_local_fw" "$@"
fi
```

### Task 2: `fw vendor` command

New subcommand that vendors the framework into the current project.

```bash
fw vendor              # Copy framework into .agentic-framework/
fw vendor update       # Update vendored copy from global (or upstream)
fw vendor status       # Show vendored version vs latest available
```

Implementation:
- Copies minimum file set from global install to `.agentic-framework/`
- Creates `VERSION` file with current fw version
- Updates `.framework.yaml` to remove `framework_path`
- Adds `.agentic-framework/` to `.gitignore` (optional — user decides if they want to commit it)

### Task 3: Update `fw init` to auto-vendor

`fw init` gains `--vendor` flag (eventually default):
- Creates project structure as today
- Additionally vendors the framework locally
- `.framework.yaml` no longer needs `framework_path`

### Task 4: Migrate existing consumer projects

- `fw upgrade` detects global-dependent projects and offers `fw vendor` migration
- Bilderkarte and Sprechloop get vendored copies
- `.framework.yaml:framework_path` field becomes optional/deprecated

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Users forget to `fw vendor update` | `fw doctor` warns if vendored version is behind global |
| `.agentic-framework/` committed to git bloats repo | Default to `.gitignore`, user opts in to commit |
| Shim detection adds latency | Walk-up is <1ms (max ~10 stat() calls) |
| Existing projects break on transition | `fw upgrade` handles migration, old model still works as fallback |
