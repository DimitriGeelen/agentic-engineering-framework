# verification-port

> lib/verification-port.sh — hard-coded Watchtower port detection (T-2732)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verification-port.sh`

## What It Does

lib/verification-port.sh — hard-coded Watchtower port detection (T-2732)
Single definition of the predicate. Sourced by:
- agents/task-create/update-task.sh  (the P-011 close gate)
- tests/unit/verification_port_hardcode.bats
It lives here rather than inline in the gate because the regression suite has
to run the REAL predicate over the real corpus. A test that re-types the
producer's expression into a local helper can only ever check the sites its
author already knew about (L-533, from the T-2729/T-2730/T-2731 escape family).
Usage: source "$FRAMEWORK_ROOT/lib/verification-port.sh"
find_port_literals "$text"   # prints offending lines, one per line

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [comment_strip](/docs/generated/lib-comment_strip) | called_by | Structural HTML-comment stripping — the single canonical rule (T-2954). |
| [verify_queue](/docs/generated/lib-verify_queue) | called_by | T-2765: re-run stored ## Verification for the human review queue. |
| [t2921_verification_comment_strip](/docs/generated/tests-unit-t2921_verification_comment_strip) | called_by | T-2921 — the P-011 verification extractor must strip comments STRUCTURALLY. |
| [t2921_verification_comment_strip](/docs/generated/tests-unit-t2921_verification_comment_strip) | tests_by | T-2921 — the P-011 verification extractor must strip comments STRUCTURALLY. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | called_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | tests_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [t3232_verification_extractor_failure](/docs/generated/tests-unit-t3232_verification_extractor_failure) | tests_by | T-3232 — extraction FAILURE must not read as "this task has no Verification section". |
| [check-human-ac-tick](/docs/generated/agents-context-check-human-ac-tick-py) | called_by | T-1731: Human-AC tick guard hook. |

---
*Auto-generated from Component Fabric. Card: `lib-verification-port.yaml`*
*Last verified: 2026-08-02*
