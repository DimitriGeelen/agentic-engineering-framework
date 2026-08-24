# root-pollution

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/root-pollution.sh`

## What It Does

T-2990 — root-level pollution detector.
Four ImageMagick PostScript files accumulated in the repo root over three
months ('os' 36MB, 'sys' 14MB, 'yaml,sys' 6.8MB, 'yaml' 5.9KB) without anything
noticing. They were written by the framework's own P-011 verification gate:
it evals each LINE of the Verification section separately, so the Python body
of a multi-line inline-python command runs as bash, and 'import yaml,sys'
reaches ImageMagick's screenshot tool — which writes to the repo root, the
gate's cwd. (Quotes here are deliberately plain, not backticks: this file is
scanned by tests/lint/no-backticks-in-inline-python.bats, and prose ABOUT an
inline-python command trips it just as real code would.)

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t2990_root_pollution](/docs/generated/tests-unit-t2990_root_pollution) | called_by | TODO: describe what this component does |
| [t2990_root_pollution](/docs/generated/tests-unit-t2990_root_pollution) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-root-pollution.yaml`*
*Last verified: 2026-08-14*
