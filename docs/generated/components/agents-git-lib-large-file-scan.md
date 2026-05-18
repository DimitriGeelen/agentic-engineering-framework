# large-file-scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/large-file-scan.sh`

## What It Does

agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845).
Origin: T-1828/T-1834 force-push surfaced two tracked binaries — an accidental
36MB ImageMagick PostScript at repo root, and a 78MB sqlite-vec index in
.context/working/ — both flagged by GitHub as oversized objects in history.
Sibling prevention class to T-1844 (secret-scan): same structural gap (no
pre-commit gate against accidentally-tracked artefacts), same fix shape.
This module is invoked by the pre-commit hook installed by
agents/git/lib/hooks.sh:install_hooks. It can also be run standalone:
large-file-scan.sh scan-staged       Scan git staged paths (the hook's mode)
large-file-scan.sh scan-tree         Scan the entire tracked tree (audit mode)

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `agents/git/lib/hooks.sh` | called_by |
| `C-004` | called_by |
| `bin/fw` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-large-file-scan.yaml`*
*Last verified: 2026-05-15*
