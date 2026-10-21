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

## External review of draft 1 (2026-10-21)

**The seats.** Isolated (outside the repo, tools off, bundle only):

- codex and claude-code answered. Their full texts are in `docs/reports/T-4415-reviews/`.
- opencode failed on its retired model (T-4506, pending).
- antigravity has no isolation block in the registry, so it was not run.

**Where both reviewers converge independently:**

1. **C should reuse JSON Schema keyword names and semantics, not an invented op set.**
   - Use `const`, `enum`, `minimum` / `maximum` / `exclusiveMinimum` / `exclusiveMaximum`, and `pattern`.
   - The draft's `oneOf` collides with JSON Schema `oneOf`, and `range` hides whether bounds are inclusive.
   - SHACL comes in through `ruleRef` with a declared profile, for ontology-backed producers.
   - FEEL is rejected: every generator would need a FEEL parser, and unary tests cannot tell an absent field from a
     null one.
2. **B: field selection belongs on the io,** but it needs a stable field reference (`fieldRef`, a field IRI such as
   `sf:Opportunity.Id`) next to the traversal `path`. Reusable selections go through a named view (`viewRef`).
3. **The type-rule versus step-expectation line is right.**
   - Add lint: an expectation that contradicts the type is an error; one implied by the type is a warning.
   - An output expectation is an assertion to check, not an assignment.
   - Narrowing may tighten the type, never loosen it.
4. **Additivity is intended but not yet shown.**
   - A's closed `type` list must equal v1.0's accepted values exactly.
   - B must not require a resolvable type on flat maps.
   - A single-field io (greenfield) needs a home: `typeRef` to a property IRI, or `fieldRef`.
   - OWL is open-world, so it does not by itself give closed-record validation.
5. **What must be specified before generation:**
   - literal typing (taken from the field type);
   - absent versus null;
   - one regex dialect (ECMA-262);
   - AND across multiple `aef:expect`;
   - list paths;
   - QName prefix resolution;
   - version pinning for `typeRef`;
   - behaviour on a failed precondition;
   - data-flow linkage between steps (is `ref` the join key?).
6. **Names:**
   - `dataType` becomes `conceptRef` / `semanticRef`, because it collides with XSD/OWL datatype.
   - `aef:attr` becomes `aef:property`.
   - `role` must be defined or dropped.
   - E (the inline structure) is deferred to v1.2 or made non-normative: greenfield rejects it and no consumer needs it.
7. **Prior art:**
   - Document a mapping to BPMN `itemDefinition` / `structureRef` / `isCollection`, without claiming equivalence.
   - Never shorten `sourceSystem` to `source`, because that collides with Zeebe mappings.
   - Align with ODCS `logicalType`, `examples` and quality rules where they fit.

**Draft 2 direction (agent):**

- **Adopt:** points 1, 2 and 3; `dataType` becomes `conceptRef`; E is deferred.
- **Specify:** the gaps in point 5.
- **Pending:** 832/greenfield's check against VZN-T1 v26 and WT-01 before draft 2 is fixed.

## 832 designer-side check of draft 1 (msgs 2f8376d0, 22282fd6, 2026-10-21)

**Their points against our review:**

| 832 point | Status | Detail |
|---|---|---|
| 6, 7 | Settled by the review | JSON Schema keywords, with `enum` values as child elements |
| 2 | Settled by the review | "one field, two ways", resolved by `fieldRef` |
| 8 | Settled by the review | QName prefixes |
| 1 | **Blocking**, not raised by the reviewers | A's v1 `type` list is wrong: it drops `ref`, `task_id` and `path`, which 54 designer maps use (`task_id` alone on 97 ios). Draft 2 must carry v1's actual `type` vocabulary unchanged, exactly as the designer and the v1 bridge accept it |
| 4 | Open | `role` values must be defined |
| 5 | Open | `cardinality` versus `required` must be reconciled |

**Accepted by the designer:** `conceptRef` for `dataType`, and deferring `aef:attr` to v1.2.

## Producer check on greenfield's real io (832 msg 6d79d60a, VZN-T1 v27 fragments)

Greenfield's maps contain two styles of io today:

- **Style A, a single field:**
  `<aef:input name="sfdc:Opportunity.Id" type="object" ref="nid:attr-salesforce-opportunity-id" role="read" dataType="id"/>`
- **Style B, legacy:**
  `<aef:output name="Account [Name, Phone, ..., OwnerId]" type="object"/>`

What draft 2 must address:

