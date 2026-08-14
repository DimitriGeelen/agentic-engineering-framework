# Arc-Scoped Driver — Worked Examples

Three worked arc-scoped driver proposals. Arc-scoped drivers differ structurally from global free drivers in three ways:

1. **Cap.** ≤3 approved per arc, weight ≤6 (not the global ≤9).
2. **Scope.** Affect ranking only within the arc; don't compete for global slots.
3. **Workflow shape.** Workflow A (batch-propose at arc-draft) is the common entry; Workflows B/C also work but on the arc's task corpus.

The arc-scoped suggestion workflow is documented in CLAUDE.md §Arc-Scoped Driver Suggestion Workflow (T-1925, arc-006) — read that first if you haven't.

These examples illustrate the shape; specific drivers may or may not ever ship as real arc-scoped drivers in this project.

---

## Example 1 — `arc-007 interface-redesign` arc, batch-propose (Workflow A)

### §1 Context

Operator created arc-007 (interface redesign) and asked for batch-proposed arc-scoped drivers. Workflow A: agent proposes 2-3 candidates with one-line rationales, written to the arc YAML's `proposed_scoped_drivers:` field. Approval stays with the operator via `fw arc approve-driver`.

### §2 Candidates Considered

Workflow A — agent reads the arc anchor task body (Problem Statement, Scope Fence, Risks, Decisions) and proposes:

```
1. visual-rhythm — distinguishes work whose value is in layout/typography/spacing read by humans, which D3 Usability's broader scope doesn't isolate
2. interactive-discoverability — distinguishes work that makes existing features findable (k-command palette, breadcrumbs, settings) from work that adds features
3. theme-coherence — distinguishes work that strengthens the design-system tokens (colour palette, density preset) from work that adds new tokens
```

### §3 Picked Candidates (Workflow A — operator picks at approval time, not during this session)

Operator reviews via `fw arc show-suggestions arc-007` then approves selectively via `fw arc approve-driver`:

- `visual-rhythm` approved at weight 5
- `interactive-discoverability` approved at weight 4
- `theme-coherence` declined ("we're not yet at the design-system-token stage; revisit after S3/S5 land")

### §4 Sharpening Dialogue (skipped — Workflow A is one-line rationales, not full sharpening)

[SKIPPED]: Workflow A — sharpening only runs on Workflows B and C.

### §5 Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | 2 of 3 candidates approved | operator | reversible |
| D2 | theme-coherence declined with justification | operator | reversible |

### §8 Final Spec (in arc-007.yaml)

```yaml
scoped_drivers:
  - id: visual-rhythm
    name: Visual Rhythm
    weight: 5
    approved: 2026-05-20
    approved_by: dimitri
    rationale: |
      R1 (one-line): distinguishes layout/typography/spacing work read by
      humans, which D3 Usability's broader scope doesn't isolate.
      R2 (one-line): weight 5, anchored above interactive-discoverability
      (4) because rhythm is more often the operator's "feels wrong" trigger
      than discoverability is.

  - id: interactive-discoverability
    name: Interactive Discoverability
    weight: 4
    approved: 2026-05-20
    approved_by: dimitri
    rationale: |
      R1 (one-line): distinguishes work that makes existing features
      findable from work that adds features.
      R2 (one-line): weight 4, anchored below visual-rhythm (5) because
      discoverability problems are more actionable when found (settings
      gear, command palette) vs. layout issues which require taste calls.

proposed_scoped_drivers:
  - name: theme-coherence
    rationale: Distinguishes design-system token work from feature work.
    declined_at: 2026-05-20
    declined_reason: Not yet at design-system-token stage; revisit after S3/S5 land.
```

### §9 Operational Consequences

After arc-scoped recompute (auto-triggered on `fw arc approve-driver`): within arc-007's 23 tasks, T-2024 (cockpit inline style hexes) climbed from #6 to #2 because visual-rhythm scores it 5. T-2032 (settings gear) climbed from #11 to #4 because interactive-discoverability scores it 5.

---

## Example 2 — `arc-009 horizon-axis-hardening` arc, discover + sharpen (Workflow B)

### §1 Context

Operator invoked `fw bvp driver suggest` while focused on arc-009 (horizon axis hardening). Workflow B scans the arc's task corpus and surfaces candidates; operator picks one; agent runs the sharpening subroutine.

