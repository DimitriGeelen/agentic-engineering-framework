# drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/drift.py`

## What It Does

File reference extraction
Matches: relative paths starting with ./ or just dir/file.ext, absolute paths,
and common stems mentioned in test/grep/python -c contexts.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `lib/reviewer/audit.py` | called_by |
| `lib/reviewer/drift_cli.py` | called_by |
| `tests/unit/test_reviewer_audit_pass_a.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-drift.yaml`*
*Last verified: 2026-05-06*
