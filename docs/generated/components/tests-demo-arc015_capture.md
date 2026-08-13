# arc015_capture

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/demo/arc015_capture.sh`

## What It Does

arc-015 (onboarding-shape-detection) — capture the headline mechanic firing.
Regenerates docs/reports/arc-015-demo-evidence.md from a live run. This is a DEMO
CAPTURE, not a test: it exists so `fw arc close --demo` has a wire-level artefact to
point at. The guard that keeps the mechanic working is
tests/unit/init_project_shape_detection.bats — this script reports that suite's result
but does not replace it.
Two disciplines this script must not lose, both learned the hard way:
1. FRESH DIRECTORY PER ECOSYSTEM. `fw init` skips the seeding block entirely on a
directory it has already initialised, so re-using one produces NO evidence line
and no mode line. Read carelessly that looks exactly like "the feature is not

---
*Auto-generated from Component Fabric. Card: `tests-demo-arc015_capture.yaml`*
*Last verified: 2026-08-10*
