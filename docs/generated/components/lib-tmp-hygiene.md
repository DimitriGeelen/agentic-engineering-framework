# tmp-hygiene

> lib/tmp-hygiene.sh - owned temp dirs for AEF test runs, a bounded orphan sweep, and a fullness verdict for the temp filesystem (T-4846)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/tmp-hygiene.sh`

## What It Does

lib/tmp-hygiene.sh - owned temp dirs for AEF test runs, a bounded orphan sweep,
and a fullness verdict for the temp filesystem (T-4846)
bats makes its run dir (bats-run-XXXXXX) under $TMPDIR and removes it from its
own EXIT handler, which a SIGKILL never reaches. The unit suite gives each file
a TMPDIR of its own (T-4215); the P-011 Verification gate and `fw test` handed
bats the caller's TMPDIR, i.e. the shared /tmp, a RAM tmpfs here. A killed run
left 2.6 GB there on 2026-10-27, and /tmp filled. /tmp is shared with other
projects on the host, so everything below touches only what it can attribute.

---
*Auto-generated from Component Fabric. Card: `lib-tmp-hygiene.yaml`*
*Last verified: 2026-10-27*
