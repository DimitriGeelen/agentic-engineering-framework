# run-sequence

> run-sequence.sh — T-3411. Drive N rounds of (Value Review -> procAsFit) through TermLink, sequentially, each round fed the previous round's results.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/prompt-sequence/run-sequence.sh`

## What It Does

run-sequence.sh — T-3411. Drive N rounds of (Value Review -> procAsFit)
through TermLink, sequentially, each round fed the previous round's results.
The prompts are NOT executed by the driving session. Each is dispatched to
its own TermLink worker; this script only composes, dispatches, waits, and
verifies. Strictly one worker at a time: two autonomous writers on one
working tree is the G-083 hazard, observed live on this host.
./tools/prompt-sequence/run-sequence.sh --dry-run
./tools/prompt-sequence/run-sequence.sh --rounds 5
./tools/prompt-sequence/run-sequence.sh --rounds 5 --start-round 3
Results are repo paths (T-818 — /tmp results are lost when the parent dies):

---
*Auto-generated from Component Fabric. Card: `tools-prompt-sequence-run-sequence.yaml`*
*Last verified: 2026-09-22*
