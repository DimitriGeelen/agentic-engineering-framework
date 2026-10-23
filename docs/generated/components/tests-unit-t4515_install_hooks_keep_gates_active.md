# t4515_install_hooks_keep_gates_active

> T-4515 (G-122): T-4403 made install-hooks keep a consumer's lines from an old framework hook, but COMMENTED OUT.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4515_install_hooks_keep_gates_active.bats`

## What It Does

T-4515 (G-122): T-4403 made install-hooks keep a consumer's lines from an old
framework hook, but COMMENTED OUT. 832's two pre-commit gates stopped running
for five hours, and their installer check, which grepped for the gate's text,
still read "installed" because the text survives inside the comment.
So these tests do not look for text. In the shape 832 used (their T-1240) they
COUNT the ACTIVE (uncommented) gate lines before and after install-hooks, and
they RUN the hook to prove the gate still executes: a failing gate must block.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4515_install_hooks_keep_gates_active.yaml`*
*Last verified: 2026-10-20*
