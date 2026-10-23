# ask-py

> Python implementation of fw ask subcommand (sibling of lib/ask.sh)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/ask.py`

**Tags:** `lib`, `fw-subcommand`

## What It Does

web/ is FRAMEWORK-owned: in a vendored consumer it lives under .agentic-framework/,
not PROJECT_ROOT, so FRAMEWORK_ROOT goes first on the path (T-3783, 010 T-3336:
`fw ask` died with "No module named web" in every vendored consumer).

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [embeddings](/docs/generated/web-embeddings) | uses | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [resolver](/docs/generated/lib-resolver) | uses | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [outcome](/docs/generated/lib-outcome) | uses | Outcome enrichment — default evaluator + back-prop + read-path join. |
| [ask](/docs/generated/web-ask) | calls | LLM-assisted Q&A for Watchtower search. |
| [ask](/docs/generated/web-ask) | uses | LLM-assisted Q&A for Watchtower search. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [focus](/docs/generated/agents-context-lib-focus) | called_by | Context Agent - focus command |
| [diagnose](/docs/generated/agents-healing-lib-diagnose) | called_by | Healing Agent - diagnose command |
| [ask](/docs/generated/lib-ask) | called_by | fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection. |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | called_by | T-1719 A3 — `fw ask` routes through the Resolver, with a cloud fallback. |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | tests_by | T-1719 A3 — `fw ask` routes through the Resolver, with a cloud fallback. |

---
*Auto-generated from Component Fabric. Card: `lib-ask-py.yaml`*
*Last verified: 2026-05-06*
