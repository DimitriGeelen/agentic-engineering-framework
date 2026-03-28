# T-490 Spike 1: Claude Code Terminal Capability Testing

**Date:** 2026-03-14
**Agent:** Sub-agent (Opus 4.6)

## Experiment 1: Background Process + Health Polling

**Command:**
```bash
python3 -m http.server 9876 & PID=$!
echo "Started PID: $PID"
sleep 2
curl -sf http://localhost:9876/ > /dev/null && echo "REACHABLE" || echo "UNREACHABLE"
kill $PID 2>/dev/null
```

**Output:**
```
Started PID: 3131784
REACHABLE
Exit code: 0
```

**Result: PASS**
- Background process starts successfully with `&`
- `sleep` works for waiting
- `curl` can poll localhost
- `kill` terminates the background process
- All within a single `run_in_background: false` Bash call

**Gotchas:**
- Must chain commands with `; ` or `&&` in a single Bash call (shell state doesn't persist between calls)
- Must `wait $PID 2>/dev/null` after kill to prevent zombie process noise in output
- Server stderr (access log) appears in output but doesn't interfere

---

## Experiment 2: Start Watchtower on Test Port

**Command:**
```bash
python3 -c "
import sys, os
sys.path.insert(0, '.')
os.environ['FW_PORT'] = '9877'
from web.app import app
app.run(host='127.0.0.1', port=9877, debug=False)
" & SERVE_PID=$!
echo "Watchtower PID: $SERVE_PID"
sleep 4
curl -sf http://localhost:9877/health
kill $SERVE_PID 2>/dev/null
```

**Output:**
```
Watchtower PID: 3132961
FW_SECRET_KEY not set — using auto-generated key. Set FW_SECRET_KEY for production deployment.
 * Serving Flask app 'web.app'
 * Running on http://127.0.0.1:9877
{"app":"ok","embeddings":{"status":"stale"},"ollama":"ok"}
Health exit: 0
Done
```

**Result: PASS**
- Watchtower starts on a non-standard port via `FW_PORT` env var
- Health endpoint responds with JSON
- Flask warnings about dev server appear but don't interfere
- Server cleanly killed

**Gotchas:**
- Need `sleep 4` (not 2) — Flask takes ~3s to bind
- `FW_SECRET_KEY` warning is cosmetic
- `debug=False` is important — `debug=True` forks a reloader process that complicates cleanup

---

## Experiment 3: Smoke Test Against Test Server

**Command:**
```bash
python3 -c "..." &  # Same Watchtower start as Experiment 2
SERVE_PID=$!
sleep 4
python3 web/smoke_test.py --port 9877 --json
kill $SERVE_PID
```

**Output (truncated):**
```json
{
  "passed": 28,
  "failed": 0,
  "total": 28,
  "errors": []
}
```

All 28 routes returned expected status codes (200 or 400 for the expected 400 on `/search/load-conversation`).

**Result: PASS**
- smoke_test.py works against a non-standard port
- `--json` flag produces machine-parseable output
- All routes pass: /, /assumptions, /cron, /decisions, /directives, /discoveries, /docs/generated, /enforcement, /fabric, /fabric/graph, /gaps, /graduation, /health, /inception, /learnings, /metrics, /patterns, /project, /quality, /risks, /search, /search/conversations, /search/feedback/analytics, /search/load-conversation, /settings/, /settings/models, /tasks, /timeline

**Gotchas:**
- smoke_test.py itself imports the app (for route discovery), so it emits the FW_SECRET_KEY warning too
- Total wall time ~15s (28 routes with some taking 1-2s each for /graduation, /timeline)

---

## Experiment 4: Log File Tailing

**Command:**
```bash
(for i in $(seq 1 5); do echo "Log line $i at $(date)"; sleep 1; done) > /tmp/test-log.txt &
LOG_PID=$!
sleep 6
cat /tmp/test-log.txt
kill $LOG_PID 2>/dev/null
```

**Output:**
```
Started log PID: 3131911
[1]+  Done  (background job completed)
--- Log contents ---
Log line 1 at Sat Mar 14 05:57:33 PM CET 2026
Log line 2 at Sat Mar 14 05:57:34 PM CET 2026
Log line 3 at Sat Mar 14 05:57:35 PM CET 2026
Log line 4 at Sat Mar 14 05:57:36 PM CET 2026
Log line 5 at Sat Mar 14 05:57:37 PM CET 2026
Exit code: 1
```

**Result: PASS**
- Background log writing works
- `cat` reads the file after the writer completes
- All 5 lines captured correctly

**Gotchas:**
- `kill $LOG_PID` exits 1 because the process already finished (5 lines x 1s = 5s, we waited 6s)
- Bash prints `[1]+  Done` job completion notice in the output
- For real test scenarios, would need to `sleep` less than the log writer duration to test mid-stream reading

---

## Experiment 5: fw init in Temp Directory

**Command:**
```bash
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init
/opt/999-Agentic-Engineering-Framework/bin/fw init 2>&1
ls -la .tasks/ .context/ .claude/ 2>/dev/null
```

**Output (key lines):**
```
Initialized empty Git repository in /tmp/tmp.NO4DHAurxq/.git/
Setting up agentic governance for tmp.NO4DHAurxq...
  ✓  Task system (.tasks/)
  ✓  Context fabric (.context/)
  ✓  Seeded: 10 practices, 18 decisions, 12 patterns
  ✓  CLAUDE.md generated
  ✓  Claude Code hooks (10 configured)
Validation passed: 34/38 checks OK (4 skipped)
  ✓  Session initialized (governance active)
  ✓  5 onboarding tasks (greenfield mode)
Done! All commands: fw help
```

All three directories created:
- `.claude/` — settings.json + commands/
- `.context/` — full working/project/episodic/handover structure
- `.tasks/` — active/completed/templates

**Result: PASS**
- `fw init` works in a fresh git repo
- Creates the full framework scaffold
- Validation passes (34/38, 4 skipped are git hooks not installed)
- Session auto-initialized with greenfield onboarding tasks

**Gotchas:**
- Must `git init` first — fw init requires a git repo
- The `rm -rf "$TMPDIR"` at the end causes `pwd: error retrieving current directory` because the cwd was deleted
- The overall exit code shows 1 because of the cleanup, not the init itself
- `cd` in Bash tool can cause issues with sandbox — subsequent calls may not find the directory

---

## Experiment 6: Test Task Gate Programmatically

**Setup:** Create a temp directory with `.context/working/focus.yaml` and `.tasks/active/`, then pipe JSON to `check-active-task.sh`.

### Test A: No active task (empty current_task)

**Command:**
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"$TMPDIR/src/main.py"}}' | \
  PROJECT_ROOT="$TMPDIR" FRAMEWORK_ROOT="/opt/999-Agentic-Engineering-Framework" \
  bash check-active-task.sh
