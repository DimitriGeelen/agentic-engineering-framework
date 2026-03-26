# Terminal Safety Audit: Framework Command Output Length

**Task:** T-629 Sub-audit 07 — Command Line Length Analysis
**Date:** 2026-03-26
**Scope:** All framework-generated commands checked for >80 character terminal safety

---

## Executive Summary

| Category | Total | >80 chars | Safe |
|----------|-------|-----------|------|
| Shell script echo/printf (fw/git commands) | 273 | 13 | 260 |
| `fw help` output lines | ~90 | 6 | ~84 |
| Tier 0 check messages (Python embedded) | 1 | 1 | 0 |
| `audit.sh` "Run:" remediation commands | ~50 | 1 | ~49 |
| Handover markdown output lines | ~10 | 3 | ~7 |
| Task file Steps sections (active + completed) | ~60 | 17 | ~43 |
| **GRAND TOTAL** | ~484 | **41** | ~443 |

**Verdict:** 41 framework-generated commands exceed 80 characters. The most common
offender is the inception decide command template (112 chars, appears in 5+ active
tasks via the inception template). Most script commands are safe (95%).

---

## Category 1: Shell Script Commands (echo/printf)

### Flagged (>80 chars)

| Len | File | Line | Text |
|-----|------|------|------|
| 109 | agents/handover/handover.sh | 505 | `**$PENDING_OBS pending observations ($URGENT_OBS urgent)** — run \`fw note triage\` before starting new work.` |
| 105 | lib/upstream.sh | 198 | `Usage: fw upstream report --title "Bug: description" [--body "details"] [--attach-doctor] [--dry-run]` |
| 104 | agents/context/check-active-task.sh | 334 | `FABRIC: $REL_PATH has $DEP_COUNT downstream dependent(s). Consider: fw fabric blast-radius after commit.` |
| 98 | agents/handover/handover.sh | 449 | `**$inception_count inception task(s) pending decision** — run \`fw inception status\` for details.` |
| 91 | agents/handover/handover.sh | 507 | `**$PENDING_OBS pending observations** — review with \`fw note list\` or \`fw note triage\`.` |
| 90 | lib/dispatch.sh | 42 | `fw dispatch send --host dev-server --task T-XXX --agent explore --summary "Found 3 issues"` |
| 87 | lib/bus.sh | 53 | `fw bus post --task T-XXX --agent explore --summary "Full report" --result "inline text"` |
| 85 | agents/git/lib/hooks.sh | 343 | `NOTE: $commits_since commits since $latest_tag. Consider: fw version bump patch --tag` |
| 82 | lib/update.sh | 401 | `The rollback backup has been consumed. Run 'fw update' again to re-fetch upstream.` |
| 82 | lib/upstream.sh | 396 | `fw upstream report --title "Bug: audit fails on empty task list" --attach-doctor` |
| 81 | lib/bus.sh | 54 | `fw bus post --task T-XXX --agent code --summary "Wrote file" --blob /path/to/file` |
| 81 | lib/preflight.sh | 334 | `$still_missing required dependency(s) still missing. Cannot proceed with fw init.` |
| 81 | agents/context/check-active-task.sh | 75 | `BLOCKED: Project initialized but session not active. Run 'fw context init' first.` |

### Near-misses (76-80 chars, worth watching)

| Len | File | Line | Text |
|-----|------|------|------|
| 80 | agents/termlink/termlink.sh | 446 | `fw termlink dispatch --task T-042 --name worker-1 --prompt 'Analyze auth module'` |
| 79 | agents/handover/handover.sh | 657 | `3. Commit with: fw git commit -m "T-XXX: Session handover SESSION_ID"` |
| 78 | lib/assumption.sh | 47 | `fw assumption invalidate A-002 --evidence 'Load test showed SQLite caps at 1K'` |
| 77 | lib/upgrade.sh | 649 | `2. Commit: fw git commit -m 'T-012: fw upgrade -- sync framework improvements'` |
| 76 | agents/git/lib/hooks.sh | 75 | `3. Emergency bypass (human only): fw tier0 approve && git commit --no-verify` |
| 76 | agents/git/lib/hooks.sh | 383 | `- Bypass: fw tier0 approve && git commit/push --no-verify (Tier 0 protected)` |
| 76 | agents/task-create/update-task.sh | 574 | `Finalize after verification: fw task update $TASK_ID --status work-completed` |

