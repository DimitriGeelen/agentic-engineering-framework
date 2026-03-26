# T-625: Global Framework Sync — Research Artifact

## Problem

Recurring deadlock: Claude Code hooks use bare `fw` → resolves to global `/root/.agentic-framework/bin/fw` → global has stale/missing scripts → all Bash/Write/Edit blocked.

### Incident Log

| Date | Missing Script(s) | Impact | Fix |
|------|-------------------|--------|-----|
| 2026-03-25 | check-project-boundary.sh, commit-cadence.sh, loop-detect.sh, check-agent-dispatch.sh | Total deadlock — manual cp by human | Copied 4 scripts manually |
| 2026-03-26 (session 1) | check-project-boundary.sh | Deadlock on session start | Manual cp |
| 2026-03-26 (session 2) | check-project-boundary.sh, commit-cadence.sh | Deadlock on session start | Manual cp (again) |

### Root Cause Chain

1. `install.sh` creates `/root/.agentic-framework/` as a standalone copy
2. New hook scripts get added to framework repo
3. `fw upgrade` syncs to consumer `.agentic-framework/` dirs — but NOT to global install
4. `.claude/settings.json` hooks use bare `fw` → PATH resolves to `/root/.agentic-framework/bin/fw`
5. Global `fw` dispatches to scripts in `/root/.agentic-framework/agents/context/` — which are stale
6. Missing script → hook exit code 1 → Claude Code blocks the tool call → deadlock

## Investigation Findings

### Spike 1: Hook Resolution

**How `fw` is resolved in hook commands:**
- Claude Code executes hooks with cwd = project root
- Shell searches PATH for `fw` → finds `/root/.local/bin/fw`
- This is a symlink: `/root/.local/bin/fw` → `/root/.agentic-framework/bin/fw`
- `bin/fw` uses `readlink -f "$0"` (line 27) which follows all symlinks → resolves to the actual file location
- Then `cd "$(dirname ...)" && pwd` canonicalizes the path → sets FRAMEWORK_ROOT

**Relative paths in hook commands:**
- NOT recommended. Framework has no special support for relative paths in settings.json
- Claude Code hooks use shell resolution which is fragile with relative paths

**Symlink support:**
- `bin/fw` fully supports symlinks via `readlink -f` + `cd/pwd` canonicalization
- If the global install were a symlink, all path resolution would work correctly

### Spike 2: Upgrade Propagation

**How global install is created:**
- `install.sh` (line 171) clones the framework repo into `~/.agentic-framework`
- `do_vendor()` in `bin/fw` (lines 92-200) copies: bin, lib, agents, web, docs, .tasks/templates, FRAMEWORK.md, metrics.sh

**What `fw upgrade` syncs (lib/upgrade.sh lines 290-353):**
- `agents/context/*.sh` hook scripts
- `agents/context/lib/*` shared libraries
- `bin/fw` consumer vendored binary
- **Target:** Only `$target_dir/.agentic-framework/` (vendored project dirs)

**THE GAP:** `fw upgrade` has **zero mechanism** to update the global install at `$HOME/.agentic-framework/`. The check at line 293 only looks for `$target_dir/.agentic-framework` — the global install at `$HOME` is never a target.

### Spike 3: Symlink Feasibility

**Current state:** `/root/.agentic-framework/` is a **full directory** with `.git/` (not a symlink)

**Safety assessment:**
- `bin/fw` handles symlinks correctly — `readlink -f` + `cd/pwd` canonicalization
- `install.sh` works through symlinks — `git -C` follows symlinks, `-d` test follows symlinks
- No scripts use `dirname "$0"` patterns that break with symlinks

**Risks:**
| Scenario | Risk | Severity |
|----------|------|----------|
| Symlink target repo deleted | Framework breaks completely | HIGH |
| Multi-repo (both /opt/999 and /opt/050) | Symlink only points to one | MEDIUM |
| Re-running install.sh | Survives (git -C follows symlinks) | LOW |
| Nested symlink chains | Works (readlink -f resolves chains) | LOW |

**Verdict:** Symlinks are safe with proper documentation.

### Spike 4: Hook Path Audit

**Critical discovery — most consumers ALREADY use relative paths:**

| Project | Hooks | Path Style |
|---------|-------|------------|
| /opt/999-Agentic-Engineering-Framework | 12 | `.agentic-framework/bin/fw` (RELATIVE) |
| /opt/001-sprechloop | 12 | `.agentic-framework/bin/fw` (RELATIVE) |
| /opt/050-email-archive | 12 | `.agentic-framework/bin/fw` (RELATIVE) |
| /opt/3021-Bilderkarte-tool-llm | 12 | `.agentic-framework/bin/fw` (RELATIVE) |
| /opt/995_2021-kosten | 12 | `.agentic-framework/bin/fw` (RELATIVE) |
| /opt/openclaw-evaluation | 12 | `.agentic-framework/bin/fw` (RELATIVE) |
| /opt/agentic-engineering-framework | 8 | `fw` (BARE) |
| /opt/150-skills-manager | 8 | `fw` (BARE) |
| /opt/termlink | 8 | `fw` (BARE) |
| 4 other projects | 1 each | OTHER (python3 scripts) |

