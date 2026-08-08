# init_strips_upstream_credentials

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/init_strips_upstream_credentials.bats`

## What It Does

T-2817 — `fw init` must not persist a credential into the new project.
lib/init.sh auto-detects the framework's git origin and writes it to the new
project's .framework.yaml as `upstream_repo:`. That file is TRACKED. A framework
cloned as https://TOKEN@host/path therefore wrote the token into every project
initialised from it.
Found 2026-08-05 the loud way, which is the only reason it was found at all: the
T-1844 secret-scan hook refused the new project's very FIRST commit, reporting
"[URL Embedded Token] .framework.yaml". Defence-in-depth caught what layer one
emitted — so the onboarding symptom (first commit blocked by a file the framework
itself authored) and the leak are the same defect seen from two sides.

---
*Auto-generated from Component Fabric. Card: `tests-unit-init_strips_upstream_credentials.yaml`*
*Last verified: 2026-08-05*
