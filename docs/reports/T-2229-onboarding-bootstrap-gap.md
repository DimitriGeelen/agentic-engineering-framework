# T-2229: Onboarding bootstrap gap — fw upgrade/init/vendor don't seed policy/value-drivers.yaml + .context/arcs/

**Status:** inception, Recommendation GO (pending operator decision via Watchtower)
**Filed:** 2026-06-06
**Origin:** operator-confirmed live on `/opt/050-email-archive` (vendored AEF 1.6.260)
**Companion to:** T-1633 (consumer-fresh upgrade simulation), T-1920 (BVP mutating verbs)

## Problem Statement

AEF's onboarding flow does not bootstrap consumer-side BVP/arc state.
Every consumer hits `ERROR: policy file not found` the first time anything
touches BVP, and `fw bvp arcs` silently returns empty because `.context/arcs/`
never gets created.

Three onboarding shapes are affected:

| Verb | Use case | Current behaviour | Missing |
|------|----------|-------------------|---------|
| `fw init` | greenfield new project | no BVP/arc bootstrap | both |
| `fw upgrade` | upgrade existing AEF consumer | no BVP/arc bootstrap | both |
| `fw vendor` | first-time adoption of existing codebase | no BVP/arc bootstrap | both |

## Evidence

### E1 — live failure on `/opt/050-email-archive`

```
$ .agentic-framework/bin/fw bvp
ERROR: policy file not found: /opt/050-email-archive/policy/value-drivers.yaml
       Run T-1917 first (or `fw bvp driver --init` once T-1920 ships).
```

- `policy/value-drivers.yaml` does not exist
- `.context/arcs/` does not exist
- 12 task files carry `bvp_scores` frontmatter (upstream framework-dev leakage,
  not consumer scoring runs)

### E2 — dead reference at `lib/bvp.sh:133`

T-1917 (BVP policy schema initial) shipped — produced the framework's own
`policy/value-drivers.yaml`, but consumers got a file in the framework repo,
not their own.

T-1920 (BVP mutating verbs: weight + driver --add/--remove + audit log)
shipped — but the `--init` flag the error message references was descoped
or never built:

```
$ fw bvp driver --help
Usage: fw bvp driver --add "name" --weight N --rationale "..."
       fw bvp driver --remove Dn --rationale "..." [--drop Dn]
```

### E3 — onboarding code paths have zero `policy/` or `value-drivers` references

```
$ grep -nE "value-drivers|policy/value|bvp.*policy" lib/upgrade.sh lib/init.sh
(empty)
```

`fw init`, `fw upgrade`, and the vendor handling code do not touch
`policy/value-drivers.yaml` at all.

## Directive analysis

| Directive | Impact of fix |
|-----------|---------------|
| D1 Antifragility | Positive — closes a learning-loop-blind failure surface |
| D2 Reliability | Positive — eliminates predictable failure on every consumer |
| D3 Usability | Positive — error message points at a working verb |
| D4 Portability | Neutral — bootstrap shape is portable |

Strong GO signal across three of four directives, neutral on the fourth.

## Build path on GO

### Spikes (gating)

- **Spike A (~20 min):** regex audit of `policy/` and `.context/arcs/` references
  across `lib/init.sh`, `lib/upgrade.sh`, `bin/fw` vendor path. Identify every
  surface needing the bootstrap call.
- **Spike B (~30 min):** examine three real consumers
  (`/opt/050-email-archive`, `/opt/termlink`, `/opt/003-NTB-ATC-Plugin`) to
  understand whether default D1-D4 weights serve their workloads or whether
  ingest needs "scan + suggest" bias.
- **Spike C (~15 min):** survey existing `FW_*` env vars + `.framework.yaml`
  config keys for the opt-out pattern.

### Build slices

- **Slice 1 — `fw bvp driver --init`:** ship the verb the error message
  already promises. Creates `policy/value-drivers.yaml` from framework template,
  idempotent (refuses if file exists unless `--force`). Update lib/bvp.sh:133
  error message to point at the working verb. ~80-120 LoC + bats coverage.
- **Slice 2 — wire into onboarding:** `fw init`, `fw upgrade`, `fw vendor`
  all call `fw bvp driver --init` idempotently. `.context/arcs/` created with
  README. ~60-100 LoC across the three surfaces.
- **Slice 3 — consumer-fresh simulation gate extension:** extend
  `tests/unit/upgrade_fresh_machine_simulation.bats` to assert BVP + arc
  bootstrap on fresh consumer. Closes the structural gap that allowed
  T-2229 to ship in the first place. ~40 LoC.
- **Slice 4 — opt-out + ingest UX (post-Spike B/C):** per the deferred
  IW-2 / IW-6 decisions.

## Recommendation

**Recommendation:** GO

**Rationale:** The gap is structural, operator-confirmed, hits every fresh
consumer, and has a constrained fix shape. Sovereignty-respecting bootstrap
(idempotent + opt-out + never overwrite consumer-authored policy) composes
cleanly with the existing T-1633/T-1635 consumer-fresh discipline. The fix
also closes a dead-reference UX bug at `lib/bvp.sh:133` that points consumers
at a non-existent verb.

The shape of HOW to bootstrap (ingest UX, opt-out surface) is a build-time
question that spikes B + C resolve. The GO/NO-GO decision on WHETHER to
bootstrap is binary and the evidence points strongly at GO.

DEFER would be a hedge per T-2144 — the evidence is complete; the only
unknowns are build-time details that spike work resolves naturally.

**Evidence:**

- `/opt/050-email-archive` live failure (operator-reported 2026-06-06)
- `lib/bvp.sh:133` dead reference to `fw bvp driver --init`
- `grep policy/value-drivers lib/init.sh lib/upgrade.sh` → 0 matches
- `fw bvp driver --help` confirms no `--init` flag exists
- T-1633/T-1635 (consumer-fresh simulation) composability

## Dialogue Log

### 2026-06-06 — Operator filed bug report

> "why are the bvp scores in a updated vendored project empty ??!!! also there
> are now value drivers we get error :: ERROR: policy file not found ... seems
> an upgrade to a project that does not have bvp or an aef installation that
> ingest an existing codebase need to be initialized we need to incorporate
> this in or upgrade and installation procedure, please incept this"

**Agent diagnosis (confirmed live):**
- 12 task files with `bvp_scores` are upstream framework-dev leakage
- `policy/value-drivers.yaml` is per-consumer state not bootstrapped
- `.context/arcs/` per-consumer state not bootstrapped
- `fw bvp driver --init` is a dead reference in the error message
- T-1917 shipped (framework policy schema); T-1920 shipped (mutating verbs)
  but `--init` flag never built

**Agent recommendation:** GO with 6 IW questions + 3 spikes + 4-slice build path.

## Cross-references

- `lib/bvp.sh:133` — dead `fw bvp driver --init` reference
- `lib/init.sh`, `lib/upgrade.sh` — onboarding surfaces missing bootstrap
- `tests/unit/upgrade_fresh_machine_simulation.bats` — T-1633's
  consumer-fresh gate (Slice 3 extends this)
- `.tasks/completed/T-1917-bvp-policyvalue-driversyaml-schema-initial.md`
- `.tasks/completed/T-1920-bvp-fw-bvp-weight-driver-mutating-verbs-au.md`
- `policy/value-drivers.yaml` (framework copy, the bootstrap template)
- L-249 (fw vendor is cross-cutting sync — bootstrap consumes the same channel)
