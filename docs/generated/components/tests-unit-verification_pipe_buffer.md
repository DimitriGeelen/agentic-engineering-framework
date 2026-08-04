# verification_pipe_buffer

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/verification_pipe_buffer.bats`

## What It Does

T-2743: the capture-then-pipe idiom is SIGPIPE-safe only below the pipe buffer.
`.tasks/templates/default.md` prescribes `out=$(cmd 2>&1); echo "$out" | grep -q PAT`
as THE SIGPIPE-safe form for ## Verification (L-387), and T-2090 hardened it to
single-pipe-only. Both are correct for small captures. Above the 65536-byte pipe
buffer, with a match early in the stream, the idiom reintroduces exactly the
SIGPIPE it exists to prevent: echo blocks on the full pipe, grep -q exits on the
match, echo takes SIGPIPE, and the pipeline exits 141 under pipefail.
These tests pin the MECHANISM, not the wording of the hint. Prose can be
reworded; the 64KB threshold is a property of the kernel and of how P-011 runs
each line (`set -eo pipefail`, agents/task-create/update-task.sh).

---
*Auto-generated from Component Fabric. Card: `tests-unit-verification_pipe_buffer.yaml`*
*Last verified: 2026-08-02*
