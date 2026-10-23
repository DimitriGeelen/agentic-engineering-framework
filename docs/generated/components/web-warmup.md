# warmup

> Startup cache warm-up for Watchtower (T-4363).

**Type:** script | **Subsystem:** watchtower | **Location:** `web/warmup.py`

## What It Does

The pages whose cold build is the expensive one (measured T-4363: /, /search,
/approvals, /tasks, /timeline were the five slowest cold routes; /cron is
named in 832's doctor report). Order: shared corpus readers first.
/search carries a keyword query (T-4458): without one the page never builds the
keyword index, and the first real search paid that build (17-89 s, host load).

---
*Auto-generated from Component Fabric. Card: `web-warmup.yaml`*
*Last verified: 2026-10-19*
