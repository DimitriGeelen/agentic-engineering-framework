# t2919_budget_gate_command_classify

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2919_budget_gate_command_classify.bats`

## What It Does

T-2919 — the budget gate must judge the command's STRUCTURE, not scan it for
a substring.
Reported by 832 on the DM rail and reproduced here before filing. The gate
classified with `re.search` over the raw command, so anything *containing* an
allowed token anywhere was allowed at critical. Measured on the 9-case probe
below: 5/9 misclassified, both negative controls holding — the regex was not
matching everything, it was specifically defeated by composition. A trailing
`# git commit` was enough to launder `npm run build`.
Every leg drives the REAL hook end-to-end (stdin JSON -> exit code), not the
classifier module in isolation. T-1890's lesson is that this class of bug

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-gate](/docs/generated/budget-gate) | calls | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [budget-gate](/docs/generated/budget-gate) | tests | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [cmd_classify](/docs/generated/lib-cmd_classify) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2919_budget_gate_command_classify.yaml`*
*Last verified: 2026-08-11*
