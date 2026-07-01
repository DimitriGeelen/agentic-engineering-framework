# discard-manifest

> TODO: describe what this component does

**Type:** script | **Subsystem:** handover | **Location:** `agents/handover/discard-manifest.sh`

## What It Does

discard-manifest.sh — Category-level compaction discard manifest (T-2366, arc-012 S4)
Slice S4 of T-2158 (continuous-run). When the agent self-compacts at a
context-budget boundary, the handover that fires (pre-compact.sh / checkpoint.sh
→ handover.sh, unified under D-028) leaves behind a machine-readable record of
WHAT was discarded, so the operator can review post-hoc.
Category-level fidelity is sufficient and is all that is achievable: the model
self-compacts internally, so a token-level before/after diff is impossible
(T-2158 S6 Q4). This script reports counts and the working-set file list mined
from the current session transcript — the categories that compaction sheds.
Usage:

---
*Auto-generated from Component Fabric. Card: `agents-handover-discard-manifest.yaml`*
*Last verified: 2026-06-13*
