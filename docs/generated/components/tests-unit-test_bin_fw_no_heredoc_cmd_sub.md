# test_bin_fw_no_heredoc_cmd_sub

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats`

## What It Does

T-1946 — Structural lint: bin/fw must contain ZERO heredoc-in-cmd-substitution
patterns. Third layer of L-332 / L-408 prevention (after the learnings and the
T-1945 PreToolUse edit-time WARN).
This is the strongest layer because it fails in CI/pre-push regardless of
whether the agent saw / heeded the WARN. A future edit reintroducing the
pattern cannot ship while this test is green.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_bin_fw_no_heredoc_cmd_sub.yaml`*
*Last verified: 2026-05-20*
