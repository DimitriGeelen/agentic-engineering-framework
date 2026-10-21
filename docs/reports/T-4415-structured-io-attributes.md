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
