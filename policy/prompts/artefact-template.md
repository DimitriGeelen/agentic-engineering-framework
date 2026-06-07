# BVP Driver Session — Research Artefact Template

Every `fw bvp driver suggest|create` session produces a research artefact at `docs/reports/T-XXXX-bvp-driver-<slug>.md`. This template defines the shape. The verb handler writes the file using this structure; the agent fills the content from the dialogue.

The canonical worked example is `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` itself — that document was authored as a research artefact for the BVP bundle inception. §6 of that document demonstrates every section of this template applied to a real session.

## Frontmatter (YAML)

```yaml
---
artefact_type: bvp-driver-session
task_id: T-XXXX
driver_id: <F-SLUG or arc-scoped-slug>
driver_name: <human-readable>
scope: global | arc:<arc-id>
created: <YYYY-MM-DDTHH:MM:SSZ>
operator: <handle>
workflow: A | B | C        # batch_propose | suggest | create
mode: <mode-string-from-verb>
session_duration_min: <int>
recompute_triggered: true | false
recompute_scope: global | arc:<id> | none
---
```

## §1 — Context

One paragraph: why this session was run, what triggered the driver question, what the operator said in the opening invocation. Include the exact verb invocation:

```
fw bvp driver suggest                    # Workflow B
fw bvp driver create "team-velocity"     # Workflow C
fw arc create <arc> --driver-propose     # Workflow A (indirect)
```

If the session originated from a concern, a prior session, or an arc-grooming pass, link the predecessor (`T-YYYY`, `G-NNN`, arc id).

## §2 — Candidates Considered

For Workflow A and B, list every candidate that was proposed (numbered, one-line rationale each). Use the same format the agent showed the operator:

```
1. <name> — <one-line: what this distinguishes>
2. <name> — <one-line>
3. <name> — <one-line>
none — proposed; operator declined
```

For Workflow C, this section reads:

```
Workflow C — operator named "<topic>" directly. No candidate scan run.
```

Preserve the operator's exact pick ("operator picked #2: <name>") so future readers can reconstruct the decision.

## §3 — Picked Candidate

The candidate that the operator selected (or named, in Workflow C). State it in one sentence, then move into the sharpening dialogue.

## §4 — Sharpening Dialogue

This is the **mandatory** dialogue log. Capture the actual back-and-forth between agent and operator, not a summary. Format:

```
### R1 — Differentiation

**Agent:** <verbatim or near-verbatim prompt>

**Operator:** <verbatim or near-verbatim response>

**Agent:** <follow-up>

**Operator:** <response>

[CONVERGED]: <one-line summary of what was agreed for R1>

### R2 — Weight Calibration

(same shape)

[CONVERGED]: <one-line summary of weight + rationale>

### O1 — Edge Cases (drilled)

(same shape if drilled; "[SKIPPED]: operator didn't engage" if not)

### O2, O3, O4 — same pattern
```

Markers for navigation:

- `[CONVERGED]:` — what the dimension settled on
- `[SKIPPED]:` — operator deferred or session ran out of time
- `[REJECTED]:` — a sub-option was considered and explicitly killed
- `[OPEN]:` — an unresolved sub-question, surfaced in §7

Capture interruptions, course corrections ("we are not doing X, we are doing Y"), and operator-flagged misunderstandings. These are the highest-signal artifact content. The dialogue log captures *why* and *how*; the spec captures only *what*.

## §5 — Decisions Ledger

| ID | Decision | Decided-by | Reversibility |
|----|----------|------------|---------------|
| D1 | <decision> | operator/agent | reversible/load-bearing |
| D2 | <decision> | operator/agent | reversible/load-bearing |

Every load-bearing decision from §4 surfaces here. The ledger is the index; §4 is the prose.

"Load-bearing" = the decision changes the spec, the rubric, the weight, or the scope. "Reversible" decisions are stylistic or cosmetic. Mark them honestly — load-bearing decisions need future-reader visibility.

## §6 — Rejected Paths

Bullet list of approaches considered and explicitly killed. One sentence each, naming the rejection reason:

- `<approach>` — rejected because <reason>.
- `<approach>` — rejected because <reason>.

Future agents should be able to skip these. If a future session starts proposing one of these, the artefact is the structural answer.

If no paths were rejected, write "No paths rejected — only one approach considered." Do not invent rejected paths to fill the section.

## §7 — Open Questions

Any `[OPEN]` markers from §4. Format:

```
- **OQ-1:** <question text>
  triggered_in: §4.R2 (or wherever)
  resolution_path: file a follow-up driver-edit session, OR defer to next arc-grooming pass, OR <other>
```

If no questions are open, write "All dimensions converged; no open questions."

## §8 — Final Spec

The exact YAML that the handler wrote to `policy/value-drivers.yaml` or the arc YAML. Copy-paste verbatim — this is the authoritative record. Future readers can `grep` this section for the driver's id and find its full provenance.

```yaml
- id: F-<SLUG>
  name: <name>
  weight: <N>
  status: active
  added: <date>
  added_by: <operator>
  source_task: T-XXXX
  rationale: |
    R1: ...
    R2: ...
    (drilled dimensions if any)
  scoring_rubric:
    "0": ...
    "1": ...
    "2": ...
    "3": ...
    "4": ...
    "5": ...
  retire_when: <plain-text>
```

## §9 — Operational Consequences

What changes downstream because this driver landed:

- **Tasks rescored:** <count> (from `fw bvp recompute` audit entry)
- **Arcs rescored:** <count>
- **Ranking shift:** <one-line: did the top-of-list change? Did any task lose its prior-#1?>
- **New BVP top-5 (after recompute):**

```
1. T-XXXX — <name>  (BVP: X)
2. T-XXXX — <name>  (BVP: X)
...
```

If the recompute was deferred (global driver, operator hasn't run `fw bvp recompute --scope global` yet), state:

```
Recompute pending — operator will trigger via `fw bvp recompute --scope global`.
```

If the operator declines recompute (arc-scoped driver with `--none --justification`), preserve the justification verbatim in this section.

## §10 — Provenance & Reproducibility

```
session_started: <ts>
session_concluded: <ts>
agent_model: <e.g. claude-opus-4-7>
fw_version: <from VERSION file>
bundle_revision: <git sha of policy/prompts/ at session start>
predecessor_artefacts:
  - <T-XXX>: <name>
  - <T-YYY>: <name>
followup_artefacts: <filled later by future sessions that reference this one>
```

This section is filled by the handler automatically; the agent should not edit it.

## Cross-references

This template references:

- `policy/prompts/bvp-driver-session.md` — the prompt that drove this session
- `policy/prompts/bvp-references/sharpening-subroutine.md` — the R1/R2/O1-O4 dimensions §4 reflects
- `policy/prompts/bvp-references/discipline-failure-modes.md` — anti-patterns the dialogue should avoid
- `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6 — the canonical worked example

## What this template does NOT enforce

- **Section length.** Some sections (§4 sharpening dialogue) are naturally long; others (§6 rejected paths) may be short or empty. Don't pad to hit length targets.
- **All sections present.** §6, §7, §9 may be empty if there's genuinely nothing to record. Empty sections must still appear (so readers know they were considered, not forgotten) with the explicit "nothing here" sentence noted above.
- **A specific writing style.** Match the operator's voice and the technical density of the topic. Some drivers warrant terse precision; others warrant prose explanation.

The template enforces **shape and traceability**. The content shape comes from the dialogue, not from the template.
