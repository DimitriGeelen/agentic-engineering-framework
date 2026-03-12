# T-468 Inception: Tool Call Telemetry from 010-termlink

## 1. Scope Assessment — Copy vs Build

### Copy Verbatim (4 files, ~3 fabric cards)

| File | Lines | Adaptation Needed |
|------|-------|-------------------|
| `agents/telemetry/extract-tool-calls.py` | 257 | **One fix**: `capture-on-compact.sh` line 11 hardcodes `EXTRACTOR="${PROJECT_ROOT}/agents/telemetry/..."`. For shared-tooling mode, must use `FRAMEWORK_ROOT`. Python file itself already reads `PROJECT_ROOT` env var — fine as-is. |
| `agents/telemetry/tool-stats.py` | 202 | None — already uses `PROJECT_ROOT` env var (line 175). |
| `agents/telemetry/analyze-errors.py` | 225 | None — already uses `PROJECT_ROOT` env var (line 112). |
| `agents/telemetry/capture-on-compact.sh` | 45 | **Two fixes**: (1) Line 11 `EXTRACTOR` path must use `FRAMEWORK_ROOT` not `PROJECT_ROOT`. (2) Line 17 reads `current_task` from focus.yaml — field name is correct (`current_task:` confirmed in framework focus.yaml). |
| `.fabric/components/{extract-tool-calls,tool-stats,analyze-errors}.yaml` | 3 cards | **Location paths** need updating from termlink paths to framework paths. Otherwise copy verbatim. |

**Effort estimate**: 30 min copy + patch. Minimal risk.

### Build from Scratch (5 items)

| Item | Complexity | Effort |
|------|-----------|--------|
| Watchtower `/telemetry` blueprint + template | Medium | 2-3h |
| `fw tool-stats` CLI routing | Trivial | 15 min |
| `fw analyze-errors` CLI routing | Trivial | 15 min |
| PreCompact hook registration in `lib/init.sh` | Small | 30 min |
| Handover integration (tool stats line) | Small | 30 min |

**Total estimated effort**: 4-5 hours across 3-4 tasks.

---

## 2. Watchtower Integration — Blueprint Pattern

### Reference: `web/blueprints/cron.py` (simplest comparable)

The cron blueprint (280 lines) follows this pattern:
- Import `Blueprint` from flask, `render_page` from `web.shared`
- Define `bp = Blueprint("cron", __name__)`
- Helper functions parse data files, compute stats
- Single `@bp.route("/cron")` renders template with computed context
- Template lives at `web/templates/cron.html`

### What a Telemetry Blueprint Needs

**File**: `web/blueprints/telemetry.py`

```python
bp = Blueprint("telemetry", __name__)

TELEMETRY_STORE = PROJECT_ROOT / ".context" / "telemetry" / "tool-calls.jsonl"
```

**Routes** (start with one, expand later):
1. `GET /telemetry` — Main dashboard: call counts, error rates, tool breakdown, session list
2. (Future) `GET /telemetry/session/<session_id>` — Drill-down per session
3. (Future) `GET /telemetry/errors` — Error analysis view

**Data loading**: Reuse logic from `tool-stats.py` and `analyze-errors.py` — either import directly or inline the JSONL parsing (both are pure stdlib). Importing is cleaner:

```python
# In blueprint, reuse the existing scripts' core functions
sys.path.insert(0, str(PROJECT_ROOT / "agents" / "telemetry"))
from tool_stats import load_records, compute_stats  # rename .py to valid module name
from analyze_errors import classify_error, escalation_level
```

**Problem**: The Python files use dashes in names (`tool-stats.py`), which are not valid Python module names. Options:
- (a) Rename to `tool_stats.py` and `analyze_errors.py` (breaking CLI invocation)
- (b) Use `importlib.import_module` with dashes
- (c) Copy the ~50 lines of parsing logic into the blueprint

**Recommendation**: Option (c) — copy `load_records()` and `compute_stats()` (~70 lines) into the blueprint. Avoids import gymnastics and keeps CLI scripts standalone.

**Registration**: Add to `web/blueprints/__init__.py` line 25:

```python
from web.blueprints.telemetry import bp as telemetry_bp
# Add to the registration tuple at line 30
```

**Template**: `web/templates/telemetry.html` — follow `cron.html` structure:
- Summary cards (total calls, error rate, sessions, top model)
- Tool breakdown table (sortable)
- Session list with call/error counts
- Error pattern table with escalation badges

---

## 3. Hook Registration — PreCompact Chain

### Current State

