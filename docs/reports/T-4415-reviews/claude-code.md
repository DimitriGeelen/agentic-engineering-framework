# Review of DRAFT 1: structured `aef:io` for mapping v1.1

## 1. Reuse a standard for C?

**Position: adapt.** Keep C's one-constraint-per-element shape, but replace the invented `op` set with **JSON Schema keyword names and semantics**. Define a normative mapping to SHACL so ontology-backed producers can compile the same rules.

**Reason (C):**
- The draft's `oneOf` already collides with JSON Schema `oneOf`, which means "exactly one subschema matches", not enumeration.
- `range` hides whether the bounds are inclusive or exclusive.
- JSON Schema keywords map almost one-to-one onto SHACL: `const`→`sh:hasValue`, `enum`→`sh:in`, `minimum`→`sh:minInclusive`, `pattern`→`sh:pattern`, presence→`sh:minCount 1`.

**Why not the other two:**
- **FEEL unary tests** (`"won"`, `>= 10000`, `not(null)`) are terse and fit Camunda. But they force every generator to embed a FEEL parser, and `pattern` is not a unary test; it needs `matches()`.
- **SHACL inline** means RDF inside BPMN XML, which is too heavy for designers.

**What an author writes:**
```xml
<aef:expect path="Status" const="won"/>
<aef:expect path="Amount" minimum="10000"/>
<aef:expect path="Owner.Email" present="true" description="an owner must be reachable"/>
```
`present`/`absent` stay AEF-specific, because JSON Schema expresses them as `required` on the parent.

**What a generator needs:**
- path resolution against the `typeRef`/`schemaRef`;
- literal typing taken from the resolved field type (`"10000"` is a number);
- a 7-row keyword table to JSON Schema and to SHACL;
- one fixed regex dialect: ECMA-262, noting that SHACL uses XPath regex;
- AND semantics across multiple `aef:expect` elements.

`ruleRef` should accept a JSON Schema or a SHACL shape, and nothing else.

## 2. Field selection on the io (B)

**Position: adopt, plus an optional `viewRef`.**
- **Why on the io:** a projection is step-specific, so it belongs on the io.
- **What `viewRef` adds:** a named SHACL shape or JSON Schema for selections that recur across steps.
- **Required clarification for OWL:** properties are not owned by classes in OWL. "Resolves in the type" must therefore be defined, for example as domain/range or a SHACL shape on the class.
- **Accept field IRIs:** allow `path="sf:Opportunity.Id"` alongside relative paths, because greenfield already writes that form.

## 3. Type-level vs step-level line (C, 5a/5b)

**Position: adopt the line, and add lint rules.**

Authors will go wrong in four predictable places:
- **Enum invariants copied into steps:** `Status enum open/won/lost` written on every io.
- **Duplicate presence rules:** B's `aef:field required="true"` and C's `present` say the same thing. Keep one, and make `present` the expectation-only form.
- **Postconditions with no enforcer:** output "guarantees" that nothing checks.
- **Recurring postconditions:** the same postcondition on every producer of a type is really a type rule.

**Lint rules:**
- An expectation that contradicts the type is an error.
- An expectation implied by the type is a warning.

## 4. Additivity (A–E)

**Position: additive for plain v1.0 maps. Not yet safe for greenfield.** Details are under "What breaks" below.

## 5. Generating pseudocode and tests

**Missing:**
- **Data-flow linkage:** how an output of step N becomes an input of step M. Is `ref` the join key?
- **Mapping and transformation:** Zeebe-style source→target mappings.
- **Path syntax for lists:** `Items[].Sku`.
- **Literal formats:** dates, decimals.
- **Version pinning syntax** for `typeRef`.
- **QName prefix resolution:** XML `xmlns`, or a map-level prefix table.
- **Behaviour on a failed precondition:** reject, route, or error event.
- **The JSON Schema export rules for E:** the draft says they are "defined" but does not give them.

