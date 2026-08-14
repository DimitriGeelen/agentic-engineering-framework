# T-2555 — designer-corpus D1: task-lifecycle diagram, compile dogfood log

Arc: designer-corpus (arc-014). Diagram: `aef-task-lifecycle` v1 (gallery,
`.context/designer/projects/aef-task-lifecycle/v1.bpmn`), saved through the live
`POST /api/save` endpoint (`{"ok":true,"v":1}`), listed by `/api/list`.
Pair-draft v1: agent-drafted; operator review/correction in the designer UI pending
(Human AC on T-2555).

## Compile run (verbatim)

Command: `bin/fw bpmn compile .context/designer/projects/aef-task-lifecycle/v1.bpmn`
Exit code: **0**. WARNs: **none**. Output:

```yaml
---
id: tl_create
name: "create task — fw work-on (status: captured)"
owner: agent
workflow_type: build
tier: 1
horizon: now
related_tasks: []
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---

---
id: tl_start
name: "start work (status: started-work, focus set)"
owner: agent
workflow_type: build
tier: 1
horizon: next
related_tasks: [tl_create]
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---

---
id: tl_work
name: "do the work; tick Agent ACs progressively"
owner: agent
workflow_type: build
tier: 1
horizon: later
related_tasks: [tl_start, tl_heal]
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---

---
id: tl_heal
name: "healing loop (status: issues → diagnose → resolve)"
owner: agent
workflow_type: build
tier: 1
horizon: later
related_tasks: [tl_work]
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---

---
id: tl_verify
name: "completion gates: Agent ACs (P-010) + ## Verification commands (P-011)"
owner: agent
workflow_type: build
tier: 1
horizon: later
related_tasks: [tl_work]
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---

---
id: tl_human_review
name: "partial-complete: review Human ACs (Watchtower /review), tick, complete"
owner: human
workflow_type: build
tier: 1
horizon: later
related_tasks: [tl_verify]
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---

---
id: tl_archive
name: "archive: move to completed/, generate episodic memory"
owner: agent
workflow_type: build
tier: 1
horizon: later
related_tasks: [tl_verify, tl_human_review]
status: captured
# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start
---
```

## Findings

1. **Loop survives.** The `issues ↔ work` back-edge (tl_f5/tl_f6) did NOT hang or break the
   flow-order walk; `tl_work` correctly lists both `tl_start` and `tl_heal` as predecessors.
2. **Owner derivation correct.** `tl_human_review` (userTask, sovereignty lane) → `owner: human`;
   all agent-lane serviceTasks → `owner: agent`. No lane/type mismatch WARNs (none expected —
   the draft is lane-clean).
3. **GAP → T-2556 (vocabulary, for 832):** this is a *documentation* diagram, but compile emitted
   7 *promotable work-plan* skeletons ("create task", "start work", … are process STEPS, not work
   items). No diagram-kind marker exists. Proposal: additive `aef:workflowMeta kind="documentation|work-plan"`.
4. **GAP → T-2557 (AEF compile reliability):** both `exclusiveGateway`s and their branch labels
   ("yes — status: issues", "yes — partial-complete") vanished silently — no WARN. Same
   silent-loss class T-2552 fixed for typed events; decision semantics deserve the same Pass-3
   visibility.
5. Minor (logged here, not tasked): start-event `triggeredBy` meta and end-event `terminalKind`
   are also dropped without surface; fold into T-2557's scope if it grows a general
   "unconsumed-annotation WARN" shape.
