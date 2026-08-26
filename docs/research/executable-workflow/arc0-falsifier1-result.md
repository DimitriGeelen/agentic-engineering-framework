# EWCR Arc 0 — Falsifier 1 result

**Task:** T-3147 · **Arc:** arc-019 (draft) · **Date:** 2026-08-26
**Commit measured:** `ce2987fd20e2b0477658521d7e3e826d9fc184d2`
**Reproduce:**

```
python3 tools/ewcr-arc0-unknown-overlap.py     # the overlap
python3 tools/ewcr-arc0-coverage-check.py      # the control
```

## Verdict

> **fence-1 blocking (3 components in the write set)**

Under the BROAD write set the figure is 4. The intersection is **not** empty, so the
"not blocking" branch does not apply.

**But the count is not the decision-relevant part of this measurement, and reporting
it alone would mislead.** See the control below.

## Numbers

| Measure | Value |
|---|---|
| Fabric cards enumerated | 1121 |
| `Unknown`-subsystem cards | 519 |
| ...carrying no location | 0 |
| Intersection with CORE write set | **3** (0.6% of Unknown) |
| Intersection with BROAD write set | **4** (0.8% of Unknown) |

The three CORE components:

- `agents/dispatch/single-host-parallel-demo.sh`
- `agents/dispatch/yield-point.sh`
- `policy/standards/aef-bpmn-mapping-v1-partI.md`

### Where the 519 actually live

| Root | Count |
|---|---|
| `tests` | 453 |
| `tools` | 31 |
| `agents` | 20 |
| `docs` | 9 |
| everything else | 6 |

**87% of the Unknown population is `tests/`.** The dossier's C1 disposition treated 512
unclassified components as a barrier to implementation decomposition. They are
overwhelmingly test files, which the runtime does not write and which carry no
blast-radius signal for it.

## The control, and why it changes the reading

A low overlap has two possible meanings, and they are opposite:

1. the runtime write set is **well classified** → fence 1 nearly passable;
2. the runtime write set is **barely in the Fabric** → fence 1 not measurable at all.

Both produce a low number. Reading (1) off the overlap alone would be a false green of
exactly the kind this programme exists to remove. `ewcr-arc0-coverage-check.py`
discriminates them:

| Root | files on disk | with a card | coverage | card = Unknown |
|---|---:|---:|---:|---:|
| `lib` | 152 | 132 | 86.8% | **0** |
| `web` | 163 | 133 | 81.6% | **0** |
| `agents` | 137 | 112 | 81.8% | 17 |
| `bin` | 9 | 9 | 100.0% | 0 |
| `policy` | 8 | 0 | **0.0%** | 0 |

**`lib`, `web` and `bin` are genuine.** High coverage, zero Unknown — the low overlap
there is real, not an artefact.

**`policy/` is the finding.** Zero of its eight YAML files carry a Fabric card:
`authority-envelope.yaml`, `value-drivers.yaml`, `anti-patterns.yaml`,
`designer-pin.yaml`, `proxy-policy.yaml`, `escalation-patterns.yaml`,
`capability-overlay/`, `prompts/`. Every one is a governance-semantics file, and
§5.1 row 2 — *procedure/runtime semantics: canonical schemas, invariants, validation,
refusal, ratification, compatibility policy* — is the single most runtime-relevant row
in the ownership contract.

The overlap measure reports `policy/` as clean. It reports every directory with zero
cards as clean. **A surface with no cards cannot contribute an Unknown card**, so the
falsifier as literally posed cannot see this class of gap at all.

(One reconciliation: the overlap script found a single `policy/` hit —
`policy/standards/…-partI.md`, a Markdown file. The coverage script counts `.yaml`
sources. Both are correct; the precise statement is *0 of 8 policy YAML files carded*.)

## What fence 1 actually costs

Not 512 components. The measured scope is:

| Item | Count |
|---|---|
| Unknown cards in the CORE write set | 3 |
| Unknown cards under `agents/` (BROAD) | 17 |
| `policy/` YAML files with no card at all | 8 |
| **Total** | **~28** |

Roughly 28 items, against a feared 512 — a ~95% reduction in the fence's cost. The
dossier's re-scoping instruction ("resolve `Unknown` for the subsystems in the runtime's
write set", not a full-corpus enrichment) is vindicated by measurement.

## Proposal for Q-03 / D5 — operator decides, nothing applied

**This is a proposal. No threshold has been configured, applied, or enforced by this
task.**

Proposed coverage threshold for fence 1:

> Fence 1 passes when, for every root in the CORE write set, Fabric coverage is ≥95%
> **and** the count of `Unknown`-subsystem cards is 0 — with `tests/` explicitly
> excluded from the denominator.

Rationale from the measured numbers:

- `lib`/`web`/`bin` already sit at 82–100% with zero Unknown, so the bar is close to
  reached rather than aspirational.
- Excluding `tests/` is what makes the threshold meaningful; including it would make
  fence 1 hostage to 453 files the runtime never writes.
- The **coverage** clause is load-bearing and must not be dropped in favour of the
  Unknown-count clause alone. `policy/` scores a perfect zero Unknown while having no
  cards whatsoever. An Unknown-count-only threshold passes `policy/` today.

## Scope compliance

Arc 0's fence (`.context/arcs/ewcr-arc0-contract-evidence.yaml`) forbids runtime
implementation, autonomy expansion, BVP confirmation, bulk task creation, and
supersession of prior DEFER/NO-GO decisions. This task wrote two measurement scripts
under `tools/`, three documents under `docs/research/executable-workflow/`, one JSON
artefact under `.context/audits/`, and its own task file. No file under `lib/`, `bin/`,
`agents/`, `web/` or `tests/` was modified. No task was created. No threshold applied.
