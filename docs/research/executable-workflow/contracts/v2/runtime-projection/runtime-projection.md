# Runtime projection contract — v1 (T-5185)

Shared contract 4 of the five agreed with 832 (AEF T-5183, 832 T-1425):
architecture-c9070637.md §"Shared versioned contracts", item 4 —
*"read-only instance/attempt/evidence state plus authenticated operator proposal types"*.

Schema: [`runtime-projection.schema.json`](runtime-projection.schema.json)
(JSON Schema draft 2020-12, `runtime_projection_version: 1`).
Pinned by `tests/unit/test_t5185_runtime_projection.py`, which validates real
responses from both endpoints (Flask test client, fixture project) against it.

## What it covers

The two endpoints AEF serves today, exactly as the code emits them. Nothing was
designed for this file; every field is derived from the code.

| Endpoint | Code | 200 body | Error bodies |
|---|---|---|---|
| `GET /api/instances?template=<map>` | `web/blueprints/designer_api.py` (T-4831) | `$defs/instances_response`: which active task sits on which `aef-task-lifecycle` node (`NODE` / `STALE` / `NO-POSITION`), plus refused files | 400 bad id, 404 unknown map → `$defs/error_response` |
| `GET /api/overlay?id=<map>` | `web/blueprints/designer.py` + `tools/corpus_overlay.py` (T-2629, T-2634) | `$defs/overlay_response`: the `aef:annotate` payload — one count badge per non-empty node bucket, with severity | 404 bad or unknown id → `$defs/error_response` |

`x-responses` in the schema maps each path and status to its `$defs` entry.

**`x-internal: true`** marks a field the Designer must not branch on: raw AEF
vocabulary (`instances[].status`), diagnostics (`examined`), and free text
(`refusals[].reason`, `nodes[].text`, `error`). Render them as text if useful;
AEF may change them without a version bump.

## Version rule

- `runtime_projection_version` lives in the schema file; neither response
  carries it on the wire today.
- **A breaking change bumps `runtime_projection_version` and is announced to
  832 before it ships.** Breaking: renaming or removing a field, adding a
  required field, changing a type, or adding or removing an enum value
  (`state`, `node`, `severity`, `type`).
- Not breaking (no bump): wording of `x-internal` fields, severity thresholds
  (7/30 days are v0 defaults), and new uids in `nodes[].uid` that come from a
  map edit.
- A change to either endpoint that the test catches is the signal: fix the
  code, or bump the version and tell 832. Never loosen the schema silently.

## Known quirks (frozen as-is, not fixed here)

- The id guards differ: `/api/instances` accepts `^[a-z0-9][a-z0-9_-]*$` and
  answers 400 on a bad id; `/api/overlay` accepts `^[a-z0-9-]{1,64}$` and
  answers 404 for both a bad and an unknown id.
- Only `aef-task-lifecycle` has instances. Any other known map answers 200
  `NO-INSTANCES` with `examined: 0`, not an error. Likewise `/api/overlay` on a
  map with no projection profile answers 200 with `nodes: []`.
- If the map's latest version is unreadable, every mapped instance is `STALE`.
- `state: NO-INSTANCES` can come with refusals: refused files do not count.
- `instances[].status` is passed through unvalidated (any string).
- Both endpoints are unauthenticated GETs.

## Not in it yet

Architecture item 4 names more than AEF serves. These are future fields; this
version does not define their shape and the Designer must not expect them:

- **Attempt projection** — read-only attempt state per instance
  (contracts v2 `attempt.schema.json`).
- **Evidence projection** — evidence references per attempt
  (contracts v2 `evidence-reference.schema.json`).
- **Workflow-instance projection** — the runner's `instance.schema.json`
  instance (`wi-…` ids, `procedure_ref`, `ledger_position`). Today's
  "instances" are task files placed on the lifecycle map, not runner
  instances; the two must not be confused.
- **Authenticated operator proposal types** — the typed proposals the Designer
  may submit back to AEF. No endpoint exists; no authentication exists on the
  projection endpoints either.

Each arrives as a new `$defs` entry under a bumped `runtime_projection_version`.

## v2 changes (T-5193)

Schema: [`runtime-projection-v2.schema.json`](runtime-projection-v2.schema.json)
(`runtime_projection_version: 2`). The v1 file above stays frozen; the live
endpoints now serve v2. Pinned by `tests/unit/test_t5193_runtime_projection_v2.py`.
Asked for by 832: Q11 (msg ccdef9f3) and msg 4fe08e05.

| Change | Where | Why |
|---|---|---|
| `runtime_projection_version: 2` on the wire | both 200 bodies | v1 carried the version in the schema file only |
| `instances[].traversed`: ordered edge uids | `/api/instances` | the overlay can draw the path the task took instead of a derived shortest path (Q11) |
| `instances[].unmapped`: `{from, to, at}` | `/api/instances` | recorded changes that fit no single edge chain are reported, never forced |
| `refusals` → `unplaced` (same items) | `/api/instances` | the old list held unparseable task *files*; the Designer reads `refusals` as *transition* refusals |
| `refusals` is always `[]` | `/api/instances` | reserved for transition refusals until AEF has a runtime that records them; keep the marker hidden while empty |

**Where `traversed` comes from.** The task file only, no git: the `## Updates`
entries that `agents/task-create/update-task.sh` writes
(`- **Change:** status: A → B`, `- **Change:** horizon: A → B`, under a dated
`### <ts> — …` header). Each entry is turned into a from-node and a to-node
with the same status+horizon table that gives `node`. A status line records
its own from-status but not the horizon in force, so the horizon is
reconstructed backwards from the current frontmatter. An entry that does not
move the node (e.g. `horizon: next → now` on a started task) adds nothing.

**Mapping a change to edges.** A change from node A to node B maps to the one
chain of map edges from A to B whose intermediate nodes are not state carriers
(gateways, `tl_start`, `tl_verify`, …). Example: `captured → started-work`
from `tl_create` is `tl_e2, tl_e14, tl_e3`. No chain, more than one chain, or
a side with no node → the change goes to `unmapped` with `at` set to the
entry's timestamp. Known unmapped classes on this repo today: `tl_work →
tl_create` and `tl_parked → tl_create` (no edge back to create in the map),
and `tl_heal → tl_work` (two chains: the direct "resolved — back to work" edge
and the detour through the completion gates; it is not guessed).

**Limits.** History written by hand or by older tooling in another format is not
read; a task whose file records nothing has both lists empty. `traversed`
reflects the map's latest version: edge uids are per-map and may change with a
map edit without a version bump.
