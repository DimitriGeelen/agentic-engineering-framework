# T-662: Eliminate Global HOME/.agentic-framework Dependency

**Status:** Research complete — GO recommendation
**Created:** 2026-03-28
**Task:** T-662 (Inception)

## Problem

The framework depends on `$HOME/.agentic-framework/` — a global install created by `install.sh`. Claude Code hooks resolve bare `fw` via PATH to this global copy. When the global copy goes stale, all Bash/Write/Edit operations deadlock (3+ incidents documented in T-625).

T-660 made the problem worse by syncing MORE files to the global install during `fw upgrade`, reinforcing the dependency instead of eliminating it. The correct fix is architectural: remove the need for the global install entirely.

## Spikes

### Spike 1: Hook Resolution Audit

**Question:** Which hooks use bare `fw` vs relative paths? Does Claude Code set CWD to project root?

**Findings:**

**Framework project** (`.claude/settings.json`): ALL 13 hooks use bare `fw` (PATH-dependent).
Examples: `fw hook check-active-task`, `fw hook budget-gate`, `fw hook pre-compact`.

**Consumer projects** (7 checked): ALL hooks use vendored relative path `.agentic-framework/bin/fw hook <name>`.
Examples: `.agentic-framework/bin/fw hook check-active-task`, `.agentic-framework/bin/fw hook budget-gate`.

**Critical divergence:** The framework project is the ONLY project using bare `fw` — every consumer already uses project-relative paths.

**A1 validation (CWD = project root):** Strongly supported. Consumer hooks use `.agentic-framework/bin/fw` (relative path) and they work in practice. `bin/fw` uses `find_project_root()` walking up from `$PWD`. If CWD were not project root, all consumer hook relative paths would fail with "command not found". Not explicitly documented by Claude Code, but reliably observed.

### Spike 2: Internal fw Calls Audit

**Question:** Which hook scripts internally call `fw` or `bin/fw`? Can all use `$FRAMEWORK_ROOT/bin/fw`?

**Findings:**

**Zero PATH-dependent bare `fw` calls in any shell script.** All 7 actual invocations already use `$FRAMEWORK_ROOT/bin/fw`:

| File | Call |
|------|------|
| `agents/audit/audit.sh` | `"$FRAMEWORK_ROOT/bin/fw" promote suggest` |
| `agents/onboarding-test/test-onboarding.sh` | `"$FRAMEWORK_ROOT/bin/fw" init` |
| `agents/onboarding-test/test-onboarding.sh` | `"$FRAMEWORK_ROOT/bin/fw" work-on` |
| `lib/upstream.sh` | `"$FRAMEWORK_ROOT/bin/fw" doctor` |
| `lib/update.sh` (x2) | `"$FRAMEWORK_ROOT/bin/fw" doctor` |
| `lib/setup.sh` | `"$FRAMEWORK_ROOT/bin/fw" doctor` |

References in `lib/init.sh` are template strings written to `settings.json` (not executed by the framework).

**Conclusion:** Internal calls are already fully path-qualified. No migration needed.

### Spike 3: Vendored fw Path Feasibility

**Question:** Can hook commands use `.agentic-framework/bin/fw` for consumers and `bin/fw` for framework?

**Findings:**

**Consumer vendored fw works correctly.** When `.agentic-framework/bin/fw` is called from CWD = project root:
- `readlink -f` resolves to `/opt/<consumer>/.agentic-framework/bin/fw`
- `FW_BIN_DIR/../` = `/opt/<consumer>/.agentic-framework/`
- That directory has `FRAMEWORK.md` + `agents/` → `resolve_framework()` case 1 matches
- `FRAMEWORK_ROOT` = `/opt/<consumer>/.agentic-framework/` (correct)
- `PROJECT_ROOT` = `/opt/<consumer>/` (found via `find_project_root()`)

**Framework repo `bin/fw` works correctly too.** When `bin/fw` is called from CWD = framework root:
- `readlink -f` resolves to `/opt/999-Agentic-Engineering-Framework/bin/fw`
- `FW_BIN_DIR/../` = `/opt/999-Agentic-Engineering-Framework/`
- Has `FRAMEWORK.md` + `agents/` → case 1 matches
- `FRAMEWORK_ROOT` = `PROJECT_ROOT` = `/opt/999-Agentic-Engineering-Framework/`

