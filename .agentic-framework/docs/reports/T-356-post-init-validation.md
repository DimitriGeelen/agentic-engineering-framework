# T-356: Post-init Validation Research

## Spike 1: Inventory — What `fw init` Creates

### Directories (11)
| # | Path | Created by |
|---|------|-----------|
| 1 | `.tasks/active/` | init.sh:84 |
| 2 | `.tasks/completed/` | init.sh:85 |
| 3 | `.tasks/templates/` | init.sh:86 |
| 4 | `.context/working/` | init.sh:87 |
| 5 | `.context/project/` | init.sh:88 |
| 6 | `.context/episodic/` | init.sh:89 |
| 7 | `.context/handovers/` | init.sh:90 |
| 8 | `.context/scans/` | init.sh:91 |
| 9 | `.context/bus/results/` | init.sh:92 |
| 10 | `.context/bus/blobs/` | init.sh:93 |
| 11 | `.context/audits/cron/` | init.sh:94 |

### Files — Core (3)
| # | Path | Content check |
|---|------|--------------|
| 12 | `.framework.yaml` | YAML valid, has project_name + framework_path + version + provider |
| 13 | `.context/bypass-log.yaml` | YAML valid, has `bypasses: []` |
| 14 | `.context/working/.gitignore` | Contains `.tool-counter`, `session.yaml`, `focus.yaml` |

### Files — Governance Seeds (7)
| # | Path | Content check |
|---|------|--------------|
| 15 | `.context/project/practices.yaml` | YAML valid, `practices:` key exists |
| 16 | `.context/project/decisions.yaml` | YAML valid, `decisions:` key exists |
| 17 | `.context/project/patterns.yaml` | YAML valid, `failure_patterns:` key exists |
| 18 | `.context/project/learnings.yaml` | YAML valid, `learnings:` key exists |
| 19 | `.context/project/assumptions.yaml` | YAML valid, `assumptions:` key exists |
| 20 | `.context/project/directives.yaml` | YAML valid, `directives:` key exists, 4 directives |
| 21 | `.context/project/gaps.yaml` | YAML valid, `gaps:` key exists |

### Files — Task Templates (2)
| # | Path | Content check |
|---|------|--------------|
| 22 | `.tasks/templates/zzz-default.md` | File exists, non-empty |
| 23 | `.tasks/templates/inception.md` | File exists, non-empty |

### Files — Provider: Claude (3)
| # | Path | Content check |
|---|------|--------------|
| 24 | `CLAUDE.md` | File exists, contains project name |
| 25 | `.claude/settings.json` | JSON valid, 10 hooks configured, all script paths resolve, all executable |
| 26 | `.claude/commands/resume.md` | File exists, non-empty |

### Files — Provider: Cursor (1)
| # | Path | Content check |
|---|------|--------------|
| 27 | `.cursorrules` | File exists, contains project name |

### Git Hooks (3, if git repo)
| # | Path | Content check |
|---|------|--------------|
| 28 | `.git/hooks/commit-msg` | Executable, contains "Task Reference" |
| 29 | `.git/hooks/post-commit` | Executable, contains "Bypass Detection" |
| 30 | `.git/hooks/pre-push` | Executable, contains "audit" |

### PATH/Symlink (1, conditional)
| # | Check | Condition |
|---|-------|-----------|
| 31 | `fw` in PATH | Only if not already present |

**Total: 31 checkable items** (provider=claude + git repo = full set)

## Spike 2: Gap Analysis — What `fw doctor` Currently Checks

| `fw doctor` check | Init item covered | Gap |
|---|---|---|
| Framework installation (agents/ + FRAMEWORK.md) | N/A (framework, not project) | — |
| `.framework.yaml` exists | #12 | Checks existence only, not content validity |
| Task directories | #1, #2 | Yes — `.tasks/active` + `.tasks/completed` |
| Context directory | #4-11 | Only checks `.context/` exists, not subdirs |
| Git commit-msg hook | #28 | Checks exists + contains "Task Reference" |
| Git pre-push hook | #30 | Checks exists + contains "audit" |
| Tier 0 enforcement hook | Part of #25 | Checks `check-tier0.sh` in settings.json |
| Agent scripts executable | N/A (framework) | — |
| Plugin task-awareness | N/A | — |
| Test infrastructure | N/A | — |
| Orphaned MCP processes | N/A | — |
| Hook config validation | #25 | Checks JSON valid, nested structure, script paths exist + executable |
| Enforcement baseline | N/A | — |

