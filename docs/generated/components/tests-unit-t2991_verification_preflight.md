# t2991_verification_preflight

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2991_verification_preflight.bats`

## What It Does

T-2991: P-011 must never eval a line bash cannot parse.
The gate is line-oriented (update-task.sh:1149,1169). A `python3 -c "` command
written across several lines is therefore not one command: line 1 is an
unterminated quote and the PYTHON BODY below it gets eval'd as bash. That put
56MB of ImageMagick PostScript into this repo's root across four incidents over
three months, because `import yaml,sys` is a valid bash line and `import` is a
screenshot tool whose last argument is its output filename (T-2990).
The load-bearing test is `the import line is never reached`. It plants a fake
`import` on PATH that TOUCHES A FILE when run — so if the preflight ever stops
working, the test fails on evidence rather than on an assertion about wording.

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verification-port](/docs/generated/lib-verification-port) | calls | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [verify_queue](/docs/generated/lib-verify_queue) | calls | TODO: describe what this component does |
| [verification-port](/docs/generated/lib-verification-port) | tests | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [verify_queue](/docs/generated/lib-verify_queue) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2991_verification_preflight.yaml`*
*Last verified: 2026-08-14*
