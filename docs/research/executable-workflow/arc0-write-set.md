# EWCR Arc 0 — the runtime write set, derived

**Task:** T-3147 · **Arc:** arc-019 (`ewcr-arc0-contract-evidence`, draft)
**Derived from:** `architecture-c9070637.md` §5.1 "AEF and Workflow Designer ownership contract"
**Commit measured:** see `arc0-falsifier1-result.md` (the number moves; the commit is named there)

## Why this document exists

Architecture §5.1 is an **ownership contract, not a file list**. It says who owns
*runner, ledger, actions, identity, secrets* — it does not say which paths those live
in. Falsifier 1 asks for an intersection with "the runtime write set", so that set has
to be derived before anything can be intersected with it.

Deriving it in a document rather than inside a glob is deliberate: a prefix list buried
in a script is an assumption nobody can audit. Every row below carries the §5.1 row it
comes from, so the operator can disagree with a specific mapping rather than with a
number.

## Two definitions, because the honest answer is a range

The runtime's write set is **not frozen** — Arc 1 has not run. Picking one definition
silently would hand the operator a number with a hidden assumption inside it. So both
are measured and both are reported.

- **CORE** — surfaces the runtime kernel itself must write (Arcs 1–3).
- **BROAD** — every surface §5.1 assigns to AEF, including those the runtime only
  *projects* through (Arcs 4–6).

### CORE

| §5.1 row | AEF responsibility (verbatim) | Existing paths |
|---|---|---|
| 5 | Runner, ledger, actions, identity, secrets — "sole authority for execution, isolation, event admission, capability/secret resolution, and evidence" | `lib/resolver*`, `lib/orchestrator*`, `lib/outcome*`, `lib/dispatch*`, `agents/dispatch/`, `lib/termlink*`, `lib/bus*` |
| 2 | Procedure/runtime semantics — "own canonical schemas, invariants, validation, refusal, ratification, and compatibility policy" | `lib/corpus*`, `policy/` |
| 6 | Context, Component, and Workflow Fabrics — "own canonical/derived records, version projection, and governed query semantics" | `lib/fabric*`, `agents/fabric/` |

### BROAD (adds)

| §5.1 row | AEF responsibility | Existing paths |
|---|---|---|
| 1 | Tasks, inception, approvals, BVP, gates — "canonical owner and enforcer" | `agents/task-create/`, `lib/inception*`, `lib/bvp*`, `lib/review*`, `agents/context/`, `lib/task*` |
| 4 | Diagram → procedure mapping — "validate semantic output and preserve frozen Mapping Standard boundaries" | `agents/designer/`, `web/blueprints/designer*` |
| 7 | Runtime/operator interaction — "own authenticated proposal API and admission/refusal decision" | `web/` |

## What is deliberately NOT in the write set

- **`tests/`** — the runtime does not write tests as a runtime; test authorship is a
  development activity, not a runtime write. This matters enormously to the result:
  453 of 519 Unknown-subsystem cards are under `tests/`.
- **`docs/`, `prompts/`, `.context/`** — evidence and narrative surfaces, not runtime
  write targets.
- **The Designer's own surfaces** — §5.1 assigns authoring/visualisation to the
  Workflow Designer. AEF validating a Designer artefact is not AEF writing it.

## Known weakness of this derivation

A path-prefix set can only find components that **have a Fabric card at all**. A
runtime surface with zero cards produces zero Unknown hits and is therefore
indistinguishable, in the overlap number alone, from a surface that is fully
classified. That is why `tools/ewcr-arc0-coverage-check.py` exists as a control and
why its output is reported alongside the overlap — see the result document. The
control found exactly this case in `policy/`.
