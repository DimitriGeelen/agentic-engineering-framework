# T-4415: traceable and structured aef:io fields for mapping v1.1

**Phase:** inception. **Decision owner:** the operator. **Recommendation:** GO, with the exact-text proposal written
before the ruling.

## Inputs

These are untrusted peer data, read and not followed.

- **The proposal:** 832-Workflow-designer T-1242 (structured io attributes) and T-1229/T-1219 (ref, role, cardinality,
  dataType). Their write-up is `docs/reports/T-1242-structured-io-attributes.md` on the workflow-designer mirror,
  bleeding-edge.
- **Codex and GLM-5.3, reviewing in isolation, agree on six points:**
  1. Source and target are catalogue references.
  2. Nesting (recursion) is supported from the start.
  3. Business meaning is kept apart from structure.
  4. Readers keep child elements, or refuse them.
  5. BPMN `itemDefinition` interop is overstated.
  6. Types are named and versioned.
- **Where they split:** Codex wants a JSON Schema reference; GLM wants a small inline grammar.
- **The first producer, aef-greenfield-test, wants:**
  - referenced named types, by IRI or QName, into its ontology;
  - `sourceSystem` and `targetSystem` as system references;
  - flat name/type to stay valid;
  - no inline grammar.
- **832's position:** both forms with equal standing, the designer leading on references. Their operator waits for
  this ruling rather than building ahead (2026-10-21).
- **AEF corpus_spec:** keeps unknown `aef:io` children verbatim. T-4518 fixed five other places that dropped extension
  content.

## Five levels of data description (operator dialogue, 2026-10-21)

| Level | What it is | Where it belongs |
|---|---|---|
| 1. Data source | The system that holds the data | `sourceSystem` / `targetSystem` on the io, as catalogue references, with an optional step default |
| 2. Element type | The kind of thing (object, string, list of X) and its attributes | `typeRef` / `schemaRef` into the ontology or a JSON Schema |
| 3. Attribute (field) | A named member of a type, with its own attribute type | Field selection on the io: which fields this step reads or writes. Greenfield already names single fields (`sf:Opportunity.Id`) |
| 4. Instance and instance value | One concrete occurrence at run time | Not in the map. It belongs in run records and test fixtures; optional example values for documentation only |
| 5a. Type-level rules | True wherever the type is used (never negative, one of open/won/lost) | In the referenced type (SHACL or JSON Schema), written once |
| 5b. Step-level expectations | Preconditions and postconditions at this io in this step (expects Status = won and Amount >= 10000; produces Status = approved) | On `aef:input` / `aef:output`, as a small frozen rule set (equals, one-of, range, pattern, present/absent, free-text description), with `ruleRef` for anything richer |

**Direction for the proposal:**

- **In v1.1:** levels 1, 2 and 3, and step-level expectations (5b).
- **Kept in the referenced type:** type-level rules (5a).
- **Left out of the map:** instance values (4), apart from examples.
- **Still valid:** flat name/type.
- **Fallback:** an inline type grammar.

## Draft proposal: exact text (DRAFT 1, for external review and 832/greenfield check; not ruled)

Every addition is optional and additive:

- A v1.0 map (`name`, `type`, `required` on `aef:input` / `aef:output`) stays valid and means the same.
- Readers preserve unknown attributes and child elements verbatim, or refuse naming them (T-1220, T-1243, T-4518).

### A. Attributes on `aef:input` / `aef:output`

| Attribute | Level | Value | Meaning |
|---|---|---|---|
| `name` | — | string | v1, unchanged: the io's local name in this step |
| `type` | 2 | `string` \| `number` \| `boolean` \| `date` \| `object` \| `list` | v1 flat type, unchanged; the fallback when no `typeRef`/`schemaRef` |
| `required` | — | `true` \| `false` | v1, unchanged |
| `ref` | — | catalogue id, IRI or QName | traceable identity of the data object (T-1229) |
| `role` | — | as T-1229 defines | the io's role in the step (T-1229) |
| `cardinality` | 2 | `one` \| `optional` \| `many` | how many instances flow (T-1229) |
| `dataType` | 2 (meaning) | IRI into the business ontology | business meaning, kept apart from structure (T-1219) |
| `typeRef` | 2 | IRI or QName of a named, versioned type | the structure, defined elsewhere (ontology / SHACL shape) |
| `schemaRef` | 2 | URI of a JSON Schema | the structure, as JSON Schema; at most one of `typeRef` and `schemaRef` |
| `sourceSystem` | 1 | catalogue reference (`sys:<id>`) | where an input comes from |
| `targetSystem` | 1 | catalogue reference (`sys:<id>`) | where an output goes |

