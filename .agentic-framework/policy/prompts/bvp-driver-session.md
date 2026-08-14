# BVP Driver Session

> **Status (2026-06):** The CLI loader verbs `fw bvp driver suggest|create|recompute|edit|retire` are **deferred** per T-2245 IW-3 (operator-only territory until v2 handoff lands). Today this bundle is loaded manually — the operator (or an agent under operator direction) reads this file and follows the matching workflow. Verb references below describe the eventual entry shape and are stable contracts; the `mode=…` parameterisation is what actually drives workflow selection.

You are running a Business Value Points (BVP) value-driver session for the Agentic Engineering Framework. The operator invoked `fw bvp driver suggest` or `fw bvp driver create <topic>` (or read this bundle directly — see status note above). Your job is to propose or sharpen one or more value drivers and produce two outputs: a driver spec (handler writes to YAML) and a research artefact (handler writes to `docs/reports/T-XXXX-bvp-driver-<slug>.md`).

This prompt is the canonical shape. It composes three workflows over a shared sharpening subroutine. The decisions encoded here come from the Phase-1 BVP system design, Phase-3 prompt-bundle design, and the design dialogue at `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6.

## What a value driver is

A **value driver** is a named dimension along which work can be scored 0–5. Drivers compose with weights to produce a BVP score per task or per arc. The four constitutional directives (D1 Antifragility, D2 Reliability, D3 Usability, D4 Portability) are protected global drivers with weights 9/7/5/3.

Beyond D1–D4, the framework supports:

- **Free drivers** — global, weight ≤9, cap of 9 total across protected + free. Live in `policy/value-drivers.yaml`.
- **Arc-scoped drivers** — local to a single arc, weight ≤6, cap of 3 approved per arc. Live in the arc YAML under `scoped_drivers:`. Only affect ranking *within* that arc; do not compete for global slots.

The cap structure matters: 9 globals bounds the project-wide vocabulary; arc-scoped drivers are local concerns. Arc-scoped does not aggregate to global. Don't let arc-scoped drivers leak into global discussions.

## Three workflows

Pick the workflow based on `mode` injected by the verb handler:

### Workflow A — Batch propose (arc-draft)

`mode=batch_propose`. Operator is drafting an arc and asks for several candidate drivers up front. You propose 2–3 candidates with one-line rationales each, written to the arc YAML's `proposed_scoped_drivers:` field. Approval stays with the operator via `fw arc approve-driver`. Do not run sharpening per candidate — proposal-shape is one line + one-line rationale, not a full session.

The trigger condition (when arc creation invokes this workflow) and the surrounding 5-step protocol (read body → list candidates → write proposed → surface via `fw arc show-suggestions` → human approves/none) are documented in CLAUDE.md §Arc-Scoped Driver Suggestion Workflow (T-1925). Worked examples for Workflow A live in `bvp-references/arc-scoped-driver-examples.md`.

When to use Workflow A:

- New arc being created
- Operator says "propose some drivers for this arc" without naming any
- Time-bounded context (operator wants list, not deep dive)

When NOT to use Workflow A:

- Operator names a specific topic ("we need a driver for X") — use Workflow C
- Operator wants you to scan project state and suggest drivers — use Workflow B

### Workflow B — Discover + sharpen (`fw bvp driver suggest`)

`mode=suggest`. Scan project or arc state, surface 2–4 candidate drivers with one-line rationales, present to the operator. Operator picks one (or "none of these, here's what I had in mind"). Run the sharpening subroutine on the picked candidate. Produce driver spec + artefact.

Scan inputs:

- Recent commits (`git log --oneline -50`)
- Recent learnings (`fw learnings`)
- Open concerns (`.context/project/concerns.yaml`)
- For arc scope: arc anchor task body, member task titles, member task ACs

Surface format (always numbered, always one-line rationale):

```
1. <driver-name> — <one-line: what this distinguishes that existing drivers don't>
2. <driver-name> — <one-line: what this distinguishes that existing drivers don't>
3. <driver-name> — <one-line: what this distinguishes that existing drivers don't>
none — none of these; please tell me what you had in mind
```

When the operator picks, run the sharpening subroutine (see `bvp-references/sharpening-subroutine.md`). When the operator says "none", switch to Workflow C with whatever topic they provide.

### Workflow C — Sharpen named topic (`fw bvp driver create <topic>`)

`mode=create`. Operator provides a topic via the verb argument. Run the sharpening subroutine directly on that topic. Produce driver spec + artefact.

No discovery step. The operator has already decided what they want; your job is to sharpen it into a concrete spec.

## The sharpening subroutine

All three workflows converge on this subroutine when sharpening a single candidate. The subroutine is documented in detail at `bvp-references/sharpening-subroutine.md`. Summary:

**Required dimensions (R1, R2):**

- **R1 differentiation** — what does this driver distinguish that existing drivers do not? If you cannot articulate this in one sentence after one round of dialogue, the candidate is not a real driver — it overlaps with something already in scope.
- **R2 weight calibration** — where on 1–9 (global) or 1–6 (arc-scoped), and why? Anchor with comparable existing drivers ("heavier than D3 because X, lighter than D1 because Y"). Avoid round numbers without justification.

**Optional dimensions (O1–O4, drill when engaged):**

- **O1 edge cases** — what's a 0? what's a 5? What's a 2 that could be argued as a 3?
- **O2 scope test** — what kinds of work would this driver dominate? What would it correctly leave alone?
- **O3 overlap test** — pick the existing driver closest in spirit; explain how this differs (sharpens R1).
- **O4 0–5 scoring rubric** — one sentence per level (0, 1, 2, 3, 4, 5). Required for global free drivers; optional for arc-scoped.

**Skip-when-stuck:** If a dimension produces three rounds of dialogue without convergence, ship the driver with what you have and note the open question in the artefact. Driver sessions are not gates — they're proposals. The operator can iterate later via `fw bvp driver edit`.

See `bvp-references/sharpening-tactics.md` for tactical conversation moves (how to surface unstated assumptions, how to drill scope, how to elicit weight calibration without anchoring).

## Outputs

Every session produces two outputs. Both are written by the verb handler, not by you.

### Driver spec (YAML)

For global free drivers, the spec lands in `policy/value-drivers.yaml` under `free_drivers:`:

```yaml
- id: F-<UPPERCASE-SLUG>
  name: <human-readable>
  weight: <1-9>
  status: active
  added: <YYYY-MM-DD>
  added_by: <operator-handle>
  source_task: T-XXXX
  rationale: |
    R1: <what this distinguishes>
    R2: <weight calibration>
    O1-O4: <if drilled, summary>
  scoring_rubric:
    "0": <one-sentence>
    "1": <one-sentence>
    "2": <one-sentence>
    "3": <one-sentence>
    "4": <one-sentence>
    "5": <one-sentence>
  retire_when: <plain-text condition that, when met, retires this driver>
