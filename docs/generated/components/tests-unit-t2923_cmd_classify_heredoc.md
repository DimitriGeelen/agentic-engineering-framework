# t2923_cmd_classify_heredoc

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2923_cmd_classify_heredoc.bats`

## What It Does

T-2923 — the budget-gate classifier must not read a heredoc BODY as commands.
Found live, by the gate blocking its own author's commit: at budget-critical,
`git commit -F - <<'EOF' … EOF` was refused with
'T-2862:' is not a wrap-up command (segment: T-2862: greenfield seed fix)
— the first line of the COMMIT MESSAGE quoted back as though it were a
command. A false block on the primary wrap-up command at exactly the moment a
session is required to wrap up.
T-2919's classifier splits on `;` `&&` `||` `|` `&` and NEWLINES outside
quotes. A heredoc body is newline-separated text that is not inside shell
quotes, so every message line became a segment.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cmd_classify](/docs/generated/lib-cmd_classify) | calls | TODO: describe what this component does |
| [cmd_classify](/docs/generated/lib-cmd_classify) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2923_cmd_classify_heredoc.yaml`*
*Last verified: 2026-08-11*
