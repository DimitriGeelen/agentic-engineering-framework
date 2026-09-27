# episodic

> Context Agent - generate-episodic command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/episodic.sh`

## What It Does

Context Agent - generate-episodic command
Generate rich episodic summary for a completed task
Hybrid approach (D-023): Git owns timeline/metrics/artifacts,
task file owns AC + decisions, episodic merges both automatically.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-write-index](/docs/generated/lib-post-write-index) | calls | Post-write vector-index hook — T-1719 A1. |
| [yaml](/docs/generated/lib-yaml) | calls | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |

## Used By (14)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context-dispatcher](/docs/generated/context-dispatcher) | called-by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | called_by | Unit tests for context episodic (11 tests) |
| [context_episodic](/docs/generated/tests-unit-context_episodic) | tests_by | Unit tests for context episodic (11 tests) |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | called_by | T-1871 — episodic generator must emit valid YAML when ## Decisions content contains YAML-double-quote-hostile characters (backticks, backslashes, embedded quotes, escape sequences). |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | tests_by | T-1871 — episodic generator must emit valid YAML when ## Decisions content contains YAML-double-quote-hostile characters (backticks, backslashes, embedded quotes, escape sequences). |
| [episodic_frontmatter_extraction](/docs/generated/tests-unit-episodic_frontmatter_extraction) | called_by | T-2731 — frontmatter extraction must be scoped to the frontmatter and must not truncate multi-line scalars. |
| [episodic_frontmatter_extraction](/docs/generated/tests-unit-episodic_frontmatter_extraction) | tests_by | T-2731 — frontmatter extraction must be scoped to the frontmatter and must not truncate multi-line scalars. |
| [episodic_yaml_timeline_escape](/docs/generated/tests-unit-episodic_yaml_timeline_escape) | called_by | T-2729 — the episodic generator's git-timeline rows must survive a commit subject containing YAML-hostile characters. |
| [episodic_yaml_timeline_escape](/docs/generated/tests-unit-episodic_yaml_timeline_escape) | tests_by | T-2729 — the episodic generator's git-timeline rows must survive a commit subject containing YAML-hostile characters. |
| [t1719_post_write_index](/docs/generated/tests-unit-t1719_post_write_index) | called_by | T-1719 A1 — the post-write index hook, and the boundary of where it may be wired. |
| [t1719_post_write_index](/docs/generated/tests-unit-t1719_post_write_index) | tests_by | T-1719 A1 — the post-write index hook, and the boundary of where it may be wired. |
| [episodic_footprint](/docs/generated/lib-episodic_footprint) | called_by | Re-mine an episodic's git footprint AFTER the completion commit exists (T-3130). |
| [episodic_worktree_mining](/docs/generated/tests-unit-episodic_worktree_mining) | tests_by | T-3129 — episodic git mining in a LINKED GIT WORKTREE, and the shape of a skipped measurement. |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-episodic.yaml`*
*Last verified: 2026-02-20*
