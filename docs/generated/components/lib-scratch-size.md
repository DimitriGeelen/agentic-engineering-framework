# scratch-size

> lib/scratch-size.sh - size verdict for .context/scratch (T-4703)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/scratch-size.sh`

## What It Does

lib/scratch-size.sh - size verdict for .context/scratch (T-4703)
.context/scratch is git-ignored, so neither git status nor audit sees it. Release
work dirs (full repo clones, 1-10 GB each) piled up there to 28 GB before anyone
measured it. fw doctor calls this with SCRATCH_WARN_GB; release_scratch_prune
(lib/release.sh) removes shipped release lanes, this catches everything else.

---
*Auto-generated from Component Fabric. Card: `lib-scratch-size.yaml`*
*Last verified: 2026-10-23*
