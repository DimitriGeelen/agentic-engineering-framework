# check-inception-decisions

> T-1984: inception_decisions task-frontmatter validation hook.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-decisions.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |
| [inception_decisions](/docs/generated/lib-inception_decisions) | calls | T-1984: inception_decisions / unlocks_inception_decision frontmatter parser. |
| [check-arc-id](/docs/generated/agents-context-check-arc-id-py) | calls | T-1849: arc_id task-frontmatter validation hook (T-NEW-2). |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |
| [inception_decisions](/docs/generated/lib-inception_decisions) | uses | T-1984: inception_decisions / unlocks_inception_decision frontmatter parser. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions) | called_by | T-1984: inception_decisions / unlocks_inception_decision validation hook (bash wrapper). The fw hook dispatcher (bin/fw:5639) loads .sh files; actual logic in check-inception-decisions.py. |
| [check-task-ac-structure](/docs/generated/agents-context-check-task-ac-structure-py) | called_by | T-2420: Task AC structure validation hook (implements T-2418 GO). |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-decisions-py.yaml`*
*Last verified: 2026-09-03*
