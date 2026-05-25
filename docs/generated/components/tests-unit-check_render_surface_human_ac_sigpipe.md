# check_render_surface_human_ac_sigpipe

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/check_render_surface_human_ac_sigpipe.bats`

## What It Does

T-1900: render-surface gate error path used to die with SIGPIPE (exit 141)
under set -eo pipefail when `render_surface_files_in | head -N` produced
more lines than head consumed. Script died with no error printed; user saw
"command did nothing" indistinguishable from success.
Origin: T-1898 update — Verification 5/5 PASS, Recommendation ✓, RCA ✓,
then silent exit 141 because the task had duplicate `### Human` headers
(first one template-only) and components: 5 render-surface paths.
Fix: awk reads to EOF instead of head closing stdin early. No SIGPIPE.
Test pins:
- the offending pipeline pattern no longer present in source

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | tests |
| `web/blueprints/arcs.py` | tests |
| `agents/task-create/update-task.sh` | tests |
| `lib/render_surface.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_render_surface_human_ac_sigpipe.yaml`*
*Last verified: 2026-05-18*
