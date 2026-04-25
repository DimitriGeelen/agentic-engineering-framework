# T-1141 — PL-007 Enforcement: Always Use fw task review

## The Problem

Agents output bare CLI commands (e.g., `fw inception decide T-XXX go --rationale "..."`)
instead of using `fw task review T-XXX` which opens Watchtower with QR code, recommendation
display, and one-click decision UI.

Reported 3+ times across sessions. The TermLink project (010-termlink) reports the agent
violated PL-007 within 3 minutes of BUILDING the PL-007 enforcement itself (T-972).

## Root Causes

### RC-1: Framework gate scripts output bare commands
- `update-task.sh` sovereignty gate: "fw task update T-XXX --status work-completed --force"
- `inception.sh` review gate: "cd $PROJECT_ROOT && bin/fw task review $task_id"
- `check-tier0.sh` approval: "./bin/fw tier0 approve"

**Partial fix already applied (T-1143):** Replaced hardcoded `bin/fw` with `_emit_user_command()`
helper. But the scripts still output commands — they should invoke `fw task review` UX flows
instead of telling the user to type commands.

### RC-2: No governance over agent text output
Claude Code has no PreTextOutput or PostMessage hook. Agent prose (including relayed error
messages) is entirely ungoverned. This is a platform limitation, not fixable in the framework.

### RC-3: CLAUDE.md already has the rule
CLAUDE.md §Presenting Work for Human Review already says:
"NEVER give raw CLI commands for human approvals" and "ALWAYS use fw task review T-XXX"

The rule exists. Agents forget it after compaction. The only structural fix is making
the gate scripts themselves invoke the right UX, so even if the agent relays the output
verbatim, the human sees the Watchtower URL, not a CLI command.

## What's Already Fixed

| Fix | Task | Status |
|-----|------|--------|
| `_fw_cmd()` helper in lib/paths.sh | T-1143 | Done |
| `_emit_user_command()` helper | T-1143 | Done |
| 3 hardcoded `bin/fw` sites fixed | T-1143 | Done |
| Narrow `--skip-sovereignty` flag | T-1142 | Done |
| Error messages use narrow flag names | T-1142 | Done |

## What Remains

1. **Gate scripts should invoke `fw task review` instead of printing commands.**
   The sovereignty gate in `update-task.sh` could call `emit_review` directly instead of
   printing "run: fw task update T-XXX --status work-completed --skip-sovereignty"

2. **PostToolUse hook to detect bare command patterns.**
   A hook that scans tool output for patterns like `fw inception decide` and warns could
   catch violations at runtime. But this requires scanning text output, which is noisy.

3. **Consolidate T-1141 and T-1146.**
   Both are about the same systemic issue. T-1146 adds the lib/watchtower.sh shared helper.
   These should be one build task.

## Recommendation

**Recommendation:** GO — but consolidate with T-1146 into one build task.

The structural fix is making gate scripts invoke UX flows instead of outputting commands.
The T-1143/T-1142 fixes were step 1 (right command form). Step 2 is making gates call
`emit_review` / `fw task review` directly. This is a ~50-line change across 3 files.

**Evidence:**
- 3+ incidents across sessions of agents relaying bare commands
- T-972: agent violated PL-007 within 3 minutes of building it
- CLAUDE.md rule exists but doesn't survive compaction
- Root cause is framework scripts, not agent behavior
- T-1143 partial fix already applied, further fixes are incremental
