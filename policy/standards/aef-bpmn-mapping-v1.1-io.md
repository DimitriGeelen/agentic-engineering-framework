# Part I addendum — v1.1: structured `aef:io` (fields and expectations)

**Status:** normative text for mapping version 1.1, written from DRAFT 2 of
`docs/reports/T-4415-structured-io-attributes.md` (decided GO, T-4415; text task T-4548). Authored by AEF as a
ratifying party, for 832's same-day check against greenfield's maps before the operator ruling.

**Relation to v1.0.** This file is **additive**. It sits beside the frozen Part I
(`aef-bpmn-mapping-v1-partI.md`, sha-pinned; see its `.provenance.yaml`) and changes **no** v1.0 rule. `aef:io`,
`aef:input` and `aef:output` stay in the semantic class of Part I §1; this addendum only says what new, optional
attributes and children on them mean. The lane rulings already marked "v1.1" inside Part I (IW-9 §3, O-3 §7) are
unaffected and are not repeated here.

**Keywords.** MUST, SHOULD and MAY are used as in RFC 2119.

**Marking.** Each rule below carries one of:

- **[v1.0]** — restates the unchanged v1.0 meaning, for reference only;
- **[v1.1-only]** — the construct is a v1.1 construct; a map that uses it MUST declare `mappingVersion="1.1"` (§1);
- **[additive]** — allowed in any map, with or without `mappingVersion="1.1"`, because a v1.0 reader preserves it.

## 1. Version declaration and compatibility

1.1 **[v1.1-only]** A map that uses any [v1.1-only] construct MUST declare `mappingVersion="1.1"` as an attribute of
the process-level `aef:meta`. A v1.0 reader that refuses unknown children then fails clearly rather than silently.

1.2 A map with no `mappingVersion` attribute is a v1.0 map, MUST remain valid, and MUST mean exactly what it meant
before this addendum.

1.3 Every addition in this addendum is OPTIONAL.

1.4 A reader MUST either preserve unknown attributes and child elements verbatim, or refuse the map naming the
element. A reader MUST NOT silently drop them.

1.5 `mappingVersion` values other than `1.1` are reserved. A reader that does not know the declared version MUST
refuse the map naming the value.

## 2. Attributes on `aef:input` / `aef:output`

| Attribute | Marking | Value | Meaning |
|---|---|---|---|
| `name` | [v1.0] | string | Unchanged. Free text stays valid, including legacy forms such as `Account [Name, Phone, …]`. |
| `type` | [v1.0] + 2.2 | open vocabulary (§3) | Unchanged vocabulary. OPTIONAL when `fieldRef` or `typeRef` is present. When both `type` and `typeRef` are present, `typeRef` is authoritative and `type` is informational. |
| `required` | [v1.0] | `true` \| `false` | Unchanged: whether the step can run without this io. |
| `cardinality` | [v1.1-only] | `one` \| `many` | How many instances flow. Absence is expressed **only** by `required`; `optional` is not a cardinality value. |
| `role` | [v1.1-only] | `read` \| `write` \| `match` \| `create` | **Field-level** (§4). Allowed on an io with `fieldRef` and on `aef:field`. |
| `operation` | [v1.1-only] | `read` \| `create` \| `update` \| `upsert` \| `delete` | **Instance-level** (§4). Allowed on an io with `typeRef` or `schemaRef`. |
| `fieldRef` | [v1.1-only] | field IRI / QName | **One field**: the identity of a single attribute, e.g. `sfdc:Opportunity.Id`. |
| `typeRef` | [v1.1-only] | IRI / QName of a class, shape or named type | **A structure**: the fields come from that definition. A property IRI MUST be written as `fieldRef`, never as `typeRef`. |
| `schemaRef` | [v1.1-only] | URI of a JSON Schema | Alternative to `typeRef`. An io MUST NOT carry both `typeRef` and `schemaRef`. |
| `conceptRef` | [v1.1-only] | IRI into the business ontology | Business meaning, kept apart from structure. |
| `sourceSystem` | [v1.1-only] | catalogue reference | Where an input comes from. |
| `targetSystem` | [v1.1-only] | catalogue reference | Where an output goes. |
| `ref` | [v1.0] + 2.3 | as in v1 | Data-object identity; read rule 2.3 for existing maps. New maps SHOULD write `fieldRef` for a field. |
| `dataType` | [v1.0] + 2.4 | as in v1 | Informational only (2.4). New maps SHOULD write `conceptRef` for meaning and `type` / `typeRef` for structure. |

