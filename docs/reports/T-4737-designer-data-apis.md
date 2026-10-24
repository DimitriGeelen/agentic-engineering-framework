# T-4737 — Which designer data APIs should AEF serve?

Inception research artifact. The decision belongs to the operator; this file records the evidence.

## Background

Designer 0.26.0 is pinned by T-4732 and served at http://192.168.10.107:3000/designer. Once `GET /api/health` answers `{ok:true}`, it calls four further endpoints. AEF answers health today, so the designer tries all four. Operator ruling: 832 owns the designer UI; AEF serves only its data APIs.

## Contract (832 msg 047ee6a3, 2026-10-24; full version in 832 `docs/reports/T-1300-designer-data-api-contract.md`)

Common rules:
- An endpoint that is not served must answer a plain non-JSON 404. The designer reads that as "feature off" and stays quiet.
- A 200 response with any other shape is recorded as a fault.
- Id patterns: map id `^[a-z0-9][a-z0-9_-]*$`; field key and element type `^[A-Za-z][A-Za-z0-9_-]*$`.

| Endpoint | Request → response | Designer behaviour when absent |
|---|---|---|
| `POST /api/validate` | `{bpmn}` → 200 `{ok, findings:[{severity, rule, location, message}], errors, warnings}`. 400 for empty input, 503 when the validator is unavailable (never an empty list), 500 on failure. The rules come from 832's `tools/validate-workflow.py run_xml()` (stdlib), which 832 can ship with each release. | "could not check: HTTP <status>", no markers |
| `GET /api/instances?template=<id>` | 200 `{template, generated, state: INSTANCES\|NO-INSTANCES, examined, instances:[{task, state: NODE\|STALE\|NO-POSITION, node, status, owner}], refusals:[…]}`. 400 for a bad id, 404 for an unknown template. | picker shows "instances: n/a" |
| `GET/PUT /api/field-profile[?id=]` | GET → 200 `{ok, profile, scope, base:sha256}` or 404 `{ok:false, base:"none"}`. PUT `{profile, base}` → 200, 422, or 409 when the stored profile changed since it was read. | default fields; read-only settings panel |
| `GET/POST /api/field-suggestions` | GET → 200 `{ok, version:1, suggestions:[…]}`. POST `{type, key, count, total, examples, map}` creates a record only; the operator approves it into `profile.fields`. | button disabled |

## Live probe (2026-10-24, this server)

```
GET  /api/health              200 application/json {"ok":true,...}
POST /api/validate            403 text/html   (CSRF guard)
GET  /api/instances?template  404 text/html
GET  /api/field-profile       404 text/html
GET  /api/field-suggestions   404 text/html
```

All four already read as "off" under 832's rule (non-JSON, non-200). Check shows "HTTP 403" instead of 404. That is cosmetic, but if validate stays unbuilt, the route should be exempted from CSRF and answer a plain 404.

## Assessment

1. **validate — GO.** It is a thin wrapper over 832's own validator. We pin `validate-workflow.py` next to the designer build (same sha256 discipline as `policy/designer-pin.yaml`) and run it in-process. The wrapper has no rules of its own, so it cannot drift from 832. Cost: one route, one pinned file, and a sync step in `fw designer sync --from-tag`.
2. **instances — GO, scoped.** AEF tasks have a status, not a `current_node`. Only `aef-task-lifecycle` has state-carrier nodes, so the route maps a task's status and horizon to one of them and answers NO-INSTANCES for every other map. Cost: one route plus the mapping table, which the lifecycle conformance rail (T-2621) can cross-check.
3. **field-profile and field-suggestions — NO-GO for now.** These are write paths with a sovereignty-bearing approval flow (`approved_by`). Nothing recorded shows demand, and absence is already a clean state. Revisit if an operator asks for designer field settings.

832 offered its reference tests as acceptance material for whichever endpoints are built.

## Dialogue Log

- 2026-10-24: 832 (msg cc960e01) asked whether AEF plans to serve the four endpoints. The agent filed T-4737 (DEFER: contracts not yet in hand) and asked for the shapes.
- 2026-10-24: 832 (msg 047ee6a3) sent the condensed contract and offered reference tests. The agent probed the live server (table above).
- Operator dialogue: none yet. The decision is pending at http://192.168.10.107:3000/inception/T-4737