**`fw upgrade` handles new hooks.** Step 5 compares hook types and regenerates `settings.json` if any are missing.

**One gap:** The stale-path check doesn't flag bare `fw hook ...` as stale (it extracts the hook name the same way from both `fw hook X` and `.agentic-framework/bin/fw hook X`). A consumer that somehow has bare `fw` commands won't be auto-migrated.

### Spike 4: install.sh Deprecation Path

**Question:** What breaks if `install.sh` stops creating `$HOME/.agentic-framework/`?

**Findings:**

Current `install.sh` behavior:
1. Clones framework repo to `$HOME/.agentic-framework/` (full git repo)
2. Creates symlinks: `~/.local/bin/fw` → `~/.agentic-framework/bin/fw`
3. Creates symlinks: `~/.local/bin/claude-fw` → `~/.agentic-framework/bin/claude-fw`

**What breaks without global install:**
- `~/.local/bin/fw` symlink target doesn't exist → bare `fw` command fails
- `~/.local/bin/claude-fw` symlink target doesn't exist → `claude-fw` wrapper fails
- Users who type `fw` from any directory get "command not found"

**What does NOT break:**
- Consumer project hooks (already use `.agentic-framework/bin/fw`)
- Framework repo hooks (need migration from bare `fw` to `bin/fw`, but this is the framework project fix)
- Internal script invocations (all use `$FRAMEWORK_ROOT/bin/fw`)

**Deprecation path:** Replace the global clone with a lightweight shim (see Spike 5).

### Spike 5: Terminal UX Impact

**Question:** Without a global install, how does user type `fw` from any directory?

**Findings:**

**Option A: Project-detecting shim** (recommended)
Replace `~/.local/bin/fw` symlink with a ~20-line bash script that:
1. Walks up from CWD looking for `.agentic-framework/bin/fw` or `bin/fw` (in framework repo)
2. If found, `exec`s the project-local `fw` with all args
3. If not found, prints "No framework project detected in this directory tree"

```bash
#!/bin/bash
# fw shim — routes to project-local fw (no global install needed)
dir="$PWD"
while [ "$dir" != "/" ]; do
    if [ -x "$dir/.agentic-framework/bin/fw" ]; then
        exec "$dir/.agentic-framework/bin/fw" "$@"
    elif [ -x "$dir/bin/fw" ] && [ -f "$dir/FRAMEWORK.md" ]; then
        exec "$dir/bin/fw" "$@"
    fi
    dir="$(dirname "$dir")"
done
echo "No framework project detected. Run from a project directory." >&2
exit 1
```

Advantages: no global install, D4-compliant, always uses project-local code, survives version differences between projects.

