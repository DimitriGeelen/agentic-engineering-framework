1. **Adapt C: reuse JSON Schema keywords in an explicit expectation profile; retain `ruleRef` for other languages.** C’s operators recreate validation vocabulary without defining value types, missing values or regex semantics. Pin a JSON Schema dialect and define expectations over a JSON representation of the IO. For the three examples, an author could reference this step-specific schema:

   ```json
   {
     "$schema": "https://json-schema.org/draft/2020-12/schema",
     "type": "object",
     "required": ["Status", "Amount", "Owner"],
     "properties": {
       "Status": {"const": "won"},
       "Amount": {"type": "number", "minimum": 10000},
       "Owner": {
         "type": "object",
         "required": ["Email"],
         "properties": {
           "Email": {"description": "an owner must be reachable"}
         }
       }
     }
   }
   ```

   Here, “present” means the member exists; `null` counts as present. Reachability remains documentation, not a guarantee. Requiring `Status` and `Amount` explicitly resolves C’s unspecified missing-value behavior.

   A generator needs the pinned validator, reference resolution, ontology-to-instance-field mapping, validation timing and failure reporting. Schema validation supports generated assertions; generating satisfying fixtures requires additional machinery.

   Candidate costs:
   - **JSON Schema:** familiar designer controls for constants, bounds and presence; generators need a validator and a defined JSON projection for ontology data.
   - **DMN FEEL unary tests:** authors could write `"won"` and `>= 10000`; designers need expression editing or translation. Generators need FEEL typing/evaluation and a separate binding/presence convention: unary tests alone do not distinguish an absent field from a bound null.
   - **SHACL:** natural for ontology-backed producers; authors use property shapes, `sh:in`, `sh:minInclusive` and `sh:minCount`. Designers need graph-path editing; generators need RDF instance mapping, shape targeting and SHACL validation.
   
   Allow a declared SHACL profile through `ruleRef` without requiring ontology producers to adopt JSON serialization.

2. **Adopt B’s placement, adapt its addressing.** Selection belongs on the IO when it describes this step’s reads or writes. Reusable selections may reference named views; they should not mutate the underlying type. B needs stable field references alongside instance paths: `sf:Opportunity.Id` is an ontology identifier, not necessarily a traversal expression. Specify whether selection projects a payload or merely declares access, and how nested collections are traversed.

3. **Adopt the distinction, adapt the authoring guidance.** C correctly separates reusable validity from contextual preconditions/postconditions. Authors will misplace “Amount is nonnegative,” lifecycle-specific status restrictions and universally mandatory fields. A rule belongs in the type only if it holds for every instance of that type; otherwise use a step expectation or a named constrained subtype/view. B’s narrowing must conjoin with type constraints, never weaken them. Contradictions should be diagnosed. An output expectation is an assertion to establish or check, not an instruction that assigns a value.

4. **Adapt; additivity is intended but not yet demonstrated.** A preserves flat maps in principle, but its enumerated `type` values are compatible only if they exactly match v1.0’s accepted vocabulary. New defaults must not reinterpret absent attributes. B cannot require a resolvable external type for existing flat IO. A/B must support Greenfield’s field identifiers without splitting their dots. Distinguish OWL classes/properties from SHACL shapes: OWL’s open-world semantics do not themselves supply closed-record validation. E’s exclusion beside external references is reasonable, provided producers never need inline definitions.

5. **Adapt A–E before generation.** Missing essentials are typed literals; exact multiplicity and presence semantics; path resolution; reference/version resolution; rule-language identification; conjunction and contradiction handling; validation timing; and unsupported-feature behavior. Tests also need fixture provenance, expected outcomes and a policy for unavailable external types. IO contracts alone cannot generate a step’s business algorithm. D’s examples are useful documentation but must not silently become fixtures. E’s second structural language is unnecessary for the first producer; defer it unless a concrete consumer needs it, or use inline JSON Schema.

6. **Adapt names selectively.** A/B should align conceptually with BPMN data inputs/outputs and `itemDefinition`, while documenting an explicit mapping rather than claiming equivalence. Camunda/Zeebe mappings describe value binding or transformation; C describes assertions, so keep those concepts separate. Data-contract standards offer useful schema, field and quality terminology, but importing their whole document model would overburden step IO. Use JSON Schema vocabulary for the selected expectation profile and RDF/SHACL identifiers for ontology bindings.

**Ambiguities producing different implementations**

- **A:** `ref` identity versus type/field identity; undefined `role`; QName bindings; version pinning; `required`/`cardinality` conflicts; reference-versus-flat-type disagreement.
- **B:** escaping dots, arrays, root fields, projection versus access declaration, and allowable narrowing.
- **C:** literal types, CSV escaping, inclusive bounds, regex dialect, missing/null behavior, rule combination, `ruleRef` language and scope, description-only expectations.
- **D:** value encoding and whether documentation is validated.
- **E:** list item representation, enum typing, recursion/references, and the promised but unspecified export.

**Compatibility breaks or blockers**

- No unavoidable break is established, but A’s type restriction could reject legacy values.
- B’s mandatory path resolution could reject flat maps or misread ontology field identifiers.
- Treating OWL declarations as closed schemas would change producer semantics.
- Preservation must retain QName namespace bindings and extension content; otherwise round-tripping can corrupt meaning.

**Names to change**

- `dataType` → `semanticRef`.
- `aef:attr` → `aef:property`, if retained.
- `ruleRef` → `constraintRef`, with a separate language/profile identifier.
- Add `fieldRef`; retain `path` for traversal rather than conflating them.
