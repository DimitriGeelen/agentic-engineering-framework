# vendor_visibility

> T-3144 — `fw vendor` writes executable code into a consumer tree and never checked that the consumer's git could see it. Reported by 010-termlink for `tools/`; the measured set is wider.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/vendor_visibility.bats`

## What It Does

T-3144 — `fw vendor` writes executable code into a consumer tree and never
checked that the consumer's git could see it. Reported by 010-termlink for
`tools/`; the measured set is wider.
ON "FAILS AGAINST PRE-CHANGE CODE" (AC6). It does, and that measurement is
worth almost nothing: before this task `fw_vendor_check_visibility` did not
exist, so every test below fails by NameError rather than by disagreeing with
a behaviour. Same degenerate control as T-3138's lint.
The tests that carry real weight are the three marked [instrument]. Each one
is a false positive this check ACTUALLY SHIPPED WITH during T-3144, caught by
running it against real trees rather than by reading it:

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [vendor-visibility](/docs/generated/lib-vendor-visibility) | tests | T-3144: after vendoring, assert the target's git can SEE what we just wrote. |
| [corpus_explain](/docs/generated/tools-corpus_explain) | tests | T-2622: agent retrieval seam — corpus maps readable without a browser. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-vendor_visibility.yaml`*
*Last verified: 2026-08-25*
