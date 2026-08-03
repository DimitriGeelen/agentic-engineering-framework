# designer

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/designer/designer.sh`

## What It Does

fw designer — vendor + serve a pinned Workflow Designer build (T-2521, T-173 beachhead).
832-Workflow-designer is SoT. AEF vendors a RELEASED single-file build (never source,
never edited in place) and serves it via the Watchtower `/designer` blueprint.
Verbs:
fw designer status                 Show the pin + whether the vendored build is present/valid
fw designer path                   Print the absolute path of the vendored build (for the blueprint)
fw designer sync --from <file>     Verify a DELIVERED artifact's sha256 against the pin and install
it read-only into the vendored path. Rejects (exit 1) on mismatch.
fw designer sync --from-tag [tag] [--dry-run]
Pull-at-tag intake (T-247/D-335, T-2616): fetch artifact +

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [corpus_spec](/docs/generated/tools-corpus_spec) | calls | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [designer_sync_from_tag](/docs/generated/tests-unit-designer_sync_from_tag) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-designer-designer.yaml`*
*Last verified: 2026-07-10*