**Option B: Shell alias/function** — Same logic but defined in `.bashrc`/`.zshrc`. Less portable (doesn't work in scripts, subshells may not inherit).

**Option C: Symlink to specific repo** — `~/.local/bin/fw` → `/opt/999-Agentic-Engineering-Framework/bin/fw`. Simple but ties all projects to one framework version. Better than global install but not as clean as Option A.

**Option D: No global `fw`** — Users always type `bin/fw` or `.agentic-framework/bin/fw`. Cleanest isolation but worst terminal UX.

**Recommendation: Option A.** The shim is tiny, has zero dependencies, and perfectly implements project isolation — every `fw` invocation runs the code from the project you're standing in.

### Spike 6: T-660 Revert Assessment

**Question:** What's the safest way to handle T-660? Revert, keep as bridge, or deprecate?

**Findings:**

T-660 added ~30 lines to `lib/upgrade.sh` (step 4c) that sync `bin/fw`, `lib/*.sh`, and `agents/context/*.sh` to `$HOME/.agentic-framework/`.

**Option 1: Revert entirely** — Safe. T-660's changes are isolated to step 4c in `lib/upgrade.sh`. Removing them doesn't affect any other upgrade step. Risk: if users still have bare `fw` in PATH pointing to stale global install, they'll get stale behavior again until they switch to the shim.

**Option 2: Keep as bridge with deprecation** — The sync code stays but prints a deprecation warning: "Global install at $HOME/.agentic-framework is deprecated. Run `fw install --shim` to switch to project-local resolution." Remove in next minor version.

**Option 3: Replace with shim migration** — Instead of syncing files, step 4c checks if `~/.local/bin/fw` is a symlink to the global install and offers to replace it with the shim. One-time migration that eliminates the dependency.

**Recommendation: Option 3** — replace-with-shim during upgrade. This:
- Migrates users automatically during their next `fw upgrade`
- Doesn't break anyone (shim is backward-compatible)
- Eliminates the global install in one step
- The global dir can be left in place (harmless) or cleaned up

## Assumptions

| ID | Assumption | Status | Evidence |
|----|-----------|--------|----------|
| A1 | Claude Code hooks run from CWD = project root | **Validated** | Consumer relative paths (`.agentic-framework/bin/fw`) work in production. `find_project_root()` walks up from `$PWD`. |
| A2 | Consumer hooks can use `.agentic-framework/bin/fw` | **Validated** | All 7 consumer projects already use this format. Confirmed working. |
| A3 | Framework repo can use `bin/fw` directly | **Validated** | `bin/fw` self-resolves via `readlink -f` + `resolve_framework()` case 1. |
| A4 | `install.sh` can stop creating global install | **Validated** | Only symlinks in `~/.local/bin/` depend on it. Replaced by shim = no breakage. |
| A5 | Removing global install doesn't break terminal usage | **Validated** | Shim preserves `fw` command from any directory, routes to project-local code. |
| A6 | Cross-machine PATH resolution may complicate this | **Not applicable** | Shim uses CWD-based detection, not PATH. Works identically on any platform. |

## Recommendation: GO

**Approach: Project-detecting shim + framework self-migration**

### Phase 1: Framework project fix (immediate)
1. Change framework's `.claude/settings.json` hooks from bare `fw` to `bin/fw`
2. Commit and verify hooks still work

### Phase 2: Shim creation
1. Create `bin/fw-shim` — the project-detecting shim (~20 lines)
2. Add `fw install --shim` command to install/replace the shim
3. Add to `install.sh` as the new default (replace clone-to-HOME)

### Phase 3: Upgrade migration
1. Modify step 4c in `lib/upgrade.sh` to replace global symlinks with shim
2. Print one-time migration notice
3. Keep T-660 sync code as fallback for users who haven't upgraded yet
4. Remove T-660 sync code in next minor version

### Phase 4: Cleanup
1. `install.sh` no longer clones to `$HOME/.agentic-framework/`
2. `fw doctor` warns if stale global install exists
3. `fw clean --global` command to remove `$HOME/.agentic-framework/`

### Migration path
- **Existing users:** `fw upgrade` auto-migrates (Phase 3)
- **New users:** `install.sh` installs shim directly (Phase 2)
- **Homebrew users:** Formula already installs to Cellar, no global install involved
- **Framework repo developers:** Phase 1 fix + shim for terminal `fw`

### Risk assessment
- **Low risk:** Consumer projects already work with vendored paths
- **Low risk:** Internal scripts already use `$FRAMEWORK_ROOT/bin/fw`
- **Medium risk:** Framework's own hooks need testing after switching from bare `fw` to `bin/fw`
- **Low risk:** Shim is backward-compatible (if it finds a project, it works; if not, clear error)

## Dialogue Log

### 2026-03-28 — User raises portability concern about T-660
- **User:** "why are we writing to a directory under $HOME, should the engineering project not be isolated to its own folder... adding files to home would violate portability right?"
- **Agent:** Reflected and agreed — T-660 reinforced the wrong pattern by syncing more files to the global install
- **Outcome:** Created T-662 inception with 6 spikes, user directed "inception first, deep, no action yet, horizon now"

### 2026-03-28 — Spike research (session 2)
- 3 parallel agents (Spikes 1-3) + manual research (Spikes 4-6)
- Key finding: framework project is the ONLY project using bare `fw` — every consumer already uses project-relative paths
- Key finding: zero internal PATH-dependent `fw` calls exist
- Key finding: `bin/fw` has `readlink -f` which defeats symlinks — the shim must `exec` the project-local fw, not symlink to it
- **Outcome:** All assumptions validated. GO recommendation with 4-phase plan.
