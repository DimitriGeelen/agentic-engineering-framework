# gen-framework-hook-lines

> T-4552 (G-122): regenerate agents/git/lib/framework-hook-lines.txt — every non-comment line of every git-hook template body (the 'HOOK_EOF' heredocs) that agents/git/lib/hooks.sh has ever held, trimmed, sorted, unique.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/gen-framework-hook-lines.sh`

## What It Does

T-4552 (G-122): regenerate agents/git/lib/framework-hook-lines.txt — every
non-comment line of every git-hook template body (the 'HOOK_EOF' heredocs)
that agents/git/lib/hooks.sh has ever held, trimmed, sorted, unique.
fw doctor reads it to tell an OLD framework hook line from a consumer's own
line among the lines the T-4403 installer commented out. Only hooks migrated
by T-4403 (478b7ac40, before T-4515) carry such lines, so a catalogue built
after T-4515 covers every template they can contain; regenerating only adds.
Usage (framework repo, needs git history): tools/gen-framework-hook-lines.sh

---
*Auto-generated from Component Fabric. Card: `tools-gen-framework-hook-lines.yaml`*
*Last verified: 2026-10-21*
