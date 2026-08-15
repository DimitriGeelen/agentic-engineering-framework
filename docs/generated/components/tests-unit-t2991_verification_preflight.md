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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2991_verification_preflight.yaml`*
*Last verified: 2026-08-14*