The framework's own `.claude/settings.json` (line 7-14) has one PreCompact hook:
```json
"PreCompact": [{
  "matcher": "",
  "hooks": [{
    "type": "command",
    "command": "/opt/999-Agentic-Engineering-Framework/agents/context/pre-compact.sh"
  }]
}]
```

This runs `agents/context/pre-compact.sh` which generates a handover, resets budget counters, and logs to `.compact-log`.

### Integration Strategy

**Option A — Chain in pre-compact.sh**: Add a telemetry capture call at the end of `agents/context/pre-compact.sh` (after line 38, before `exit 0`):

```bash
# Capture tool call telemetry before compaction
TELEMETRY_CAPTURE="$FRAMEWORK_ROOT/agents/telemetry/capture-on-compact.sh"
if [ -x "$TELEMETRY_CAPTURE" ]; then
    PROJECT_ROOT="$PROJECT_ROOT" "$TELEMETRY_CAPTURE" 2>/dev/null || true
fi
```

**Option B — Separate hook entry**: Add a second PreCompact hook in settings.json. Claude Code processes all hooks for a matcher sequentially.

**Recommendation**: Option A. One hook entry, one orchestration script. The `pre-compact.sh` already handles the "save state before compaction" concern. Telemetry capture is the same concern.

### Consumer Project Registration

In `lib/init.sh`, the `generate_claude_code_config()` function (line 528) generates `.claude/settings.json` for consumer projects. The PreCompact command (line 544) already points to the framework's `pre-compact.sh`. Since we chain in pre-compact.sh directly, **no init.sh changes needed** — consumer projects inherit the telemetry capture automatically.

**Caveat**: The `capture-on-compact.sh` path resolution (line 11) must use `FRAMEWORK_ROOT`:
```bash
EXTRACTOR="${FRAMEWORK_ROOT}/agents/telemetry/extract-tool-calls.py"
```
And `TELEMETRY_DIR` stays as `PROJECT_ROOT` (telemetry data lives in the project, not the framework):
```bash
TELEMETRY_DIR="${PROJECT_ROOT}/.context/telemetry"
```

---

## 4. Handover Integration

### Injection Point

In `agents/handover/handover.sh`, the natural injection point is between "Files Changed This Session" (line 601) and "Recent Commits" (line 606).

**Alternatively**: Add a new section "## Tool Call Summary" before "## Suggested First Action" (line 572). This is more useful — the suggested action section is the last thing the next session reads.

### Implementation

Add ~15 lines to `handover.sh` at line 570:

```bash
# Step 2.N: Tool call summary (if telemetry store exists)
TELEMETRY_STORE="$PROJECT_ROOT/.context/telemetry/tool-calls.jsonl"
TOOL_STATS="$FRAMEWORK_ROOT/agents/telemetry/tool-stats.py"
if [ -f "$TELEMETRY_STORE" ] && [ -f "$TOOL_STATS" ]; then
    TOOL_SUMMARY=$(python3 "$TOOL_STATS" --compact 2>/dev/null || echo "")
    if [ -n "$TOOL_SUMMARY" ]; then
        cat >> "$HANDOVER_FILE" << TOOLEOF
## Tool Call Summary

$TOOL_SUMMARY

TOOLEOF
    fi
fi
```

**Invasiveness**: Low. Conditional block, fails silently, no changes to existing handover structure. 15 lines added, 0 lines changed.

**Gotcha**: `tool-stats.py --compact` reads ALL records in the store (all sessions). For handover, we might want `--session CURRENT_SESSION_ID`. But session ID isn't trivially available in `handover.sh`. Options:
- (a) Show all-time stats (useful for trends)
- (b) Add `--last-session` flag to `tool-stats.py` that auto-selects most recent session
- (c) Pass the session UUID from Claude Code environment

**Recommendation**: Start with (a) — all-time compact line. Add (b) as follow-up.

---

## 5. Dependencies — Shared Tooling Adaptation

### Critical Fix: `capture-on-compact.sh`

The termlink version uses `PROJECT_ROOT` for both data AND script paths. In shared-tooling mode:
- **Scripts** live in `FRAMEWORK_ROOT` (the framework repo)
- **Data** lives in `PROJECT_ROOT` (the consumer project)

Lines needing change in `capture-on-compact.sh`:

| Line | Current | Fix |
|------|---------|-----|
| 8 | `PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"` | Keep (data location) |
| 9 | `TELEMETRY_DIR="${PROJECT_ROOT}/.context/telemetry"` | Keep (data in project) |
| 11 | `EXTRACTOR="${PROJECT_ROOT}/agents/telemetry/..."` | Change to `FRAMEWORK_ROOT` |

