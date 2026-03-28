#!/bin/bash
# Block built-in EnterPlanMode — bypasses framework governance (T-242)
# Use /plan skill instead (requires active task, writes to docs/plans/)
echo "BLOCKED: Built-in plan mode is disabled (bypasses framework governance)." >&2
echo "Use '/plan' skill instead (requires active task, writes to docs/plans/)." >&2
echo "If you need to explore first: create a task, then use Explore agent." >&2
exit 2
