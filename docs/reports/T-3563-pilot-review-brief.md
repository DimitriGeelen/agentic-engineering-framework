# External review — T-3563 pilot: do these arc drafts faithfully explain their arcs?

You are an independent reviewer with **read-only** access to a software repository (the
Agentic Engineering Framework, AEF). You did not write these drafts and owe their authors
nothing. Do not modify anything.

## Background (short)

An **arc** in AEF is a container for a feature or initiative spanning many tasks. It is a
YAML file in `.context/arcs/<slug>.yaml`. Arcs explained themselves badly: the reasoning
lived in the arc's *anchor inception* (a task plus a research report with the human
operator's words) and the arc never showed it. A three-vendor review settled a new set of
fields, and the operator adopted them:

`purpose` (≤25 words, what and why) · `objective` (≤40 words, the outcome state that value
drivers, task scoring and closure are judged against) · `supports` (project objective IDs;
none exist yet, so empty is correct) · `success_criteria` (what closure checks one by one)
· `non_goals` · `context` (3–6 bullets, each linking a source) · `decisions` (≤20 words
each, with status and source) · `open_questions` · `history` · `evidence` · `provenance`.
The existing `headline_mechanic` (a testable demo claim) stays unchanged and separate.

**The operator's rule:** an agent drafts; an independent panel, which is you, checks each
draft against its sources; nothing needs the operator's approval, and the operator may
correct afterwards. So your review is what stands between a draft and the live arc.
Mechanical checks already passed: valid YAML, word limits met, and all 112 cited paths
exist.

## The three drafts

| arc | draft | the arc itself |
|---|---|---|
| continuous-run | `docs/reports/T-3563-pilot-continuous-run.yaml` | `.context/arcs/continuous-run.yaml` |
| readme-first-run | `docs/reports/T-3563-pilot-readme-first-run.yaml` | `.context/arcs/readme-first-run.yaml` |
| orchestrator-rethink | `docs/reports/T-3563-pilot-orchestrator-rethink.yaml` | `.context/arcs/orchestrator-rethink.yaml` |

Each draft lists its sources under `provenance`. Open them.

## For each arc, check

1. **Fidelity.** Is every context point, decision and history line actually supported by
   the source it cites? Spot-check at least four citations per arc by opening the file.
   Flag anything invented, overstated, or attributed to the wrong source.
2. **Substance.** Is `purpose` specific to this arc, or would it fit any arc? Is it
   boilerplate?
3. **Objective quality.** Is `objective` an outcome state, not an activity list? Could the
   arc's scoped drivers, its task scoring and a closure check be judged against it? Does it
   duplicate the `headline_mechanic` instead of complementing it?
4. **Success criteria.** Are they observable, and do they match what the arc actually set
   out to do?
5. **Omissions.** Is there a decision, pivot or open question in the sources that a cold
   reader needs and the draft leaves out?

## Answer format — one block per arc, then an overall line

```
ARC: <slug>
VERDICT: green | amber | red
  green = apply as drafted; amber = apply with the corrections below; red = redraft
FIDELITY: <what you checked, and any claim not supported by its source>
CORRECTIONS:
  - field: <field name, or list item>
    replace_with: <the exact replacement text or YAML>
    why: <one line>
```

Keep corrections to what matters. Give exact replacement text, so the corrections can
be applied without another round. End with:

```
OVERALL: <one sentence — is this structure, drafted this way, fit to go live?>
```
