# t3182_loop_exit_recorder

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3182_loop_exit_recorder.bats`

## What It Does

T-3182 (arc-012) — the continuous-run loop must say why it stopped.
Before this, every exit path out of bin/claude-fw's main loop exited in silence.
That makes "the loop stopped" and "the loop was never armed" the same observable
state: a supervisor that quit leaves exactly what a supervisor with nothing to do
leaves. Answering "why is the loop not running?" then costs process forensics on
PIDs and file mtimes, and only works while that evidence happens to survive.
These tests read the REAL wrapper — they lift its function and statically scan its
loop — so editing bin/claude-fw moves them. A test written against a transcribed
copy would stay green against a wrapper that had stopped recording entirely.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3182_loop_exit_recorder.yaml`*
*Last verified: 2026-08-26*
