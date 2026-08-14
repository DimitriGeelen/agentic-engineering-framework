# integrate-go-live

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/integrate-go-live.sh`

## What It Does

integrate-go-live.sh — safe zone-3 host go-live (T-2483; OBS-086).
Make MAIN's running framework code match a remote ref (default origin/master)
WITHOUT merging two divergent busy checkouts.
Going live = MAIN's CODE (lib/ agents/ bin/) matches master. The DATA
(.context/*) must stay MAIN's — it carries accumulators (feedback-stream,
gate-bypass-log, decisions, inbox, metrics-history) that diverge legitimately
per host and must never be clobbered. So we do a surgical code-only sync:
git checkout <remote-ref> -- <code dirs>   # bring master's code, only code
git commit -m "T-XXX: ..."                 # commit only the staged code
This touches ZERO .context/ data, so it cannot conflict on accumulators and

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `bin-integrate-go-live.yaml`*
*Last verified: 2026-07-22*
