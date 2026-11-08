# working-oversize

> T-5061 (G-130): name runaway files under .context/working/ before they fill a disk.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/working-oversize.sh`

## What It Does

T-5061 (G-130): name runaway files under .context/working/ before they fill a disk.
Origin: on the Greenfield laptop .context/working/.checkpoint.handover.stderr reached 183 GB
of one repeated handover block in under two hours; the host disk filled, WSL and the
operator's Claude crashed, and nothing had warned. fw doctor and fw audit both call this.
Database files (*.db and their -wal/-shm journals, e.g. the semantic index) are large by
design and are skipped. Threshold: FW_WORKING_FILE_WARN_BYTES (default 1 GiB).
Usage: source it, then  fw_working_oversized <working-dir> [threshold-bytes]
Prints "<bytes> <path relative to working-dir>" per oversized file, largest first.
Exit 0 always; no output means none.

---
*Auto-generated from Component Fabric. Card: `lib-working-oversize.yaml`*
*Last verified: 2026-11-07*
