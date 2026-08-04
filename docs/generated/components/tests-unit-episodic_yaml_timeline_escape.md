# episodic_yaml_timeline_escape

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/episodic_yaml_timeline_escape.bats`

## What It Does

T-2729 — the episodic generator's git-timeline rows must survive a commit
subject containing YAML-hostile characters.
Origin: closing T-2728 produced .context/episodic/T-2728.yaml that PyYAML
refused to load. The mined subject contained `\x` (from "reviewer crashes on
\x in task text") and the emitter wrote it into a DOUBLE-quoted YAML scalar
after escaping only the double quote. In a double-quoted scalar backslash is
the escape introducer: `\x` is an invalid escape (hard parser error) and `\n`
would silently become a newline instead of the two literal characters.
This is the FIFTH emission site in this one writer. T-1871 converted
decisions; T-1873 converted outcomes, challenges and artifacts — both for

---
*Auto-generated from Component Fabric. Card: `tests-unit-episodic_yaml_timeline_escape.yaml`*
*Last verified: 2026-08-02*
