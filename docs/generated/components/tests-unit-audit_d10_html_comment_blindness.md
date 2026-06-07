# audit_d10_html_comment_blindness

> Bats unit tests pinning D10 audit ("Decision-without-Dialogue") behaviour
against HTML-comment-blindness false positives (T-1889). 4 cases verify:
template-stub-only Human section is silent, real unchecked AC outside
comments fires, checked AC is silent, mixed comments+real AC doesn't
double-count. Forward-pins the strip-comments call added to audit.sh
D10 block — future refactors that remove it fail test #1.


**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/audit_d10_html_comment_blindness.bats`

**Tags:** `test`, `bats`, `audit`, `d10`, `false-positive`, `T-1889`

## What It Does

T-1889: D10 audit must ignore HTML-comment-only Human AC sections.
D10 (Decision-without-Dialogue) flags inception/spec tasks where Human ACs
exist but none are checked. Until T-1889 the counter ran naked .count("[ ]")
against the section body, also counting checkboxes inside <!-- ... --> template
stubs. Result: every task whose `### Human` section was only the template
example fired D10 falsely. Origin: T-1455.
Pattern matches the canonical strip in lib/inception.sh:517 (sed /<!--/,/-->/d).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [inception](/docs/generated/lib-inception) | tests | fw inception - Inception phase workflow |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_d10_html_comment_blindness.yaml`*
*Last verified: 2026-05-17*
