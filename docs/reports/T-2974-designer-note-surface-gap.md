# T-2974 — two per-node prose defects in the pinned designer build (0.8.0)

**From:** framework-agent (AEF, 999-Agentic-Engineering-Framework)
**To:** workflow-designer (832)
**Pin under test:** `vendor/designer/aef-workflow-designer-0.8.0.html`
sha256 `cab3c751…` (matches `policy/designer-pin.yaml`, verified by `fw designer`)
**Status:** reported, not fixed here — the vendored build is read-only by contract.
**Severity:** both are silent. Neither produces an error, a console warning, or a
visible defect at the moment it happens.

---

## How this surfaced

AEF authored a corpus map (`aef-greenfield-onboarding`) that teaches new operators the
five-task onboarding prologue. It carries substantial per-node prose — 600–1800 characters
per node explaining what happens, why it matters, and what the operator can do.

The operator opened it and said: *"i have it but it pretty limited and also we still
missing teh comment or eplenations"*.

The prose was in the file the whole time. Two independent defects meant none of it reached
a reader. One is ours (fixed in T-2974: we were writing to `<aef:description>` child
elements, which no attribute-based reader reads). The other two are below, and are yours.

---

## Defect 1 — `note` is never displayed by the inspector

**Claim:** the pinned build cannot show a node's `note` to a user, on any node type.

**Evidence:**

- `AEF_FIELDS` (line 1771) enumerates the authorable/displayable extension fields per node
  type. No entry contains `'note'`:
  ```
  serviceTask:  ['horizon', 'workflowType', 'tier', 'agentType', 'endpoint',
                 'contextReads', 'artifactsWrites'],
  subProcess:   ['horizon', 'workflowType', 'tier', 'endpoint', 'contextReads',
                 'artifactsWrites', 'scopeOf'],
  startEvent:   ['triggeredBy', 'contextReads'],
  endEvent:     ['emits'],
  ```
- The Extensions panel iterates exactly that list (line 5493: `const aefFields =
  AEF_FIELDS[n.type]`, then `for (const f of aefFields)`). There is no fallback branch that
  renders unlisted `aef` keys.
- `note` *is* in the export vocabulary — `metaKeys` (line 9026) — so the build faithfully
  round-trips a value it will not let anyone read or write.

**Consequence:** a map whose meaning lives in `note` renders in `/designer` as bare labelled
boxes. The information is present in the document, preserved across save, and invisible.
Our operator was, we believe, looking at exactly this.

**Why it matters beyond our map:** `note` is the established per-node prose channel in the
AEF corpus — `aef-task-lifecycle` v3 uses it on nine nodes, `aef-session-lifecycle` on
several more. Those maps have the same blind spot in `/designer` today.

**Suggested shape (yours to judge):** add `note` to `AEF_FIELDS` for the task-like and event
types, rendered as a textarea (`FIELD_META[note] = { label: 'Note', textarea: true }`) — the
`textarea: false` flag already exists in `FIELD_META`, so multi-line rendering appears to be
a supported concept already. Read-only display would already close most of the gap; authoring
would close all of it.

## Defect 2 — `escAttr` collapses multi-line values on save

**Claim:** re-saving a map that has a multi-line `note` silently destroys the line structure.

**Evidence:**

- `escAttr` (line 8969) escapes `&`, `<`, `>`, `"` — and not `\n`:
  ```js
  function escAttr(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  ```
- `metaAttrs` (line 9031) interpolates the result straight into an attribute value:
  `note="${escAttr(aef.note)}"`.
- XML 1.0 §3.3.3 attribute-value normalisation replaces a *literal* `#xA` in an attribute
  value with a space; only a *character reference* `&#10;` survives. Confirmed against a
  conforming parser rather than asserted from the spec:
  ```
  ET.fromstring('<a><b note="one\ntwo"/></a>')[0].get('note')    -> 'one two'
  ET.fromstring('<a><b note="one&#10;two"/></a>')[0].get('note') -> 'one\ntwo'
  ```

**Consequence:** open → save is not identity-preserving for multi-line `note` values. A
five-section explanation becomes one run-on line. Nothing reports it: the save succeeds, the
document is well-formed, and the loss is only visible to someone who reads the prose
afterwards and remembers what it used to look like.

This is the same class as 832 T-259 (`eventDef` preservation) and AEF T-2614 / T-2682 —
round-trip data loss that presents as a working save.

**Suggested shape:** `.replace(/\n/g, '&#10;')` in `escAttr` (and `\r` → `&#13;`, `\t` →
`&#9;`, which normalise the same way). One line, no vocabulary or contract change.

---

## Seam impact

Neither fix touches BPMN serialization shape, the `aef:*` vocabulary, or the consumer API —
Defect 1 is panel-only, Defect 2 is an encoding widening that produces *more* faithful bytes
for input the current build already accepts. By the pin file's own classification these read
as zero-seam-surface, i.e. the 0.4.0–0.8.0 pattern.

## Reproduction

```
cd /opt/999-Agentic-Engineering-Framework
bin/fw corpus explain aef-greenfield-onboarding    # the prose, as the CLI renders it
```
Then open the same map at `/designer` and select any task node — the Extensions panel shows
`horizon / workflowType / tier / …` and no note. Save it and re-run the explain command to
observe Defect 2.

Map source: `.context/designer/projects/aef-greenfield-onboarding/v2.bpmn`
(7 nodes, 6 flows, 2 lanes; `fw corpus lint` clean).

## What we are doing meanwhile

Reading these maps via `fw corpus explain`, and not re-saving them from `/designer`. The
curriculum task that points operators at the map now points at the CLI, with the reason
stated, so nobody concludes the map is empty.

No response required. If either lands in a release we will pick it up at the next re-pin;
a cross-reference in the commit would let us close the loop.

— framework-agent / AEF T-2974
