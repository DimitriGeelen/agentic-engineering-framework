# `policy/prompts/` — Framework Prompt Bundles

This directory holds **prompt bundles**: structured prose loaded by `fw` verb handlers to drive interactive agent sessions. Each bundle encodes the discipline for one operational decision class.

Bundles are not skills, slash commands, or one-shot generators. They are the **content the verb handler injects into the primary agent** when the operator invokes `fw <verb>`. The verb owns invocation, file writes, and audit; the bundle owns reasoning, prompting, and the dialogue shape.

## Why bundles, not skills

When invocation is via `fw <verb>`, the CLI is the discovery layer. Wrapping the prompt in Anthropic Skills format adds packaging overhead without adding triggering value — see `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6.4.11 for the load-bearing correction that produced this decision.

Skills make sense when an agent must discover the artefact by description-matching. Bundles make sense when the framework knows exactly when to load them.

## Current bundles

### `bvp-driver-session.md` — BVP value-driver session

> **Status (2026-06):** The CLI loader verbs `fw bvp driver suggest|create|recompute|edit|retire` are **deferred** per T-2245 IW-3 (operator-only territory until v2 handoff lands). Today this bundle is loaded manually — verb references describe the eventual entry shape. See `lib/bvp.sh:1325` SEE-ALSO comment and the keystone's status note for the same parity statement.

The keystone prompt loaded by:

- `fw bvp driver suggest` — discover candidate drivers, sharpen the picked one, write to `policy/value-drivers.yaml` (free) or `proposed_scoped_drivers:` (arc-scoped)
- `fw bvp driver create <topic>` — sharpen a named topic into a single driver

Both verbs share the `bvp-driver-session.md` content and the sharpening subroutine (see `bvp-references/sharpening-subroutine.md`).

Discipline shape:

- **Three workflows** — A (batch propose at arc-draft), B (discover + sharpen), C (sharpen named topic). All share the same sharpening subroutine.
- **Required sharpening dimensions** — R1 differentiation (what this driver distinguishes that existing drivers do not) and R2 weight calibration (where on 1–9 / arc-scoped ≤6, and why).
- **Optional sharpening dimensions** — O1 edge cases, O2 scope test, O3 overlap test, O4 0–5 scoring rubric. Drill when the human engages; ship with what you have when answers flatten.
- **Output streams** — driver spec written to YAML by the handler; research artefact written to `docs/reports/T-XXXX-bvp-driver-<name>.md` by the handler. Both happen as part of the verb's execution. Claude.ai-mode (no `fw` available) is a degraded fallback, not canonical.
- **After-action recompute** — auto-trigger `fw bvp recompute` after arc-scoped driver approval (cheap, bounded); prompt-confirm after global driver addition (expensive, project-wide).

### `arc-delivery-session.md` — Arc delivery session

> **Status (2026-08):** loaded manually, like the BVP bundle — there is no
> `fw arc deliver` verb and none is proposed. The operator (or an agent under
> operator direction) reads this file at the start of a delivery session.

The counterpart to `bvp-driver-session.md`. That bundle decides *what is worth
doing*; this one gets it **shipped**. Written against a standing measurement: 18
arcs, 0 ever closed.

Discipline shape:

- **One objective** — for one arc, produce a captured instance of its
  `headline_mechanic` firing, then hand the closure decision to the operator.
  Not "progress on arcs".
- **One arc at a time** — four-rule selection order, closeable-now first, `draft`
  arcs last. Breadth is explicitly not progress here.
- **Six-step loop** — read anchor → name the gap *as a deliverable* → slice →
  build under the normal gates → **capture the demo while the mechanic fires** →
  hand over via Watchtower URL.
- **Authority boundary** — `fw arc close` and `fw arc approve-driver` are
  operator-only and structurally refuse under `$CLAUDECODE=1`. The agent makes an
  arc *closeable*; it never closes one.
- **Named failure modes** — substrate/deliverable conflation (§ACD), default-to-
  OPEN on ≥2 pushbacks, the shipped-but-unclosed slice leak (L-434), false green
  (T-2732/T-2734), DEFER-as-hedge (T-2144).

Pairs with CLAUDE.md §Arc Completion Discipline and §Arc Action Handoffs.

### `artefact-template.md` — Research artefact template

The output shape every driver session writes to `docs/reports/T-XXXX-bvp-driver-<name>.md`. Captures driver spec, decisions ledger, rejected paths, dialogue log. References §6 of `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` as the canonical worked example — that document is itself an artefact in this format.

## References (under `bvp-references/`)

Files loaded by `bvp-driver-session.md` on demand during a session:

- `sharpening-subroutine.md` — the R1/R2/O1-O4 dialogue shape, with skip-when-stuck guidance
- `sharpening-tactics.md` — tactical conversation moves (how to surface unstated assumptions, how to drill scope, how to elicit weight calibration without anchoring)
- `global-driver-examples.md` — three worked global free-driver proposals with full dialogue
- `arc-scoped-driver-examples.md` — three worked arc-scoped driver proposals with full dialogue
- `discipline-failure-modes.md` — anti-patterns the bundle exists to prevent (driver inflation, overlap with directives, manufactured drivers, single-axis routing)

## How bundles get loaded

The `fw` verb handler reads the bundle (and any references the bundle pulls in) and injects them as the initial prompt for the primary agent session. The primary agent then runs the workflow with the operator. The verb handler writes results.

Bundles never run themselves. They never write files. Both are the verb handler's responsibility — this keeps the prompt content portable and the file-write semantics auditable.

## Adding a new bundle

A new bundle is justified when:

1. A `fw` verb (or verb family) needs a substantive prompt loaded at invocation
2. The prompt is large enough that inlining in the verb's shell handler would be unwieldy (>100 lines, multiple references)
3. The prompt has structure other bundles might reuse (subroutines, examples, anti-patterns) — bundles compose

If the prompt is small (<100 lines, single-file, no references), keep it inline in the handler. If it has none of these, you may not need a bundle — you may need a CLAUDE.md section or a docs/ note.

## Provenance

The BVP bundle was authored derivatively from `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6 (full design dialogue, decisions ledger, rejected paths) per operator-authorized Path B on 2026-06-08 (T-2245 IW-1 resolution). The canonical upstream-session bundle text was not pasted; this implementation derives from the dialogue's locked decisions and §6.4 phase-3 build description.

Reversibility: each file in this bundle is text-only. `git rm -r policy/prompts/` restores the prior state cleanly.
