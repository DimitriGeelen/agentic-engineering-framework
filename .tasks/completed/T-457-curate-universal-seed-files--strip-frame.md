---
id: T-457
name: "Curate universal seed files — strip framework-specific items"
description: >
  Create filtered lib/seeds/ containing only universal items (59% of current). Keep: D-001 to D-029 (24 decisions), all 15 patterns, universal learnings. Strip: D-022+ Watchtower/deployment, L-068-076 infrastructure, framework-specific gaps. Add scope: universal marker to each item. Result: clean seed files that don't pollute consumer projects.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [init, seeds, isolation]
components: []
related_tasks: []
created: 2026-03-12T17:00:41Z
last_update: 2026-03-13T09:57:16Z
date_finished: 2026-03-13T09:57:16Z
---

# T-457: Curate universal seed files — strip framework-specific items

## Context

Seeds (`lib/seeds/`) are copied into consumer projects by `fw init`. They must contain only universal framework governance items — no project-specific decisions, patterns, or infrastructure references. Analysis shows the seed files were already curated (Feb 2026) with proper `scope: universal` markers.

## Acceptance Criteria

### Agent
- [x] `lib/seeds/decisions.yaml` contains only items with `scope: universal` — no project-specific decisions
- [x] `lib/seeds/patterns.yaml` contains only items with `scope: universal` — no project-specific patterns
- [x] `lib/seeds/practices.yaml` contains only items with `scope: universal` — no project-specific practices
- [x] Every item in all seed files has `scope: universal` and `inherited_from: framework` markers
- [x] No Watchtower/deployment/infrastructure references in seed files
- [x] All three seed files parse as valid YAML
- [x] `fw init` copies seed files correctly (init.sh references all three)

## Verification

# All 18 seed decisions have scope: universal (field, not comment)
test "$(grep -c '^    scope: universal' lib/seeds/decisions.yaml)" = "18"
# All 12 seed patterns have scope: universal
test "$(grep -c '^    scope: universal' lib/seeds/patterns.yaml)" = "12"
# All 10 seed practices have scope: universal
test "$(grep -c 'scope: universal' lib/seeds/practices.yaml)" -ge "10"
# All items have inherited_from: framework
test "$(grep -c 'inherited_from: framework' lib/seeds/decisions.yaml)" = "18"
test "$(grep -c 'inherited_from: framework' lib/seeds/patterns.yaml)" = "12"
test "$(grep -c 'inherited_from: framework' lib/seeds/practices.yaml)" = "10"
# No Watchtower/deployment/infrastructure references in seed item data
test "$(grep -ci 'watchtower\|lxc\|proxmox\|traefik' lib/seeds/decisions.yaml || true)" = "0"
test "$(grep -ci 'watchtower\|lxc\|proxmox\|traefik' lib/seeds/patterns.yaml || true)" = "0"
test "$(grep -ci 'watchtower\|lxc\|proxmox\|traefik' lib/seeds/practices.yaml || true)" = "0"
# Valid YAML
python3 -c "import yaml; yaml.safe_load(open('lib/seeds/decisions.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('lib/seeds/patterns.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('lib/seeds/practices.yaml'))"
# init.sh references all three seed files
grep -q "seeds/practices.yaml" lib/init.sh
grep -q "seeds/decisions.yaml" lib/init.sh
grep -q "seeds/patterns.yaml" lib/init.sh

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-12T17:00:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-457-curate-universal-seed-files--strip-frame.md
- **Context:** Initial task creation

### 2026-03-13T09:56:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T09:57:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
