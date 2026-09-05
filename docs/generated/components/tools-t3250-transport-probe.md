# t3250-transport-probe

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t3250-transport-probe.sh`

## What It Does

T-3250 / G-097 re-measurement — can a turn be DELIVERED into a live Claude TUI?
WHY THIS EXISTS. The continuous loop needs a way to hand a running agent session
a new turn. Of the three routes, injection into a live TUI is the only one that
gives cheap repeatable multi-hop (the Stop hook is capped at one continuation by
the platform; a session restart costs a full budget trip per hop). G-097 measured
that route as BROKEN on 2026-09-03: `termlink inject` returns 0 and delivers
nothing into an ink-based raw-mode TUI, while `tmux send-keys` against the
identical pane at the identical moment delivers correctly.
That finding is two days old and was taken at a different termlink build. Before
any rig is designed around it — or any transport leg is added to the driver

---
*Auto-generated from Component Fabric. Card: `tools-t3250-transport-probe.yaml`*
*Last verified: 2026-09-04*
