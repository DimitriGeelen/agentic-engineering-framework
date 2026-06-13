---
task: T-2351
title: Arc close form pre-population — Defect D from T-2347 (form fields empty when agent surfaces close)
status: in-progress
recommendation: GO
created: 2026-06-12
---

# T-2351 — Arc close form pre-population RCA

## 1. Trigger

T-2347 GO recorded, Slice C1 shipped. Agent surfaced `http://192.168.10.107:3000/arcs/value-prioritisation/close` to operator. Operator opened it, found:
- Demo path: empty
- Demo evidence: not pre-populated  
- Decision narrative: empty

Operator pushback (verbatim): *"ok but Demo Evidence is no prepopulated, demo path is also not prepopulated and Decisioon narrative is also empty , why do you epxet operator to provide as agent is surfacing arc for cempületion, as mentioend before we need teh same mechanics as with taksks and inceptiosn"*

This is Defect D — missed from T-2347's three-defect RCA. Same class: surface exists, agent has the data, no mechanic to pre-populate.

## 2. Symptom

`/arcs/<slug>/close` form on GET:
- `demo_value` MAY pre-pop from `_anchor_recommendation["suggested_demo"]` (web/blueprints/arcs.py:1318) — works if anchor task `## Recommendation` block contains a `Suggested demo: ...` field.
- `decision` textarea: hardcoded empty (arcs.py:1335 `prev_decision=...if request.method == "POST" else ""`). Never pre-populates on GET.
- `justification` textarea: hardcoded empty (same pattern). Never pre-populates.

For arc-006:
- T-1915 anchor task `## Recommendation` has GO verdict + rationale, **but no `Suggested demo:` field** → `suggested_demo == ""` → demo_value empty too.
- Decision narrative was never going to pre-populate regardless.

Operator faces empty form. Has to hand-type the demo path agent knew + write the decision narrative from scratch.

## 3. Comparison to tasks/inceptions (the operator's "same mechanics" reference)

| Surface | Agent writes | Form/page renders | Operator action |
|---------|--------------|-------------------|-----------------|
| Task review (`/review/T-XXX`) | `## Recommendation` block in task body (GO/NO-GO/DEFER + rationale + evidence) | `_anchor_recommendation` parses + template renders verdict/rationale/evidence as read-only sections; per-AC checkboxes for unchecked Human ACs | Read, confirm or amend, click submit |
| Inception decision (`/inception/T-XXX`) | `## Recommendation` block in task body | Same: full recommendation rendered, operator clicks GO/NO-GO/DEFER | Read, decide |
| **Arc close (`/arcs/<slug>/close`)** | (no convention) | Form fields blank except `demo_value` IF anchor has `Suggested demo:` | **Hand-type everything** |

Three carriers for the agent's recommendation, all consumed by `_anchor_recommendation` (web/blueprints/arcs.py:556-606):
- `verdict` (GO/NO-GO/DEFER) — extracted, rendered
- `rationale` — extracted, rendered  
- `evidence` — extracted, rendered
- `suggested_demo` — extracted, **but only `Suggested demo:` field** (line 604 regex match)

`Suggested decision:` and `Suggested justification:` sibling fields don't exist in the parser, don't get extracted, don't get wired into the form.

## 4. 5-Whys

| # | Why | Evidence |
|---|-----|----------|
| 1 | Why is the form empty? | `arcs.py:1335` hardcodes `prev_decision="" if request.method == "GET"`. |
| 2 | Why doesn't the parser surface a Suggested decision? | `_anchor_recommendation` (arcs.py:556-606) only knows about `Suggested demo:` (line 600-604 regex). No sibling fields exist. |
| 3 | Why was only `Suggested demo:` added? | Demo evidence is the §ACD-gated REQUIRED field for `fw arc close --demo`. The decision narrative is OPTIONAL (`--decision` is not required by `lib/arc.sh:arc_close`). The form surfaced what the close gate strictly needed; pre-pop ergonomics were left for later. |
| 4 | Why no convention for the agent to write the decision pre-handoff? | T-2347 C1 covered "use URL not CLI" but didn't extend to "write the recommendation into anchor task before handoff." Same omission class as T-2347 A/B/C — the surfaces exist (anchor `## Recommendation`, arc YAML `decision:`), the agent convention to write them doesn't. |
| 5 | Why didn't T-2347 catch this? | I (agent) walked T-2347 RCA looking at the *handoff surface* (URL vs CLI) but didn't open the form to check what the operator would see after clicking. Same blind spot the operator just caught. |

