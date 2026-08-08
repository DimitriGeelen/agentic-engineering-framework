# claude_fw_copy_not_symlink

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/claude_fw_copy_not_symlink.bats`

## What It Does

T-2807 — claude-fw on PATH must be a COPY, not a symlink into $INSTALL_DIR.
install.sh puts two things on PATH and used to treat them differently: the
router was copied, claude-fw was `ln -sf "$INSTALL_DIR/bin/claude-fw"`. That
was correct while $INSTALL_DIR was permanent. T-2800 makes the fetched
framework temporary, so the symlink dangles — and what dangles is the T-179
auto-restart wrapper, whose failure mode is a session that never recovers at
budget-critical. Nothing errors; supervision just stops.
Test 3 is the one that is easy to leave out. A `cp` onto an existing symlink
follows it and writes THROUGH to the target — so an installer that "copies"
without removing first silently overwrites the global install's own

---
*Auto-generated from Component Fabric. Card: `tests-unit-claude_fw_copy_not_symlink.yaml`*
*Last verified: 2026-08-05*
