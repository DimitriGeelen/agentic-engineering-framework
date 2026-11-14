# t5033_grant_refused_verbs_resolved

> T-5033 (ring20-dashboard a14cb4c1): the refusal of metadata changes and archive extraction on create-granted paths (T-4989) judges what the command ACTS ON, not whether the grant's text appears in it: a glob, the command's own variables, a…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5033_grant_refused_verbs_resolved.bats`

## What It Does

T-5033 (ring20-dashboard a14cb4c1): the refusal of metadata changes and archive extraction
on create-granted paths (T-4989) judges what the command ACTS ON, not whether the grant's
text appears in it: a glob, the command's own variables, a relative operand from a cwd in
the grant. Refused verbs elsewhere keep today's verdict.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5033_grant_refused_verbs_resolved.yaml`*
*Last verified: 2026-11-14*
