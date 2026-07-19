# BPMN Agent — Child-2 Forward Compiler

Compiles a BPMN 2.0 process diagram into AEF task skeletons. This is the **forward bridge**
of the AEF ↔ 832-Workflow-Designer integration (diagram → tasks), the primary value path.

## Invocation

```
fw bpmn compile <file.bpmn>   # emit AEF task-skeleton YAML frontmatter to stdout
fw bpmn help
```

Mechanical script: `agents/bpmn/bpmn.sh` → `tools/bpmn_to_tasks.py`.

## What it maps (ratified contract — see docs/reports/T-2522-bpmn-aef-mapping-contract.md)

| BPMN | AEF | Ruling |
|------|-----|--------|
| task node (`userTask`/`serviceTask`/`scriptTask`) | one task skeleton | — |
| `aef:uid` in `<extensionElements>` | `id` (stable identity) | IW-1 keystone |
| lane | `owner` (`human`/`agent`) — from lane only, node-owner ignored | IW-7 / IW-9 (832 T-189) |
| node-type vs lane conflict | Lane wins + WARN | O-1 |
| `sequenceFlow` order (task-hops from start) | `horizon` (tier1→now, tier2→next, tier≥3→later) | T-2532 |
| nearest task predecessor (gateways/events transited) | `related_tasks: [uid…]` | T-2532 |
| node kind | `workflow_type: build` (default), `tier: 1` (default) | ratified defaults |
| `subProcess` + `<aef:meta workflowType="inception">` | `workflow_type: inception` + `owner: human` | T-2534 (slice 3) — G-3 implied go/no-go |
| `<aef:laneMeta authority="sovereignty">` | `owner: human` (authority-of-record) | T-2534 / IW-7 |
| `<aef:constituents>` on inception subProcess | `# constituents:` AC-seed comment | T-2534 |

Namespace-agnostic: matches BPMN/aef elements by **local name**, so it is forward-compatible
with 832's real `aef:` namespace URI when the vendored corpus lands.

## Roadmap

