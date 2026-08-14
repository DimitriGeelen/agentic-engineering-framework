# url-credentials

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/url-credentials.sh`

## What It Does

URL credential handling — one dialect, shared by every writer of an upstream URL.
Origin: T-2693 / OBS-106. `bin/fw` wrote the vendored `.upstream` sentinel from
`git remote get-url origin` verbatim, so a credentialed origin put a live token
into a tracked file (and into vendor stdout). The repair already existed in
`lib/consumer-recover.sh` as `_cr_strip_credentials` and had simply never been
applied on the write path — a producer/consumer split of the L-399 family:
one side of a contract shipped, the other side left alone.
This file is that contract's single implementation. Callers source it rather
than re-deriving a second `sed` dialect, so a future fix to the transformation
lands everywhere at once. Deliberately dependency-free and side-effect-free

---
*Auto-generated from Component Fabric. Card: `lib-url-credentials.yaml`*
*Last verified: 2026-07-31*
