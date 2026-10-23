# gen-stock-hook-digests

> T-4568: regenerate agents/git/lib/stock-hook-digests.txt — "<lines> <sha256>" for every git-hook template body (the 'HOOK_EOF' heredocs) that agents/git/lib/hooks.sh held BEFORE the marked block (T-4403), i.e.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/gen-stock-hook-digests.sh`

## What It Does

T-4568: regenerate agents/git/lib/stock-hook-digests.txt — "<lines> <sha256>"
for every git-hook template body (the 'HOOK_EOF' heredocs) that
agents/git/lib/hooks.sh held BEFORE the marked block (T-4403), i.e. every hook
file a pre-block install-hooks wrote verbatim.
install-hooks reads it to recognise a stock old framework hook — exactly, or
with project lines appended — so it replaces the old template whole and keeps
only the appended lines. Without it, the lines an old template has and the new
one lacks were kept as "project lines", did not parse after the block, and the
upgrade REFUSED a hook nobody had edited (cloud job 2, v1.8.14 consumer).
The set is closed: since T-4403 install-hooks never writes a bare template, so

---
*Auto-generated from Component Fabric. Card: `tools-gen-stock-hook-digests.yaml`*
*Last verified: 2026-10-21*