| | Point | Detail |
|---|---|---|
| a | An existing `ref` already holds a field IRI | The reviewers' `fieldRef`. Draft 2 must say how an existing `ref` holding a field IRI is read, or style A changes meaning. |
| b | Existing `dataType` holds technical tokens | Values are `id` and `reference`, not concept IRIs. `conceptRef` is right going forward, but `dataType="id"` in existing maps needs a stated reading. |
| c | `type="object"` on a single field is a forced placeholder | `type` becomes optional when `fieldRef` or `typeRef` is present. |
| d | `role` values | Confirmed: `read`, `write`, `create`, `match`. `match` also appears on an output (tacton currency), so define it as a lookup/join key. |
| e | Systems come from the path prefix | Today `sfdc:` and `tacton:` imply the system. Allow `sourceSystem` / `targetSystem` to be derived from a prefix-to-system entry in a declared prefix map, with the explicit attribute overriding. Prefixes must be declared: draft 1's example uses `sf:`, greenfield writes `sfdc:`. |
| f | Style B maps one-to-one onto `typeRef` + `aef:field` | The free-text form must stay valid v1. |
| g | Lists are a must | Examples: Solution line items (including TradeIn lines), OpportunityContactRole, QuoteLineItem. Draft 2 needs a list-path syntax and a way to select one KIND of line. |
| h | Their only expectations are behavioural | "Update if exists else create" (their H-039/H-042) is upsert semantics. It is carried by `role` (`match` + `create`) or `ruleRef`, not by C's value checks; draft 2 must say where it goes. |
| i | Field-to-field transformations stay in the ontology | Their AttributeMapping, consistent with the draft. |

**Full maps:** awaiting greenfield's operator. Draft 2 can be written from these fragments; the full maps confirm it.

## Draft proposal: exact text (DRAFT 2, 2026-10-21; supersedes draft 1; not ruled)

**Sources:**

- the external review of draft 1 (codex, claude-code);
- 832's designer check (points 1-8);
- greenfield's producer check (points a-i).

**Rules that hold throughout:**

- Every addition is optional.
- A v1 map is valid and means exactly what it meant before.
- Readers preserve unknown attributes and child elements verbatim, or refuse them naming the element; never drop.
- A map that uses v1.1 constructs declares `mappingVersion="1.1"` on `aef:meta` at process level, so a v1.0 reader that
  refuses unknown children fails clearly rather than silently.

### A. Attributes on `aef:input` / `aef:output`

| Attribute | Value | Meaning |
|---|---|---|
| `name` | string | v1, unchanged. Free text stays valid, including legacy forms like `Account [Name, Phone, …]` (832 f) |
| `type` | v1's vocabulary, **unchanged and open** | The v1 vocabulary is the designer's nine values: `string`, `number`, `boolean`, `ref`, `path`, `task_id`, `arc_id`, `list`, `object` (832, from IO_TYPES). See the reading rules below. **Optional** when `fieldRef` or `typeRef` is present (greenfield c). When both `type` and `typeRef` are present, `typeRef` is authoritative and `type` is informational |
| `required` | `true` \| `false` | v1, unchanged: whether this step can run without the io |
| `cardinality` | `one` \| `many` | How many instances flow. **Absence of the value is expressed only by `required`.** So `optional` is not a cardinality value (832 5) |
| `role` | `read` \| `write` \| `create` \| `delete` \| `match` | What the step does with the data (greenfield d; `delete` added from operator dialogue 2026-10-21). See below |
| `fieldRef` | field IRI / QName | **One field.** The identity of a single attribute, e.g. `sfdc:Opportunity.Id` or `nid:attr-…` (review 2, greenfield a) |
| `typeRef` | IRI / QName of a class, shape or named type | **A structure.** The fields come from that definition. Allowed to name a property IRI only through `fieldRef`, never here |
| `schemaRef` | URI of a JSON Schema | Alternative to `typeRef`; at most one of the two |
| `conceptRef` | IRI into the business ontology | Business meaning, kept apart from structure. Replaces draft 1's `dataType` |
| `ref` | as in v1 | **Read rule for existing maps (greenfield a):** when `ref` holds a field IRI and there is no `fieldRef`, a reader treats it as `fieldRef`. Otherwise `ref` keeps its v1 meaning (data-object identity). New maps write `fieldRef` |
| `dataType` | as in v1 | **Read rule for existing maps (greenfield b):** technical tokens such as `id` and `reference` are read as v1 `type` hints, never as a concept. New maps write `conceptRef` for meaning and `type` / `typeRef` for structure |
| `sourceSystem` / `targetSystem` | catalogue reference | Where an input comes from, or where an output goes. If absent, they are **derived from the prefix map**: a declared prefix (`sfdc:`, `tacton:`) can name its system. An explicit attribute overrides the derivation, and a step default on `aef:meta` sits in between (greenfield e) |

**Reading rules for `type`:**

