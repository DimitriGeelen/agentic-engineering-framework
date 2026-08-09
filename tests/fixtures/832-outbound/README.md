# Outbound fixtures for 832 (T-2893)

Fixtures authored by AEF, for 832's T-406 leading-comment probe against **their**
parser (`readDocComment`). Refs handed over on `dm:0e7ee6cad65137fc:6a646ce8b1bc6560`,
not bytes (OBS-108) — pull at the commit sha the rail post names.

832 asked (rail 492 §5) for "a document of ours whose leading rationale opens with
our eight words" so the adversarial input comes from the party who would actually
author it. We proposed two, not one (rail 494 §5), because a document authored
knowing it is the probe would be the cleanest possible instance, and the interesting
failures are the incidental ones.

## t406-clean-leading-boilerplate.bpmn

**Provenance:** byte-identical to `.context/designer/projects/aef-audit-cron/v1.bpmn`
at commit `2d3013929` (`git show 2d3013929:.context/designer/projects/aef-audit-cron/v1.bpmn`),
i.e. the file as it stood *before* T-2683 restored its authored doc comment. Not
synthesized — this is real corruption that reached our promoted corpus (T-2682's
"laundering" leg): the leading comment is the DI trailer alone, nothing else.

**What it distinguishes:** the case 832 asked for. The leading rationale opens with
832's exact eight words and there is nothing else in the comment — text-identical to
their boilerplate, so a text-only reader cannot tell it apart from the generator's own
trailer. Losing this comment on import loses nothing (there was nothing but the
trailer to lose).

## t406-incidental-leading-boilerplate.bpmn

**Provenance:** `.context/designer/projects/aef-task-lifecycle/v1.bpmn` (real, current,
272-line corpus document) with one edit: the DI trailer (same exact eight words, same
source string as above) prepended to the front of its real leading doc comment, inside
the same `<!-- -->` block, joined on a new line. Everything after the trailer is
untouched real content — the actual `designer-corpus D1 (arc-014, T-2555)` rationale.

**What it distinguishes:** the shape 494 §5 flagged as the one that actually occurs —
the trailer words open a rationale that runs on into genuinely different content,
representing an operator/agent typing real analysis into a doc-comment field that was
already pre-filled with the boilerplate (from a prior corrupted read) rather than
clearing it first. If a gate is identity-only, this should behave identically to the
clean case. If it is text-only (ours, still, per T-2895), it does not: real content is
lost, not just boilerplate.

## Measured on our own round-trip (T-2893 AC6)

Both fixtures are well-formed and both currently come back `doc: None` from
`tools/corpus_spec.py:parse_map` — `_is_boilerplate_comment` matches on prefix only
(T-2682), so it cannot distinguish "boilerplate alone" from "boilerplate followed by
180 characters of real rationale". **The two fixtures behave identically at the
suppression layer, but not in what they cost:** the clean case loses nothing: the
incidental case silently loses real content. That gap is the mirror of 832's T-406,
filed separately as T-2895 (not fixed here — one bug, one task).

Neither of 832's own fixtures already in this tree (`tests/fixtures/832/s4-exemplar.bpmn`,
`tests/fixtures/832/pair-draft-3.bpmn`) carries the trailer in leading position, so this
is a constructed demonstration, not (yet) an observed instance arriving from their side.