**Totals:** 112 hooks. 84 use relative paths. 24 use bare `fw`. 4 use other.

**Key insight:** 7 out of 10 framework projects already use relative `.agentic-framework/bin/fw` paths — they're immune to the global stale-script problem. Only 3 projects use bare `fw` and are vulnerable.

### Spike 5: Cross-Machine Scan

**This machine inventory:**
- Global (`/root/.agentic-framework/`): 17/17 scripts present (after manual fix today)
- Framework source: 17/17 scripts (latest)
- Consumer 001-sprechloop: 1 stale script (check-tier0.sh — content mismatch)
- Consumer 050-email-archive: 3 stale scripts (check-tier0.sh, checkpoint.sh, budget-gate.sh)

**Cross-machine:** TermLink hub to .107 Mac not available — cannot verify Mac's global install.

**Vulnerability surface:** 5 stale script instances across 2 consumer projects (33% of consumer base affected).

## Assumptions Validation

| ID | Assumption | Status | Evidence |
|----|-----------|--------|----------|
| A1 | Global install never updated after install.sh | **CONFIRMED** | `fw upgrade` has no global install target (lib/upgrade.sh:290-353) |
| A2 | fw upgrade skips global install | **CONFIRMED** | Only syncs to `$target_dir/.agentic-framework/` |
| A3 | Claude Code hooks run from project CWD | **CONFIRMED** | T-495 report + spike 1 testing |
| A4 | Symlink breaks if repo removed | **CONFIRMED** | Standard symlink behavior — dangling link |
| A5 | Multiple machines have different primary repos | **UNKNOWN** | TermLink to .107 unavailable |
| A6 | Consumer machines have same vulnerability | **PARTIALLY CONFIRMED** | 2/6 consumers on this machine have stale scripts |

## Recommendation

**Two-pronged fix — both are needed:**

### Fix 1: Migrate remaining bare `fw` hooks to relative paths (immediate, eliminates the deadlock class)

Only 3 projects still use bare `fw` in hook commands:
- `/opt/agentic-engineering-framework` (8 hooks)
- `/opt/150-skills-manager` (8 hooks)
- `/opt/termlink` (8 hooks)

Change from `"command": "fw hook ..."` to `"command": ".agentic-framework/bin/fw hook ..."`.

This eliminates the dependency on the global install for hooks entirely. 7 other projects already work this way.

**Blast radius:** 24 hook commands across 3 projects. Single `sed` per project.

### Fix 2: Add global install sync to `fw upgrade` (structural, prevents future drift)

Add a step after line 353 in `lib/upgrade.sh` that:
1. Detects the global install location (`$HOME/.agentic-framework/`)
2. Syncs `agents/context/*.sh` and `agents/context/lib/*` to it
3. Only runs when upgrading from the framework repo itself (not from consumer projects)

This is a safety net — Fix 1 removes the hook dependency, but the global install should still be current for `fw` CLI use outside Claude Code.

### Fix 3 (optional): Symlink for this machine

Replace `/root/.agentic-framework/` with a symlink to `/opt/999-Agentic-Engineering-Framework/.agentic-framework/`. Zero maintenance, always in sync. Only viable on machines with a single primary framework repo.

## Correction: Spike 4 Agent Error

TermLink shell verification (2026-03-26) proved the Spike 4 agent was **wrong** about bare `fw` usage:

| Project | Bare `fw` | Relative | Spike 4 claimed |
|---------|-----------|----------|-----------------|
| 150-skills-manager | 0 | 15 | "8 bare fw" (WRONG) |
| termlink | 0 | 11 | "8 bare fw" (WRONG) |
| agentic-engineering-framework | N/A | N/A | "8 bare fw" — project deleted (was stale duplicate) |

**All remaining projects already use relative `.agentic-framework/bin/fw` paths.** The hook path class of the problem is already solved. The only remaining issue is the global install at `/root/.agentic-framework/` going stale.

## Revised Recommendation

**Single fix needed:** Add global install sync to `fw upgrade` (lib/upgrade.sh, ~30 lines). When upgrading from the framework repo, also sync hook scripts to `$HOME/.agentic-framework/`.

Optional: symlink `/root/.agentic-framework` → framework repo's `.agentic-framework/` for zero-maintenance on development machines.

## Rejected Alternatives

| Alternative | Why Rejected |
|-------------|-------------|
| Migrate hook paths to relative | Already done — all projects use relative paths |
| Global install only (no vendored) | Breaks multi-project isolation. Each project needs its own vendored copy for version pinning. |
| Cron job to sync global install | Adds complexity, timing issues, requires sudo for some paths. Upgrade propagation is simpler. |
| Remove global install entirely | Breaks `fw` CLI access from non-project directories. Users expect `fw version`, `fw doctor` etc. to work anywhere. |

## Build Tasks (if GO)

1. **T-626**: Add global install sync to `fw upgrade` (lib/upgrade.sh, ~30 lines)
2. **T-627**: Sync stale consumer scripts (001-sprechloop: 1, 050-email-archive: 3)
3. **T-628** (optional): Symlink `/root/.agentic-framework` on this machine