### Items NOT checked by `fw doctor`:
- **Templates copied** (#22-23): no check
- **Governance seeds valid** (#15-21): no check for YAML validity or key presence
- **`.framework.yaml` content** (#12): no check that framework_path resolves or version matches
- **`CLAUDE.md` generated** (#24): no check
- **`resume.md` generated** (#26): no check
- **Post-commit hook** (#29): no check
- **Context subdirectories** (#5-11): only parent dir checked
- **`.gitignore` in working/** (#14): no check
- **`bypass-log.yaml`** (#13): no check
- **Cellar path in settings.json paths** (#25): checked (T-355 added)
- **`fw` in PATH** (#31): no check

**Coverage: ~8/31 items checked = 26%**

## Spike 3: Design Options

### Option A: Extend `fw doctor` with `--post-init` flag
- Add ~15 checks to `fw doctor` gated behind `--post-init`
- Called automatically at end of `fw init`
- Pro: Single health check command, no new subcommand
- Con: `fw doctor` already long (250+ lines of checks); mixes runtime health with init completeness

### Option B: New `fw validate-init` subcommand
- Standalone validation script in `lib/validate-init.sh`
- Called from end of `fw init` and available as `fw validate-init`
- Pro: Clean separation, can be run independently
- Con: Yet another subcommand to discover

### Option C: Inline validation at end of `fw init` (recommended)
- Add validation directly in `do_init()` after all creation steps
- Each creation step already prints ✓/⚠ — add a final verification pass
- Pro: No new command, runs every time, catches failures immediately
- Con: Makes init.sh longer

**Recommendation: Option C** — validation is tightly coupled to what init creates. A separate command would drift. Inline validation with clear pass/fail output is the simplest reliable approach.

### Implementation sketch (Option C):
```bash
# --- Post-init validation ---
local validation_errors=0

# Check critical files exist and are valid
for f in .framework.yaml .context/bypass-log.yaml; do
    if [ ! -f "$target_dir/$f" ]; then
        echo -e "  ${RED}✗${NC}  Missing: $f"
        validation_errors=$((validation_errors + 1))
    fi
done

# Check .framework.yaml content
if [ -f "$target_dir/.framework.yaml" ]; then
    if ! python3 -c "import yaml; yaml.safe_load(open('$target_dir/.framework.yaml'))" 2>/dev/null; then
        echo -e "  ${RED}✗${NC}  .framework.yaml is not valid YAML"
        validation_errors=$((validation_errors + 1))
    fi
fi

# Check settings.json (provider=claude)
if [ "$provider" = "claude" ] || [ "$provider" = "generic" ]; then
    if [ -f "$target_dir/.claude/settings.json" ]; then
        if ! python3 -c "import json; json.load(open('$target_dir/.claude/settings.json'))" 2>/dev/null; then
            echo -e "  ${RED}✗${NC}  .claude/settings.json is not valid JSON"
            validation_errors=$((validation_errors + 1))
        else
            # Check all hook script paths resolve
            local broken_hooks
            broken_hooks=$(python3 -c "
import json, os
with open('$target_dir/.claude/settings.json') as f:
    data = json.load(f)
broken = 0
for event, entries in data.get('hooks', {}).items():
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            parts = cmd.split()
            script = next((p for p in parts if '=' not in p), '')
            if script and not os.path.exists(script):
                print(f'  Missing: {os.path.basename(script)}')
                broken += 1
print(f'BROKEN:{broken}')
" 2>/dev/null)
            local count
            count=$(echo "$broken_hooks" | grep "BROKEN:" | cut -d: -f2)
            if [ "${count:-0}" -gt 0 ]; then
                echo -e "  ${RED}✗${NC}  $count hook script(s) not found:"
                echo "$broken_hooks" | grep "Missing:"
                validation_errors=$((validation_errors + count))
            fi
        fi
    fi
fi

# Check git hooks (if git repo)
if [ -d "$target_dir/.git" ]; then
    for hook in commit-msg post-commit pre-push; do
        if [ ! -x "$target_dir/.git/hooks/$hook" ]; then
            echo -e "  ${RED}✗${NC}  Git hook not installed: $hook"
            validation_errors=$((validation_errors + 1))
        fi
    done
fi

# Summary
if [ "$validation_errors" -gt 0 ]; then
    echo ""
    echo -e "  ${RED}⚠ $validation_errors validation error(s)${NC} — init may be incomplete"
    echo -e "  Run ${BOLD}fw doctor${NC} for detailed diagnostics"
    return 1
else
    echo -e "  ${GREEN}✓${NC}  All checks passed"
fi
```

## Spike 4: Would This Have Caught T-352 / T-355?

### T-352: `_sed_i` undefined
- `_sed_i` was called in init but wasn't sourced → init silently failed partway through
- **Option C catches this:** the files that `_sed_i` was supposed to create wouldn't exist → validation detects missing files

### T-355: Cellar path hardcoding
- `fw init` wrote Cellar paths into settings.json → hooks resolve at init time but break after `brew upgrade`
- **Option C partially catches this:** the hook path check at init time would PASS (paths exist at that moment). BUT: could add a Cellar-path-pattern check that warns about non-stable paths
- **Full catch requires:** `if [[ "$script" == *"/Cellar/"* ]]; then warn "Cellar path detected"`

**Verdict:** Would have caught T-352 (missing files). Would catch T-355 with a Cellar-specific check added.

## Go/No-Go Assessment

| Criterion | Result |
|-----------|--------|
| Clear inventory >10 checkable items | **YES** — 31 items |
| Implementable in <1 hour | **YES** — Option C, ~50 lines of bash |
| Would have caught T-352 or T-355 | **YES** — catches T-352, catches T-355 with Cellar check |
| `fw doctor` already covers 90%? | **NO** — only 26% coverage |
| Validation logic fragile? | **NO** — checks are file existence + simple parse validation |
| Overhead > 5 seconds? | **NO** — all local file checks, estimated <1s |

**Recommendation: GO**

## Decision Record

**Decision:** GO — Option B (independent `lib/validate-init.sh`) with self-documenting `#@init:` tags.

### Design: `#@init:` Tag Convention

Each unit of work in `init.sh` is declared with a structured comment:

```bash
#@init: <type>-<3char_key> <path> [check_args]
# <human-readable description>
<implementation>
```

**Example:**
```bash
#@init: yaml-8kj .framework.yaml project_name,framework_path,version
# Project configuration with framework path and version
cat > "$target_dir/.framework.yaml" << FYAML
...
FYAML

#@init: json-3fz .claude/settings.json hooks
# Claude Code hooks (10 configured)
generate_claude_code_config "$target_dir"

#@init: exec-7nm .git/hooks/commit-msg "Task Reference"
# Git commit-msg hook for task traceability
PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks

#@init: dir-2pw .tasks/active
# Task system active directory
mkdir -p "$target_dir/.tasks/active"
```

**Tag key format:** `<type>-<3char_alphanumeric>` — e.g. `yaml-8kj`, `json-3fz`, `exec-7nm`, `dir-2pw`
- Type: `dir`, `yaml`, `json`, `exec`, `file`
- 3-char key: random, unique across init.sh

**Check types:**
| Type | Validation |
|------|-----------|
| `dir` | Directory exists |
| `yaml` | File exists + valid YAML + listed keys present |
| `json` | File exists + valid JSON + listed keys present |
| `exec` | File exists + executable + contains string |
| `file` | File exists + non-empty |

**Output format (user-facing):**
```
✓ yaml-8kj  Project configuration
✓ json-3fz  Claude Code hooks (10 configured)
✗ exec-7nm  Git commit-msg hook — not executable
✓ dir-2pw   Task system active directory
```

### Three-Layer Assurance

1. **Layer 1 — Blast-radius nudge (real-time):** Component Fabric edge `init.sh → validate-init.sh`. Agent sees "validate-init.sh depends on this" after every commit touching init.sh.

2. **Layer 2 — Structural gate: SKIP.** Rare event (init changes ~2x/year). Gate overhead not justified.

3. **Layer 3 — Cron audit (after-the-fact):** Periodic check counts `#@init:` tags in init.sh, compares against validate-init.sh checks. Drift surfaces in audit YAML → discovery findings → handover → agent sees it next session. Self-healing: finding becomes a task.

### Why Not Option A/C

- **Option A (extend fw doctor):** Mixes runtime health with init completeness. fw doctor already 250+ lines.
- **Option C (inline in init):** Can't run independently. If init itself is broken, validation may not run.
- **Option B wins:** Clean separation, reusable, testable. `#@init:` tags eliminate the manifest-drift problem.
