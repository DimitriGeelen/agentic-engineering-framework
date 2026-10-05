# T-2899: should designer-stored maps carry producer provenance?

**Status:** inception, recommendation NO-GO. Artifact written 2026-10-05 (T-3896). The inception was filed without one; this file consolidates what the task records, re-verified, so the decision rests on a durable artifact (C-001).

## Question

`tools/corpus_spec.py` stamps `exporter="aef-corpus-spec"` on `generate()` output. Should stored designer maps carry that producer stamp, so that 832's T-406 identity gate can tell AEF-produced maps from others?

## Findings (re-verified 2026-10-05)

- `tools/corpus_spec.py:407` emits `exporter="aef-corpus-spec"` on `generate()` output.
- `web/blueprints/designer_api.py:140` (`/api/save`) writes the posted BPMN verbatim. Nothing strips the stamp on save.
- At filing, **0 of 37** stored designer maps and **0** `.bpmn` files on disk carried the stamp. No stored map was ever produced through `generate --save`.

## Analysis

- **IW-1 (answered: NO).** 832's identity gate reads "names a different producer → preserve".
  - A laundered AEF document, AEF text mis-adopted elsewhere, carries *our* stamp.
  - So stamping stored maps would move them onto the stamped-other branch, and the gate would confidently *preserve* the corruption it exists to suppress.
  - Producer identity is the wrong axis at this seam (rail 501).
  - Confidence is 2, because this reasons from 832's description of their gate (rail 502), not from their source.
- **IW-2 (deferred).** Is the emitter stamp dead code, or correctly scoped to exports? It needs one spike: enumerate every consumer of `generate()` output. It doesn't change the NO-GO, because the stamp stays out of the store either way.
- **IW-3 (deferred).** A project-wide sweep for "mechanism reported shipped without measuring it at the seam" (class L-560) is broader than this inception.

## Recommendation

**NO-GO** on propagating the stamp into the store to feed 832's identity gate. Keep the stamp on exports as is. Settle IW-2 before anyone retires or extends the emitter stamp.
