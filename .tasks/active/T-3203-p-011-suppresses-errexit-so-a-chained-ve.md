---
id: T-3203
name: "P-011 suppresses errexit so a chained verification line is judged only on its
  last command, while the template tells authors to rehearse under set -eo pipefail"
description: >
  P-011 suppresses errexit so a chained verification line is judged only on its last
  command, while the template tells authors to rehearse under set -eo pipefail

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-27T21:53:09Z
last_update: 2026-08-28T13:01:14Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-27T22:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=262,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T22:00:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3203: P-011 suppresses errexit so a chained verification line is judged only on its last command, while the template tells authors to rehearse under set -eo pipefail

## Context

Reported by 832-Workflow-designer on the chat arc (offset 665) about their own
tree; verified here, because it is the same shared code.

`agents/task-create/update-task.sh:14` sets `set -euo pipefail`. Line 1215 then
runs every verification command as the **condition of an `if`**:

```
if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED; cd "$PROJECT_ROOT" && eval "$cmd") >/tmp/… 2>&1; then
```

POSIX suppresses `-e` for a compound command in an `if` condition, and the
suppression reaches inside the subshell. `pipefail` is not suppressed. Measured,
comparing the real gate shape against the rehearsal the template prescribes:

| verification line | gate | documented rehearsal |
|---|---|---|
| `false; true` | **PASS** | FAIL |
| `out=$(exit 3); echo ok` | **PASS** | FAIL |
| `grep -q nope /etc/hostname; true` | **PASS** | FAIL |
| `false \| cat` | FAIL | FAIL (pipefail survives) |

So a chained line is judged on its last element alone, while the template tells
authors to rehearse under conditions stricter than the gate applies.

**Blast radius — small, and the first number was wrong.** First count said 1025 of
10959 lines had a last element that cannot fail. That count split on `;`, took the
last fragment, and matched `^echo` — but the dominant pattern is
`out=$(cmd 2>&1); echo "$out" | grep -q PAT`, whose last element is a *pipeline*
ending in `grep`, and grep's failure IS caught because pipefail is live. Corrected
count: **15**, most of them `for`-loops the `;` split mangled, plus several
`bash -c "set -e -o pipefail; …; echo ok"` lines which are **correct** — an inner
`bash -c` is a separate shell whose errexit the outer `if` does not suppress.

So this is a documentation-vs-reality gap with a near-zero live footprint, not a
blocker. It is filed because the template actively teaches the shape it cannot
enforce, and because a live instance appeared in T-3193's own verification block
during the same session: `bin/fw release nosuchsubcmd >/dev/null 2>&1; test $? -ne 0`
passes the gate and fails the rehearsal. It was rewritten to
`if bin/fw release nosuchsubcmd >/dev/null 2>&1; then exit 1; fi`, which is correct
under both.

Related but distinct: L-240 and L-613 already record that pipefail is live. Neither
says errexit is not. That is the gap.

## Acceptance Criteria

### Agent
- [x] REPRODUCE FIRST. A probe demonstrates the divergence before anything is
      changed: the same verification line judged by the real gate shape and by the
      rehearsal the task template prescribes. If they agree, this task is wrong and
      closes as such
- [x] The task template's L-387 hint no longer claims P-011 runs commands under
      `set -eo pipefail`. It states what is actually true: **pipefail is live,
      errexit is NOT**, because the command runs as the condition of an `if`
      (`agents/task-create/update-task.sh:1215`), and POSIX suppresses `-e` for a
      compound command in an `if` condition — including inside a subshell
- [x] The template tells authors the safe shape for a multi-command line: one
      command whose own exit status is the verdict, or an explicit
      `bash -c 'set -eo pipefail; …'` sub-shell whose errexit the outer `if`
      cannot suppress. Both forms verified, not asserted
- [x] Decide and record in `## Decisions` whether the gate should be changed to
      match the docs (run each line under errexit) or the docs changed to match the
      gate. Changing the gate re-judges 10,959 existing verification lines; that
      blast radius is the argument, and it goes in the decision either way
- [x] Blast radius measured and stated with the query that produced it, so the
      number can be re-derived rather than trusted
- [x] CONTROL LEG: a line that SHOULD fail under the corrected guidance is shown
      failing, so the new advice is demonstrated to bite and not merely to read well

### Human
<!-- No Human ACs. Every claim here is a measured shell semantic with a control
     leg, so per T-1878 it belongs in ## Verification, not behind a [REVIEW]. -->

## Verification

out=$(timeout 300 bats tests/unit/t3203_p011_gate_semantics.bats 2>&1); echo "$out" | grep -q "^ok 11" && ! echo "$out" | grep -q "^not ok"
grep -q "bash -c 'set -o pipefail; <your verification line>'" .tasks/templates/default.md
if grep -q "bash -c 'set -eo pipefail; <your verification line>'" .tasks/templates/default.md; then exit 1; fi
grep -q 'JUDGED ONLY ON cmd2' .tasks/templates/default.md
grep -q '10,997 verification lines; 2,644 contain' docs/reports/T-3203-p011-gate-semantics.md
grep -q 'if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED;.*eval "\$cmd")' agents/task-create/update-task.sh

## Decisions

### 2026-08-28 — change the DOCS, not the gate

- **Chose:** correct the template and pin the gate's real semantics. The gate's
  execution shape is unchanged.
- **Why:** changing the gate to run each line under errexit would re-judge
  **2,644** of 10,997 existing verification lines (query in
  `docs/reports/T-3203-p011-gate-semantics.md`, re-derivable). Those lines were
  authored against the gate's actual behaviour, and most are correct — they put
  the assertion last. A gate change would redden an unknown fraction of them at
  once, on tasks already closed, with no author present to fix them. That is a
  mass re-judgement of settled work to satisfy a doc comment.
- **Rejected:** changing the gate to match the docs. The docs were the thing that
  was wrong; the gate has behaved consistently, and only a `;`-sequence with a
  trailing assertion is at risk — which is also the shape the corrected template
  now steers authors away from.
- **Residual, stated rather than hidden:** a line whose setup fails silently still
  passes. It is now documented, pinned and steered against at author time, but not
  prevented. Preventing it means either the gate change rejected above or a lint
  over `;`-lines; that is a separate decision with its own blast radius, and it is
  the operator's to take, not mine.

## RCA

**Symptom.** The task template told authors to rehearse a verification line with
`bash -c 'set -eo pipefail; <line>'`, and stated that P-011 "runs each line under
`set -eo pipefail`". Neither is what the gate does.

**Root cause.** The gate runs each line as the condition of an `if`
(`update-task.sh:1215`). POSIX suppresses errexit for a compound command in an
`if` condition, through the subshell. Pipefail survives; errexit does not. The
documentation described the options the *script* sets — a true statement about the
script and a false one about the line.

**Why it survived.** The divergence is one-directional: the prescribed rehearsal
only ever fails lines the gate would pass. It never let a broken line through, and
produced only false reds — which read as useful strictness rather than as error.
Meanwhile the same file already stated the correct rule further down, in the TEST
RUNNERS paragraph, so the file contradicted itself and the wrong claim came first.

**Prevention.** `tests/unit/t3203_p011_gate_semantics.bats` (11 tests) pins the
gate's real semantics, both rehearsals, the one-directional property and the
template wording — plus a guard asserting the gate's own if-condition shape at
source, so the suite cannot keep passing against a gate that has changed.
Mutations M1-M3 each reddened exactly one intended test.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-27T21:53:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3203-p-011-suppresses-errexit-so-a-chained-ve.md
- **Context:** Initial task creation