```

**Output:**
```
BLOCKED: No active task. Framework rule: nothing gets done without a task.

To unblock:
  1. Create a task:  fw task create --name '...' --type build --start
  2. Set focus:      fw context focus T-XXX

Attempting to modify: /tmp/tmp.EEFFKy2gcO/src/main.py
Policy: P-002 (Structural Enforcement Over Agent Discipline)
EXIT_CODE_NO_TASK=2
```

**Result: PASS** — Gate correctly blocks with exit code 2.

### Test B: Active task with properly formatted ACs

When the task file has a section after `## Acceptance Criteria` (like `## Verification`), the AC parser works correctly. With a well-formed task file containing real ACs, the gate allows through.

However: if the task file has `## Acceptance Criteria` as the LAST section (no following `## ` header), the `sed` range pattern `'/^## Acceptance Criteria/,/^## [^A]/p'` captures nothing, and the AC count reads as 0, triggering a false G-020 block.

**Result: PASS (with caveat)**
- Gate correctly blocks when no task is set (exit 2)
- Gate correctly blocks when task has placeholder ACs (exit 2)
- Gate correctly allows when task has real ACs AND a following section header
- **Caveat:** The `sed` range needs a section after `## Acceptance Criteria` to work. If ACs are the last section in the file, parsing fails. This is a pre-existing issue in check-active-task.sh, not a Claude Code limitation.

### Critical Discovery: stdin requirement

The script reads JSON from stdin (`INPUT=$(cat)` on line 26). If you run it without piping input, it **hangs indefinitely** waiting for stdin. This is expected behavior for a Claude Code PreToolUse hook (which receives JSON on stdin), but means you cannot test it interactively without providing stdin.

---

## Summary Table

| # | Experiment | Result | Exit Code | Notes |
|---|-----------|--------|-----------|-------|
| 1 | Background HTTP server + poll | **PASS** | 0 | Works perfectly. Chain with `;` in single call. |
| 2 | Watchtower on test port | **PASS** | 0 | sleep 4 needed. Health endpoint responds. |
| 3 | Smoke test against test server | **PASS** | 0 | 28/28 routes pass. ~15s total. |
| 4 | Log file tailing | **PASS** | 1* | Works. *Exit 1 = kill on already-dead process. |
| 5 | fw init in temp directory | **PASS** | 0 | Full scaffold created. 34/38 validation. |
| 6 | Task gate programmatic test | **PASS** | 2/0 | Gate works. Must pipe JSON to stdin. |

## Key Findings for Self-Test Architecture

1. **Background processes work** — `&` backgrounding, `sleep`, `curl` polling, and `kill` cleanup all function within a single Bash tool call.

2. **Watchtower can be started/stopped programmatically** — Flask on a non-standard port, health check, smoke test, all work. This is the foundation for "start server, run tests, stop server" CI-like patterns.

3. **Shell state does NOT persist between Bash tool calls** — Each call gets a fresh shell. Background processes started in one call cannot be killed from another. All lifecycle (start/test/kill) must be in a single chained command.

4. **stdin-dependent scripts need special handling** — Hook scripts that read from stdin (check-active-task.sh, budget-gate.sh) must have JSON piped to them. Without it, they hang.

5. **`cd` in Bash tool can cause sandbox issues** — When a temp directory is created and cd'd into, then deleted, subsequent operations may fail. Prefer using absolute paths and environment variables (PROJECT_ROOT, FRAMEWORK_ROOT) over cd.

6. **smoke_test.py is the ideal test runner** — Already knows all routes, supports `--port` and `--json`, returns machine-parseable pass/fail counts. Perfect for CI integration.

7. **Timeout management matters** — Flask needs ~4s to start. smoke_test.py needs ~15s for 28 routes. Budget at least 30s timeout for full server lifecycle tests.

8. **Exit code interpretation** — `kill` on an already-dead process returns 1. `rm -rf` of current directory causes pwd errors. These are cosmetic, not failures. Self-test harness should handle them.
