# T-4502: 832 designer-saved goldens through corpus derive / generate (plain task counts)

**Source:** 832's workflow-designer repo, `tests/goldens/third-party/*.bpmn.golden`
(github mirror, bleeding-edge 80eb425). These were handled as untrusted data: they were
parsed only, and two were copied to `tests/fixtures/corpus-832-goldens/` as fixtures.

**What is counted:** `bpmn:task` elements, i.e. the plain untyped activity (T-4488)
and not typed tasks.
- **in**: every `bpmn:task` anywhere in the source document, across all processes.
- **derived**: nodes of type `task` in the spec from `parse_map`, which is what `corpus_spec derive` emits.
- **generated**: `bpmn:task` in `emit_map(spec)`, which is what `corpus_spec generate` emits.

**When:** 2026-10-20. "Before" is `tools/corpus_spec.py` at 009901a82 (before T-4496);
"after" is the same file with T-4496, T-4501 and T-4502 applied.

## After (T-4496 + T-4501 + T-4502)

| golden | in | derived | generated | note |
|---|---:|---:|---:|---|
| bizagi-nested-ns | 1 | 1 | 1 | stderr warning: drops the empty second process `Id_f2afc6ec-…` ("Hauptprozess"). It holds only an empty `<documentation/>` and an empty laneSet. |
| boundary-events | 3 | 3 | 3 | 3 boundaryEvents round-trip; canonical diff IDENTICAL (T-4501) |
| collaboration-message-flows | 2 | REFUSED | – | `Process_2` (a message startEvent) would be dropped, so it now refuses (T-4502) |
| i18n-documentation | 1 | 1 | 1 | |
| kitchen-sink | 7 | REFUSED | – | gets past boundaryEvent, then refuses at `bpmn:manualTask id="lan_4_activity"`. This is the next unsupported tag, not filed here. |
| multiple-diagrams | 2 | REFUSED | – | `Process_2` (Task_B) would be dropped, so it now refuses (T-4502) |
| simple | 1 | 1 | 1 | |
| zeebe-service-task | 1 | 1 | 1 | |

## Before (009901a82)

| golden | in | derived | generated | note |
|---|---:|---:|---:|---|
| bizagi-nested-ns | 1 | 1 | 1 | empty second process dropped, no word |
| boundary-events | 3 | REFUSED | – | unsupported `bpmn:boundaryEvent` |
| collaboration-message-flows | 2 | 2 | 2 | **silent loss**: the task counts match, but `Process_2`'s startEvent was dropped with exit 0 |
| i18n-documentation | 1 | 1 | 1 | |
| kitchen-sink | 7 | REFUSED | – | unsupported `bpmn:boundaryEvent` |
| multiple-diagrams | 2 | 1 | 1 | **silent loss**: Task_B dropped, exit 0 (the T-4502 report) |
| simple | 1 | 1 | 1 | |
| zeebe-service-task | 1 | 1 | 1 | |

## Reading

- No golden now goes from "in" to a lower count with exit 0. Every lossy case either refuses
  or, for the bizagi shell that holds no content, warns on stderr.
- collaboration-message-flows shows why a task count alone is a weak check: the counts were
  2/2/2 while a whole process was being discarded. The refusal keys on process content,
  not on the task count.
- Still open, and outside these three tasks:
  1. `bpmn:manualTask` (kitchen-sink).
  2. Multi-process or multi-pool documents can only be refused, not represented. The
     collaboration's second participant and its messageFlows are a separate, pre-existing gap.

Re-derive: run `parse_map` / `emit_map` over each golden and count
`{http://www.omg.org/spec/BPMN/20100524/MODEL}task` with ElementTree `iter()` on the
source and the output, and nodes with `type == "task"` in the spec.