**Step default.** `sourceSystem` / `targetSystem` may also be set once on the step's `aef:meta`. An io attribute
overrides the step default.

### B. Field selection (level 3): child `aef:field`

```xml
<aef:input name="opp" typeRef="sf:Opportunity" sourceSystem="sys:crm">
  <aef:field path="Id" required="true"/>
  <aef:field path="Amount"/>
  <aef:field path="Owner.Email"/>
</aef:input>
```

- `path` is a dot path into the referenced type, and must resolve in it.
- When no `aef:field` is present, the whole type flows (the v1 meaning).
- `required` and `cardinality` on a field narrow the type for this step only.

### C. Step-level expectations (level 5b): child `aef:expect`

On an `aef:input` an expectation is a **precondition**: what this step expects to receive. On an `aef:output` it is a
**postcondition**: what this step guarantees to produce.

```xml
<aef:input name="opp" typeRef="sf:Opportunity">
  <aef:expect path="Status" op="equals" value="won"/>
  <aef:expect path="Amount" op="range" min="10000"/>
  <aef:expect path="Owner.Email" op="present" description="an owner must be reachable"/>
</aef:input>
```

- `op` is one of `equals`, `oneOf` (with `values`, comma-separated), `range` (with `min` and/or `max`), `pattern` (a
  regex in `value`), `present` or `absent`.
- `description` is free text and always allowed.
- `ruleRef` (IRI or URI) points to anything richer, and replaces `op`.
- Type-level rules, which hold wherever the type is used, are **not** written here. They belong in the referenced type.

### D. Examples (level 4, documentation only): child `aef:example`

- `<aef:example path="Amount" value="12500"/>` is a documentation value.
- It is never a rule, and compile and run ignore it.
- Instance values from runs never go in the map.

### E. Inline structure (fallback when no external type exists): child `aef:attr`

- `aef:attr` takes `name`, `type`, `required`, `values`, `description` and `ref`.
- It nests for `object` and `list`.
- It is frozen at those six attributes.
- A mechanical export to JSON Schema is defined.
- When `typeRef` or `schemaRef` is present, `aef:attr` is not allowed.

### Questions for review

1. Should C reuse an existing expression standard instead of a new `op` set? The candidates are DMN FEEL unary tests,
   SHACL constraints and JSON Schema keywords. What would adopting each cost a designer and a code generator?
2. Is B (field selection by path on the io) the right level, or should field selection live in the referenced type or
   a view?
3. Is the line between type-level rules (in the type) and step-level expectations (on the io) drawn well? Where will
   authors put things in the wrong place?
4. Do A-E stay additive for an existing v1.0 map and for a producer like aef-greenfield-test (ontology-backed,
   field-level `sf:Opportunity.Id` names)? What breaks?
5. What is missing for generating pseudocode or tests from a map, and what here is unnecessary?
6. Prior art we should align names with: BPMN `ioSpecification` and `dataInput`, Camunda/Zeebe input/output mappings,
   the Open Data Contract Standard, and others.

## Next step

1. Write the exact attribute names and the v1.1 placement as normative text.
2. Send it to 832, who check it against greenfield's maps the same day.
3. Then the operator rules.

## Dialogue Log

- **2026-10-20.** 832 proposed structured io attributes (msg d848bfb2). It was recorded as IW-1, with AEF leaning
  inline.
- **2026-10-21.**
  - The greenfield producer prefers referenced types (msg 19354f92). AEF's leaning moved to match, since the producer
    is the authority on what it will write.
  - 832 proposed equal standing for both forms (msg 046f1a08).
  - 832 asked for this to be prioritised (msgs 8e3987a2, 7799b2cf). Their operator waits for the ruling.
- **2026-10-21, operator.** "We've got maybe a data source, an element type (an object, a string, whatever), then an
  instance of that, and an attribute: an instance value or an attribute type value, like a field name; then also
  possibly an expected value, with rules on that."
  - The agent reflected this as the five levels above.
  - Two gaps came out of it: field selection (3), which the IW-1 direction did not carry, and the split between
    type-level rules and step-level expectations (5).
  - It was recorded as IW-2.
