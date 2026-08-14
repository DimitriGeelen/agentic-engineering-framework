# T-2603 — Corpus spec format v1 + deterministic generator (S1 evidence)

T-2602 GO child 1/3. Delivers the declarative spec format, the `fw corpus`
deriver/generator/comparator (`tools/corpus_spec.py`), and the S1 round-trip
evidence on both served source maps. Inception artifact:
`docs/reports/T-2602-spec-driven-corpus-authoring.md`.

## Spec format v1

One YAML per map under `.context/designer/specs/<map-id>.yaml` (git-tracked —
corpus history = git history). Top-level keys:

| Key | Meaning |
|-----|---------|
| `spec_version` | format version, currently `1` |
| `id` | map id (store directory name, `^[a-z0-9][a-z0-9_-]*$`) |
| `title` | `aef:workflowMeta title` (long descriptive) |
| `pool_name` | participant/pool display name (short header shown on canvas) |
| `schema_version`, `tier_default` | `aef:workflowMeta` passthrough |
| `doc` | the definitions-level XML comment (provenance/pair-draft note) |
| `lanes[]` | `{id, name, abbr, authority, height}` — `aef:laneMeta` |
| `nodes[]` | see below |
| `flows[]` | `{id, from, to, name?, uid?}` — sequence flows |

Node entry:

```yaml
- id: agt_msg_result          # BPMN element id (stable; lane_seq_slug convention)
  lane: agent                 # lane id; drives laneSet flowNodeRef emission
  type: catch                 # start|end|service|user|gateway|catch|throw
  name: worker result on bus  # display label
  uid: dl_msg_result          # aef:uid — the cross-system stable key (T-2531 IW-1)
  pos: [620.0, 120.0]         # aef:position
  event: {kind: message, binding: bus:task-channel}   # aef:eventDef (typed events, T-204)
  meta: {note: "..."}         # aef:meta attrs verbatim (note/triggeredBy/terminalKind/state)
```

Handoff (off-page connector) entry — the contract-v0 enforcement point:

```yaml
- id: agt_7_handoff_back
  type: throw                 # throw = outgoing handoff; catch+event absent + link = incoming
  handoff:
    target: aef-task-lifecycle   # map id (preferred, readable) OR raw uuid
    link_id: ""                  # orthogonal intra-diagram throw/catch pairing axis (T-2571)
    # ghost_intent: true         # required to emit a uuid that does NOT resolve in the store
    # derived_from_legacy_form: true   # derive-time marker: source XML used targetWorkflow slug
```

**Generate always emits the ratified uuid form** `<aef:link workflowRef="<uuid>"
name="<display>" linkId="…"/>` (T-2571 offsets 108/109). A map-id target is
resolved against the store registry at generate time; an unresolvable target is
a hard refusal unless `ghost_intent: true` (the deliberate T-2584 ghost flow).
The legacy `targetWorkflow` slug form is **accepted on derive** (the corpus
contains it) and **never emitted** — deriving + regenerating a legacy map is the
migration.

## CLI

```
bin/fw corpus derive  <file.bpmn | store-map-id> [--v N] [--out spec.yaml]
bin/fw corpus generate <spec.yaml> [--version N] [--out f.bpmn]
                       [--save --url $(bin/fw watchtower url) [--save-id ID] [--note ...]]
bin/fw corpus canon   <file.bpmn | store-map-id>       # canonical semantic JSON
bin/fw corpus diff    <a> <b>                          # exit 0 iff canonically identical
```

Writes go through `/api/save` only (registry ghost-sync + ghost-task minting
fire exactly as for any author; store is never written directly). The generator
self-checks well-formedness (`ET.fromstring`) before emitting anything.

## Canonical comparator (IW-3 answer)

"Recreate = identical" means **equal canonical semantic form**: id, title,
pool_name, doc, schema/tier, lanes (sorted), nodes (sorted; type, name, uid,
pos, event, meta, handoff-target **normalized to resolved uuid**), flows
(sorted; endpoints, names, uids). Excluded: `workflowMeta version` (bumped by
`/api/save` on every write) and serialization style. Ref normalization is what
lets a legacy-authored map and its regenerated uuid-form twin compare EQUAL —
without it round-trip identity could never pass on the existing corpus.

## S1 per-element inventory (AC2)

Tag census of both served source maps (`aef-task-lifecycle` v2,
`aef-dispatch-loop` v3) vs spec representation:

| XML element | Spec carrier | Notes |
|-------------|--------------|-------|
| definitions id/targetNamespace/xmlns | derived from `id` (house style) | constant per corpus |
| top-level `<!-- ... -->` comment | `doc` | captured via comment-preserving parse |
| collaboration/participant | `id` + `pool_name` | ids derived (`Collaboration_<id>`, `Pool_<snake>`) |
| process + workflowMeta | `id/title/schema_version/tier_default` | `version` stamped at generate/save time |
| laneSet/lane + laneMeta | `lanes[]` | `LaneSet_<abbr>` id derived from map id initials |
| flowNodeRef | derived from `nodes[].lane` | emission order = node order |
| startEvent/endEvent/serviceTask/userTask/exclusiveGateway/intermediateCatchEvent/intermediateThrowEvent | `nodes[].type` | 7-value enum, both directions |
| aef:uid / aef:position / aef:meta | `uid` / `pos` / `meta` | meta attrs verbatim |
| aef:eventDef | `event` | typed-event vocabulary (T-204) |
| aef:link (both forms) | `handoff` | legacy accepted in, uuid form out |
| incoming/outgoing | derived from `flows[]` | order = flow declaration order |
| sequenceFlow (+uid, +name) | `flows[]` | |

**Zero unrepresented semantic elements.** One gap was found and closed during
S1 itself: `pool_name` (participant display name ≠ workflowMeta title) was
initially dropped and the comparator was blind to it — both fixed in the same
pass; the comparator now diffs on it.

## S1 round-trip evidence (IW-2)

All runs 2026-07-22, live store + live Watchtower (`bin/fw watchtower url`):

1. **Derive→generate→diff, both maps:** `fw corpus diff <served> <regenerated>`
   → `IDENTICAL (canonical semantic form)` for `aef-task-lifecycle` v2 AND
   `aef-dispatch-loop` v3.
2. **Contract upgrade observed:** served task-lifecycle v2 carries legacy
   `<aef:link targetWorkflow="aef-dispatch-loop" linkId=""/>`; the regenerated
   twin carries `<aef:link workflowRef="e32a518c-01de-4243-aafc-691cc99caf0d"
   name="aef-dispatch-loop" linkId=""/>` — and the two still compare IDENTICAL
   (ref normalization working as designed).
3. **Mutation detection (comparator not vacuous):** one-character name mutation
   (`worker paused?` → `worker paused??`) → diff exit 1 with the exact field.
4. **Save leg:** spec-generated task-lifecycle twin saved via
   `POST /api/save {id: t2603-roundtrip}` → `{ok:true, v:1}`; ghost registry
   before == after (only the pre-existing `398f4752` t2584 fixture); re-fetched
   `GET /api/version?id=t2603-roundtrip&v=1` → canonically IDENTICAL to the
   served original. The probe map was deleted afterwards via
   `POST /api/delete {scope: map}` (which also exercises the T-2605 delete leg
   + `remove_project_refs` registry cleanup).

## Open (AC6)

IW-1 — spec-authoritative vs canvas-authoritative + reverse export — awaits the
operator's answer; the generator's authority semantics land in `## Decisions`
of T-2603 when it does. Everything above is valid under either answer (derive
IS the reverse-export path).
