# check-paid-backend

> check-paid-backend — PreToolUse hook (Bash): paid review backends need an approved proposal.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-paid-backend.sh`

## What It Does

check-paid-backend — PreToolUse hook (Bash): paid review backends need an approved proposal.
T-3583 operator ruling: every review or dispatch has a cost; a PAID backend (openrouter,
and anything the operator classes paid in policy/review-backends.yaml) is used only
against an approved, unused proposal for the focused task. Internal backends are allowed
and reminded to log their cost.
Detection is data, not code: each backend's `match:` regexes in the registry (default:
its id as a word). lib/review_cost.py check-command owns the verdict; this wrapper only
extracts the command and the focused task.
T-3586 rebuilt this. The T-3583 version read the command from "$1" (hooks receive JSON on
stdin, so it saw "." and never fired), read `task:` from focus.yaml (the key is

---
*Auto-generated from Component Fabric. Card: `agents-context-check-paid-backend.yaml`*
*Last verified: 2026-09-30*
