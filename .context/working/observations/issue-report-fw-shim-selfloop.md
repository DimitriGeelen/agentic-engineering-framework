---
type: issue-report
title: "bin/fw replaced with shim → infinite exec loop; every `fw` call hung"
reported: 2026-04-17
reporter: agent (during T-1277 RCA)
investigated_by: agent
severity: high
frequency: 100% (whenever `fw` is invoked from inside the framework repo in this state)
related_task: T-1278
status: rca-complete + hot-fix-applied
tags: [bug, tooling, shim, regression, rca]
---

# Issue Report — bin/fw Self-Exec Loop

## Symptom

`bin/fw work-on …` (and any other `fw` subcommand) hangs indefinitely. Killed after 30s via `timeout`. No stdout/stderr before kill.

## Root cause (confirmed)

`/opt/999-Agentic-Engineering-Framework/bin/fw` had been replaced with the **shim** contents — byte-for-byte identical to `bin/fw-shim` (md5 `5f0d74e5b52a89d2d7a7bb3a4b7c4528`, both 50 lines). Git HEAD has the real CLI at `bin/fw` (4262 lines). `git status` showed the overwrite as an uncommitted modification.

### Mechanism — infinite exec loop

Shim logic (`bin/fw-shim:18-34`):

```bash
find_fw() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -x "$dir/bin/fw" ] && [ -f "$dir/FRAMEWORK.md" ]; then
            echo "$dir/bin/fw"; return 0
        fi
        ...
        dir="$(dirname "$dir")"
    done
}
fw_path=$(find_fw) || { ... }
exec "$fw_path" "$@"
```

Run from inside the framework repo:

1. `bin/fw ARGS` starts the shim.
2. `find_fw` walks up, finds `/opt/999-Agentic-Engineering-Framework/bin/fw` (itself) + `FRAMEWORK.md` ✓
3. `exec "$PWD/bin/fw" "$@"` → re-enters the same shim.
4. GOTO 2. Process spins forever until a wrapping `timeout` kills it.

`~/.local/bin/fw` is a symlink back to the same file, so `fw` on PATH was equally stuck.

## Evidence

- `md5sum bin/fw bin/fw-shim` → both `5f0d74e5b52a89d2d7a7bb3a4b7c4528` (identical).
- `wc -l bin/fw` → 50; `git show HEAD:bin/fw | wc -l` → 4262.
- `git status` → `modified: bin/fw`.
- `timeout 30 bin/fw work-on …` → killed, exit 143.
- After `git checkout HEAD -- bin/fw`: `timeout 10 bin/fw version` → `fw v1.5.16` in <1s, exit 0.

## How it masked itself

- No output before kill → looked like "hooks slow" or "Claude frozen".
- Every other framework probe worked (ls, cat, git, python) because nothing called `fw`.
- `fw doctor` also calls `fw` → same loop → couldn't self-diagnose.
- `~/.local/bin/fw` symlink meant even `fw` from outside the repo failed, pointing blame at the shell/PATH rather than the file.

## Why it happened — confirmed root cause

**`lib/upgrade.sh:379` writes the shim through a destination symlink into the framework repo's `bin/fw`:**

```bash
# T-665 shim-migration block
local current_fw="$local_bin/fw"     # = ~/.local/bin/fw
if [ -L "$current_fw" ]; then        # yes, it's a symlink → /opt/.../bin/fw
    ...
    cp "$shim_src" "$current_fw"     # BUG: cp follows the destination symlink
                                     # and overwrites /opt/.../bin/fw with the shim
```

`cp SRC DST` on Linux, when `DST` is a symlink, writes to the symlink's **target** by default — it does not replace the symlink. So every `fw upgrade` that hits this branch silently corrupts the framework repo's `bin/fw`, turning the real 4262-line CLI into the 50-line shim and arming the self-exec loop.

Reproduced in-session: I restored `bin/fw` via `git checkout HEAD -- bin/fw` at ~12:16, verified it worked (`bin/fw version` → `fw v1.5.16`), then — between the restore and my commit — a background `fw work-on` process finally completed, and during its work the shim got written back. My subsequent `git add bin/fw && git commit` committed the broken state to master (commit `5b38b394`, later reset via `git reset --soft`).

**Fix applied:** `lib/upgrade.sh` now does `rm -f "$current_fw"` before the `cp`, so the symlink is removed first and the new file lands at `~/.local/bin/fw` (not through the symlink). Alternative: `cp --remove-destination`.

Touch timestamps: `bin/fw` had been corrupted some time around 2026-04-16 20:49 — coincides with a `fw upgrade` run during T-1256 release-tagging work. That was the original corruption; today's `fw work-on` re-triggered it.

## Impact

- 100% reproducible hang of every `fw` invocation from inside the repo.
- Hooks that `source` or shell out to `fw` degrade silently.
- Amplifies T-1277 (4h stall) — if `checkpoint.sh` or auto-handover ever called `fw` here, it'd compound the freeze.
- User experience: complete loss of the framework CLI with no diagnostic output.

## Hot fix (applied)

```bash
cd /opt/999-Agentic-Engineering-Framework
git checkout HEAD -- bin/fw
# Verified:
bin/fw version  # → fw v1.5.16
```

## Durable fix (tracked in T-1278)

1. **Shim self-loop guard:** before `exec`ing, compare `realpath "$fw_path"` to `realpath "${BASH_SOURCE[0]}"`. If equal, exit with a loud, actionable error instead of looping.
2. **`fw doctor` check:** flag `bin/fw` that is suspiciously small or matches the shim signature (FAIL, not WARN).
3. **`fw upgrade` refuses to stomp framework-repo `bin/fw`:** if the target directory contains `FRAMEWORK.md`, it's the framework repo, not a consumer — never write the shim there.
4. **Bats test:** synthesize the broken state in a tmp dir and assert the guard trips in <1s.

## Relationship to T-1277 (the 4h stall)

Different bug, different class:

| Aspect | T-1277 (4h stall) | T-1278 (fw shim loop) |
|---|---|---|
| Failure mode | Hang on unbounded `git push` network op | Hang on self-exec loop (local) |
| Trigger | Auto-handover at critical tokens + unreachable remote | Any `fw` invocation inside the repo |
| Fix | `timeout` wrapper + `http.lowSpeedTime` | Self-realpath guard + doctor check |
| Reachable via | PostToolUse hook, `/compact`, manual handover | Anywhere `fw` is called |

Both are in the "hooks hang without bound" family, but neither is the other's cause — they're independent bugs that happened to compound. Bundling them would blur causality.

## Next actions

- [ ] Framework: ingest this observation + T-1278 into episodic memory
- [ ] Implement guard + doctor check (T-1278 ACs)
- [ ] After fix ships: add a regression learning `L-0XX: hot tools (fw, handover) must self-verify they're not looping`
