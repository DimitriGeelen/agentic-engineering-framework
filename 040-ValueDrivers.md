# Value Drivers — Business Value Points

## Overview

A **value driver** is a named dimension along which work is scored. Each
driver carries a weight; each task scores 0-5 against each driver. The sum
`Σ(weight × score)` is the task's **BVP** (Business Value Points). Arcs
inherit BVP from their constituent tasks. Watchtower visualises BVP × cost
as a quadrant scatter to surface high-value/low-cost work.

The mechanic decouples "what's urgent" from "what compounds." Without
explicit drivers, prioritisation collapses to whoever spoke last; with
drivers, every task carries a traceable claim about *which* of the
framework's commitments it advances.

**Origin.** Adapted from Dimitri Geelen's 2019 post on Business Value Points
for backlog prioritisation
(<https://blog.dimitrigeelen.com/2019/10/using-business-value-points-for-backlog-prioritisation/>).

**AEF adaptations.** The Geelen 2019 mechanic was workload-agnostic — drivers
named whatever the team valued. AEF binds the four top-weight drivers to the
**Constitutional Directives** (CLAUDE.md §"Four Constitutional Directives"),
so prioritisation can never drift away from the framework's stated commitments
(D8). AEF also adds (a) arc-scoped drivers with cap-3/weight-≤6 (M2), (b) a
TermLink-backed BVP estimator with v2-delta semantics (M3), (c) a composite
cost dimension (F8), and (d) an §ACD gate on every policy edit (M6).

## The Four Constitutional Directives

The protected drivers are the four directives in CLAUDE.md, with shipped
default weights:

| ID | Driver | Weight | Mandate |
|----|--------|-------:|---------|
| **D1** | Antifragility | 9 | System strengthens under stress; failures are learning events |
| **D2** | Reliability   | 7 | Predictable, observable, auditable execution; no silent failures |
| **D3** | Usability     | 5 | Joy to use/extend/debug; sensible defaults; actionable errors |
| **D4** | Portability   | 3 | No provider/language/environment lock-in; prefer standards |

**Protected** means: identifiers D1-D4 cannot be removed, renamed, or
reordered. Weights *may* be adjusted via `fw bvp weight` under §ACD
sovereignty (M6) — the directives' relative priority is itself a sovereignty
call.

Source of truth: `policy/value-drivers.yaml` → `protected_drivers:`.

## Free Drivers (M1 — add-one-drop-one)

A project may register up to **5 additional global drivers** alongside the
four protected ones. Free drivers capture commitments specific to the
project (e.g., a finance product might add `auditability`; an agent
framework might add `learning-capture`).

**Cap:** total drivers (protected + free) ≤ **9**. Adding a 6th free driver
triggers **M1 add-one-drop-one**: the new driver displaces an existing free
driver in one audit-logged event. The displacement is intentional friction —
the cap forces the team to decide what they *stopped* caring about.

```
fw bvp driver --add "auditability" --weight 4 \
    --rationale "compliance-driven; tracks structural audit trail coverage" \
    --drop F_observability
```

`--drop` is required when the cap is already at 9. Removing a free driver
without replacement is also §ACD-gated (sovereignty boundary on what the
project values).

Source of truth: `policy/value-drivers.yaml` → `free_drivers:`.

## Arc-Scoped Drivers (M2 — cap 3, weight ≤ 6)

Arcs may carry up to **3 scoped drivers** in addition to the global drivers.
Scoped drivers exist to distinguish what's specific about the arc *that the
global drivers do not capture* (D6).

**Caps:** ≤ 3 scoped drivers per arc; each weight ≤ 6 (M2 — scoped weights
can never dominate global directives).

```
fw arc approve-driver value-prioritisation "rubric-calibration" --weight 5 \
    --i-am-human
```

If the arc has no driver worth tracking separately, the human declares so
explicitly:

```
fw arc approve-driver value-prioritisation --none \
    --justification "global D1-D4 fully capture this arc's value"
```

Approval is §ACD-gated (M6): the verb refuses under `$CLAUDECODE=1` unless
`--i-am-human` or `--from-watchtower` is passed. The justification (or the
approval) is logged to `.context/audits/arc-scoped-driver-bypass.jsonl`.

**Why scoped drivers exist.** The constitutional directives are mandatory
but coarse — they cover *every* arc by design. An arc on rubric calibration
might want to score tasks on `rubric-coverage` separately, because that
dimension is specific to the arc's purpose and would average out to noise
across the project. See R5 (CLAUDE.md): manufacturing scoped drivers to
look thorough is worse than `--none`.

## Scoring (0-5 × 0-9 weight)

Each task scores each driver on a **0-5 scale**:

| Score | Meaning |
|------:|---------|
| 0 | No connection to the driver |
| 1 | Touches the driver only incidentally |
| 2 | Improves the driver locally (one site, one consumer) |
| 3 | Improves the driver at component/subsystem level |
| 4 | Changes the driver at framework level (cross-cutting) |
| 5 | Changes the *class* of behaviour the driver protects against |

The per-task BVP is `Σ(driver_weight × driver_score)` across all drivers
(protected + free, plus arc-scoped where applicable). `bvp_norm` is BVP
divided by the max-possible (i.e. 5 × Σweights), giving a value in [0, 1].

Two independent scorers reading the same task at low temperature must score
within **±1 on every driver** for the rubric to be considered calibrated.
Larger drift is a rubric defect, not a scorer defect. Per-driver criteria
and worked examples live in `policy/bvp-scoring-rubric.md`.

## Quadrants

`fw bvp --quadrant {hv-lc|hv-hc|lv-lc|lv-hc}` splits the task list on the
**median BVP** × **median cost** axes:

| Quadrant | Reading | Action |
|----------|---------|--------|
| **hv-lc** | High value, low cost | Ship now — these are the highest leverage |
| **hv-hc** | High value, high cost | Plan deliberately — worth doing, expensive |
| **lv-lc** | Low value, low cost | Batch or defer — cheap but low payoff |
| **lv-hc** | Low value, high cost | Question the premise — usually wrong shape |

Medians (not absolute thresholds) make the quadrant *relative* to the
current backlog — a project doesn't need to calibrate a "cost is high above
N" rule, the split is derived live each invocation (D9 reactive).

## Cost Composite (F8 — 3-component disclosure)

`cost_estimate` on a task is the composite:

```
cost = 0.6 × blast_radius + 0.3 × tier + 0.1 × effort
```

Three components, weighted to surface what tends to dominate:

| Component | Source | Why dominant share |
|-----------|--------|---|
| **blast_radius** (0.6) | `fw fabric blast-radius` count | Determines how many surfaces an error can corrupt |
| **tier** (0.3) | 0=Tier 3 cheap → 3=Tier 0 destructive | Tier 0 work is by definition expensive to reverse |
| **effort** (0.1) | T-shirt 2/4/6/8 (S/M/L/XL) | Engineer-hours dominate budget conversation but not blast risk |

**F8 disclosure rule.** Whenever a cost is shown (CLI, Watchtower, audit),
the three components must be visible at one click of detail. A composite
that hides its parts becomes folklore — the disclosure is the audit trail.

**Q2 T-shirt fallback.** When blast_radius is not computable yet (task
hasn't touched fabric), a T-shirt cost (S=2, M=4, L=6, XL=8) is used as a
single-component proxy. The proxy is marked as such; it does not
silently masquerade as the 3-component composite.

## BVP Estimator (M3 — v2-delta)

The TermLink-backed BVP estimator (T-1922) reads a task body and proposes
per-driver scores. The estimator writes to **`bvp_scores_proposed:`**
(timestamped list of proposals), not to `bvp_scores:`.

**M3 v2-delta.** A new proposal is appended only when it differs from the
last confirmed score by **≥ 2 on at least one driver**. This avoids
oscillation noise around already-confirmed values; small drift (±1) is
within the rubric's calibrated determinism band and not interesting.

Estimator output is a proposal, never an assignment. Confirmation —
moving `bvp_scores_proposed` → `bvp_scores` — is sovereignty-bound to the
human and §ACD-gated:

```
fw bvp confirm T-1234                                    # accept estimator proposal as-is
fw bvp confirm T-1234 --override D2=4 --i-am-human       # adjust one driver
```

The override mechanism preserves the estimator's signal while letting the
human correct specific drivers without re-scoring the whole task. The
estimator's rubric file is `policy/bvp-scoring-rubric.md`; changes to the
rubric change estimator output (R9).

## Driver Decision Gate

Three classes of action mutate the driver policy. All three are §ACD-gated:

| Action | Gate verb | Notes |
|--------|-----------|-------|
| Change a weight | `fw bvp weight --set Dn=N --rationale "≥30 chars"` | M6; rationale persisted to `.context/bvp-weight-history.yaml` |
| Add/remove free driver | `fw bvp driver --add/--remove --rationale "..."` | M1 add-one-drop-one applies at cap=9 |
| Approve arc-scoped driver | `fw arc approve-driver <arc> "<name>" [--weight N]` | M2 cap-3 / weight ≤6 |
| Confirm task scores | `fw bvp confirm T-XXX` | Moves proposed → confirmed |

Under `$CLAUDECODE=1`, each verb refuses unless `--i-am-human` or
`--from-watchtower` is passed (M6). This is **D8 sovereignty-at-policy-edit**
made structural: the agent can propose, score, and rank — it cannot decide
what the project values.

## `fw bvp` CLI (M7 — full surface)

| Verb | Purpose |
|------|---------|
| `fw bvp` | Rank scored tasks by BVP desc |
| `fw bvp T-<id>` | Per-driver detail for one task |
| `fw bvp arcs` | Rank arcs by global-driver BVP |
| `fw bvp --quadrant {hv-lc\|hv-hc\|lv-lc\|lv-hc}` | Filter by quadrant (median × median) |
| `fw bvp weight --set Dn=N --rationale "..."` | Change driver weight (§ACD) |
| `fw bvp driver --add "name" --weight N --rationale "..." [--drop Dn]` | Add free driver (M1) |
| `fw bvp driver --remove Dn --rationale "..."` | Remove free driver (§ACD) |
| `fw bvp confirm T-<id> [--override Dn=N]...` | Confirm scores (§ACD) |

All mutating verbs require `--rationale "<≥30 chars>"` and log to
`.context/bvp-weight-history.yaml` for audit.

## `fw arc approve-driver` CLI (M6 — §ACD gate)

| Verb | Purpose |
|------|---------|
| `fw arc approve-driver <arc> "<name>" [--weight N]` | Append scoped driver (M2 cap 3, weight ≤6) |
| `fw arc approve-driver <arc> --none --justification "..."` | Declare no scoped drivers |
| `fw arc show-suggestions <arc-id>` | Surface estimator-proposed drivers for human review |

On first approval (or on `--none`) the arc flips `draft → in-progress` —
approving the value model is the act that opens the arc for work. Refusals
under `$CLAUDECODE=1` are logged to
`.context/audits/arc-scoped-driver-bypass.jsonl`.

## Relation to the Authority Model (D8 sovereignty-at-policy-edit)

The Authority Model (CLAUDE.md §"Authority Model") gives the agent
**initiative** and reserves **authority** for the human. BVP is the
operational mechanism that makes the boundary visible:

- **Agent initiative:** propose scores, compute BVP, rank tasks, surface
  arcs, flag high-leverage work. None of this needs human consent — the
  agent is free to reason about value continuously.
- **Human authority:** weights, free drivers, scoped drivers, confirmation
  of scores, enabling auto-promote. All §ACD-gated.

This is **D8 sovereignty-at-policy-edit**: the policy is what defines
"value" for the project. Changing the policy is changing what the project
*means*, and that decision belongs to the human. The estimator's
proposal-only design (M3) is the same boundary at the per-task level.

## Reversibility (no one-way doors)

Every BVP mutation is reversible:

- **Weight changes** are logged to `.context/bvp-weight-history.yaml`. The
  rationale is preserved; re-running with the prior value reverses the
  change cleanly.
- **Free driver add/remove** is symmetric — the M1 drop-one event captures
  what was lost, so the inverse is mechanical.
- **Scored tasks** retain `bvp_scores_proposed:` history; re-confirming
  with an earlier proposal reverses the confirmation.
- **Rubric changes** invalidate estimator output but do not retroactively
  rewrite confirmed scores (the historical record persists).
- **Auto-promote** ships **off** by default; enabling is §ACD-gated and
  reversible by flipping the flag.

The R9 reversibility commitment is structural, not aspirational: there is
no BVP action that cannot be undone with another BVP action.

## Source-of-truth files

| File | Owner | Purpose |
|------|-------|---------|
| `policy/value-drivers.yaml` | Human (§ACD) | Driver list + weights + auto-promote config |
| `policy/bvp-scoring-rubric.md` | Human (Tier-1 edits ok; load-bearing) | Per-driver scoring criteria + worked examples |
| `.context/bvp-weight-history.yaml` | Auto (mutating CLI) | Audit trail for weight + driver edits |
| `.context/audits/arc-scoped-driver-bypass.jsonl` | Auto (`fw arc approve-driver`) | Audit trail for scoped-driver decisions |
| Per-task frontmatter: `bvp_scores`, `bvp_scores_proposed`, `cost_estimate` | Mixed | Confirmed scores (human), proposals (estimator), cost composite (computed) |

## Driver Session Prompt Bundle (T-2245 / T-2246)

When proposing a new free driver, arc-scoped driver, or sharpening an
existing one, the canonical workflow lives in **`policy/prompts/`**:

- `bvp-driver-session.md` — keystone: three workflows (A=batch-propose,
  B=discover+sharpen, C=sharpen named topic), entry/exit conditions,
  outputs, anti-patterns, init refusal, degraded mode.
- `artefact-template.md` — research artefact YAML frontmatter + 10
  sections. References §6 of `INGESTION-bvp-driver-prompt-bundle-2026-06-06.md`
  as the canonical worked example.
- `bvp-references/sharpening-subroutine.md` — R1 (differentiation),
  R2 (weight calibration), O1-O4 (edge/scope/overlap/rubric, optional),
  skip-when-stuck mechanics.
- `bvp-references/sharpening-tactics.md` — conversational moves:
  surfacing assumptions, drilling scope without leading, eliciting
  weight without anchoring, recovering from frustration.
- `bvp-references/discipline-failure-modes.md` — anti-patterns: driver
  inflation, overlap with directives, manufactured drivers, single-axis
  routing, skipped dialogue capture, death-marching, cap blindness,
  init skip, defer-as-hedge, spec-over-dialogue drift.
- `bvp-references/global-driver-examples.md` — three worked global
  free-driver proposals (F-RECALL real reconstruction, killed-mid-session,
  recommend --none).
- `bvp-references/arc-scoped-driver-examples.md` — three worked arc-
  scoped proposals (Workflow A batch-propose, Workflow B discover,
  Workflow C sharpen named topic).
- `policy/prompts/README.md` — bundle orientation, why bundles not skills.

Read the keystone first; reach into references when a specific tactic,
example, or failure mode applies.

## See also

- `CLAUDE.md` §"Arc-Scoped Driver Suggestion Workflow" — the 5-step protocol
  the agent runs after a new arc is created
- `012-ArcSystem.md` — arc lifecycle and `scoped_drivers:` field reference
- `010-TaskSystem.md` — task frontmatter, including the BVP fields
- `docs/reports/T-1915-bvp-inception.md` — inception artefact with full
  mechanic list, risk register, and Geelen 2019 origin discussion
- `policy/prompts/bvp-driver-session.md` — driver-session keystone (see above)
