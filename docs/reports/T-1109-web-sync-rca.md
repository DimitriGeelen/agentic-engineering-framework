# T-1109 — Fw Upgrade Silently Skips Web/ Sync (Research Stub — RCA In Progress)

**Date:** 2026-04-11
**Status:** RCA worker dispatched via TermLink
**Artifact purpose:** Research trail — will be populated incrementally as RCA worker investigates (C-001)

---

## Problem

Live evidence discovered 2026-04-11 during Watchtower terminal feature availability check (user question: "is it available to consumer projects?").

### Observable symptoms

**Framework upstream (/opt/999):**
- Terminal feature complete on master (T-962 inception GO, T-964..T-967, T-980 all work-completed)
- `web/blueprints/terminal.py` exists (177 lines)
- `web/templates/terminal.html` exists (546 lines)
- `web/terminal/` module exists (adapters, sessions, registry)
- `web/requirements.txt` declares `flask-socketio>=5.0`
- `/terminal` route returns HTTP 200 on `:3003`

**Consumer projects — 4 of 5 inspected are missing terminal.py:**
- `/opt/025-WokrshopDesigner/.agentic-framework/web/blueprints/terminal.py` → MISSING
- `/opt/051-Vinix24/.agentic-framework/web/blueprints/terminal.py` → MISSING
- `/opt/050-email-archive/.agentic-framework/web/blueprints/terminal.py` → MISSING
- `/opt/openclaw-evaluation/.agentic-framework/web/blueprints/terminal.py` → MISSING
- `/opt/termlink/.agentic-framework/web/blueprints/terminal.py` → PRESENT (anomaly — why only this one?)

**Live confirmation:** `curl -sI http://192.168.10.107:3001/terminal` (which is /opt/025's Watchtower) returns **HTTP 404 NOT FOUND**.

### The smoking gun

`/opt/025-WokrshopDesigner` ran `fw upgrade` today:
- `.framework.yaml` says `version: 1.5.246`, `upgraded_from: 1.5.242`, `last_upgrade: 2026-04-11T10:50:34Z`
- BUT the vendored `.agentic-framework/VERSION` file says `1.1.16` (drifted by 0.4.230 versions — years of terminal-shaped updates)
- `.framework.yaml` and the actual vendored copy are **reporting two different versions**

The upgrade claimed success (updated yaml, wrote timestamp) but **did not land the new files**.

### Code path under suspicion

`lib/update.sh:183-192` — the sync include list:
```bash
local includes=(
    bin
    lib
    agents
    web        # ← should include web/blueprints/terminal.py
    docs
    .tasks/templates
    FRAMEWORK.md
    metrics.sh
)
```

`lib/update.sh:207-220` — the rsync loop:
```bash
for item in "${includes[@]}"; do
    if [ -e "$tmpdir/upstream/$item" ]; then
        local dest_dir
        dest_dir=$(dirname "$vendored_dir/$item")
        mkdir -p "$dest_dir"
        if [ -d "$tmpdir/upstream/$item" ]; then
            if command -v rsync &>/dev/null; then
                rsync -a --delete $rsync_excludes "$tmpdir/upstream/$item/" "$vendored_dir/$item/"
            else
                rm -rf "${vendored_dir:?}/${item:?}"
                cp -r "$tmpdir/upstream/$item" "$vendored_dir/$item"
            fi
```

**Two questions the code doesn't answer:**
1. Does the loop actually reach the `web` iteration? (Is the include list even this code path?)
2. What's `$tmpdir/upstream/`? Where does the upstream tmpdir come from, and is it fetching the right version?

## Hypotheses to test

**H1 — Alternate upgrade code path:** `bin/fw upgrade` routes to a different function, not `lib/update.sh:do_update()`. The include list I'm reading is dead code. Testable by: `grep -n 'upgrade)' bin/fw` and trace the dispatch.

**H2 — Tmpdir resolves to stale upstream:** `$tmpdir/upstream/` is populated from a git clone/pull of `upstream_repo`. If the remote is pointing at an old commit (or a shallow clone), the upstream copy doesn't have terminal.py yet. Testable by: add logging to update.sh or run with `bash -x` on a sandbox consumer.

