# episodic_yaml_decision_escape

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/episodic_yaml_decision_escape.bats`

## What It Does

T-1871 — episodic generator must emit valid YAML when ## Decisions content
contains YAML-double-quote-hostile characters (backticks, backslashes,
embedded quotes, escape sequences).
L-392 class: double-quoted YAML scalars process escape sequences like `\X`
and reject unknown ones, so embedding a markdown code-span like
`markdown2.markdown(f"\`\`\`{lang}…\`\`\`")` blows up yaml.safe_load on the
generated artefact. Fix: emit decision fields as single-quoted YAML scalars
(only escape is '→''), which pass everything else through verbatim.
Witness: T-1764 close 2026-05-16 → .context/episodic/T-1764.yaml line 47
rejected with "found unknown escape character `\``".

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [episodic](/docs/generated/agents-context-lib-episodic) | calls | Context Agent - generate-episodic command |
| [episodic](/docs/generated/agents-context-lib-episodic) | tests | Context Agent - generate-episodic command |
| [shared](/docs/generated/web-shared) | tests | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [extract_decisions](/docs/generated/agents-context-lib-extract_decisions) | calls | TODO: describe what this component does |
| [extract_decisions](/docs/generated/agents-context-lib-extract_decisions) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-episodic_yaml_decision_escape.yaml`*
*Last verified: 2026-05-16*