### §2 Candidates Considered

```
1. horizon-fidelity — distinguishes work that hardens the horizon-axis surface (read path, write path, derived state) from work that touches horizon as a side-effect
2. terminal-state-cleanup — distinguishes work that cleans up trailing fields on completed/abandoned items from work that adds new fields
3. drift-detection — distinguishes work that adds drift-detection surfaces (audit checks, doctor warnings) from work that fixes drift instances
none — none of these
```

### §3 Picked Candidate

Operator picked #1: `horizon-fidelity`.

### §4 Sharpening Dialogue

#### R1 — Differentiation

**Agent:** "What does horizon-fidelity distinguish that D2 Reliability doesn't?"

**Operator:** "D2 is broad — no silent failures. horizon-fidelity is specifically about the horizon-axis surface: read path (audit), write path (update-task.sh), derived state (cards on /tasks). A task that hardens one of those three should rank above a task that fixes a generic D2 issue, within this arc."

**Agent:** "Test: a task that scores high on horizon-fidelity AND low on D2?"

**Operator:** "T-2160 — the dropdown filter on /tasks. That improves horizon visibility without fixing a silent failure."

[CONVERGED]: horizon-fidelity = work on the horizon-axis read-path / write-path / derived-state. D2 is the broader reliability surface.

#### R2 — Weight Calibration

**Agent:** "Where on 1-6 (arc-scoped cap)? Anchor."

**Operator:** "Top of the cap. 6. This arc exists because horizon was fragile across all three surfaces; anything that hardens one of them is the highest-signal arc work."

**Agent:** "Confirming 6 even though arc-scoped 6 is heavier than D3 (5) and D4 (3) globally — that means within this arc, horizon-fidelity work outranks generic D3/D4 work."

**Operator:** "Yes. That's what I want. Within this arc, horizon-fidelity work IS the point."

[CONVERGED]: weight 6 (arc-scoped cap), explicit choice to outrank D3/D4 within arc context.

#### O1 — Edge Cases (drilled)

**Agent:** "Score 0?"

**Operator:** "Anything unrelated to horizon."

**Agent:** "Score 5?"

**Operator:** "A fix that closes the entire write-side drift class (like T-2163)."

**Agent:** "Score 3?"

**Operator:** "A fix to one of the three surfaces but not a class-closing fix."

[CONVERGED]: 0=unrelated; 3=single-surface fix; 5=class-closing fix.

#### O2, O3, O4 (skipped)

[SKIPPED]: arc-scoped drivers don't require rubric for scoring; the operator's taste applies at scoring time.

### §5 Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | horizon-fidelity is the arc's keystone driver | operator | load-bearing |
| D2 | Weight 6 (max), explicitly outranks D3/D4 within arc | operator | load-bearing |
| D3 | No rubric written (arc-scoped exemption) | jointly | reversible |

### §6 Rejected Paths

- `terminal-state-cleanup` — operator: "that's a sub-case of horizon-fidelity; same dimension."
- `drift-detection` — operator: "that's a workflow pattern, not a per-task quality dimension; doesn't fit BVP scoring."

### §8 Final Spec (in arc-009.yaml)

```yaml
scoped_drivers:
  - id: horizon-fidelity
    name: Horizon Fidelity
    weight: 6
    approved: 2026-06-01
    approved_by: dimitri
    rationale: |
      R1: Captures work on the horizon-axis read-path (audit),
      write-path (update-task.sh), and derived-state (cards on /tasks).
      D2 Reliability is the broader no-silent-failures surface; this
      arc exists because horizon was fragile across all three.
      R2: Weight 6 (arc-scoped cap), chosen explicitly to outrank D3/D4
      within this arc. Within arc-009, horizon-fidelity work IS the point.
      O1: 0=unrelated; 3=single-surface fix; 5=class-closing fix.
```

### §9 Operational Consequences

Auto-recompute triggered (arc-scoped). Within arc-009's 4 tasks: T-2163 (write-side fix) and T-2162 (audit CTL-030) both rank above T-2160 (filter dropdown) — matches operator's mental model.

---

## Example 3 — `arc-006 bvp` arc, sharpen named topic (Workflow C)

### §1 Context