**H3 — Pattern 6 (nested .agentic-framework):** `$vendored_dir` resolves to the wrong path. If the consumer has `.agentic-framework/.agentic-framework/`, the rsync writes to the outer dir but the actual Watchtower loads from the inner dir. (From T-1100 isolation pattern survey.) Testable by: `find /opt/025 -name .agentic-framework -type d`.

**H4 — Rsync silent failure:** rsync exits non-zero and the loop continues. The `|| true` or trap pattern swallows the error. Testable by: re-run update.sh with `set -e; set -x` and watch rsync exit codes.

**H5 — Version file is a relic:** VERSION file is written at vendor-time only (not at upgrade-time). `.framework.yaml` is the authoritative version. The 1.1.16 in VERSION is just leftover from the original vendoring and has no bearing on actual file contents. Testable by: check whether `/opt/025/.agentic-framework/lib/` has been updated — if yes, VERSION file is stale/unused; if no, the rsync is broken.

**H6 — fw upgrade is a shim-only update:** What `fw upgrade` actually does is update the SHIM (`~/.local/bin/fw` project-detecting shim) and rewrites `.framework.yaml`, but does NOT re-vendor `.agentic-framework/` contents. The last_upgrade timestamp is the shim update, not a re-vendor. The consumer needs a separate `fw vendor --target /opt/025` to get new vendored files. Testable by: read `bin/fw` upgrade case + trace what it actually writes.

**H7 — upstream_repo pointer mismatch:** `/opt/025/.framework.yaml` has `upstream_repo: /opt/999-Agentic-Engineering-Framework`. If fw upgrade reads upstream_repo and does a git archive / rsync, it should see terminal.py because it IS in /opt/999's working copy. Unless it's doing `git show HEAD:web/blueprints/terminal.py` against a different ref.

## Chokepoint candidates (structural fix)

**Chokepoint C1 — single vendor function for all vendor-like operations:**
- `do_vendor()` becomes the ONLY function that writes to `<consumer>/.agentic-framework/`. 
- Everything else (`fw init`, `fw upgrade`, `fw update`) must call `do_vendor()` internally — no direct rsync.
- Atomic replace: remove existing vendored dir, write new one. No merge, no partial.
- Writes the VERSION file AND updates .framework.yaml in the same atomic step.
- This eliminates the VERSION/.framework.yaml drift class.

**Chokepoint C2 — manifest-driven sync:**
- Framework root has a canonical `.vendor-manifest.yaml` listing every path that must be present in a vendored copy with its hash.
- `fw upgrade` resolves the manifest from upstream, diffs against consumer, rsyncs missing/changed files.
- `fw doctor` can verify manifest conformance as a read-only check.

## Invariant tests (validation plan)

