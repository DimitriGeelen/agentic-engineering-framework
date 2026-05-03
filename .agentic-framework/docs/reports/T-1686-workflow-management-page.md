# T-1686 Phase 1 spike — Watchtower /workflows management page

**Inception task:** T-1686
**Author:** agent (autonomous Phase 1, requires human GO before any build)
**Created:** 2026-05-02
**Status:** spike-complete

## Question

Is a Watchtower `/workflows` management page (configurable
workflow_type → model + thinking_level + cost-cap, plus per-workflow
telemetry) a viable consumer-enabler for the orchestrator substrate,
and can its scope fit a single buildable task?

## Why this exists

G-064: orchestrator substrate has zero production consumers. T-1685
showed `fw audit` has no LLM-amenable workload to refactor (NO-GO).
T-1686 explores a different angle: instead of forcing a consumer,
make the substrate USEFUL when someone DOES invoke it. Today the
orchestrator can only learn from past dispatches; it cannot be
configured. Adding a config + telemetry surface is what turns
"speculative substrate" into "an opt-in product an operator might
choose to invoke."

## Current state survey

### What exists today

- **`/orchestrator` page** (web/blueprints/orchestrator.py 337 LOC,
  template 369 LOC). Renders learned model_stats (success rates per
  `model:task_type`), recent dispatch list, capability entries from
  `route_cache.json`, and a links panel. Read-only.
- **`route_cache.json`** schema:
  ```
  {
    "entries": { capability: { specialist, confidence, ttl_hours, ... } },
    "model_stats": { "model:task_type": { successes, failures, last_used } }
  }
  ```
- **Config keys** (lib/config.sh):
  - `DISPATCH_LIMIT` (2) — Agent-tool dispatches before TermLink gate
  - `DISPATCH_MODEL_DEFAULT` (empty) — global fallback model
  - **No per-workflow_type config exists.**
- **`workflow_type`** is a known field on every task (build, test,
  inception, design, refactor, decommission, specification). 7 used
  blueprints reference it. It is the natural primary key for
  per-workflow config.
- **Token cost telemetry** exists via `fw costs` (T-801) — captures
  per-session token usage from JSONL transcripts. Not yet aggregated
  by `workflow_type`.

### What does not exist today

- Per-workflow_type config (model pin, thinking_level, cost-cap,
  override-cache flag).
- The concept of `thinking_level` anywhere in the codebase.
- Cost-cap enforcement.
- Workflow-level telemetry (today: session-level CPT/FTC/PTR;
  task-level outcomes; no roll-up by workflow_type).
- A surface to set or display these.

## Proposed scope

**Storage** — `.context/project/workflows.yaml`:

```yaml
workflows:
  build:
    pinned_model: null            # null = use route_cache learning
    thinking_level: medium        # low|medium|high|max (mapped to thinking budget)
    cost_cap_usd: null            # null = no cap
    override_cache: false         # if true, ignore route_cache and always use pinned_model
  inception:
    pinned_model: opus
    thinking_level: high
    cost_cap_usd: 5.00
    override_cache: true
  design:
    pinned_model: sonnet
    thinking_level: medium
    cost_cap_usd: null
    override_cache: false
  # ... test, refactor, decommission, specification
```

**Resolver wiring** (agents/termlink/termlink.sh):

- `_resolve_dispatch_model_and_fallback` consults `workflows.yaml`
  FIRST. If `override_cache: true` → use `pinned_model` directly.
  If `pinned_model: null` → fall through to existing route_cache
  logic. Backward-compat: if `workflows.yaml` is missing, behaviour
  identical to today.

**Surface** — new `web/blueprints/workflows.py` + template:

- GET `/workflows` — table of all workflow_types: pinned_model |
  thinking_level | cost_cap | override-cache | (telemetry: count
  this week / success rate / avg duration / total cost).
- POST `/workflows/<type>` — htmx form to update config row.
- Telemetry aggregation: read `route_cache.model_stats` keyed by
  `workflow_type` + read `fw costs --json` and group by
  `workflow_type` from task focus history.

**Tests** — pin schema, resolver precedence, backward-compat (no
config file → current behaviour), Watchtower page renders empty
state and populated state.

## Files touched (estimate)

| File | Action | Approx lines |
|---|---|---|
| `.context/project/workflows.yaml` | new | 30 (template) |
| `agents/termlink/termlink.sh` | modify resolver | +30 |
| `lib/workflows.sh` | new (read/write helpers) | 120 |
| `web/blueprints/workflows.py` | new | 200 |
| `web/templates/workflows.html` | new | 250 |
| `web/blueprints/__init__.py` | register | +1 |
| `tests/unit/test_workflows_resolver.py` | new | 150 |
| `tests/unit/test_workflows_page.py` | new | 100 |

Total: ~6 new files, 2 modifications, ~880 LOC.

## Cost estimate

**1.5–2 sessions of agent work.** Phase boundaries:

1. Schema + helpers (lib/workflows.sh) + resolver wiring +
   backward-compat tests. ~1 session.
2. Watchtower page + telemetry aggregation + page tests. ~0.5–1
   session.

Reversible — additive. Removing requires deleting workflows.yaml +
reverting the resolver branch. No persistent state migrations.

## Honest read on whether this closes G-064

**It does not.** A management page lets users CONFIGURE the
substrate. It does not autonomously INVOKE it. After this ships,
`fw termlink dispatch` is still only invoked when an agent or human
manually types it. G-064 stays OPEN.

What the page DOES change:

- Removes the "no one would configure this" objection. Today there
  is no surface to configure; the substrate can only learn what it
  observes. Post-T-1686: an operator can pin "inception always uses
  opus" and observe per-workflow cost.
- Makes future autonomous consumers more attractive — once cost-cap
  + thinking_level exist, an audit-style consumer or a typed
  sub-agent dispatcher has knobs to dial against, instead of opaque
  defaults.
- Gives the existing /orchestrator surface a meaningful sibling
  (observation vs configuration), reducing the "is this substrate
  alive?" question to "is anything configured? what's the
  telemetry?"

## Recommendation

**GO** — but with explicit honesty about what it does and does not
solve.

**Rationale:** Real product feature. Real user request. Reversible.
Reasonable scope. Makes the existing orchestrator substrate
meaningfully more useful. Phase 1 (schema + resolver + backward-
compat) is independently shippable; Phase 2 (page + telemetry) can
land in a follow-up if Phase 1 surfaces unexpected friction.

**Caveat:** Does NOT close G-064 by itself. T-1686 makes the
substrate a configurable product; it does not make anything use the
product autonomously. G-064 closure still requires either:

(a) a production caller emerging naturally (someone configures
    inception=opus and `fw inception start` is wired to dispatch), OR
(b) explicit acceptance that the orchestrator is opt-in only and
    "no autonomous consumer" is fine.

## Decisions captured

### 2026-05-02 — Why GO with the management-page scope

- **Chose:** GO on T-1686 with two-phase scope (schema/resolver
  first, page+telemetry second).
- **Why:** Real user-asked feature; modest LOC; reversible; gives
  orchestrator substrate a configurable surface that today doesn't
  exist; makes future consumers easier to justify.
- **Rejected:** Going straight to page-without-resolver (the
  resolver wiring is the load-bearing change; the page is UI on top).
- **Rejected:** Bundling cost-cap enforcement into Phase 1 — defer
  to a follow-up; cost-cap requires intercepting dispatch on cost
  threshold, which is a separate cross-cutting concern.
