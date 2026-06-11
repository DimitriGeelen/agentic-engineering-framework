---
artefact_type: bvp-driver-session
task_id: T-2255
driver_id: (3 proposals — see §3)
driver_name: (3 proposals — see §3)
scope: arc:arc-001
created: 2026-06-08T11:27:25Z
operator: (none — agent-only proposal pass)
workflow: A
mode: batch_propose
session_duration_min: 35
recompute_triggered: false
recompute_scope: none
---

# T-2255 — BVP driver session: arc-001 dispatch-safety (Workflow A dogfood)

## §1 — Context

This is an **agent-only Workflow A proposal pass** dogfooding the BVP driver-session bundle (`policy/prompts/`) on an in-progress arc that has never had `proposed_scoped_drivers:` populated. arc-001 (dispatch-safety) was selected because:

- It has a clearly-defined, wire-level `headline_mechanic` (worker pauses on severity×likelihood threshold → emits `pause_requested` → exits → operator resolves → re-dispatch with `retry_of_dispatch_id` link → worker completes first-try).
- It is in-progress with 11 constituent tasks — sufficient corpus signal to anchor distinguishing dimensions.
- It is the highest-value of the six arcs (arc-001, arc-002, arc-003, arc-004, arc-005, arc-009) that have never had Workflow A run.

**Verb invocation:** none — this session was triggered by the operator's standing directive ("proceed as seen fit … focus … BVP prompt arc"). No `fw bvp driver suggest` or `fw arc create … --driver-propose` verb was used; the agent ran Workflow A's proposal step directly per §Arc-Scoped Driver Suggestion Workflow in CLAUDE.md (T-1925, the 5-step protocol).

**Predecessor artefacts:**
- `policy/prompts/bvp-driver-session.md` — the keystone the agent followed.
- `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6 — the canonical worked example.
- arc-006/007/008 — prior Workflow A runs whose `proposed_scoped_drivers:` shapes informed the YAML shape used here.

**Variant honesty:** the bundle documents Workflow A as triggered by `fw arc create … --driver-propose` on a freshly-drafted arc with operator dialogue. arc-001 is already in-progress and there is no operator on the line. This is therefore a *variant* Workflow A pass — proposals written to `proposed_scoped_drivers:` without operator engagement, awaiting later approval. The §4 sharpening dialogue section reflects this honestly (no dialogue ran).

## §2 — Candidates Considered

```
1. uncertainty-recognition — distinguishes worker-DECISION-level epistemic honesty
   from D1/D2's framework-level resilience/no-silent-failure
2. severity-likelihood-calibration — distinguishes pause-trigger tuning quality
   from D2's "the worker emits SOMETHING" floor
3. operator-resolution-latency (WEAK) — distinguishes the operator-interrupt-cost
   dimension of pause-to-resolve from D3's general usability; may be too D3-adjacent