- **Slice 1 (T-2531, done):** node → skeleton (uid, lane→owner, O-1).
- **Slice 2 (T-2532, done):** sequenceFlow → horizon + related_tasks.
- **Slice 3a (T-2533, done):** `fw bpmn compile` CLI verb.
- **Slice 3 (T-2534, done):** inception *semantics* — a `subProcess` with
  `<aef:meta workflowType="inception">` → `workflow_type: inception` + `owner: human`
  (owner from `<aef:laneMeta authority="sovereignty">`; go/no-go implied at the boundary,
  no child gateway). 832's ratified contract, rail offset 32/34. Positive fixture
  `inception-gonogo-sample.bpmn` (AEF twin of 832's `inception-gonogo.bpmn`), negative
  `plain-composite-sample.bpmn`. Correction from the offset-30 guess: the marker is
  `workflowType`, NOT `scopeOf` (scopeOf is the T-081 composition back-ref).
- **Slice 3 cross-validation (T-2535, done):** byte-exact against 832's canonical
  `inception-gonogo.bpmn` (positive, sha `093858…`) and `resume-status.bpmn` (negative,
  sha `7b15f3e0…`), both delivered inline over the DM rail. This caught the uid-attribute
  bug (T-2536): 832 serializes uid as `<aef:uid value="X"/>`, not text content.
- **O-3 fail-fast (T-2537, done):** O-3 graduated to v1.1 (832 T-195, rail offset 47) as
  MUST + machine-checkable G-3 — an inception's go/no-go boundary MUST be sovereignty-laned.
  A mis-laned inception now raises `MalformedInceptionError` (CLI exit 3, actionable ERROR),
  superseding the pre-graduation force-human+WARN. Fixture: `inception-mislaned-sample.bpmn`.
- **O-3 VETO tightening (T-2540, done):** 832 VETOed (rail offset 49) the T-2537 name-only-"Human"
  accept+WARN ramp. Per mapping-v1 §3 (IW-9, v1.1) `<aef:laneMeta authority>` is the SOLE
  authority-of-record — a lane NAME is not an authority carrier. So **only `authority="sovereignty"`
  satisfies O-3**; name-only-Human, no-lane, laneMeta-without-@authority, and non-sovereignty
  authority ALL raise identically (§7). The gate now keys off `authority` directly, not the
  name-folded `lane_owner`, structurally excluding the name heuristic from the sovereignty check.
  Conformance fix to an already-frozen fence (no sovereign GO needed). `inception-nameonly-lane-sample.bpmn`
  moved warn-set → raises-set. Also locks PL-035 (832 offset 50): an existence rule must fire
  HARDEST on absent input — the inline node-loop check has no early return, so a no-laneSet inception
  raises (regression-locked by `test_no_laneset_inception_raises`).
- **Write-out staging (T-2539, done — from T-2538 GO):** `fw bpmn compile --write` stages
  uid-keyed *proposals* to `.context/bpmn-staged/<diagram>/` (one `<uid>.md` per node +
  `manifest.yaml`). Proposals are `status: proposal`, NOT tasks — no `.tasks/` write, no gate,
  no T-ID allocation (C1). Idempotent upsert by `aef:uid`; stale proposals pruned. This is
  candidate C of the T-2538 governance inception (`docs/reports/T-2538-writeout-mode-governance.md`).
- **Write-out promotion (T-2542, done — from T-2541 + 832 T-201 GO):** `fw bpmn promote <uid|all>`
  turns staged proposals into real `.tasks/` files via `fw task create` — the ONE governed writer —
  forcing `owner: human` + `status: captured` (un-overridable G2/G3: proposal content can never
  override them). Stamps an `aef_provenance` frontmatter block (`uid`, `source_diagram`,
  `source_bpmn_sha`, `promoted_at`) per 832's IW-2 contract (T-201 §3b): frontmatter is authoritative,
  the uid↔T-ID map is a derived cache re-scanned from `.tasks/` each run (no ledger file, no split-brain).
  Reconcile keyed on `(uid, source_bpmn_sha)`: **new**→create, **unchanged**→NO-OP (idempotent re-promote),
  **changed**→refresh if captured+untouched / REFUSE-clobber if started-work/human-touched,
  **deleted**→orphan+flag (never auto-delete). Dry-run is the default; `--write` executes.
  Impl: `tools/bpmn_promote.py`, tests `tests/unit/test_bpmn_promote.py`. Provenance is injected by
  promote after the gated create (create-task.sh has no arbitrary-frontmatter pass-through — Spike-1);
  the window is benign (captured+owner:human triggers zero automation — Spike-2).
- **Gate-level hardening (T-2543, Dimitri sovereignty bar, rail offset 60):** owner:human+captured is
  enforced **at the gate**, not the caller — promote sets `FW_TASK_ORIGIN=bpmn-promote` and
  `create-task.sh` refuses any promote-origin create that isn't owner:human+captured (a future promote
  caller bug is refused, not silently written; non-promote creates unaffected). Every `--write`
  materialization appends an audit line to `.context/working/.bpmn-promote-audit.jsonl` (no silent
  `.tasks/` writes). `changed`→**propose-not-clobber**: a changed proposal is never auto-written,
  flagged for human review regardless of captured/touched (supersedes T-2542's changed+captured→refresh).
- **E2E forward-bridge test (T-2545, done):** `tests/unit/bpmn_promote_e2e.bats` exercises the WHOLE
  chain against the REAL `create-task.sh` gate in a hermetic temp PROJECT_ROOT (the unit tests
  `test_bpmn_promote.py` mock `create_via_gate`; this one doesn't). Pins: created tasks are
  owner:human+captured with an `aef_provenance` block; owner is FORCED human even for Agent-lane nodes
  (G2); each `--write` appends an audit line; a promote-origin `create --owner agent` is REFUSED (no
  file); a stale `source_bpmn_sha`→PROPOSE-not-clobber (materialized content intact).
- **Canonical joint fixture + seam-slice (T-2548, done):** adopted 832's `two-lane-joint.bpmn`
  (`tests/fixtures/bpmn/two-lane-joint.bpmn`, sha `efb53839`, owner-bearing task in BOTH lanes:
  `n_inception` sovereignty→owner:human/inception + `n_plan` initiative→owner:agent/build) as the
  canonical joint fixture. `bpmn_promote_e2e.bats` seam-slice drives compile→promote→REAL gate off it,
  proving the **initiative→agent** owner derivation (n_plan is owner:agent in the manifest, G2-forced to
  owner:human at the gate) — the leg the single-node `inception-gonogo` and `two-lane-sample` fixtures
  can't reach. 832's producer contract is `tests/test_promote_contract.py` (their side); this is the
  consumer half.
- **Inception-node materialization (T-2549, done — surfaced by T-2548's joint fixture):** `fw bpmn
  promote` previously RAISED on any diagram with a `workflow_type: inception` node — `create_via_gate`
  delegated to `fw task create --type inception` with no `--recommendation`/`--rationale`, so the T-2204
  recommendation-completeness gate (fires under `CLAUDECODE=1`) refused it. Latent since T-2542 (prior
  e2e had no inception node; units mock the gate). Fix: `create_via_gate` injects
  `--recommendation DEFER --rationale "…human go/no-go pending"` for `inception` nodes ONLY (the honest
  awaiting-decision state, matching the T-2208 cron backstop's DEFER stub); build/test nodes unchanged.
  The materialized inception task carries a `## Recommendation: DEFER` block. Captured as L-504.
