# upstream

> Safe issue creation from field installations to framework upstream repo. Resolves upstream repo from .framework.yaml or git remotes. Supports dry-run, confirmation, fw doctor attachment, patch attachment, and sent-file tracking.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/upstream.sh`

**Tags:** `upstream`, `gh-cli`, `field-report`

## What It Does

lib/upstream.sh — Safe issue/PR creation from field installations to framework repo
Part of the Agentic Engineering Framework
Inception: T-451 | Build: T-454

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |
| `lib/init.sh` | reads |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | calls |
| `bin/fw` | called_by |

## Related

### Tasks
- T-761: Fix shellcheck warnings in update.sh, upstream.sh, init.sh, notify.sh, setup.sh

---
*Auto-generated from Component Fabric. Card: `lib-upstream.yaml`*
*Last verified: 2026-03-12*
