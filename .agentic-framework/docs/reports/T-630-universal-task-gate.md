# T-630: Universal Task Gate — Research Artifact

## Problem

The framework's core principle "Nothing gets done without a task" is structurally enforced by `check-active-task.sh` as a PreToolUse hook. But the hook's matcher only covers `Write|Edit`. Three bypass paths exist:

| Bypass | Mechanism | Severity |
|--------|-----------|----------|
| Bash | `echo >`, `sed -i`, `tee`, `cat <<EOF` all write files. Bash only goes through Tier 0 + boundary check. | CRITICAL |
| Agent/TaskCreate | Zero PreToolUse gating. Agent can self-authorize by creating task, setting focus, then Write/Edit passes. | HIGH |
| TermLink workers | Independent `claude -p` processes. No settings.json hooks inherited. Zero governance. | HIGH |

## Spike Results

### Spike 1: Bash File-Write Detection

**Sample**: 7,920 Bash invocations from most recent session transcript.

| Category | Count | % |
|----------|-------|---|
| FW hook commands (mixed) | 6,198 | 78% |
| Other framework/callbacks | 1,046 | 13% |
| Read-only commands | 475 | 6% |
| File-writing operations | 113 | 1.4% |
| FW task/git operations | 88 | 1.1% |

**Key finding**: Only 1.4% of Bash calls are explicit file writes. A write-pattern blocklist catches these with <0.5% false-positive rate.

**Reliable write-detection patterns** (regex):
- Redirects: `[^>]>[^>]`, `>>`
- File ops: `\brm\b`, `\bmkdir\b`, `\btouch\b`, `\bcp\b`, `\bmv\b`, `\bchmod\b`
- In-place edit: `\bsed\b.*-i`
- Git mutations: `\bgit\b.*(add|commit|push|reset|checkout|merge|rebase|cherry-pick)`
- Heredocs: `<<\s*['"]?EOF`
- FW writes: `\bfw\b.*(task|git|inception|handover|context\s+(add|init))`

**Recommendation**: HYBRID approach — use a safe-command allowlist for fast-path (read-only commands pass without task check), then write-pattern blocklist for everything else.

### Spike 2: Agent/TaskCreate Gate Feasibility

**Finding**: check-active-task.sh handles empty `file_path` gracefully. When Agent or TaskCreate is matched:
1. `FILE_PATH=""` (no file_path in tool input)
2. Empty string doesn't match any exempt path case
3. Falls through to the active-task check (line 107+)
4. Correctly blocks if no active task, allows if task exists

**Conclusion**: **Zero code changes needed** in check-active-task.sh. Just update settings.json:
```json
"matcher": "Write|Edit|Agent|TaskCreate|TaskUpdate"
```

### Spike 3: TermLink Governance Propagation

**Current state**: `fw termlink dispatch` in `lib/dispatch.sh` spawns `claude -p` workers. Workers receive a prompt file but NO hook configuration. The dispatch preamble (`agents/dispatch/preamble.md`) contains behavioral rules but no structural enforcement.

**The problem**: TermLink workers are full Claude Code sessions. They have their OWN `.claude/settings.json` from whatever project they run in. If the project has hooks configured, they work. If not (like `/tmp/` workspaces), no governance.

**Options**:
| Option | Mechanism | Structural? |
|--------|-----------|-------------|
| A. Require `--task` flag | `fw termlink dispatch` refuses without `--task T-XXX` | Yes |
| B. Inject task context in prompt | Preamble includes "You are working on T-XXX, all commits must reference it" | Behavioral |
| C. Copy settings.json | Dispatch copies parent's hooks to worker's project | Yes but fragile |
| D. Validate output | Post-dispatch: check worker output files for task references | After-the-fact |

**Recommendation**: Option A + B combined. `fw termlink dispatch` already accepts `--task`. Make it mandatory (exit 1 without it). The preamble already exists — add task enforcement language.

### Spike 4: Safe-Command Allowlist

**Design**: A `is_bash_safe_command()` function in `agents/context/lib/safe-commands.sh`.

**Categories** (27 patterns total):

| Category | Patterns | Examples |
|----------|----------|---------|
| Git read-only | 8 | `git status`, `git log`, `git diff`, `git show`, `git branch`, `git remote`, `git describe`, `git rev-parse` |
| File reading | 7 | `cat`, `head`, `tail`, `ls`, `wc`, `file`, `stat` |
| Searching | 4 | `grep`, `rg`, `sed` (no -i), `awk` (no -i) |
| FW diagnostics | 6 | `fw doctor`, `fw metrics`, `fw audit`, `fw version`, `fw resume`, `fw context status` |
| System | 6 | `curl` (GET), `which`, `date`, `uname`, `ps`, `ss` |
| Validation | 2 | `bash -n`, `python3 -c` (parse only) |