2.1 Attribute names are exact. In particular `sourceSystem` MUST NOT be shortened to `source` (Zeebe uses that name).

2.2 A missing `type` with neither `fieldRef` nor `typeRef` reads as `string` (§3).

2.3 **`ref` read rule (for existing maps).** A reader MUST treat `ref` as `fieldRef` only when all four hold:

1. the map does not declare `mappingVersion="1.1"`;
2. the io has no `fieldRef`;
3. the io has no `typeRef`;
4. the IRI's prefix is declared in the prefix map (§6) with `kind="field"`.

In every other case `ref` keeps its v1 meaning (data-object identity). That is the conservative default.

2.4 **`dataType` read rule.** v1 `dataType` values (e.g. `id`, `reference`) are informational only. They map to no
`type` and to no concept, and a reader MUST preserve them verbatim.

2.5 **System derivation.** When `sourceSystem` / `targetSystem` is absent, a reader MAY derive it from the prefix
map: a declared prefix's `system` names its system. Precedence, highest first: the explicit attribute on the io; a
step default on the step's `aef:meta`; the prefix map's `system`.

## 3. The `type` vocabulary [v1.0, restated]

3.1 The v1 vocabulary is the designer's nine values: `string`, `number`, `boolean`, `ref`, `path`, `task_id`,
`arc_id`, `list`, `object`.

3.2 The vocabulary is **open**. A reader MUST preserve an unknown value and MUST NOT refuse it.

3.3 A missing `type` reads as `string`.

3.4 Aliases: `int` reads as `number`; `bool` reads as `boolean`.

3.5 `enum` remains a valid `type` value. In v1.1 the same intent MAY be written as `type="string"` plus an `enum`
expectation (§8).

## 4. `role` (field level) and `operation` (instance level) [v1.1-only]

The two attributes answer different questions and MUST NOT be conflated: `role` is what the step does to **one
field**, `operation` is what the step does to **the instance**.

4.1 `role` is allowed on an io with `fieldRef` and on `aef:field`:

| `role` | Meaning |
|---|---|
| `read` | The step reads the field's value. |
| `write` | The step sets the field's value, on create and on update alike. |
| `match` | The field is the key used to find an existing instance (lookup / join). Allowed on inputs and outputs. |
| `create` | The field is a reference whose target is found or created (e.g. `tacton:Opportunity.accountId`). |

4.2 `operation` is allowed on an io with `typeRef` or `schemaRef`:

| `operation` | Meaning |
|---|---|
| `read` | Read existing instance(s). |
| `create` | Create a new instance. |
| `update` | Change an existing instance. |
| `upsert` | Update if it exists, else create. |
| `delete` | Hard-remove the identified instance(s). |

4.3 An io with `operation` `update`, `upsert` or `delete` MUST carry at least one field with `role="match"`. Its
absence is a **lint error**: a map MUST NOT be readable as "update everything" or "delete everything".

4.4 A `match` field with neither `fieldRef` nor `path` means "a key exists but is not yet determined". It is
allowed, with a **lint warning**. A generator MUST refuse to produce update, upsert or delete code for that io until
the key is named.

4.5 A **soft delete** (deactivate, archive) is an `update`, not a `delete`: `operation="update"` plus an expectation
such as `<aef:expect path="Status" const="archived"/>`.

