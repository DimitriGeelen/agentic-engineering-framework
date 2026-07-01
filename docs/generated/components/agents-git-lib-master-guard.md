# master-guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/master-guard.sh`

## What It Does

master-guard.sh — Master-as-merge-only pre-commit guard (T-2396, inception T-2394 G1)
Refuses a DIRECT authored commit when HEAD is on master/main. Allows:
- merge commits    (MERGE_HEAD present)
- rebases          (rebase-merge / rebase-apply in progress)
- fast-forwards    (no commit object created → this hook never fires)
- feature branches (anything not master/main)
- protection off   (PROTECT_MASTER != 1)
- explicit bypass  (FW_ALLOW_MASTER_COMMIT=1)
Enable:  fw config set PROTECT_MASTER 1     (or FW_PROTECT_MASTER=1 for a one-off)
Bypass:  FW_ALLOW_MASTER_COMMIT=1 git commit ...   (Tier-2, WARN to stderr)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-master-guard.yaml`*
*Last verified: 2026-06-14*
