# T-3751: minted project_id at the sidecar circuit project level

Inception research artifact. Requested by 010-termlink (sidecar t3325-project-uuid,
@129, operator priority); run under the /decision-brief protocol (010 T-3305,
framework:pickup @294; adopted as the standing process, T-3764).

## Facts (verified 2026-10-03)

- The minted id exists: `project_id: pid-<16 hex>` in `.framework.yaml`
  (`lib/project_identity.sh`, T-3534), minted by `fw init` and `fw whoami --register`,
  back-filled by `fw upgrade` since T-3750. Ours: `pid-ffd1e8ea93077f93`.
- The project slot is two different things today:
  - path form on the wire: basename — `lib/sidecar/circuit.py:136 project_id()`,
    e.g. `//dimitrimintdev/cacc73ea32b121dd/832-Workflow-designer`;
  - V9 grammar: root path — `lib/aef_address.py:10`, ratified in T-3287 D2.
- The V9 ladder climbs agent → session → project → hub (`aef_address.py climb()`).
- Value-driver weights (`policy/value-drivers.yaml`): D1 9, D2 7, D3 5, D4 3,
  F-AUTONOMY 4 (F-RECALL 6, F1 7, F2 6, F3 7 not touched by IW-1).

## Decisions

| IW | Ruling | Date |
|----|--------|------|
| IW-1 | C — minted id in the project slot of both forms; name display-only | 2026-10-03 |

## Dialogue Log

### 2026-10-03 — IW-1 (decision 1)
- Agent correction stated first: told 010 the project level is "the folder name";
  in fact the path form uses the basename and the V9 grammar the full root path.
- Options A keep path (−25), B id only (+25), C id + display-only name (+35),
  D defer (−7). Recommendation C.
- Operator: "Okay, proceed as suggested." Read as: ruling C.
