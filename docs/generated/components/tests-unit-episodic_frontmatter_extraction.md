# episodic_frontmatter_extraction

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/episodic_frontmatter_extraction.bats`

## What It Does

T-2731 — frontmatter extraction must be scoped to the frontmatter and must not
truncate multi-line scalars.
Origin OBS-129: .context/episodic/T-100202.yaml was unparseable. Its task file
has a body line beginning `name:` at line 248, and the generator extracted
fields with `grep "^name:" "$task_file"` — which matches the WHOLE FILE. Two
lines came back, so the emitted `task_name: "…"` scalar spanned lines.
The same bespoke grep also kept only the first physical line, so every
multi-line name was silently truncated mid-sentence and every folded
description collapsed to a bare `>`. That half never raised — it just quietly
wrote the wrong value.

---
*Auto-generated from Component Fabric. Card: `tests-unit-episodic_frontmatter_extraction.yaml`*
*Last verified: 2026-08-02*
