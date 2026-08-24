# focus

> Context Agent - focus command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/focus.sh`

## What It Does

Context Agent - focus command
Set or show current task focus

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ask-py](/docs/generated/lib-ask-py) | calls | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [/capture Skill](/docs/generated/capture-skill) | read_by | Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement. |
| [context-dispatcher](/docs/generated/context-dispatcher) | called-by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [/capture Skill](/docs/generated/capture-skill) | used-by | Emergency ejector seat for untracked conversations. When invoked, reads the JSONL transcript, extracts the current topic's conversation, writes a structured research artifact to docs/reports/, and commits it. Closes the governance gap where pure conversation sessions bypass all framework enforcement. |
| [context_focus](/docs/generated/tests-unit-context_focus) | called_by | Unit tests for context focus (15 tests) |
| [context_focus](/docs/generated/tests-unit-context_focus) | tests_by | Unit tests for context focus (15 tests) |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | called_by | TODO: describe what this component does |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | tests_by | TODO: describe what this component does |
| [embed_health](/docs/generated/web-embed_health) | called_by | TODO: describe what this component does |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-focus.yaml`*
*Last verified: 2026-02-20*
