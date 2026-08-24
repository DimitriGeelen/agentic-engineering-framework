# watchtower-staleness

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/watchtower-staleness.sh`

## What It Does

T-2938: does the RUNNING Watchtower actually run the code on disk?
Origin. The operator recorded GO on T-2925 through Watchtower. The decision
was written to the task file and then refused at the commit boundary by the
G-052 duplicate-task-ID scan — the exact failure T-2864 had already fixed in
`web/blueprints/inception.py` four days earlier. Both facts were true at once:
the fix was on disk, and the defect was in the running process. The Watchtower
serving :3001 had been started on Aug 6 23:44; the fix landed Aug 8 09:38, and
Flask runs with `debug=False` here, so there is no reloader. Six days of a
process holding bytes nobody could see.
Why doctor could not see it. The existing triple check (bin/fw ~:1892) asks

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-watchtower-staleness.yaml`*
*Last verified: 2026-08-12*