- **Missing type.** A missing `type` reads as `string` (the designer's import rule).
- **The vocabulary is open.** An unknown value is preserved and never refused. Neither the designer nor AEF's
  `corpus_spec` validates the value today.
- **Aliases.** `int` reads as `number`, and `bool` as `boolean`.
- **`enum` stays.** It is valid as a type value (it appears on 16 ios) until v1.1 expresses it as `string` plus
  allowed values (an `enum` expectation in C).

The values found in 832's tracked maps were:

| Value | Count |
|---|---|
| `string` | 167 |
| `task_id` | 97 |
| `ref` | 38 |
| `list` | 24 |
| `enum` | 16 |
| `path` | 7 |
| `boolean` | 5 |
| `number` | 2 |
| `int` | 2 |
| `bool` | 1 |

**`role` values:**

| Value | Meaning |
|---|---|
| `read` | Read existing data |
| `create` | Create a new instance |
| `write` | Update an existing instance. Needs a `match` io on the same step. **To confirm with greenfield:** does their `write` already mean exactly this? |
| `delete` | Hard-remove the identified instance(s) in the target system. Needs a `match` io (or a `fieldRef` to the identifying field) on the same step |
| `match` | The io is a lookup/join key used to find an existing instance. Allowed on inputs and outputs |
| `match` + `create` | **Upsert**: update if it exists, else create (greenfield h) |

**Rules for `delete`:**

- A `delete` without a key is a **lint error**. A map must never be readable as "delete everything".
- A **soft delete** (deactivate, archive) is an update, not a delete: `write`, plus an expectation such as
  `<aef:expect path="Status" const="archived"/>`. Keeping the two apart stops a generator from removing data that
  should only be deactivated.
- A delete's natural postcondition is that the key is absent afterwards: `<aef:expect fieldRef="…" present="false"/>`.

**Prefix map.** Prefixes are declared once per map in `aef:prefixes` on the process `aef:meta`:

```xml
<aef:prefix name="sfdc" iri="…" system="sys:salesforce"/>
```

An undeclared prefix is an error.

### B. Field selection: child `aef:field`

```xml
<aef:output typeRef="sfdc:Account" targetSystem="sys:salesforce" role="write">
  <aef:field fieldRef="sfdc:Account.Name"/>
  <aef:field path="Phone"/>
  <aef:field path="OwnerId" required="true"/>
</aef:output>
```

- Each `aef:field` carries `fieldRef` (an identity) or `path` (traversal relative to `typeRef`), or both.
- **List paths** use `[]`: `LineItems[].Sku` (greenfield g).
- **A kind of line** is selected with a child condition:
  ```xml
  <aef:field path="LineItems[]"><aef:when path="Kind" const="TradeIn"/></aef:field>
  ```
  `aef:when` uses the keywords in C.
- **Narrowing** may tighten the type (`required="true"`, `cardinality="one"`), never loosen it.
- With no `aef:field` the whole type flows (the v1 meaning).
- Legacy style B maps one-to-one onto `typeRef` plus `aef:field` (greenfield f), and the free-text form stays valid.

### C. Step expectations: child `aef:expect`

An expectation is a **precondition** on an input and a **postcondition** on an output. It is an assertion to check,
never an assignment.

| Keyword | Meaning |
|---|---|
| `const` | equals |
| `enum` | one of the child `<aef:value>` elements (no comma lists) |
| `minimum` / `maximum` | inclusive bounds |
| `exclusiveMinimum` / `exclusiveMaximum` | exclusive bounds |
| `pattern` | ECMA-262 regex |
| `present` / `absent` | `true`: the member exists or does not exist; a `null` member counts as present |

How expectations are read:

- Literals are typed from the resolved field type.
- Several `aef:expect` on one io all must hold (AND).
- `description` is free text.
- `ruleRef` with `ruleLanguage` (`jsonschema` \| `shacl`) carries anything richer; it may sit alongside `path` and
  `description`.
- **On failure** a precondition makes the step not start. The map may route that to a BPMN error boundary event;
  otherwise it is a runtime error. A failed postcondition is an error raised by the step.

**Behavioural rules** such as upsert are expressed by `role` (`match` + `create`), not by expectations (greenfield h).

**Type-level rules** (true wherever the type is used) belong in the referenced type, never here. Lint:

- an expectation that contradicts the type is an **error**;
- one already implied by the type is a **warning**.

### D. Examples: child `aef:example`

`<aef:example path="Amount" value="12500"/>` is documentation only. It is never a rule and never a fixture.

### E. Out of v1.1

- **Inline structure** (draft 1's `aef:attr`) is deferred to v1.2; no producer needs it.
- **Field-to-field transformations** stay in the producer's ontology (greenfield's AttributeMapping), not in the map
  (greenfield i).

### Still open for the ruling

1. ~~832 to give the exact v1 `type` vocabulary~~: given and adopted (832 msg ac157dd5).
2. Whether `ref` is also the **data-flow join key** between one step's output and the next step's input, or whether
   that needs its own attribute.
3. **`typeRef` version pinning:** an IRI that includes the version, or a separate attribute? greenfield's OWL classes
   may carry no per-class version.
4. Confirmation against **greenfield's full maps** (VZN-T1, WT-01).
5. **Prior-art mapping, documented as a mapping only:** `typeRef` ↔ BPMN `itemDefinition@structureRef`,
   `cardinality=many` ↔ `isCollection`. Never shorten `sourceSystem` to `source`, because Zeebe uses it.

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
