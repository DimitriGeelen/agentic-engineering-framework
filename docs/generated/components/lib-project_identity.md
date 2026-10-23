# project_identity

> lib/project_identity.sh — who this project is, and which instance of it you are (T-3534)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/project_identity.sh`

## What It Does

lib/project_identity.sh — who this project is, and which instance of it you are (T-3534)
── WHY ───────────────────────────────────────────────────────────────────────
Operator, 2026-09-28: "Here again I got another project asking me if it's you.
So we should also have mechanics to register project name and the project root
directory so it always knows who it is and where to find that."
Identity was IMPLIED in four places — .framework.yaml, PROJECT_ROOT/
FRAMEWORK_ROOT, TermLink session tags, the T-559 boundary gate — and ANSWERABLE
in none. There was no verb an agent could call to say who it is.
── THE TWO IDENTITIES, WHICH ARE NOT THE SAME THING ──────────────────────────
PROJECT identity   = project_id + project_name.  Lives in .framework.yaml,

---
*Auto-generated from Component Fabric. Card: `lib-project_identity.yaml`*
*Last verified: 2026-09-28*
