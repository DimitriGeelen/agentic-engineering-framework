# Framework MCP Tools Overview

The framework MCP server (shipped T-2265; tool-set classified in T-2258) exposes 22 tools
from `policy/capability-overlay/tool-set.yaml` in two access classes: 16 `read_only` and
6 `agent_authority`.

**Task management** — `task_list`, `task_show`, `review_queue`, `inception_status` (read);
`work_on`, `task_update` (write). Query and advance task lifecycle.

**Knowledge & memory** — `learnings`, `decisions`, `recall`, `ask`, `bvp_rank` (read);
`context_add_learning`, `assumption_add` (write). Access and extend project knowledge.

**Health & observability** — `metrics`, `doctor`, `gaps`, `costs`, `version`. Monitor
framework and project state passively.

**Fabric & structure** — `fabric_search`, `fabric_deps`. Navigate component topology.

**Session context** — `note`, `context_focus`. Capture lightweight observations and set
task focus.

Agent-authority tools require `task_id`. Five sovereignty-bound verbs (`bvp_confirm`,
`inception_decide`, `arc_close`, `tier0_approve`, `enforcement_baseline`) are excluded
from MCP exposure entirely.
