---
id: T-1754
name: "fabric enrich — add .bats parser + standalone tag for orphan scripts"
description: >
  fabric enrich — add .bats parser + standalone tag for orphan scripts

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, tests/unit/test_enrich_bats_parser.py]
related_tasks: []
created: 2026-05-05T22:02:05Z
last_update: 2026-05-05T22:11:17Z
date_finished: 2026-05-05T22:11:17Z
---

# T-1754: fabric enrich — add .bats parser + standalone tag for orphan scripts

## Context

T-1753 ran `fw fabric enrich`, dropping edgeless cards 100 → 84. Investigation showed the
residual 84 split as:
- **57× tests** — unit/playwright/governance bats files. `agents/fabric/lib/enrich.py` only
  parses `.sh` and `.py` (line 501-504). Bats files are skipped, so test-card edges (which
  always point at the system-under-test) never auto-populate.
- **7× tools/probes** — t1700-ollama-harness.sh, t1703-probe-matrix.sh, t1704-hermes3-probe.sh,
  t1706-tool-loop-probe.sh, escalation-scan-v0.5.py, g064-readiness.py, t1700 hermes3 probe.
  Genuinely standalone — no framework imports. They should be marked `standalone` rather
  than chase synthetic edges.
- **20× residual** — agent scripts, prompts, doc reports. Mixed; address opportunistically.

This task delivers (A) the bats parser, (B) a `standalone` convention for orphan scripts,
and (C) re-runs enrich to flush the gain. Targets reduction from 84 → ≤30 edgeless cards.

## Acceptance Criteria

### Agent
- [x] `agents/fabric/lib/enrich.py` recognises `.bats` files (new `detect_bats_deps`, dispatch
      branch added at line 515 — bats files routed before bash; reuses bash patterns + adds
      VAR= / `bash "$REPO_ROOT/..."` / literal-path / bare-`bin/fw` patterns)
- [x] Unit tests cover the bats parser: 9 cases in `tests/unit/test_enrich_bats_parser.py` (var
      assignment, bash invocation, bare bin/fw, literal path, empty file, no-self-ref, dedupe,
      missing-target skip, tools/python path)
- [x] `bin/fw fabric enrich` after change reduces edgeless count by ≥40 (84 → 33, -51)
- [x] 7 standalone probes/tools tagged with `standalone: true` (4 tools/probes + gpu-recover +
      api-usage + watchtower-rss-sample)
- [x] `bin/fw audit` shows the WARN line below 45 cards (was 100/543 → now 33/536, -67%;
      standalone-tagged cards excluded from total too)
- [x] `bin/fw fabric drift` clean (unregistered: 0, orphaned: 0, stale: 14 — pre-existing)

## Verification

python3 -m pytest tests/unit/test_enrich_bats_parser.py -q
bin/fw fabric drift
test "$(python3 -c "import os,yaml; n=sum(1 for f in os.listdir('.fabric/components') if f.endswith('.yaml') and (lambda d: not (d.get('depends_on') or []) and not (d.get('depended_by') or []))(yaml.safe_load(open(os.path.join('.fabric/components', f))) or {})); print(n)")" -lt 45

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

### 2026-05-06 — bats parser uses `tests` edge type, not `calls`
- **Chose:** Edges from bats files use `type: "tests"` (semantic — this is a test of X)
- **Why:** Reverse-edge readers can filter "what tests me?" via `tests` type; `calls` already
  used for runtime dependency. Distinct types preserve the directional semantics.
- **Rejected:** Reuse `calls` — would conflate test-coverage edges with runtime invocations
  in `depended_by` lists.

### 2026-05-06 — `standalone: true` audit-skip flag, not synthetic edges
- **Chose:** Audit excludes cards with `standalone: true` from edgeless count
- **Why:** Probe scripts (t1700-t1706, gpu-recover, api-usage) are standalone by design —
  no framework imports. Inventing synthetic edges would lie about the topology; excluding
  them from the metric is honest.
- **Rejected:** Force every card to have ≥1 edge — would require adding fake `bin/fw` edges
  to scripts that don't actually depend on it, polluting the graph.

## Recommendation

**Recommendation:** GO (auto-close)
**Rationale:** Two structural improvements (bats parser + standalone flag) reduce persistent
audit WARN by 67% and preserve graph honesty. All ACs pass.
**Evidence:**
- enrich.py: `detect_bats_deps` at line 162-220, 64 lines added
- audit.sh: `standalone: True` skip added at line 642 (3 lines)
- Test coverage: 9/9 pass (`tests/unit/test_enrich_bats_parser.py`)
- Edgeless reduction: 100/543 → 33/536 (cumulative with T-1753, -67%)
- Subsystem coverage: tests +156 edges, context-fabric +36, audit +13, task-management +11
- Standalone tags: 7 cards correctly classified as by-design orphans
- Drift clean: unregistered 0, orphaned 0, stale 14 (pre-existing)

## Updates

### 2026-05-05T22:02:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1754-fabric-enrich--add-bats-parser--standalo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e137c67
- **Timestamp:** 2026-06-02T14:59:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/fabric/lib/enrich.py` recognises `.bats` files (new `detect_bats_deps`, dispatch
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/fabric/lib/enrich.py in: `agents/fabric/lib/enrich.py` recognises `.bats` files (new `detect_bats_deps`, dispatch`
### 2026-05-05T22:11:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
