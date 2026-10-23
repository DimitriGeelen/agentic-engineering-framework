# vector-index-health

> Vector-index (semantic recall) health — bash side of lib/vector_index_health.py. T-3783.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/vector-index-health.sh`

## What It Does

Vector-index (semantic recall) health — bash side of lib/vector_index_health.py.
T-3783. ONE predicate, called by fw doctor, fw audit (corpus-health section),
the handover, the hourly `fw index reindex` cron and the fw recall / fw ask banner.
Needs FRAMEWORK_ROOT and PROJECT_ROOT; uses fw_config when lib/config.sh is loaded.

---
*Auto-generated from Component Fabric. Card: `lib-vector-index-health.yaml`*
*Last verified: 2026-10-03*