**Test 1 — Post-upgrade manifest consistency:**
```bash
# tests/integration/upgrade-vendor-complete.bats
# Given: a throwaway consumer project at an old version
# When: fw upgrade runs to the current framework version
# Then: every file in upstream `web/blueprints/*.py` exists in consumer
#       every file in upstream `web/templates/*.html` exists in consumer
#       every file in upstream `web/terminal/*.py` exists in consumer
#       consumer's VERSION file == upstream's VERSION file
#       consumer's .framework.yaml version == upstream's VERSION file
```

**Test 2 — Drift detection (no silent writer mismatch):**
```bash
# tests/lint/version-source-consistency.bats
# Greps framework code for every place that writes VERSION or .framework.yaml version
# Asserts there is exactly ONE writer function
# Fails if two separate code paths can update these fields independently
```

**Test 3 — fw doctor manifest check:**
```bash
# Add to bin/fw doctor: "Vendor manifest check"
# For each consumer project (or the current project):
#   compare hashes of its vendored files against upstream manifest
#   report drift with actionable copy-paste fix command
```

**Test 4 — Live reproduction gate:**
```bash
# Before the fix: manually confirm /opt/025 is missing terminal.py
# After the fix: run fw upgrade /opt/025 → /opt/025/.agentic-framework/web/blueprints/terminal.py exists
#                run fw doctor from /opt/025 → no drift warnings
#                curl http://<ip>:<025-port>/terminal → HTTP 200
```

## RCA plan for the worker

**Phase 1 — Code path trace (30 min)**
- Find `fw upgrade` dispatch in `bin/fw`
- Read every function it calls end-to-end
- Document which `rsync` / `cp` invocations actually execute
- Identify the source (upstream location) at runtime

**Phase 2 — Live reproduction (20 min)**
- Pick a throwaway consumer (e.g., create `/tmp/fake-consumer` with `fw init`)
- Run `fw upgrade` with `bash -x` or instrumented logging
- Observe which files actually get copied
- Compare to the include list in update.sh

**Phase 3 — Hypothesis elimination (20 min)**
- Test H1..H7 in order of cheapest test
- Short-circuit as soon as root cause is confirmed
- Write ruled-in / ruled-out for each

**Phase 4 — Structural fix design (15 min)**
- Pick between C1 (chokepoint only) and C2 (manifest-driven) based on root cause
- Sketch the exact patch (file paths, line counts)
- Identify migration path for the 4 currently-broken consumers

**Phase 5 — Invariant test design (10 min)**
- Concrete bats test per validation plan
- Identify any test infrastructure needed (fake consumer fixture, git worktree, etc.)
- Estimate cost (lines, files, CI time)

**Phase 6 — Recommendation (5 min)**
- GO / NO-GO / DEFER
- Cite the confirmed root cause
- Reference the chokepoint + invariant test pair per T-1105 discipline

## Deliverable

This file — updated incrementally by the worker with findings from each phase. Final recommendation section at the bottom.

---

## Worker findings (to be filled)

(Worker writes here — main session seed below)

---

## Main session pre-investigation (seeded 2026-04-11 before worker dispatch)

Before dispatching the worker, main session performed Phase 1 (code path trace) and reached a confident root-cause hypothesis. The worker should validate and extend these findings.

### Dispatch table — two divergent upgrade commands

`bin/fw` routes `upgrade` and `update` to **two different functions** in two different files:

| fw subcommand | Source file | Function | Sync approach |
|---|---|---|---|
| `fw update` | `lib/update.sh:10` | `do_update()` | Whole-directory rsync with include list |
| `fw upgrade` | `lib/upgrade.sh:8` | `do_upgrade()` | Handcrafted per-file sync (partial) |

`bin/fw:2693-2700`:
```bash
update)
    source "$FW_LIB_DIR/update.sh"
    do_update "$@"
    ;;
upgrade)
    source "$FW_LIB_DIR/init.sh"
    source "$FW_LIB_DIR/upgrade.sh"
    do_upgrade "$@"
    ;;
```

### The include list in `lib/update.sh:183-192` is DEAD CODE for `fw upgrade`

`do_update()` has:
```bash
local includes=(
    bin lib agents web docs .tasks/templates FRAMEWORK.md metrics.sh
)
```

And rsyncs each one from `$tmpdir/upstream/` into the vendored dir with `rsync -a --delete`. If `do_update()` runs, `web/blueprints/terminal.py` would be copied. **But `fw upgrade` does NOT call `do_update()`.** It calls `do_upgrade()` instead.

### `do_upgrade()` in `lib/upgrade.sh:320+` — handcrafted partial sync

The vendored-scripts sync block starts at line 320. It handles:
- `agents/context/*.sh` (handcrafted list, line 331)
- `bin/fw` (line 358)
- `lib/*.sh` (handcrafted list, line 376)
- `agents/*/` files (handcrafted list per agent, line 396)
- `VERSION` file (line 426)

**Never synced by `do_upgrade()`:**
- `web/` (blueprints, templates, static, terminal/, requirements.txt)
- `docs/`
- `.tasks/templates/`
- `metrics.sh`
- `FRAMEWORK.md`

The handcrafted sync is a denylist-by-omission — if it isn't named explicitly, it isn't synced. When T-962..T-967 added `web/blueprints/terminal.py`, `do_upgrade()` was NEVER updated to include it. Same for every other new file in `web/`, `docs/`, `.tasks/templates/`.

### G-024 explanation (finally)

G-024 was registered as "fw upgrade does not sync web/blueprints/" — a reported observation. The CODE that looks correct (`lib/update.sh`) is for `fw update`, a different command. The `fw upgrade` command has a fundamentally different sync strategy (handcrafted per-file) that structurally cannot sync new files without code changes in `lib/upgrade.sh` itself. Every new blueprint, template, or web module requires a manual edit to `lib/upgrade.sh` — which is exactly the drift G-035 describes at the doc layer.

### Why `/opt/termlink` is the anomaly

`/opt/termlink` has `terminal.py`. The other 4 consumers don't. Hypotheses:
- /opt/termlink was vendored (via `fw vendor` or `fw init`, which both call `do_vendor()` with the include list) more recently than its last upgrade, overwriting everything
- /opt/termlink was upgraded with `fw update` (not `fw upgrade`) at some point
- /opt/termlink was manually rsync'd
- /opt/termlink is on a newer version that already had the handcrafted terminal entry added to `lib/upgrade.sh` (unlikely — the handcrafted list is grep-able)

Worker: please confirm by checking `/opt/termlink/.agentic-framework/VERSION` and comparing to git log for when terminal.py was added.

### Hypothesis status (pre-worker)

| H | Description | Status |
|---|---|---|
| H1 | Alternate code path | **CONFIRMED** — `fw upgrade` → `do_upgrade()`, not `do_update()` |
| H2 | Tmpdir resolves to stale upstream | Unlikely — `do_upgrade` doesn't use a tmpdir; it reads from `$FRAMEWORK_ROOT` directly |
| H3 | Pattern 6 nested | Unlikely but worker should check `find /opt/025 -name .agentic-framework` |
| H4 | Rsync silent failure | N/A — no rsync of `web/` in `do_upgrade()` at all |
| H5 | Version file relic | Possibly related — `do_upgrade()` writes VERSION at line 426, but .framework.yaml is written elsewhere (two writers → drift) |
| H6 | fw upgrade is shim-only | **PARTIALLY CONFIRMED** — it IS more than shim-only (syncs bin/fw, lib/, agents/) but is NOT a full re-vendor |
| H7 | upstream_repo pointer | Relevant — worker should verify whether `do_upgrade()` reads upstream_repo or just uses `$FRAMEWORK_ROOT` |

### Chokepoint recommendation (pre-worker)

**C1 (do_vendor chokepoint)** is confirmed as the right direction. Details:

1. Delete the handcrafted sync block in `lib/upgrade.sh:320-445` (or whatever range). Replace with a single call:
   ```bash
   do_vendor --target "$target_dir" --source "$upstream_source"
   ```
2. `do_vendor()` (in `bin/fw:117-285` or wherever) is already the canonical full re-vendor with the proper include list matching `do_update()`.
3. Collapse `fw update` and `fw upgrade` into a single command that calls `do_vendor()` + updates `.framework.yaml` + migrates configuration.
4. Keep `fw update` as a deprecated alias for compatibility.
5. `do_vendor()` should also write `.framework.yaml` version atomically with the vendored files — eliminating the two-writer drift (H5).

### Invariant test sketch

```bash
# tests/integration/fw_upgrade_syncs_web.bats
@test "fw upgrade copies every file from upstream web/ into consumer" {
    # setup: fake consumer at /tmp/t1109-consumer via fw init
    # act: rm /tmp/t1109-consumer/.agentic-framework/web/blueprints/terminal.py
    # act: fw upgrade on /tmp/t1109-consumer
    # assert: /tmp/t1109-consumer/.agentic-framework/web/blueprints/terminal.py exists
    # assert: sha256sum matches upstream
    # assert: /tmp/t1109-consumer/.agentic-framework/VERSION == upstream VERSION
    # assert: /tmp/t1109-consumer/.framework.yaml version == upstream VERSION
}
```

Runs in CI on every PR. Catches any regression where a new subsystem is added without being synced.

### Worker's remaining job

1. Phase 2 — live reproduction: create /tmp/t1109-test-consumer, confirm the bug end-to-end with `bash -x`
2. Phase 3 — confirm or refine H5 (version writer drift — how many writers are there?)
3. Phase 4 — sketch the exact patch for C1 chokepoint (line counts, migration path)
4. Phase 5 — flesh out the invariant test (what fixture, what assertions, CI integration)
5. Phase 6 — final GO/NO-GO/DEFER recommendation with cost estimate and risk analysis

The root cause is strongly implicated by code reading alone. The worker's value is in validating it with live reproduction, catching any dark-corner surprises, and producing the concrete fix artifact for the build task.

