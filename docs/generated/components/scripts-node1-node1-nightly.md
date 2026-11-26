# node1-nightly

> scripts/node1/node1-nightly.sh — T-5392: nightly unit-suite run on node1 (ring20's pool).

**Type:** script | **Subsystem:** framework-core | **Location:** `scripts/node1/node1-nightly.sh`

## What It Does

scripts/node1/node1-nightly.sh — T-5392: nightly unit-suite run on node1 (ring20's pool).
Builds and stages the unit-suite bundle of HEAD, submits every node1-compatible unit
test file (scripts/node1/node1-incompatible.txt lists the rest), holds while node1's
feed health is not healthy, collects the results and writes
.context/audits/unit-suite/node1/<date>.yaml + LATEST.yaml. Logic: node1_nightly.py.
scripts/node1/node1-nightly.sh --dry-run          list what would be sent (no network)
scripts/node1/node1-nightly.sh --health           node1's feed health only
scripts/node1/node1-nightly.sh --limit 20         a small real run
scripts/node1/node1-nightly.sh                    the nightly run (cron: node1-unit-suite-nightly)
scripts/node1/node1-nightly.sh --repin            OPERATOR ONLY: pin the pool client's new sha256 (T-5410)

---
*Auto-generated from Component Fabric. Card: `scripts-node1-node1-nightly.yaml`*
*Last verified: 2026-11-24*
