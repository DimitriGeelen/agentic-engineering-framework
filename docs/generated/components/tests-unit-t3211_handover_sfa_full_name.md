# t3211_handover_sfa_full_name

> T-3211 — handover's "Suggested First Action" truncated the task name at the first physical line of a folded/quoted multi-line YAML `name:` scalar (the template's normal shape for long names), leaving an unclosed opening quote.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3211_handover_sfa_full_name.bats`

## What It Does

T-3211 — handover's "Suggested First Action" truncated the task name at the
first physical line of a folded/quoted multi-line YAML `name:` scalar (the
template's normal shape for long names), leaving an unclosed opening quote.
Root cause (agents/handover/handover.sh, Suggested First Action block,
formerly ~line 1341): `re.search(r'^name:\s*(.+)', content, re.M)` reads
only the first physical line. Fixed by parsing the frontmatter as YAML
(falling back to joining indented continuation lines when it doesn't
parse) via a local `extract_frontmatter_name()` helper.
Same _selector extraction technique as tests/unit/t3210_handover_suggested_action.bats
(carves the shipped `$(python3 -c "...")` block out of handover.sh and runs

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3211_handover_sfa_full_name.yaml`*
*Last verified: 2026-09-22*
