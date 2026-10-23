# lifecycle

> arc-011 sidecar receiver lifecycle — start/stop/monitor the HTTP server.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/sidecar/lifecycle.py`

## What It Does

### Framework Reference

```
Captured → Started Work ↔ Issues → Work Completed
```

**Map (T-2624):** the designer corpus renders this lifecycle as `aef-task-lifecycle` with state-carrier nodes — `tl_create`/`tl_parked` (captured, split on horizon), `tl_work` (started-work), `tl_heal` (issues), `tl_human_review` (partial-complete: work-completed still in `active/`), `tl_archive` (work-completed). Read it: `bin/fw corpus explain aef-task-lifecycle`. Open it: Watchtower `/designer`. The conformance rail (T-2621) audits map-vs-code transition parity.

---
*Auto-generated from Component Fabric. Card: `lib-sidecar-lifecycle.yaml`*
*Last verified: 2026-10-01*
