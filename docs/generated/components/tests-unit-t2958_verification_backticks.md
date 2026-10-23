# t2958_verification_backticks

> T-2958: P-011 must not eval a line whose backticks bash will command-substitute.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2958_verification_backticks.bats`

## What It Does

T-2958: P-011 must not eval a line whose backticks bash will command-substitute.
The gate evals each Verification line. Markdown writes code with backticks, so
`grep -q "``" f` reaches eval as `grep -q "" f` — matches any file — and a
code-fence regex inside "…" runs its middle as a command. Both lines PARSE, so
T-2991's preflight lets them through. T-446 shipped the collapsed-regex shape;
T-1413 escaped that one line and the rule never generalised.
The e2e test proves the refusal on evidence: the offending line would create a
file if eval'd, and the file must not exist afterwards.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2958_verification_backticks.yaml`*
*Last verified: 2026-10-20*
