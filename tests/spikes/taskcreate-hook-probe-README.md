# TaskCreate Hook Probe — Fresh-Session Verification Spike

**Task:** T-1115 (inception) / T-1116 (build). Verifies whether Claude
Code fires `PreToolUse` hooks on its built-in `TaskCreate` /
`TaskUpdate` / `TaskList` / `TaskGet` tools. This is the must-verify
evidence gate before committing to Phase 2 of T-1115 (Level 1 block
hook vs CLAUDE.md-rule-plus-PostToolUse-scanner fallback).

## Why a spike (not an in-session test)

Claude Code hooks are snapshotted at session start. Mid-session edits
to `.claude/settings.json` do NOT take effect until restart. That's
why this is a spike for a fresh session, not a live test.

## Prerequisites

- The repo is cloned and you have `bash` + the `fw` CLI on PATH
- You are NOT in the middle of precious uncommitted work — a fresh
  session means you close your current one

## Step-by-step

1. **Commit/stash your current work.**
   You'll need to exit your current Claude Code session. If anything
   is uncommitted and important, commit it first.

2. **Merge the hook fragment into `.claude/settings.json`.**

   Single-line copy-paste command (backs up settings.json, merges the
   PreToolUse entry using jq, preserves all other hooks):

   ```
   cd /opt/999-Agentic-Engineering-Framework && cp .claude/settings.json .claude/settings.json.pre-t1116 && jq '.hooks.PreToolUse += (.hooks.PreToolUse // []) | .hooks.PreToolUse += [{"matcher":"TaskCreate|TaskUpdate|TaskList|TaskGet","hooks":[{"type":"command","command":"/opt/999-Agentic-Engineering-Framework/tests/spikes/taskcreate-hook-probe.sh"}]}]' .claude/settings.json.pre-t1116 > .claude/settings.json && python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "Merged OK"
   ```

   If `jq` isn't available, edit `.claude/settings.json` by hand —
   copy the PreToolUse entry from
   `tests/spikes/taskcreate-hook-probe-settings-fragment.json` and
   append it to the existing `hooks.PreToolUse` array.

3. **Clear any previous probe log.**

   ```
   cd /opt/999-Agentic-Engineering-Framework && rm -f .context/working/.taskcreate-probe.log
   ```

4. **Exit the current Claude Code session.**
   `/exit` or close the terminal. Hooks only snapshot at startup.

5. **Start a fresh Claude Code session.**
   `cd /opt/999-Agentic-Engineering-Framework && claude`

6. **Invoke a harmless built-in task tool call.**
   In the fresh session, ask Claude to do one of:
   - "Show me your current todo list" (likely triggers `TaskList`)
   - "Add a TODO: test the spike" (likely triggers `TaskCreate`)
   - "What tasks are pending?" (may trigger `TaskList` / `TaskGet`)

   Claude may refuse due to the framework governance rules. That's
   OK — you can override with "this is a spike — please make the
   tool call for the test". The probe is no-op, so letting it fire
   does no harm.

7. **Check the probe log.**

   ```
   cd /opt/999-Agentic-Engineering-Framework && cat .context/working/.taskcreate-probe.log 2>&1
   ```

   **Result A — log contains one or more lines:**
   PreToolUse fires on Task* tools. Hookability is CONFIRMED.
   → Report "Result A" on T-1116 and proceed to Phase 2 Level 1
     implementation (block-task-tools.sh).

   **Result B — log empty or missing:**
   PreToolUse does NOT fire on Task* tools. Hookability is DENIED.
   → Report "Result B" on T-1116 and proceed to Phase 2 fallback
     (CLAUDE.md §Built-in Task Tool Ban rule + PostToolUse scanner).

8. **Restore your settings.json (cleanup).**

   ```
   cd /opt/999-Agentic-Engineering-Framework && mv .claude/settings.json.pre-t1116 .claude/settings.json
   ```

   Leave the spike files in `tests/spikes/` — they're committed and
   serve as the invariant-test template for Phase 2.

## What you should see

### Result A example (hooks fire)

```
$ cat .context/working/.taskcreate-probe.log
2026-04-12T09:14:22Z pid=82341 argv=[] stdin={"session_id":"...","hook_event_name":"PreToolUse","tool_name":"TaskList","tool_input":{},"cwd":"...","permission_mode":"default"}
```

Single line per invocation. The `tool_name` field in the stdin JSON
tells us which Task* tool fired.

### Result B example (hooks don't fire)

```
$ cat .context/working/.taskcreate-probe.log
cat: .context/working/.taskcreate-probe.log: No such file or directory
```

Or the file exists but is empty. Either way: no PreToolUse fired for
the Task* tool.

## Interpretation notes

- **Partial hookability** is possible: PreToolUse may fire on
  `TaskCreate` but not `TaskList` (or vice versa). If the log shows
  entries for some tools but not others, document which tools fired
  and which didn't — Phase 2 design will depend on the partial
  coverage.
- **Matcher sensitivity**: if the log is empty, try changing the
  matcher from `TaskCreate|TaskUpdate|TaskList|TaskGet` to just
  `.*` (match all tools). If `.*` catches the Task* calls and the
  specific matcher doesn't, that's a matcher-parsing bug worth
  filing upstream.
- **JSON output schema spike** (optional follow-up): once we know
  hooks fire, the next question is whether `updatedInput` silently
  rewriting the args on a Task* tool actually takes effect. That's
  a separate spike, deferred to Phase 2 design.

## References

- Research artifact: `docs/reports/T-1115-anthropic-task-tool-prehook.md`
- Prior art (pattern template): `agents/context/block-plan-mode.sh`
- GitHub issue (human's RFC): https://github.com/anthropics/claude-code/issues/45427
