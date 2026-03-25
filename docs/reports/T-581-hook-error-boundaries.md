# T-581: Hook Error Boundaries — Analysis

## Question
Should we add error boundaries to distinguish critical vs advisory hook failure modes?

## Finding
Hooks already implement error boundaries correctly via Claude Code's built-in semantics:
- **PreToolUse** = critical (fail-closed on crash = correct behavior for gates)
- **PostToolUse** = advisory (all hooks already fail open via `|| true`, explicit `exit 0`, or dependency checks)

## Audit Summary (11 hooks)

| Hook | Event | Crash-safe? | Method |
|------|-------|------------|--------|
| check-active-task | PreToolUse | Fail-closed (correct) | 15x stderr suppression |
| check-tier0 | PreToolUse | Fail-closed (correct) | 5x stderr suppression |
| budget-gate | PreToolUse | Fail-closed (correct) | 5x stderr suppression |
| check-project-boundary | PreToolUse | Fail-closed (correct) | 4x stderr suppression |
| block-plan-mode | PreToolUse | Cannot crash | 3 lines, always exit 2 |
| checkpoint | PostToolUse | Yes | exit 1 only in usage branch |
| error-watchdog | PostToolUse | Yes | Always exit 0 |
| commit-cadence | PostToolUse | Yes | Always exit 0 |
| check-fabric-new-file | PostToolUse | Yes | `|| true` wrapper |
| loop-detect | PostToolUse | Yes | Fail open if no node |
| check-dispatch-pre | PreToolUse | Yes | Fail open if Python fails |

## Recommendation
**NO-GO** — No code change needed. The event type (Pre vs Post) naturally classifies hooks as critical vs advisory.
