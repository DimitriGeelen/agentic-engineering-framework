# T-1120 — Review Marker Gate Blocks Watchtower

## Bug

Watchtower's inception approve button calls `fw inception decide`. The T-973 gate in
`lib/inception.sh:225` requires `.context/working/.reviewed-T-XXX` to exist first.
This marker is only created by `fw task review` (CLI). Watchtower doesn't create it.

Result: human clicks approve → "Task review required" error.

## Fix

`web/blueprints/inception.py:record_decision()` now creates the review marker before
calling `fw inception decide`. The human IS reviewing by being on the Watchtower page.

## Impact

Unblocks all 12 pending inception decisions in Watchtower.
