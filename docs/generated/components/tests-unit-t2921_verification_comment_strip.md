# t2921_verification_comment_strip

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2921_verification_comment_strip.bats`

## What It Does

T-2921 — the P-011 verification extractor must strip comments STRUCTURALLY.
The block this extractor produces is handed to `eval`. So `<!--` opening a
line is prose to discard, and the same delimiter inside a line is argument
text belonging to a command. The pre-fix whole-block
`re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)` could not tell them apart:
* mangled  — `sed '/<!--/,/-->/d' f` became `sed '/d' f` (errors; loud)
* deleted  — `.*?` spans newlines under DOTALL, so a mid-line `<!--` pairs
with the NEXT `-->` below, deleting every command between them
BEFORE `wc -l` counts them. The gate then prints "N/N passed"
over a population it silently shrank. Quiet, and worse.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verification-port](/docs/generated/lib-verification-port) | calls | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [verification-port](/docs/generated/lib-verification-port) | tests | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2921_verification_comment_strip.yaml`*
*Last verified: 2026-08-12*
