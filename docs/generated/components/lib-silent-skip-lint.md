# silent-skip-lint

> T-4219: the Silent-Skip lint step of `fw test lint` (T-3217).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/silent-skip-lint.sh`

## What It Does

T-4219: the Silent-Skip lint step of `fw test lint` (T-3217).
fw_silent_skip_lint <framework_root>
Scans <framework_root>/tests/ for bats tests that skip silently.
rc 0 — clean, or NOT APPLICABLE: a vendored copy (.agentic-framework/) ships
no tests/, so there is nothing of the framework's to scan. Before
T-4219 that case read as "the scan examined nothing" and failed
`fw test lint` in every consumer.
rc 1 — silent skips found, or the scan examined nothing although tests/
exists (the linter's own exit 2): not a pass.
Prints its own section header and result line.

---
*Auto-generated from Component Fabric. Card: `lib-silent-skip-lint.yaml`*
*Last verified: 2026-10-16*