Add after line 8:
```bash
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$PROJECT_ROOT}"
```
Then line 11 becomes:
```bash
EXTRACTOR="${FRAMEWORK_ROOT}/agents/telemetry/extract-tool-calls.py"
```

This follows the standard pattern used by all agents: `PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"` (see MEMORY.md).

### Python Scripts: Already Safe

All three Python scripts use `os.environ.get('PROJECT_ROOT', os.getcwd())` for the telemetry store path. This resolves correctly in both self-hosted and shared-tooling modes because:
1. PreCompact hook passes `PROJECT_ROOT=$dir` (lib/init.sh line 544)
2. Direct CLI invocation from project dir uses `os.getcwd()` fallback

### `extract-tool-calls.py`: Session JSONL Location

Line 26-28 computes the Claude project transcript directory:
```python
project_root = os.environ.get('PROJECT_ROOT') or os.getcwd()
dir_name = project_root.replace('/', '-')
return Path.home() / '.claude' / 'projects' / dir_name
```

This depends on Claude Code's internal directory naming convention (path-to-dashes). This is correct for the framework running inside its own repo AND for consumer projects, because Claude Code creates project directories based on the working directory path.

### `fw init` — Telemetry Directory

Need to add `.context/telemetry` to the directory creation list in `lib/init.sh` (after line 116):
```bash
#@init: dir-XXX .context/telemetry
# Tool call telemetry data
mkdir -p "$target_dir/.context/telemetry"
```

---

## 6. Proposed Build Tasks (Independently Shippable)

### Task 1: Copy Capture Layer + CLI Routing
**Type**: build | **Effort**: 1h | **Depends on**: nothing

- Copy 4 files from termlink to `agents/telemetry/`
- Fix `capture-on-compact.sh` for `FRAMEWORK_ROOT` (see section 5)
- Copy 3 fabric cards to `.fabric/components/`, fix paths
- Add `fw tool-stats` routing in `bin/fw` (exec to `agents/telemetry/tool-stats.py`)
- Add `fw analyze-errors` routing in `bin/fw` (exec to `agents/telemetry/analyze-errors.py`)
- Add `.context/telemetry` directory creation to `lib/init.sh`
- Verification: `fw tool-stats --help`, `fw analyze-errors --help`, `fw fabric drift`

### Task 2: PreCompact Hook Integration
**Type**: build | **Effort**: 30 min | **Depends on**: Task 1

- Add telemetry capture call to `agents/context/pre-compact.sh`
- Non-blocking: `|| true` ensures compaction still succeeds
- Verification: trigger manual compaction, check `.context/telemetry/tool-calls.jsonl` exists

### Task 3: Handover Integration
**Type**: build | **Effort**: 30 min | **Depends on**: Task 1

- Add tool call summary section to `agents/handover/handover.sh`
- Conditional: only appears if telemetry store exists
- Uses `tool-stats.py --compact` for one-line summary
- Verification: `fw handover --no-commit`, check for "Tool Call Summary" section

### Task 4: Watchtower Telemetry Page
**Type**: build | **Effort**: 2-3h | **Depends on**: Task 1

- Create `web/blueprints/telemetry.py` following cron.py pattern
- Create `web/templates/telemetry.html`
- Register in `web/blueprints/__init__.py`
- Add nav link to base template
- Features: summary cards, tool breakdown table, session list, error patterns
- Verification: `curl -sf http://localhost:3000/telemetry`

### Dependency Graph
```
Task 1 (capture layer)
  ├── Task 2 (PreCompact hook)
  ├── Task 3 (handover integration)
  └── Task 4 (Watchtower page)
```

Tasks 2, 3, 4 are independent of each other. Task 1 is prerequisite for all.

---

## 7. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| JSONL store grows unbounded | Low (metadata only, ~200 bytes/call) | Add retention cleanup (future task) |
| Claude Code JSONL format changes | Medium — extractor breaks silently | `try/except` already handles parse errors; `capture-on-compact.sh` is non-blocking |
| PreCompact hook slows compaction | Low — extraction is fast (<1s for typical sessions) | Already non-blocking (`|| true`) |
| Session UUID not available for filtered stats | Low — all-time stats still useful | Add `--last-session` flag later |

## 8. Go/No-Go Recommendation

**GO** — with Task 1 as immediate next step. The capture layer is copy-ready with two path fixes. Build tasks are small and independently shippable. No architectural risk.