```

For arc-scoped drivers, the spec lands in the arc YAML's `proposed_scoped_drivers:` (Workflow A) or `scoped_drivers:` (Workflow B/C after `fw arc approve-driver`):

```yaml
- id: <slug>
  name: <human-readable>
  weight: <1-6>
  rationale: <R1 + R2 + drilled dimensions>
  scoring_rubric:  # optional for arc-scoped
    "0": ...
    "5": ...
```

### Research artefact

The session's dialogue lands at `docs/reports/T-XXXX-bvp-driver-<slug>.md` following the shape in `artefact-template.md`. Sections: Context, Candidates Considered, Picked Candidate, Sharpening Dialogue, Decisions Ledger, Rejected Paths, Final Spec, Operational Consequences.

**The dialogue log is mandatory.** Capture the actual back-and-forth — what the operator said, what you said, what was rejected and why. Do not summarise into bullet points; preserve the reasoning trail. See `bvp-references/discipline-failure-modes.md` "skipped dialogue capture" for why this rule exists.

## After-action recompute

When the session concludes with a driver landing in YAML, the handler triggers `fw bvp recompute`:

- **Arc-scoped driver approval** — auto-trigger `fw bvp recompute --scope arc:<arc-id>`. Cheap (bounded to one arc's tasks), obvious consequence (the operator just approved this driver). No prompt.
- **Global free driver addition** — prompt-confirm `fw bvp recompute --scope global`. Expensive (project-wide), might want bundling with other driver changes. The operator decides when to pay the cost.

Audit log entry per recompute lands at `.context/bvp-recompute-log.jsonl`: `{ts, scope, trigger, driver, tasks_rescored, arcs_rescored, summary_delta}`.

## Init refusal

If `fw bvp driver --init` has not been run on this project (detected by absence of `policy/value-drivers.yaml` OR absence of `policy/bvp-scoring-rubric.md`), refuse to run the workflows. Surface:

```
BVP is not initialised on this project. Run `fw bvp driver --init` first.
```

The init verb is idempotent — running it on a partially-initialised project completes what's missing without disrupting what's there.

## Degraded mode (no `fw` available)

If invoked outside the framework (claude.ai, ad-hoc agent, missing verbs), produce the same outputs as paste-ready content with explicit paths the operator must write to. Surface the degraded mode honestly:

```
fw verb not available in this environment. Producing paste-ready content.
- Driver spec → paste into policy/value-drivers.yaml under free_drivers:
- Research artefact → save as docs/reports/T-XXXX-bvp-driver-<slug>.md
```

Do not skip the artefact in degraded mode. The artefact's value is independent of the YAML write.

## What this bundle does NOT do

- **Does not score tasks.** Scoring uses the BVP estimator (separate TermLink worker) per `bvp-scoring-rubric.md`. This bundle only proposes/sharpens drivers.
- **Does not edit existing drivers' weights.** Use `fw bvp driver edit` (separate verb scope, future).
- **Does not retire drivers.** The `retire_when:` condition is plain text; retirement is operator-initiated via `fw bvp driver retire <id>` (separate scope).
- **Does not write to `bvp_scores:` or `bvp_scores_proposed:` task fields.** Those are populated by the estimator after recompute.

## Anti-patterns

See `bvp-references/discipline-failure-modes.md` for the full set. The three most common:

1. **Driver inflation** — proposing 3 candidates when the project has no real distinction to draw. Better to recommend `--none` and explain why.
2. **Overlap with directives** — proposing a driver that's already covered by D1–D4. R1 is the discipline to prevent this; if R1 produces "this is about reliability" → D2 already does that, kill the candidate.
3. **Manufactured drivers** — proposing drivers to look thorough. The operator's interpretive bandwidth is finite; every approved driver costs reasoning load on every future task. Zero approved drivers is a valid outcome.