**Root cause:** parity gap between `## Recommendation` rendering on task/inception review surfaces (full agent recommendation rendered, operator confirms/amends) and arc close form (mostly empty fields, operator hand-types). The `_anchor_recommendation` parser supports one Suggested-* field; the form pre-pops one slot from it. Both need to grow to three (demo / decision / justification).

## 5. Candidate remediation — single Slice D

This is small and bounded enough for ONE build task (T-2351a) rather than three. Three coupled changes:

| Change | File:line | Cost |
|--------|-----------|------|
| Extend `_anchor_recommendation` to also extract `Suggested decision:` + `Suggested justification:` | `web/blueprints/arcs.py:556-606` — add two `re.search` siblings to the existing demo extraction | XS — ~6 LoC |
| Pre-populate `prev_decision` + `prev_justification` from extracted Suggested-* fields | `web/blueprints/arcs.py:1318-1335` — mirror the existing demo fallback pattern | XS — ~6 LoC |
| Document the convention (anchor `## Recommendation` carries Suggested-* trio when surfacing arc close) | CLAUDE.md §Arc Action Handoffs + extend memory L-482 | XS — prose |

Optional (deferred per IW-5):
- `proposed_decision:` arc YAML field as a secondary carrier if anchor parse fails

**Verification:** add a Playwright pin or curl-based smoke that visits `/arcs/<test-arc>/close` on a test arc whose anchor task has `Suggested decision: foo` and asserts `<textarea name="decision">foo</textarea>` rendered.

## 6. Recommendation

**GO** — Defect D is structurally identical to T-2347 A/B/C: surface exists, convention to populate it doesn't, agent omitted a mechanic the user explicitly compared against existing task/inception flows. ~12 LoC of pre-pop + ~6 LoC of parser extension + prose. Reversible, scoped, high-value (every arc closure handoff today loses the agent's known data at the form boundary).

After GO:
- File T-2351a (Slice D build task) — parser + pre-pop + memory/CLAUDE.md
- For arc-006 immediately: agent edits T-1915 anchor task `## Recommendation` to ADD `Suggested demo: docs/reports/value-prioritisation-demo/` + `Suggested decision: <full narrative>`. Even before T-2351a ships, the `Suggested demo:` field gets read RIGHT NOW (existing wiring) — operator opens the form and sees demo path filled in.

## 7. Dialogue Log

### 2026-06-12 — Trigger conversation

**Agent (after T-2347 C1 ship, recommending arc-006 close path):** Surfaced `/arcs/value-prioritisation/close` URL.

**Operator:** "ok but Demo Evidence is no prepopulated, demo path is also not prepopulated and Decisioon narrative is also empty , why do you epxet operator to provide as agent is surfacing arc for cempületion, as mentioend before we need teh same mechanics as with taksks and inceptiosn"

**Agent (this artefact):** Investigated. Found `_anchor_recommendation` only extracts `Suggested demo:`; `prev_decision`/`prev_justification` hardcoded empty on GET. Filed T-2351 (this inception) with recommendation GO + 5 IW questions disposed (3 answered, 1 dissolved, 1 deferred).

**Decision point:** Operator GO/NO-GO on the single-slice Z-hybrid approach (anchor task carrier, form reads it). T-2351a slice is the build leg if GO.

### 2026-06-12 — Why missed in T-2347

The T-2347 RCA walked the *handoff surface* (URL vs CLI) and ended at "use the URL". It didn't open the form to verify the post-click experience. The operator's pushback was literally to perform that step — open the form, find it empty, surface the gap. That's the missing audit step for arc-action RCA: walk one click past the handoff to verify what the operator actually sees.

## 8. Out-of-scope (explicit)

- **Three-field arc YAML schema migration** — IW-5 deferred. Only adopt if anchor-task-only carrier proves insufficient across multiple arcs.
- **Approve-driver form pre-pop** — different form. The proposed driver row already shows the agent's rationale; approve button submits weight without narrative. No defect there today.
- **T-2347a (arc_detail.html button)** — T-2349 covers it. Independent slice.
- **T-2347b (constituent counter parity)** — T-2350 covers it. Independent slice.
