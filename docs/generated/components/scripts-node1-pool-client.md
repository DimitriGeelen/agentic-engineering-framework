# pool-client

> scripts/node1/pool-client.sha256 — T-5410: sha256 of ring20's pool client, verified by node1_nightly.py before every run.

**Type:** script | **Subsystem:** framework-core | **Location:** `scripts/node1/pool-client.sha256`

## What It Does

scripts/node1/pool-client.sha256 — T-5410/T-5417: sha256 of ring20's pool client and the
files it loads (`<sha256>  <absolute path>`, the client first), verified by node1_nightly.py
before every run and every pool-client call. Re-pin only by operator action:
scripts/node1/node1-nightly.sh --repin
pinned 2026-11-25 (operator yes 2026-11-24; ring20's 19:28Z republish)
poold.py pinned 2026-11-25, T-5417 (operator yes 2026-11-25; ring20's 2026-11-24 20:58Z republish)

---
*Auto-generated from Component Fabric. Card: `scripts-node1-pool-client.yaml`*
*Last verified: 2026-11-25*