Operator invoked `fw bvp driver create "estimator-coverage"` while focused on arc-006 (BVP). The arc has the BVP estimator worker as a major substrate; operator wants to track work that improves estimator coverage as an arc-scoped driver.

### §3 Picked Candidate

`estimator-coverage` — captures work that improves the BVP estimator's signal extraction from task bodies.

### §4 Sharpening Dialogue

#### R1 — Differentiation

**Agent:** "What does estimator-coverage distinguish that D2 (Reliability) or D3 (Usability) doesn't?"

**Operator:** "D2 and D3 are project-wide. estimator-coverage is specifically about: when the estimator scores a task, does it produce a non-no-signal rationale? Improvements to that signal-extraction are what this driver tracks."

**Agent:** "Test: a task scoring high here, low globally?"

**Operator:** "T-2168 — added F-RECALL+F-ORCH dedicated heuristics. Within arc-006 that's huge; globally it scored as a generic D1 task."

[CONVERGED]: estimator-coverage = work that improves signal extraction in the BVP estimator, distinct from generic D-driver work.

#### R2 — Weight Calibration

**Agent:** "Where on 1-6? Anchor."

**Operator:** "5. Not 6 because the arc has other dimensions too (e.g. UI surfaces, audit integrations). 5 leaves headroom for a future arc-keystone driver if one emerges."

[CONVERGED]: weight 5, deliberately leaving the 6-slot open.

#### O1 — Edge Cases

**Agent:** "Score 0 / 5?"

**Operator:** "0 — UI work that doesn't touch estimator. 5 — a new heuristic that closes a no-signal class."

[CONVERGED]: 0=no-estimator-touch; 5=class-closing heuristic.

#### O2 — Scope Test (drilled)

**Agent:** "3 recent arc-006 tasks. Which would estimator-coverage dominate?"

**Operator:** "T-2168 yes, T-2171 yes (activation gate, indirectly), T-2185 no (gauge-closure surface, no estimator touch)."

[CONVERGED]: 2 of 3 dominated. Good scope shape.

#### O3, O4 (skipped — operator low engagement)

[SKIPPED]: operator said "ship it, I'll iterate". Honoured per skip-when-stuck.

### §5 Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | Approve estimator-coverage as arc-scoped driver | jointly | load-bearing |
| D2 | Weight 5 (deliberately leaving 6-slot open) | operator | load-bearing |

### §8 Final Spec (in arc-006.yaml)

```yaml
scoped_drivers:
  - id: estimator-coverage
    name: Estimator Coverage
    weight: 5
    approved: 2026-06-01
    approved_by: dimitri
    rationale: |
      R1: Tracks work that improves the BVP estimator's signal extraction
      from task bodies. Distinct from D2/D3 which are project-wide.
      R2: Weight 5, deliberately leaving 6-slot open for a future
      arc-keystone driver.
      O1: 0=no-estimator-touch; 5=class-closing heuristic.
      O2: scope test 2/3 dominated on recent arc tasks.
      O3/O4: [OPEN] — operator declined to drill; iterate via
      `fw bvp driver edit` if signal gets noisy.
```

### §9 Operational Consequences

Auto-recompute triggered. Within arc-006: T-2168 ranks #1 (was #4 pre-driver); T-2171 ranks #2 (was #7). Operator: "exactly the shape I expected."

---

## What these examples teach

- **Workflow A is fast.** Example 1's batch-propose ran in one round per candidate — no sharpening.
- **Workflow B sharpens deeply.** Example 2 drilled R1, R2, O1 fully. The artefact captures *why* horizon-fidelity outranks D3/D4 within arc-009 — that's the load-bearing decision.
- **Workflow C honours operator bandwidth.** Example 3's operator skipped O3/O4 explicitly. Don't death-march; the artefact records the `[OPEN]` honestly.
- **Arc-scoped weights deliberately differ from globals.** Example 2 went to the cap (6); Example 3 left room for a future keystone driver. Both are deliberate.
- **Decline is a valid outcome.** Example 1's `theme-coherence` was declined-with-justification. That's not failure — that's the operator using the workflow as designed.
- **The cap rule matters.** Example 1 approved 2 of 3 candidates; if all 3 had been approved (with theme-coherence at weight 5), arc-007 would have hit the 3-cap. Future arc-007 driver sessions would need to retire an existing driver before adding a new one.