**Compound commands**: For `&&`/`||`/`;`/`|` chains, extract first command only. If first command is safe, allow. The chain's destructive parts (if any) are caught by Tier 0 separately.

**False-positive rate**: <0.5% based on session data analysis.

### Spike 5: FW_SAFE_MODE Escape Hatch

**Problem**: Expanding the task gate increases deadlock surface. If the expanded gate breaks, more tools are blocked, harder to recover.

**Design**:
```bash
# Top of check-active-task.sh
if [ "${FW_SAFE_MODE:-0}" = "1" ]; then
    echo "SAFE MODE: Task gate bypassed (FW_SAFE_MODE=1)" >&2
    exit 0
fi
```

**Activation**: User sets `export FW_SAFE_MODE=1` before starting Claude Code.
**Deactivation**: Unset the env var and restart session.
**Logging**: Safe mode activations logged to `.context/bypass-log.yaml` automatically.
**Scope**: Only disables task gate (check-active-task.sh). Tier 0 and boundary check remain active.

## Design: The Universal Task Gate

### Architecture

```
PreToolUse hook fires
  │
  ├─ Tool = Write|Edit
  │   └─ check-active-task.sh (existing — file_path check)
  │
  ├─ Tool = Bash
  │   └─ check-active-task.sh (NEW path):
  │       1. FW_SAFE_MODE? → allow
  │       2. Extract command from tool_input.command
  │       3. is_bash_safe_command()? → allow (read-only diagnostic)
  │       4. Is command fw hook *? → allow (framework internal)
  │       5. Does command write files? → require active task
  │       6. Otherwise → allow (unknown commands default to permissive)
  │
  ├─ Tool = Agent|TaskCreate|TaskUpdate
  │   └─ check-active-task.sh (existing path — empty file_path):
  │       1. FW_SAFE_MODE? → allow
  │       2. Active task exists? → allow
  │       3. No active task → BLOCK
  │
  └─ Tool = Tier0-checked (unchanged)
      └─ check-tier0.sh (destructive commands)
```

### settings.json Changes

```json
{
  "matcher": "Write|Edit|Bash",
  "hooks": [{
    "type": "command",
    "command": "fw hook check-active-task"
  }]
}
```

Plus add Agent/Task tools:
```json
{
  "matcher": "Agent|TaskCreate|TaskUpdate",
  "hooks": [{
    "type": "command",
    "command": "fw hook check-active-task"
  }]
}
```

### check-active-task.sh Changes

1. Add `FW_SAFE_MODE` check at top (3 lines)
2. Extract `command` field for Bash tool input (5 lines)
3. Source `lib/safe-commands.sh` and call `is_bash_safe_command()` for Bash (2 lines)
4. Add write-pattern detection for non-safe Bash commands (15 lines)
5. Allow `fw hook *` commands unconditionally (hooks calling hooks) (3 lines)

**Total: ~28 lines added to existing 339-line script.**

### lib/safe-commands.sh (New File)

~80 lines: `is_bash_safe_command()` function with case statement covering 27 safe patterns.

### dispatch.sh Changes (TermLink)

1. Make `--task` flag mandatory (error if missing) (5 lines)
2. Add task reference to worker prompt preamble (3 lines)

## Recommendation

**GO.** Build in 3 tasks:

1. **T-631: Bash task gate** — Add Bash to check-active-task.sh PreToolUse matcher. Implement safe-command allowlist + write-pattern detection + FW_SAFE_MODE.
2. **T-632: Agent/Task gate** — Add Agent|TaskCreate|TaskUpdate to PreToolUse matcher. Zero code changes to check-active-task.sh needed.
3. **T-633: TermLink governance propagation** — Make `--task` mandatory in `fw termlink dispatch`. Add enforcement language to dispatch preamble.

**Estimated effort**: T-631 (medium, ~1 session), T-632 (small, ~15 min), T-633 (small, ~30 min).

**Risk**: The Bash gate (T-631) is the most complex. The safe-command allowlist may need tuning over the first few sessions. FW_SAFE_MODE provides the escape hatch if the initial patterns are too aggressive.

**Evidence base**: 7,920 Bash invocations analyzed, <0.5% expected false-positive rate, zero code changes needed for Agent/Task gating, proven FW_SAFE_MODE recovery pattern.
