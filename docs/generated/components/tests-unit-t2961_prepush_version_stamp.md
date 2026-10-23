# t2961_prepush_version_stamp

> T-2961 (T-2925 GO): the pre-push VERSION stamp composed <major.minor>.<commits> from `git describe`, dropping the tag's patch.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2961_prepush_version_stamp.bats`

## What It Does

T-2961 (T-2925 GO): the pre-push VERSION stamp composed <major.minor>.<commits>
from `git describe`, dropping the tag's patch. The third field was a distance
that reset at every tag: v1.8.9 + 92 commits stamped 1.8.92, which sorts
"newer" than v1.8.10. The stamp now writes T-4055's grammar, X.Y.Z+N.gSHA,
the same string bin/fw _derive_version produces.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2961_prepush_version_stamp.yaml`*
*Last verified: 2026-10-20*