**Unnecessary:**
- **`dataType` alongside `ref` and `typeRef`:** three identity attributes. Merge `dataType` into `typeRef`, or rename it (see Names).
- **`role` in this spec:** it is undefined here, so drop it or define it.
- **E in v1.1:** greenfield rejects it. Defer it to v1.2, or keep it non-normative.

## 6. Prior art

**BPMN:**
- `dataInput`/`dataOutput` carry `itemSubjectRef`→`itemDefinition@structureRef` and `isCollection`.
- Document the mapping `typeRef`↔`structureRef` and `cardinality=many`↔`isCollection`.
- Do not claim interop beyond that.

**Zeebe:**
- `zeebe:input source="=expr" target="var"` uses source and target to mean variables.
- So never shorten `sourceSystem` to `source`.

**ODCS v3:**
- Align with `logicalType`, `required`, `examples` (plural), and the `quality` rules block.
- ODCS's `server` corresponds to the draft's `sourceSystem`.

**SHACL:** align `path` with `sh:path`.

---

## Ambiguities (two implementers would diverge)

- **`values` comma-separated:** what happens to values that contain commas, and is whitespace trimmed?
- **`range`:** are the bounds inclusive? Are they numeric or lexical for dates?
- **`value` literal typing:** does `equals value="10000"` compare as a string or a number?
- **Expect paths:** must an `aef:expect` path be among the selected `aef:field`s?
- **Narrowing direction:** can a field's `required="false"` loosen a type-required field? Can `cardinality=one` narrow a `many`?
- **`ruleRef` "replaces `op`":** may `path` and `description` remain?
- **`sourceSystem` on an output:** what does it mean? And does the step default apply to outputs, inputs, or both?
- **`required` vs `cardinality`:** `required="false"` with `cardinality="one"` conflict, and `optional` duplicates `required="false"`.
- **`type` alongside `typeRef`:** is it allowed, and which wins when they disagree?
- **"Refuse naming them":** must a refusing reader name the specific unknown element? Is refusal per element or per map?
- **"Named, versioned type":** where does the version live: in the IRI, `owl:versionIRI` (which is ontology-level), or a separate attribute?

## What breaks

- **v1.0 `type` values:** if v1.0 accepted `type` values outside the six listed, A's closed enumeration invalidates those maps. Keep it open, or list the v1.0 set exactly.
- **Readers that refuse unknown children:** v1.0 readers on that path reject every v1.1 map. That is acceptable only if it is stated as a version gate (for example a `mappingVersion="1.1"` attribute).
- **Greenfield field-level ios:** an io that is a single field (`sf:Opportunity.Id`) has nowhere to go. `typeRef` demands a named type, meaning a class, and the field is a datatype property. Allow `typeRef` to a property IRI, or allow `ref`/`path` for single-field ios.
- **Greenfield versioning:** "versioned" types block greenfield if its OWL classes carry no per-class version.
- **`aef:meta` defaults:** step defaults on `aef:meta` break any reader that refuses unknown attributes there. T-4518 should be confirmed to cover `aef:meta`.

## Names to change

| Current | Replacement | Why |
|---|---|---|
| `op="equals"` | `const` | JSON Schema |
| `op="oneOf"` + `values` | `enum`, with child `<aef:value>` elements | avoids the `oneOf` collision and comma escaping |
| `op="range"` + `min`/`max` | `minimum` / `maximum` / `exclusiveMinimum` / `exclusiveMaximum` | JSON Schema; explicit inclusivity |
| `op="pattern"` | `pattern` attribute | JSON Schema |
| `dataType` | `conceptRef` | `dataType` collides with XSD/OWL datatype, which is the opposite of "meaning" |
| `aef:attr` | `aef:property` | "attr" is confusable with XML attributes |
| `ref` | `dataRef` | distinct from `typeRef`, `ruleRef` and `viewRef` |
| `aef:example@value` | keep the element; document its relation to ODCS/JSON Schema `examples` | — |
