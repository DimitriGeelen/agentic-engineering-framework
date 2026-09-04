# vendor-visibility

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/vendor-visibility.sh`

## What It Does

T-3144: after vendoring, assert the target's git can SEE what we just wrote.
`fw vendor` writes executable code into a consumer tree, and `bin/fw` then
execs several of those files by absolute path. If the consumer's `.gitignore`
hides them, they are on disk for the developer who ran the vendor and absent
for everyone who clones — and the failure surfaces as
python3: can't open file '<proj>/.agentic-framework/tools/corpus_explain.py'
not as anything that names vendoring. Reported by 010-termlink for `tools/`.
The check must run in the TARGET repo. `git check-ignore` is answered by the
consumer's `.gitignore`, which is the thing at fault; asking our own repo the
question returns a clean answer about the wrong tree.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [vendor_visibility](/docs/generated/tests-unit-vendor_visibility) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-vendor-visibility.yaml`*
*Last verified: 2026-08-25*