4.6 The natural postcondition of a `delete` is that the key is absent afterwards:
`<aef:expect fieldRef="…" absent="true"/>`.

4.7 **Upsert as contract and as expansion.** `operation="upsert"` on a summary step is the **contract**. A detail map
linked from that step (`aef:link targetWorkflow`) MAY draw it as structure (exists? → update | create → merge); that
is its **expansion**, and both are valid. The detail map's key SHOULD be the summary's `match` field; when both carry
ios and the keys differ, that is a **lint warning**.

4.8 Behavioural rules such as upsert are expressed by `operation` and `role` (`match`, `create`), never by
expectations (§8).

## 5. Field selection: child `aef:field` [v1.1-only]

5.1 Each `aef:field` MUST carry `fieldRef` (an identity) or `path` (a traversal relative to the io's `typeRef`), or
both — except as allowed by 4.4.

5.2 List paths use `[]`, e.g. `LineItems[].Sku`.

5.3 A kind of line is selected with a child `aef:when`, which uses the keywords of §8:
`<aef:field path="LineItems[]"><aef:when path="Kind" const="TradeIn"/></aef:field>`.

5.4 An `aef:field` MAY carry `role`, `required` and `cardinality`. Narrowing MAY tighten the type
(`required="true"`, `cardinality="one"`) and MUST NOT loosen it.

5.5 An io with no `aef:field` children carries the whole type (the v1 meaning).

5.6 **No wildcard selection in v1.1.** A selection such as `billing*` MUST be written as an explicit list of
`aef:field`. The legacy free-text `name` form stays valid.

5.7 Legacy style-B names map one-to-one onto `typeRef` plus `aef:field`.

## 6. Prefix map: `aef:prefixes` / `aef:prefix` [additive]

6.1 Prefixes are declared once per map, in an `aef:prefixes` element on the process-level `aef:meta`:

```xml
<aef:prefixes>
  <aef:prefix name="sfdc" iri="…" system="sys:salesforce" kind="field"/>
</aef:prefixes>
```

6.2 `name` and `iri` are REQUIRED. `system` is OPTIONAL and feeds 2.5. `kind` is OPTIONAL, one of `field` | `type` |
`object`, and tells a reader, without loading the ontology, what IRIs under that prefix name.

6.3 A QName in a v1.1 attribute (`fieldRef`, `typeRef`, `conceptRef`) whose prefix is not declared is an **error**.

6.4 `aef:prefixes` MAY appear in a map that does not declare `mappingVersion="1.1"`. It is additive, and v1.0 readers
preserve unknown elements (1.4). This is what makes 2.3 condition 4 reachable for existing maps.

## 7. Step expectations: child `aef:expect` [v1.1-only]

7.1 On an input an expectation is a **precondition**; on an output it is a **postcondition**. It is an assertion to
check, never an assignment.

7.2 An `aef:expect` addresses its member with `fieldRef` or `path` (relative to the io's type).

## 8. Expectation keywords [v1.1-only]

The keywords are the JSON Schema keywords of the same name, applied to the addressed member:

| Keyword | Meaning |
|---|---|
| `const` | equals |
| `enum` | one of the child `<aef:value>` elements (comma lists MUST NOT be used) |
| `minimum` / `maximum` | inclusive bounds |
| `exclusiveMinimum` / `exclusiveMaximum` | exclusive bounds |
| `pattern` | ECMA-262 regular expression |
| `present` / `absent` | `true` only: the member exists / does not exist |

8.1 Literals are typed from the resolved field type.

8.2 Several `aef:expect` on one io MUST all hold (AND).

8.3 **Empty and absent.** "Empty" is `const=""` (the member is present with an empty value). "Not there" is
`absent="true"`. A `null` member counts as present.

8.4 `description` is free text. `ruleRef` with `ruleLanguage` (`jsonschema` | `shacl`) carries anything richer and MAY
sit alongside `path` and `description`.

8.5 **On failure** a precondition makes the step not start; the map MAY route that to a BPMN error boundary event,
otherwise it is a runtime error. A failed postcondition is an error raised by the step.

8.6 **Type-level rules** (true wherever the type is used) belong in the referenced type, never in `aef:expect`. Lint:
an expectation that contradicts the type is an **error**; one already implied by the type is a **warning**.

## 9. Examples: child `aef:example` [v1.1-only]

9.1 `<aef:example path="Amount" value="12500"/>` is documentation only. It is never a rule and never a fixture.

## 10. Out of v1.1

10.1 Inline structure (draft 1's `aef:attr`) is deferred to v1.2.

10.2 Field-to-field transformations stay in the producer's ontology (e.g. an AttributeMapping), not in the map.

10.3 Wildcard field selection is deferred (5.6).

10.4 Prior art is a documented mapping only, not a v1.1 construct: `typeRef` ↔ BPMN `itemDefinition@structureRef`;
`cardinality="many"` ↔ `isCollection`.

## 11. Worked examples (informative)

**Instance operation with field roles** (greenfield owner rule H-042):

```xml
<aef:output typeRef="tacton:Opportunity" operation="upsert">
  <aef:field fieldRef="tacton:Opportunity.crmOppExtId" role="match"/>
  <aef:field fieldRef="tacton:Opportunity.name" role="write"/>
  <aef:field fieldRef="tacton:Opportunity.accountId" role="create"/>
</aef:output>
```

**Field selection on a type, with a target system:**

```xml
<aef:output typeRef="sfdc:Account" targetSystem="sys:salesforce" operation="create">
  <aef:field fieldRef="sfdc:Account.Name" role="write"/>
  <aef:field path="Phone" role="write"/>
  <aef:field path="OwnerId" role="write" required="true"/>
</aef:output>
```

**A style-B name migrated to a postcondition** (`Opportunity [StageName=Closed Won]`):

```xml
<aef:output typeRef="sfdc:Opportunity" operation="update">
  <aef:field fieldRef="sfdc:Opportunity.Id" role="match"/>
  <aef:expect path="StageName" const="Closed Won"/>
</aef:output>
```

**Soft delete and hard delete:**

```xml
<aef:output typeRef="sfdc:Contact" operation="update">
  <aef:field fieldRef="sfdc:Contact.Id" role="match"/>
  <aef:expect path="Status" const="archived"/>
</aef:output>
<aef:output typeRef="sfdc:Contact" operation="delete">
  <aef:field fieldRef="sfdc:Contact.Id" role="match"/>
  <aef:expect fieldRef="sfdc:Contact.Id" absent="true"/>
</aef:output>
```

## 12. Migration note for producers (informative)

An existing map has no `aef:prefixes`, so condition 4 of the `ref` read rule (2.3) never holds for it: a style-A
`ref` stays a v1 data-object identity, which is the safe default. A producer carries field intent in one of two ways:

- **Minimal** (stays a v1.0 map): add an `aef:prefixes` block declaring its field prefixes with `kind="field"`.
  Existing `ref` values are then read as `fieldRef`, with no other edit.
- **Full** (becomes a v1.1 map): rewrite those `ref`s as `fieldRef` and declare `mappingVersion="1.1"`.

Style-B names migrate mechanically: `[StageName=Closed Won]` becomes an `aef:expect const`; `model.id` becomes a
`path`; `posities (lineNumber, …)` becomes a list path. The placeholder `type="object"` may stay; once `typeRef` is
written, `typeRef` is authoritative (§2).

## 13. Not decided by this text

These remain open for the ruling and are deliberately not normative here:

1. Whether `ref` is also the data-flow join key between one step's output and the next step's input, or needs its
   own attribute.
2. `typeRef` version pinning: an IRI that includes the version, or a separate attribute.
3. Confirmation against greenfield's full maps (VZN-T1, WT-01).