```

Three candidates: one strong (#1), one moderate (#2), one explicitly weak (#3). Per R5 (manufactured-drivers) and the `discipline-failure-modes.md` driver-inflation counter-move: *"When in doubt, propose one strong candidate and one weak one, naming the weak one as weak — give the operator a chance to confirm 'yeah, just the strong one' without the false-thoroughness signal."*

## §3 — Picked Candidate

No operator engagement yet — all three are PROPOSED, none picked. The artefact's §8 Final Spec mirrors the YAML write for **all three** candidates as `proposed_scoped_drivers:` entries. The operator picks via `fw arc approve-driver dispatch-safety "<name>" --weight N --i-am-human|--from-watchtower` once that verb lands (currently captured under arc-006, see T-1925/T-1926), or via direct YAML edit before that.

## §4 — Sharpening Dialogue

**[NO DIALOGUE — agent-only proposal pass.]**

Per `bvp-driver-session.md` Workflow A description: *"Do not run sharpening per candidate — proposal-shape is one line + one-line rationale, not a full session."* §4 is canonically minimal/absent in Workflow A artefacts. The bundle's sharpening subroutine (R1+R2 required, O1-O4 optional) runs in Workflows B/C only.

R1 (differentiation) is captured per-candidate in §8's `rationale` field. R2 (weight calibration) is captured in the `weight:` field and anchored in §8's rationale prose. When the operator engages with one of these candidates (via approve, `--none`, or a follow-up `fw bvp driver create <name>` Workflow C pass), a successor artefact will carry the full sharpening dialogue.

## §5 — Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | Run agent-only Workflow A variant on arc-001 (no operator dialogue) | agent | reversible |
| D2 | Propose 3 candidates with one explicitly labelled weak (R5 counter-move) | agent | reversible |
| D3 | Weights 5/4/3 (descending) reflect strength-of-distinction ordering, anchored to existing scoped drivers (arc-007 aesthetic-cohesion=5 strong-distinction, arc-006 estimator-fidelity=3 weaker) | agent | load-bearing if approved |
| D4 | `uncertainty-recognition` (not `epistemic-honesty` or `worker-uncertainty`) for the strong candidate — name optimises for both operator-reading (backlog view) and estimator-reading (rubric scoring), per single-axis-routing anti-pattern counter-move | agent | reversible (re-namable via `fw bvp driver edit` once verb lands) |

## §6 — Rejected Paths

- **`pause-protocol-fidelity`** — rejected because too narrow: it scores adherence to the specific pause/resolve mechanic rather than a general arc-wide dimension. Tasks NOT building the pause mechanic would score 0 across the board, making the driver near-uniform and low-signal. Per `discipline-failure-modes.md` "manufactured drivers": *"the driver's scoring rubric is hard to write because there's no real signal to score against."*
- **`risk-policy-coverage`** — rejected because it's a sharpening of D2 (Reliability — no silent failures). A task with high risk-policy coverage is, by definition, more reliable around uncertainty; the global D2 already rewards this. R1 produces *"this is about reliability"* → kill per overlap-with-directives counter-move.
- **`mid-dispatch-state-loss-prevention`** — considered as a worker-side reliability dimension; rejected because (a) it's a subset of D2 again, and (b) the v1 pause+exit-clean design already structurally prevents mid-dispatch state loss, so the driver would always score uniformly high.
- **Recommending `--none`** — considered honestly per R5. Decided AGAINST because arc-001's `headline_mechanic` is structurally different from D1-D4 (it scores worker epistemic state, not framework state) — there IS a real distinction to draw. The weak candidate (#3) is a hedge so the operator can land 1-2 drivers cleanly without #3 if they prefer.

## §7 — Open Questions

- **OQ-1:** Should `uncertainty-recognition` and `severity-likelihood-calibration` be merged into one driver (`uncertainty-handling`)? Counter-argument: they score different aspects (recognition = epistemic act, calibration = threshold-tuning). Resolution path: operator engages with one of them via Workflow C, sharpens R1 via the dialogue, decides whether merging is more honest than keeping separate.
  - triggered_in: §6 rejected-paths reasoning while considering whether to collapse #1 + #2.
  - resolution_path: defer to operator's first engagement with this proposal — `fw bvp driver create uncertainty-handling` Workflow C would produce the merged variant; approving #1 and #2 separately commits to the split.

- **OQ-2:** Does `operator-resolution-latency` (#3) actually distinguish from D3 enough to warrant its own driver? The R1 articulation is plausible (D3 = joy-to-use generally, this = interrupt-cost specifically), but the boundary is subtle.
  - triggered_in: §2 candidates list — weak labelling.
  - resolution_path: operator's first read of this artefact answers OQ-2 directly. Most likely outcome: operator either approves #1 + #2 and `--none`-justifies #3, OR engages with #3 via Workflow C to sharpen the boundary.

## §8 — Final Spec

The exact YAML written to `.context/arcs/dispatch-safety.yaml`:

```yaml
proposed_scoped_drivers:
  - name: uncertainty-recognition
    weight: 5
    rationale: >-
      Distinguishes worker-DECISION-level recognition of "I don't have enough
      information to proceed safely" from D1 (Antifragility — framework-level
      stress-strengthening) and D2 (Reliability — framework-level no-silent-
      failures). arc-001's headline_mechanic scores the worker's epistemic act
      (pause_requested, severity×likelihood self-assessment, risk-policy preamble),
      not the framework's robustness around the worker. A task scores high if it
      builds pause-detection logic, self-assessment rubrics, or worker-side
      uncertainty signalling. Anchored heavier than arc-006 estimator-fidelity (3)
      because the distinction is sharper, lighter than D1 (9) because it scores
      one specific worker decision class.
    source: agent
    ts: 2026-06-08T11:27:25Z
  - name: severity-likelihood-calibration
    weight: 4
    rationale: >-
      Distinguishes how well-calibrated the pause-trigger threshold is from D2's
      "the worker emits SOMETHING when it can't proceed" floor. D2 is binary
      (emits / silent); this driver scores the *quality* of when pauses fire —
      false-positive rate (pause on noise → operator-cost waste) and false-
      negative rate (silence under real ambiguity → wrong work shipped). Tasks
      that tune the threshold, audit live pause rates against retrospective
      "should-have-paused" classification, or revise the risk-policy score high.
      Heavier than arc-006 estimator-fidelity (3) because calibration here has
      direct safety consequences (over-confidence ships wrong work); lighter
      than #1 because #1 is the prerequisite (you can't calibrate something the
      worker isn't recognising at all).
    source: agent
    ts: 2026-06-08T11:27:25Z
  - name: operator-resolution-latency
    weight: 3
    rationale: >-
      (WEAK candidate per R5 — flagged for operator decision.) Distinguishes the
      operator-interrupt-cost dimension of pause-to-resolve from D3 (Usability —
      joy to use/extend/debug overall). D3 covers usability broadly across all
      framework surfaces; this driver scores specifically the cost of operator
      attention when a pause fires (Watchtower badge surfacing, push-notification
      on pause, queue prioritisation of unresolved pauses, time-to-first-glance
      latency). Tasks reducing operator interrupt-cost score high. Recommended
      at weight 3 because the boundary with D3 is subtle — operator may prefer
      to keep this folded into D3 and approve --none on this candidate. See OQ-2.
    source: agent
    ts: 2026-06-08T11:27:25Z
