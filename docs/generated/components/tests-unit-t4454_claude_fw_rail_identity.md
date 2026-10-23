# t4454_claude_fw_rail_identity

> T-4454 — claude-fw must register its TermLink session with the PROJECT key.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4454_claude_fw_rail_identity.bats`

## What It Does

T-4454 — claude-fw must register its TermLink session with the PROJECT key.
TermLink registration reads TERMLINK_IDENTITY_FILE with the same precedence as
signing. claude-fw spawned claude-master-$$ without it, so the session carried the
HOST identity while every signing path used the project's RAIL_IDENTITY_FILE.
A fake termlink on PATH records the identity env it sees at `spawn`.
Never set the variable for a missing key: TermLink would mint a keypair there.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4454_claude_fw_rail_identity.yaml`*
*Last verified: 2026-10-20*
