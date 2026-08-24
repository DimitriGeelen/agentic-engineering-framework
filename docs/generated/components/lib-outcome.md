# outcome

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/outcome.py`

## What It Does

### Framework Reference

Not asserted — joined from `.context/dispatches.jsonl` (1339 dispatches) and
`.context/dispatch-outcomes.jsonl` (1838 outcome events), T-3037:

| workflow_type | N | verification pass | Dispatch? |
|---|---:|---:|---|
| refactor | 41 | 65% | Yes — best measured class |
| build | 696 | 30% | Yes, but verify the result |
| test | 66 | 83% verif / 9% AC | Yes — note the unexplained AC divergence |
| **inception** | **122** | **0%** | **Never** |

**122 inception dispatches produced zero passing outcomes.** Inceptions are
dialogue with a human; there is no prompt to write. The sharpened rule:

*(truncated — see CLAUDE.md for full section)*

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [outcome-shim](/docs/generated/lib-outcome-sh) | called_by | Thin shell shim that routes `fw outcome` invocations to lib/outcome.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [test_outcome](/docs/generated/tests-unit-test_outcome) | called_by | TODO: describe what this component does |
| [escalation-scan-v0.5](/docs/generated/tools-escalation-scan-v0-5) | called_by | TODO: describe what this component does |
| [ask-py](/docs/generated/lib-ask-py) | uses_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |

---
*Auto-generated from Component Fabric. Card: `lib-outcome.yaml`*
*Last verified: 2026-05-03*
