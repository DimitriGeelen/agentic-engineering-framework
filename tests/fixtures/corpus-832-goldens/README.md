# 832 designer-saved goldens (T-4501, T-4502)

Copied verbatim from 832's workflow-designer repo, `tests/goldens/third-party/`
(github mirror, bleeding-edge 80eb425), `.bpmn.golden` renamed to `.bpmn`.
Third-party BPMN as 832's designer saves it — test input for
`tools/corpus_spec.py derive`, not AEF corpus maps.

- `boundary-events.bpmn` — three `bpmn:boundaryEvent`s on a subProcess and a task (T-4501)
- `multiple-diagrams.bpmn` — two `bpmn:process`es, the second in the default namespace (T-4502)
