# External review — T-3535: are these the right project objectives for AEF?

You are an independent reviewer with **read-only** access to a software repository, the
Agentic Engineering Framework (AEF), at /opt/999-Agentic-Engineering-Framework. You did
not write the draft and owe its author nothing. Do not modify any file.

## Background (short)

AEF is a governance framework for AI coding agents: tasks, gates, context memory, audits,
reviews. Work is grouped into **arcs** (`.context/arcs/*.yaml`), which each carry a
`supports:` field meant to point at **project objectives**. No project objectives exist
yet. Their main job is to make work **declinable**: 20 arcs are in progress, several
stale, 300+ tasks await human review, and there is no basis for saying no to any of it.

An agent drafted the objectives from sources. The operator's rule: an agent drafts; an
independent panel (you) checks; the operator sees the result ONCE and corrects it. These
objectives sit above everything, so a wrong one quietly steers every arc under it.

## Read

- The draft: `docs/reports/T-3535-objectives-draft.md`. Section 1 has the proposed
  objectives, section 2 the arc mapping, and section 3 the author's own doubts.
- The design and rulings: `docs/reports/T-3535-per-project-objectives.md` and
  `.tasks/active/T-3535-*.md`
- The sources the draft cites. Open at least five of them, and read the arc YAMLs for
  any mapping you question.

## Check

1. **Fidelity.** Does each objective, and the headline, follow from its cited sources?
   Flag anything invented, overstated or mis-attributed.
2. **Outcome, not activity.** Is each objective a state of the world one could observe,
   rather than a work programme? Does each one avoid merely restating the four directives
   (antifragility, reliability, usability, portability)?
3. **Declinability.** Can each objective actually say "no" to some arc? Is any one so
   broad that everything fits under it?
4. **Coverage.** Is a real, source-backed project direction missing? The author asks
   specifically about: efficient model use (orchestrator-rethink), portability across
   agent runtimes (capability-overlay), and the conflict between T-010's "one repo, one
   framework instance" and the newer cross-project circuit ruling (T-3558).
5. **Mappings.** Which arc→objective mappings in section 2 are wrong or stretched?
   Which NONE mappings are wrong?
6. **Measures.** Is each measure honest about what can be computed today?

## Answer format

```
VERDICT: green | amber | red
  green = adopt as drafted; amber = adopt with the corrections below; red = redraft
FIDELITY: <what you checked; any claim not supported by its source>
CORRECTIONS:
  - target: <headline | O-n | out_of_scope | mapping:<arc> | new objective>
    replace_with: <exact replacement text or YAML>
    why: <one line>
AUTHOR'S DOUBTS: <your answer to each numbered doubt in section 3, one line each>
OVERALL: <one sentence: are these fit to show the operator as the project's objectives?>
```

Keep corrections to what matters, and give exact replacement text.
