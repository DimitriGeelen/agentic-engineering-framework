# T-877: Install-to-First-Session Pipeline — Root Cause Analysis

## Evidence Source

Real user install on 025-WokrshopDesigner (2026-04-05). The framework author himself hit ALL failure modes in a single session.

## Spike 1: Full Flow Audit

### The Journey (install.sh → fw init → first session)

| Step | What happens | What's missing |
|------|-------------|----------------|
| 1. `curl \| bash` | Clones to `~/.agentic-framework`, links `fw` to `~/.local/bin/` | Nothing — works |
| 2. User runs `fw init` | **From which directory?** Installer says `fw init` without context | No `cd` guidance. User on `/root/` would init `/root/` |
| 3. `fw init` creates dirs | `.tasks/`, `.context/`, copies templates | Good |
| 4. `fw init` vendors framework | Copies `.agentic-framework/` into project | Good |
| 5. `fw init` seeds governance | practices, decisions, patterns, learnings | Good |
| 6. `fw init` generates config | CLAUDE.md, hooks, settings.json | Good |
| 7. `fw init` validates | `validate-init.sh` structural + functional | Good |
| 8. `fw init` activates | `context init` for session state | Good |
| 9. `fw init` seeds tasks | Onboarding tasks for greenfield/existing | Good — but user doesn't know about them |
| 10. User runs `fw doctor` | Shows 4-5 WARNs | **Git hooks, git identity, enforcement baseline all missing** |
| 11. User starts Claude Code | No guidance on this step | **Post-init messaging doesn't mention it** |

### Failure Mode Catalog

| # | Failure | Root Cause | Severity | Fix Category |
|---|---------|------------|----------|-------------|
| F1 | `Run:` prefix copied as command | install.sh prints `Run:` before suggestion | **Fixed** (T-875) | UX |
| F2 | `fw init` from wrong dir | No `cd` instruction in post-install message | High | Messaging |
| F3 | Git hooks not installed | `fw init` doesn't call `fw git install-hooks` | High | Auto-remediation |
| F4 | Git identity not configured | `fw init` doesn't check/inherit global config | Medium | Auto-remediation |
| F5 | No enforcement baseline | `fw init` doesn't call `fw enforcement baseline` | Low | Auto-remediation |
| F6 | No "start Claude Code" guidance | Post-init message focuses on `fw` commands, not agent launch | High | Messaging |
| F7 | Version mismatch after update | Installer updates global, not consumer projects | Medium | Auto-remediation |
| F8 | Global install sync despite isolation | `fw upgrade` still syncs to `~/.agentic-framework` | Medium | Architecture (T-878) |

## Spike 2: Auto-Remediation Feasibility

### F3: Git hooks — Can `fw init` auto-install?

**Current code** (lib/init.sh line 85-89): `fw init` already initializes git if needed. But it never calls `fw git install-hooks`.

**Feasibility:** YES. Add after git init:
```bash
# Install git hooks (traceability enforcement)
"$target_dir/.agentic-framework/bin/fw" git install-hooks 2>/dev/null || \
    "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks 2>/dev/null || true
```

**Risk:** Low. `install-hooks` is idempotent. If hooks already exist, it compares and warns.

### F4: Git identity — Can we inherit from global?

**Current code:** fw doctor warns but fw init does nothing.

**Feasibility:** YES, with conditions. Check global config:
```bash
if ! git -C "$target_dir" config user.email >/dev/null 2>&1; then
    local global_email=$(git config --global user.email 2>/dev/null || true)
    if [ -n "$global_email" ]; then
        git -C "$target_dir" config user.email "$global_email"
        git -C "$target_dir" config user.name "$(git config --global user.name 2>/dev/null || echo 'Developer')"
    else
        warn "Git identity not configured — commits will fail"
        echo "  git config user.email 'you@example.com'"
    fi
fi
```

**Risk:** Low. Only inherits if global exists. Never overwrites existing project config.

### F5: Enforcement baseline — Can we auto-create?

**Feasibility:** YES. Add at end of init:
```bash
"$target_dir/.agentic-framework/bin/fw" enforcement baseline 2>/dev/null || true
```

**Risk:** None. Baseline is a snapshot, not enforcement.

### F7: Version mismatch — Can installer auto-upgrade consumers?

**Feasibility:** DEFER. The installer runs from `curl | bash` — it shouldn't scan the filesystem for consumer projects. This is `fw upgrade`'s job. The doctor already tells users to run `fw upgrade <path>`.

## Spike 3: Post-Install Messaging

### Current messaging (install.sh lines 319-343)

```
Installation complete!
  Get started (in current dir, or specify a path):
    fw init                  # current directory
    fw init /path/to/project # specific directory
  ...
```

### Problems

1. **No `cd` guidance** — User runs `fw init` from wherever they are (often `/root/`)
2. **Uses `fw` not `bin/fw`** — Global `fw` may resolve wrong (T-664 shim helps but not always)
3. **No mention of onboarding tasks** — The best feature of init is invisible
4. **No mention of starting an agent** — The framework exists to govern agents, but post-install doesn't say "start your agent"

### Proposed improved messaging

```
Installation complete!

  Next step — initialize your project:

    cd /path/to/your/project
    fw init

  What happens:
    - Creates governance structure (.tasks/, .context/)
    - Installs git hooks for commit traceability
    - Seeds onboarding tasks to guide your first session

  Then start your AI agent (e.g., Claude Code) in the project directory.
  The onboarding tasks will guide you through setup.

  Dashboard: fw serve
  Documentation: $INSTALL_DIR/FRAMEWORK.md
```

## Recommendation: GO

**6 of 8 failure modes** can be fixed:
- F1: DONE (T-875)
- F2: Fix post-install messaging
- F3: Auto-install git hooks in `fw init`
- F4: Auto-inherit git identity from global config
- F5: Auto-create enforcement baseline in `fw init`
- F6: Improve post-install messaging to mention agent + onboarding tasks

**2 deferred:**
- F7: Version mismatch — `fw upgrade` handles this; adding consumer scanning to installer is scope creep
- F8: Global sync — T-878 (separate concern)

### Implementation Plan

**Build task deliverables:**
1. `lib/init.sh`: Add git hooks install after git init
2. `lib/init.sh`: Add git identity inheritance from global config
3. `lib/init.sh`: Add enforcement baseline creation
4. `install.sh`: Rewrite post-install message with `cd` guidance, onboarding mention, agent start guidance
5. Update `fw init` post-init message to mention onboarding tasks

**Estimated scope:** ~50 lines of code across 2 files. Single session.

## Dialogue Log

- **User showed** real install output from 025-WokrshopDesigner with 5 warnings
- **User pointed out** agent missed the `fw init` from root problem, agent was fixing symptoms not causes
- **User demanded** RCA before more symptom fixes
- **Agent reflection:** Was in execution mode (ticking boxes) instead of evaluating user experience holistically
