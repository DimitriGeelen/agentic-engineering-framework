# t5089_fabric_dotfile_slug

> T-5089 (GitHub #109) — `fw fabric register .gitignore` wrote `.fabric/components/.yaml`: the slug stripped the dotfile's whole name as if it were an extension.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5089_fabric_dotfile_slug.bats`

## What It Does

T-5089 (GitHub #109) — `fw fabric register .gitignore` wrote `.fabric/components/.yaml`:
the slug stripped the dotfile's whole name as if it were an extension. A second dotfile
collided by registration order, and `.framework.yaml` got the slug of `framework.yaml`.
A dotfile's leading dot now becomes a `dot-` prefix; every other path keeps its slug.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5089_fabric_dotfile_slug.yaml`*
*Last verified: 2026-11-12*
