# T-878: Global Install Sync Violates Project Isolation

## Research Artifact (C-001)

**Task:** T-878
**Created:** 2026-04-05
**Status:** Complete

---

## Problem

`fw upgrade` step 4c ("Shim migration + global install sync") syncs files from the framework repo to `$HOME/.agentic-framework/`:
- `bin/fw` (CLI entry point)
- `lib/*.sh` (all subcommand implementations)
- `agents/context/*.sh` (context agent scripts)
- `agents/context/lib/*` (context agent libraries)

This directly contradicts T-662's GO decision to **eliminate** the global install dependency. T-662 established the shim pattern (`~/.local/bin/fw` is a project-detecting script, not a symlink), which makes the global install unnecessary. Yet the sync still runs on every upgrade.

**The contradiction:** Line 469 says "no global install dependency" and then line 480 immediately syncs to the global install.

## Investigation

### What the sync code does (lib/upgrade.sh:480-558)

The sync is guarded by `if [ -d "$global_dir/agents/context" ]` — it only runs if the global install directory exists and has agent content. On this machine:

```
/root/.agentic-framework/ exists — still has old framework docs (001-Vision.md, etc.)
/root/.agentic-framework/agents/context/ — would trigger sync
```

The sync copies:
1. `bin/fw` → `~/.agentic-framework/bin/fw`
2. `lib/*.sh` → `~/.agentic-framework/lib/`
3. `agents/context/*.sh` → `~/.agentic-framework/agents/context/`
4. `agents/context/lib/*` → `~/.agentic-framework/agents/context/lib/`

### Why it was added (T-660)

T-660 added the sync as a **bridge measure** — users who still had the global install would get stale-script deadlocks if the global copy diverged from the project copy. The sync was a pragmatic fix for the symptom: keep global in sync until the global install is deprecated.

### Why it should be removed

1. **T-662 solved the root cause.** The shim pattern means `fw` typed from any directory resolves to the correct project's framework. The global install is no longer needed for PATH resolution.

2. **The sync creates a false sense of correctness.** By keeping the global install "up to date," it masks the fact that the global install should not exist. Users don't realize they have a redundant copy.

3. **It writes outside PROJECT_ROOT.** The framework's own governance says "never edit files outside PROJECT_ROOT." Step 4c writes to `$HOME/.agentic-framework/` which is definitionally outside any project.

4. **Multiple framework versions compound.** If projects A and B run different framework versions, whichever upgrades last wins the global install. This is exactly the problem vendoring was designed to avoid.

### Current state on this machine

- `~/.agentic-framework/` — exists, contains old docs, bin/, lib/, agents/
- `~/.local/bin/fw` — shim script (project-detecting), works correctly
- All 11 consumer projects — vendored `.agentic-framework/bin/fw`
- **The global install is unused but still receives sync updates.**

## Options

### Option A: Remove sync, keep global install (minimal change)
- Delete lines 480-558 of `lib/upgrade.sh` (the sync block)
- `~/.agentic-framework/` still exists but becomes stale over time
- No breakage — the shim doesn't use the global install
- **Risk:** Stale global install confuses users who manually `cd ~/.agentic-framework && bin/fw`

### Option B: Remove sync + deprecation warning (recommended)
- Delete the sync block
- Add deprecation notice: "~/.agentic-framework/ is no longer maintained. The framework is vendored per-project."
- `fw doctor` flags the global install as "deprecated, can be removed"
- **Risk:** None — the shim handles PATH resolution

### Option C: Remove sync + auto-clean
- Delete the sync block
- Add `fw cleanup` or `fw doctor --fix` that removes `~/.agentic-framework/`
- Most aggressive but cleanest end-state
- **Risk:** Users who have custom modifications in `~/.agentic-framework/` lose them

## Recommendation

**GO — Option B** (remove sync + deprecation warning)

### Rationale
1. T-662 decided GO on eliminating global dependency — this is the logical follow-through
2. The sync is actively counterproductive: it maintains a copy that nothing uses
3. The shim (`~/.local/bin/fw`) already handles the terminal UX concern
4. Adding a `fw doctor` warning gives users visibility without forcing action
5. Small, bounded change — delete 80 lines of sync code, add 5 lines of deprecation warning

### Evidence
- `~/.local/bin/fw` is a shim script (confirmed: `file` reports Bourne-Again shell script)
- All 11 consumer projects have vendored `.agentic-framework/bin/fw`
- `fw` from any directory resolves correctly via the shim
- The global install sync writes to 4 directories outside PROJECT_ROOT

### Suggested Build Tasks
| Task | Scope | Effort |
|------|-------|--------|
| B-1 | Remove sync block from `lib/upgrade.sh` | Small |
| B-2 | Add `fw doctor` deprecation warning for `~/.agentic-framework/` | Small |
| B-3 | Update CLAUDE.md to document the shim pattern | Small |

## Dialogue Log

User reported: "fw upgrade step 4c syncs scripts to ~/.agentic-framework despite T-662 establishing project isolation. The INFO message says 'no global install dependency' but then immediately syncs to global." This observation is precise — the code literally says one thing and does the opposite on the next line.