```

## §9 — Operational Consequences

**Recompute not triggered.** Per `bvp-driver-session.md` "After-action recompute" section, arc-scoped driver *approval* auto-triggers `fw bvp recompute --scope arc:<arc-id>`. This session only writes *proposals* (`proposed_scoped_drivers:`), not approvals (`scoped_drivers:`). No recompute fires until the operator approves at least one candidate via `fw arc approve-driver` (T-1925/T-1926 — verb not yet implemented; see arc-006 for the parent inception that gates that work).

**What happens next:**

1. **Operator reviews this artefact.** The three candidates land in `proposed_scoped_drivers:` on `.context/arcs/dispatch-safety.yaml`. Watchtower `/arcs/dispatch-safety` will surface them once T-1930 (BVP Watchtower arc page extensions) ships — until then, the operator reads them via `grep -A 20 "proposed_scoped_drivers:" .context/arcs/dispatch-safety.yaml` or directly via the YAML file.

2. **Operator decides approve / `--none` / Workflow C sharpen.** Three plausible outcomes:
   - **Approve #1 + #2, `--none` #3** — likely if OQ-2 resolves toward "#3 folds into D3".
   - **Approve only #1, Workflow C-sharpen #2** — likely if the operator wants to drill calibration-rubric edge cases before committing weight.
   - **`--none` all three** — operator may prefer arc-001 stays ranked purely by D1-D4 + global free drivers. Valid outcome per "zero approved drivers is a valid outcome."

3. **If `fw arc approve-driver` verb has not yet landed** (status: T-1925/T-1926 captured in arc-006), the operator can still approve by directly editing `.context/arcs/dispatch-safety.yaml` to add a `scoped_drivers:` block mirroring the approved entries — same shape as arc-006's `estimator-fidelity` entry (with `approved_at:` timestamp). This bypass is structurally equivalent to the verb's planned behaviour.

**Successor artefact reference:** when the operator next engages this proposal (approve / `--none` / Workflow C), the engaging session should reference this artefact as a predecessor in its §10.

## §10 — Provenance & Reproducibility

```
session_started: 2026-06-08T11:27:25Z
session_concluded: 2026-06-08T11:35:00Z   (approx — single-pass authoring)
agent_model: claude-opus-4-7
fw_version: 1.6.9
bundle_revision: 2d303227c (HEAD at session start)
predecessor_artefacts:
  - T-2246: bvp-driver-prompt-bundle Path B build (bundle authoring)
  - T-2245: bvp-driver-prompt-bundle ingestion inception
  - T-2253: bundle ↔ §Arc-Scoped cross-link (this session's CLAUDE.md anchor)
  - INGESTION-bvp-driver-prompt-bundle-2026-06-06.md §6: canonical worked example
followup_artefacts: (filled by future sessions that engage these proposals)
```

## Cross-references

- `policy/prompts/bvp-driver-session.md` — the keystone followed in this session
- `policy/prompts/bvp-references/sharpening-subroutine.md` — R1/R2/O1-O4 (not drilled per Workflow A discipline; recorded for predecessor traceability)
- `policy/prompts/bvp-references/discipline-failure-modes.md` — R5 counter-move (driver inflation), overlap-with-directives, manufactured-drivers, skipped-dialogue-capture (avoided honestly via §4 "no dialogue" disclosure)
- `policy/prompts/bvp-references/arc-scoped-driver-examples.md` — worked examples of Workflow A on arc-scoped drivers
- `CLAUDE.md` §Arc-Scoped Driver Suggestion Workflow (T-1925) — the 5-step protocol this session enacted
- arc-006/007/008 — prior arc-scoped driver proposals whose YAML shapes informed §8's write
