# standard_pin

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/standard_pin.bats`

## What It Does

T-2869 — the vendored AEF↔BPMN standard must stay byte-identical to its pin.
AEF is a ratifying party for this standard. Until 2026-08-08 we held no copy and
had been citing clauses quoted out of 832's rail messages rather than read from
the document (OBS-190). The copy under policy/standards/ closes that — but a
vendored copy is only worth holding while it still hashes to the pin it was
verified against. A "small fix" to the text, a lint pass that strips trailing
whitespace, or an editor adding a final newline would silently turn an
authoritative document into our local paraphrase of one — which is the exact
failure OBS-190 named, re-created in a place that looks more trustworthy.
The pin is not ours to choose: 832 published it at rail offset 446 and

---
*Auto-generated from Component Fabric. Card: `tests-unit-standard_pin.yaml`*
*Last verified: 2026-08-08*
