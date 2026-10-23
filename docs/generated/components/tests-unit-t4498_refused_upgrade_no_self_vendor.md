# t4498_refused_upgrade_no_self_vendor

> T-4498: a refused fw upgrade must be side-effect free (T-4278 rule) — the inline self-vendor sync included.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4498_refused_upgrade_no_self_vendor.bats`

## What It Does

T-4498: a refused fw upgrade must be side-effect free (T-4278 rule) — the
inline self-vendor sync included.
Origin: dimitri-mint-dev (msg ae5a4e7f). An upgrade from a SHALLOW clone of a
be tag was refused as foreign-source (the consumer's version_sha is not visible
in truncated history), but `Self-vendor: synced 3 file(s) to
.agentic-framework/lib/` had already run. do_upgrade called the _self_vendor_*
helpers before the T-1912 version precheck and the T-4278 vendor precheck, and
those helpers write into the SOURCE's own .agentic-framework/ — a tree the
T-4278 test never hashed.
Contract: a refusal leaves the consumer AND the source byte-identical; an

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4498_refused_upgrade_no_self_vendor.yaml`*
*Last verified: 2026-10-20*
