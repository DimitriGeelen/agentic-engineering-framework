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
