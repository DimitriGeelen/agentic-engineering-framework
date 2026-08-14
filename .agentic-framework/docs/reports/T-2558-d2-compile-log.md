# T-2558 — designer-corpus D2: inception-flow diagram, compile dogfood log

Arc: designer-corpus (arc-014). Diagram: `aef-inception-flow` v1 (gallery, saved via live
`POST /api/save` → `{"ok":true,"v":1}`). Pair-draft v1: agent-drafted; operator UI review
pending (Human AC on T-2558).

## Compile run (verbatim WARN stream + skeleton summary)

Command: `bin/fw bpmn compile .context/designer/projects/aef-inception-flow/v1.bpmn`
Exit 0. Skeletons: 5 — `if_file`, `if_artifact` (agent/build), `if_inception`
(**human/inception** — the T-2549 collapsed-subProcess dialect materializes correctly),
`if_children`, `if_archive` (agent/build). WARNs:

```
WARN: node 'agt_gw_outcome' is a exclusiveGateway ('decision?') with branches [GO → agt_4_children; NO-GO / DEFER → agt_5_archive] — decision semantics are not representable in AEF task skeletons (T-2557); surfaced here, not applied
```

## Findings

1. **T-2557 fix validated on first post-fix corpus diagram:** exactly 1 gateway WARN
   (`agt_gw_outcome`, both branch labels GO / NO-GO+DEFER with targets). The decision
   semantics loss is now visible, per the arc's zero-silent-drops headline.
2. **Inception vocabulary round-trips:** sovereignty-laned collapsed subProcess →
   `owner: human, workflow_type: inception` skeleton with constituents carried — the
   G-3 ratified form covers the real inception flow without extension.
3. **No new gap class surfaced.** The known T-2556 gap applies here identically (this is
   also a documentation diagram compiling to promotable skeletons); no new filing needed —
   the diagram-kind marker remains the open vocabulary item awaiting 832's disposition.