---

## Category 2: `fw help` Output

6 lines in `fw help` exceed 80 chars:

| Len | Line | Content |
|-----|------|---------|
| 92 | Examples | `fw deploy scaffold --app my-app --pattern swarm --port-prod 5040 --port-dev 5041` |
| 89 | Commands | `bus <cmd>            Result ledger for sub-agent dispatch (post, read, manifest, clear)` |
| 87 | Setup | `vendor               Copy framework into project .agentic-framework/ (full isolation)` |
| 86 | Setup | `termlink <cmd>       TermLink integration (check\|spawn\|exec\|status\|cleanup\|dispatch)` |
| 84 | Commands | `upstream <cmd>        Report issues to framework upstream (report, config, status)` |
| 81 | Discovery | `task list          List all tasks (filterable by --status, --type, --component)` |

---

## Category 3: Tier 0 Check Messages

The inception decision pattern in `agents/context/check-tier0.sh:144` outputs a
188-character message:

```
INCEPTION DECISION: GO/NO-GO decisions require human authority. Present your
recommendation and rationale, then ask the human to run: fw inception decide
T-XXX go|no-go --rationale "..."
```

This is not a copy-paste command (it's agent instruction text), but it contains an
embedded command suggestion that the agent will relay to the user, and that relayed
command will be the inception template command (112 chars).

---

## Category 4: `audit.sh` Remediation Commands

1 command exceeds 80 chars:

| Len | Line | Content |
|-----|------|---------|
| 83 | 2890 | `Run: fw deploy scaffold --app <name> --pattern swarm --port-prod <N> --port-dev <N>` |

All other audit "Run:" commands are under 80 chars.

---

## Category 5: Handover Markdown Output

3 lines in handover output exceed 80 chars (written to LATEST.md):

| Len | Line | Content |
|-----|------|---------|
| 107 | 505 | `**N pending observations (M urgent)** -- run \`fw note triage\` before starting new work.` |
| 96 | 449 | `**N inception task(s) pending decision** -- run \`fw inception status\` for details.` |
| 87 | 507 | `**N pending observations** -- review with \`fw note list\` or \`fw note triage\`.` |

These are markdown lines written to a file (not terminal commands), so they are
lower risk -- they won't break a paste. But they can cause wrapping in terminal
output when the handover is generated.

---

## Category 6: Task File Steps Commands

17 commands in task file Steps sections exceed 80 chars. The worst offenders:

### Inception decide template (systemic -- 112 chars)

The inception template at `.tasks/templates/inception.md:56` contains:

```
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"
```

**Length: 112 chars.** This template is copied into every inception task, and
appears in at least 5 active tasks:
- T-608 (line 97)
- T-614 (line 57)
- T-619 (line 57)
- T-625 (line 86)
- T-629 (line 57)

### Other long task commands

| Len | File | Line | Command |
|-----|------|------|---------|
| 146 | T-371 (completed) | 46 | `echo '{"tool_name":"Write"...}' \| agents/context/check-fabric-new-file.sh` |
| 144 | T-509 (completed) | 47 | `echo '{"tool_name":"Task"...}' \| agents/context/check-dispatch-pre.sh; echo $?` |
| 116 | T-621 (active) | 40 | `ssh root@192.168.10.107 "cd /opt/... && bin/fw serve stop && bin/fw serve --port 8050"` |
| 113 | T-481 (active) | 38 | `curl -fsSL https://raw.githubusercontent.com/.../install.sh \| bash` |
| 104 | T-560 (completed) | 44 | `fw doctor > /tmp/fw-doctor-t560.txt 2>&1 \|\| true; grep -q "Hook path validation" ...` |
| 100 | T-448 (active) | 37 | `cd /opt/... && curl -sf http://localhost:3000/cron \| grep -q "Run Now"` |
| 100 | T-604 (active) | 40 | `diff .context/cron/agentic-audit.crontab /etc/cron.d/agentic-audit-999-...` |
| 98 | T-544 (active) | 53 | `git tag -d v0.1.0 && git push github :refs/tags/v0.1.0 && ...` |
| 94 | T-355 (completed) | 36 | `mkdir /tmp/test-cellar && cd /tmp/test-cellar && git init && fw init ...` |
| 89 | T-617 (completed) | 37 | `cd /opt/... && bin/fw upgrade /opt/001-sprechloop --dry-run` |
| 86 | T-415 (completed) | 54 | `fw task update T-411 --status started-work 2>&1 \| grep -q ...` |
| 82 | T-352 (completed) | 35 | `mkdir /tmp/test-brew && cd /tmp/test-brew && git init && fw init ...` |

---

## Category 7: Hook Scripts — Command Suggestions

### check-active-task.sh (PreToolUse)
- Line 75: 81 chars -- `BLOCKED: Project initialized but session not active. Run 'fw context init' first.`
- Line 112: 67 chars -- safe
- Line 334: 104 chars -- fabric advisory (dynamic, includes file path and dep count)
- All "fw work-on" suggestions: 38-56 chars -- safe
- "fw task update" suggestions: 38-72 chars -- safe

### budget-gate.sh (PreToolUse)
- All "ALLOWED:" and "Action:" lines: 48 chars -- safe
- The box-drawing block output is informational, not commands -- safe

### check-tier0.sh (PreToolUse)
- Line 326: `./bin/fw tier0 approve` -- 22 chars -- safe
- Python inception message: 188 chars but it's instructional text, not a paste command

### check-dispatch-pre.sh (PreToolUse)
- All output is JSON advice text, no paste commands -- safe

### check-dispatch.sh (PostToolUse)
- Advisory text about preamble -- no paste commands -- safe

### check-agent-dispatch.sh (PreToolUse)
- Line 94: 64 chars -- safe
- Line 100: 19 chars -- safe
- Line 103: 17 chars -- safe

### error-watchdog.sh (PostToolUse)
- No command suggestions at all -- safe (just investigation reminder text)

### check-project-boundary.sh (PreToolUse)
- All output is informational block text -- no paste commands -- safe

### checkpoint.sh (PostToolUse)
- Line 151: 51 chars -- safe
- Line 159: 52 chars -- safe
- Line 184: 53 chars -- safe
- Line 198: 39 chars -- safe
- Line 204: 34 chars -- safe

### agents/git/lib/hooks.sh (git hooks)
- Line 75: 76 chars -- borderline
- Line 126: 73 chars -- safe
- Line 131: 75 chars -- borderline
- Line 343: 85 chars -- **FLAGGED**
- Line 357: 71 chars -- safe
- Line 383: 76 chars -- borderline

---

## Category 8: update-task.sh Command Suggestions

| Len | Line | Text |
|-----|------|------|
| 75 | 40 | `1. Human completes: fw task update $TASK_ID --status work-completed --force` |
| 64 | 41 | `2. Reassign first: fw task update $TASK_ID --owner agent --force` |
| 38 | 387 | `fw task update T-XXX --status captured` |
| 42 | 555 | `Run manually: fw healing diagnose $TASK_ID` |
| 76 | 574 | `Finalize after verification: fw task update $TASK_ID --status work-completed` |
| 63 | 604 | `Focus cleared (task completed). Set new focus: fw work-on T-XXX` |
| 51 | 729 | `Run manually: fw context generate-episodic $TASK_ID` |

Line 574 is borderline at 76 chars. With a real task ID like T-629, it would be 76 chars (safe). All others are safe.

---

## Root Cause Analysis

The 41 violations fall into these patterns:

### Pattern A: Inception decide template (5+ instances, 112 chars)
The biggest systemic issue. The `cd /path && bin/fw inception decide T-XXX go|no-go --rationale "..."` pattern
is 112 chars. This is baked into the inception template and propagated to every inception task.

### Pattern B: Multi-flag help/usage examples (8 instances)
Commands like `fw deploy scaffold --app <name> --pattern swarm --port-prod <N> --port-dev <N>` and
`fw upstream report --title "..." [--body "..."] [--attach-doctor]` have many flags that push length.

### Pattern C: Informational messages with embedded commands (6 instances)
Messages like "N pending observations (M urgent) -- run `fw note triage` before starting new work"
are prose + command. The prose padding pushes past 80 chars.

### Pattern D: Task-specific verification commands (17 instances)
Complex pipeline commands in Human AC Steps blocks (grep chains, SSH commands, etc.).

### Pattern E: `fw help` description padding (6 instances)
Help text uses column alignment that pushes descriptions past 80 chars.

---

## Proposed Fixes

### Fix 1: Shorten inception decide template (HIGH PRIORITY)
**Current (112 chars):**
```
cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"
```
**Proposed (split into 2 lines, each <80):**
```
cd /opt/999-Agentic-Engineering-Framework
bin/fw inception decide T-XXX go --rationale "your rationale"
```
Or use an alias: `bin/fw decide T-XXX go "rationale"` (45 chars).

Better yet, since `T-XXX` is always a placeholder, the template could say:
```
cd /opt/999-Agentic-Engineering-Framework
bin/fw inception decide T-XXX go \
  --rationale "your rationale"
```

### Fix 2: Shorten `fw help` descriptions
Truncate long descriptions or move subcmd detail to `fw <cmd> help`:
```
# Before (89 chars):
bus <cmd>            Result ledger for sub-agent dispatch (post, read, manifest, clear)
# After (54 chars):
bus <cmd>            Result ledger (post, read, manifest, clear)
```

### Fix 3: Split informational messages from commands
Instead of:
```
**N observations (M urgent)** -- run `fw note triage` before starting new work.
```
Use:
```
**N observations (M urgent)** -- triage before starting.
Run: `fw note triage`
```

### Fix 4: Add `fw shorthand` aliases for common long commands
- `fw decide` -> `fw inception decide`
- `fw scaffold` -> `fw deploy scaffold`
- This reduces the longest commands by 8-15 chars each

### Fix 5: Structural enforcement
Add a CI/lint check that scans all echo/printf lines for >80-char command output.
Could be a BATS test in `tests/e2e/` or part of `fw self-audit`.

### Fix 6: Multi-flag examples on separate lines
For help/usage examples with many flags, show them across multiple indented lines:
```
fw deploy scaffold \
  --app <name> \
  --pattern swarm \
  --port-prod <N> \
  --port-dev <N>
```

---

## Files Requiring Changes (Priority Order)

1. **`.tasks/templates/inception.md:56`** -- Inception decide command (112 chars, propagated to all tasks)
2. **`bin/fw` (help section)** -- 6 long description lines
3. **`lib/upstream.sh:198`** -- Usage line (105 chars)
4. **`agents/handover/handover.sh:449,505,507`** -- Informational markdown lines
5. **`agents/context/check-active-task.sh:334`** -- Fabric advisory (104 chars, dynamic)
6. **`lib/dispatch.sh:42`** -- Example command (90 chars)
7. **`lib/bus.sh:53-54`** -- Example commands (81-87 chars)
8. **`agents/git/lib/hooks.sh:343`** -- Version staleness note (85 chars)
9. **`agents/audit/audit.sh:2890`** -- Deploy scaffold example (83 chars)
10. **`lib/update.sh:401`** -- Informational message (82 chars)
11. **`lib/preflight.sh:334`** -- Error message (81 chars)
12. **`agents/context/check-active-task.sh:75`** -- Block message (81 chars)
