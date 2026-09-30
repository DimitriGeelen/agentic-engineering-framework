---
id: T-9002
name: "Genuine short hypothesis"
workflow_type: inception
status: work-completed
---

# T-9002: Loop detector feasibility

## Hypothesis

A PostToolUse hook can detect an agent re-running the same failing command: the
hook already sees tool_input and exit status, so a rolling hash of the last five
(command, exit) pairs in .context/working is enough state. Measured on T-574's
transcript: 50 identical failing calls, all within one session, none interleaved
with a different command — a window of five would have fired on call six and
saved ~40K tokens. Disproved if any legitimate retry loop exceeds five calls.

## Acceptance Criteria

### Agent
- [x] Hypothesis tested

## Recommendation

**Recommendation:** GO
