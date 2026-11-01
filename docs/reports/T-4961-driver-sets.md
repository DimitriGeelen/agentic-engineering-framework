# T-4961 — per-arc value-driver sets (`driver_set:`)

**Status:** inception, recommendation GO (narrow form); the decision is still to be recorded by the operator in Watchtower.
**Requested by:** 010-termlink (msg c39df4cd, their T-3638; their operator's ruling 2026-11-01).

## The ask

010-termlink adopts two value-driver sets:
- a DEVELOPMENT set, the live `policy/value-drivers.yaml`;
- a PRODUCT set, `policy/value-drivers-product.yaml`, with weights D1 6, D2 9, D3 7, D4 3 and free drivers F-TRUST 7, F-SURFACE 5 and F-CONV-RECALL 5.

They ask that an arc (and a task without one) can name a set, for example `driver_set: product`, resolving to `policy/value-drivers-<set>.yaml`. That set would be used by both `bvp.sh` ranking and the estimator. The protected D1-D4 keep their meaning; only the weights differ per set. Until then they score product decisions by hand, labelled "product set".

## The four blocking points they named

1. The estimator lets the live file win on collisions (`agents/termlink/bvp-estimator/estimator.py:2727-2736`).
2. D1-D4 cannot be scoped (`lib/arc-driver-review.sh` check_b).
3. Scoped weights are capped at 6, and at 3 drivers per arc (`lib/arc.sh:1567,1624`).
4. `bvp rank`, `arcs` and `detail` read only the live file (`lib/bvp.sh:285-364`).

## Dialogue log

- **2026-11-01, agent → operator:** three options were put to the operator.
  1. GO narrow: only the loading path, no new gates; design read and short review first.
  2. A design read before deciding.
  3. NO-GO: one set per project stays; the peer keeps hand-scoring.
- **Operator:** chose **"GO, narrow (Recommended)"**.
- **2026-11-01, 010-termlink (msg c7c90927):** the arc-level form covers them; their product work sits in product arcs, so **task-level naming is not needed**. They will read the design and re-vendor at the named be-tag.

## Scope of the narrow form (to be refined by the design read)

- `driver_set: <name>` on an arc YAML. A task inherits its arc's set; a task with no arc uses the live file. A task does not name a set directly (not needed by the requester, c7c90927; it stays out of the narrow form).
- The name resolves to `policy/value-drivers-<name>.yaml`. A missing file is a refusal, not a silent fall back to the live set.
- Ranking (`bvp.sh`) and the estimator read the arc's set. Weights and caps come from that set.
- D1-D4 are the same four directives in every set; only their weights change.
- No new gates, no new approval path.

## Next

1. Design read of the four points: what changes in each, and what each change touches (fabric blast radius).
2. A short independent review of the design (two internal seats, like T-4953).
3. Build slices as separate tasks; tell 010-termlink the form and the be-tag.
