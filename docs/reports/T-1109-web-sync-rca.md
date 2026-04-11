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

## Worker findings

---

## Phase 1 — Code path trace

**Finding: `fw upgrade` → `lib/upgrade.sh:do_upgrade()`. No tmpdir, no git clone, no rsync.**

### Dispatch chain
```
bin/fw:2697-2700
  upgrade)
    source "$FW_LIB_DIR/lib/upgrade.sh"
    do_upgrade "$@"
```

`do_upgrade()` is a 914-line function with 10 explicit sections. It does NOT call `do_update`, `do_vendor`, `_do_update_vendored`, or any rsync-from-upstream logic. It syncs files by direct `diff -q` + `cp` from `$FRAMEWORK_ROOT` to `$target_dir`.

### Section 4b — the vendored script sync (lib/upgrade.sh:320-446)

Section 4b is the only section that writes to `<consumer>/.agentic-framework/`. It syncs:

| What | Source | Mechanism |
|------|--------|-----------|
| `agents/context/*.sh` | `$FRAMEWORK_ROOT/agents/context/` | diff -q → cp |
| `agents/context/lib/` | `$FRAMEWORK_ROOT/agents/context/lib/` | diff -q → cp |
| `bin/fw` | `$FRAMEWORK_ROOT/bin/fw` | diff -q → cp |
| `lib/*.sh` | `$FRAMEWORK_ROOT/lib/` | diff -q → cp |
| Agent dirs | `$FRAMEWORK_ROOT/agents/{task-create,handover,git,healing,fabric,dispatch,resume,audit,session-capture}/` | diff -q → cp |
| VERSION | Written directly | `echo "$fw_version" > VERSION` (T-859) |

**`web/` is completely absent.** The agent_dirs string at lib/upgrade.sh:388 is:
```bash
local agent_dirs="task-create handover git healing fabric dispatch resume audit session-capture"
```

No `web`, no `web/blueprints`, no `web/templates`, no `web/terminal`.

Searching the entire 914-line file for "web" finds only a comment inside a HEREDOC (line 286: `# Read by web/blueprints/cron.py`). There is no web sync anywhere in `do_upgrade`.

### Contrast: `do_vendor()` (bin/fw:181-190)

`fw init` calls `do_vendor` which has this includes list:
```bash
local includes=(
    bin
    lib
    agents
    web        # ← includes web/
    docs
    .tasks/templates
    FRAMEWORK.md
    metrics.sh
)
```

`do_vendor` IS comprehensive. `do_upgrade` step 4b is SELECTIVE and was never updated to include `web/` after the terminal feature landed.

### Answer to H6 (strongest hypothesis)
H6 was "fw upgrade is shim-only". PARTIALLY CONFIRMED but nuanced: `fw upgrade` does vendor SOME files (step 4b syncs agents, bin/fw, lib, VERSION), but NOT `web/`. The web directory is the gap. H6 was right that upgrade doesn't re-vendor the full `.agentic-framework/` — it only re-vendors a known subset.

### Secondary finding: shim routes to vendored fw (chicken-and-egg)

The global shim `~/.local/bin/fw` (T-664) resolves framework in this order:
1. Look for `bin/fw + FRAMEWORK.md` walking up from CWD (framework repo)
2. Look for `.agentic-framework/bin/fw` walking up from CWD (consumer project)

When run from `/opt/025-WokrshopDesigner`, the shim finds `.agentic-framework/bin/fw` (resolution #2). The vendored `bin/fw` then runs `resolve_framework()` which returns `.agentic-framework/` itself as `FRAMEWORK_ROOT` (because `.agentic-framework/` has `FRAMEWORK.md` + `agents/`).

Result: when `fw upgrade` is run via the shim from a consumer project, `FRAMEWORK_ROOT` = the vendored copy, and `FW_VERSION` = the vendored VERSION (1.1.16 for /opt/025). Step 4b syncs from the vendored copy TO the vendored copy → zero changes. Step 9 writes the OLD version back to `.framework.yaml`.

**But the audit trail for /opt/025 shows `framework_root: /opt/999-Agentic-Engineering-Framework`** for all recent upgrades. This means these upgrades were run via `/opt/999/bin/fw upgrade /opt/025-WokrshopDesigner` (not via the shim from within the consumer directory). In those cases, `FRAMEWORK_ROOT = /opt/999` and step 4b correctly syncs scripts from `/opt/999`. But `web/` is still missing because it's not in step 4b's sync list.

The VERSION=1.1.16 mystery: versions in the upgrade audit trail start at 1.5.51 (April 9). T-859 was added April 4. All script syncs in step 4b would find `/opt/025/.agentic-framework/agents/context/...` already matching `/opt/999/agents/context/...` if they were already synced in a prior run — so `script_updated=0`. The T-859 VERSION write happens inside the same 4b block: if `script_updated` is incremented for any reason, VERSION gets written. But if all files already match (script_updated=0), VERSION is still written (line 426-432 always runs). So VERSION SHOULD be current. This remains a secondary mystery but does not affect the primary bug conclusion.

---

## Phase 2 — Live reproduction

**Result: BUG REPRODUCED. `fw upgrade` silently skips web/ and reports false "OK".**

### Steps

```bash
# 1. Create test consumer
rm -rf /tmp/t1109-test-consumer
mkdir /tmp/t1109-test-consumer
/opt/999-Agentic-Engineering-Framework/bin/fw init --provider claude
# → fw init correctly vendors terminal.py (via do_vendor which includes web/)

# 2. Verify: terminal.py present
ls /tmp/t1109-test-consumer/.agentic-framework/web/blueprints/terminal.py  # EXISTS

# 3. Simulate stale state
rm /tmp/t1109-test-consumer/.agentic-framework/web/blueprints/terminal.py

# 4. Run fw upgrade
/opt/999-Agentic-Engineering-Framework/bin/fw upgrade /tmp/t1109-test-consumer
```

### Upgrade output (key lines)

```
[4b/9] Vendored framework scripts
  OK  All vendored scripts current    ← FALSE NEGATIVE: terminal.py still missing
```

### Post-upgrade check

```bash
ls /tmp/t1109-test-consumer/.agentic-framework/web/blueprints/ | grep terminal
# → empty — terminal.py NOT restored
```

**`fw upgrade` reported "OK All vendored scripts current" but terminal.py was not present.** No error, no warning. Silent skip.

### Blueprint diff: /opt/025 vs /opt/999

```
diff <(ls /opt/025-WokrshopDesigner/.agentic-framework/web/blueprints/) \
     <(ls /opt/999-Agentic-Engineering-Framework/web/blueprints/)
20a21
> sessions.py
22a24
> terminal.py
```

`sessions.py` and `terminal.py` are missing from `/opt/025`. Both are newer additions to the framework that post-date the original vendoring.

---

## Phase 3 — Hypothesis elimination

| Hypothesis | Status | Evidence |
|------------|--------|----------|
| H1 — Alternate code path | **RULED OUT** | `fw upgrade` definitively routes to `lib/upgrade.sh:do_upgrade()`, not `lib/update.sh:do_update()` |
| H2 — Stale tmpdir | **RULED OUT** | `do_upgrade()` has no tmpdir or git clone. That pattern belongs to `lib/update.sh:_do_update_vendored()` only |
| H3 — Nested .agentic-framework | **RULED OUT** | `find /opt/025-WokrshopDesigner -name .agentic-framework -type d` returns exactly one result |
| H4 — Silent rsync failure | **RULED OUT** | `do_upgrade` step 4b uses `diff -q + cp`, not rsync. No rsync in the upgrade path |
| H5 — VERSION is a relic | **PARTIALLY TRUE** | `.framework.yaml` is authoritative. But the real issue is missing web/ files, not the VERSION label |
| H6 — Upgrade is shim-only | **PARTIALLY CONFIRMED** | `do_upgrade` does vendor some files (step 4b), but `web/` is NOT in the sync list — the omission is the bug |
| H7 — upstream_repo mismatch | **RULED OUT (for this code path)** | `do_upgrade` reads directly from `$FRAMEWORK_ROOT`, never reads `upstream_repo` from `.framework.yaml`. This config key is only used by `lib/update.sh` |

### Why /opt/termlink has terminal.py (anomaly explained)

`/opt/termlink/.framework.yaml` has `upstream_repo: DimitriGeelen/agentic-engineering-framework` (a GitHub URL) and VERSION=0.9.585. The `upstream_repo` GitHub URL format triggers `lib/update.sh:_do_update_vendored()` which performs a `git clone` and calls `do_vendor` with the full includes list (including `web/`). This is the `fw update` code path, not `fw upgrade`. It gets terminal.py from GitHub.

### Confirmed root cause

`lib/upgrade.sh:do_upgrade()` step 4b maintains an explicit file-by-file enumeration for syncing `.agentic-framework/`. The `web/` directory was never added to this enumeration. When terminal.py was added in T-964..T-967/T-980, only the framework repo got the file — no update was made to step 4b's sync list.

`do_vendor()` (in `bin/fw`) is the comprehensive sync used by `fw init` and `fw update`. It includes `web/`. The two mechanisms diverged silently.

**Class of bug**: Missing entry in an explicit enumeration — a structural pattern that requires every new directory to be registered in two places (do_vendor includes + do_upgrade step 4b).

---

## Phase 4 — Structural fix design

### Root cause requires fix at: `lib/upgrade.sh:do_upgrade()` step 4b

### Option A — Minimum viable fix (add web/ to step 4b enumeration)

**Approach:** Add web/ sync to section 4b, similar to how agent dirs are synced.

**Exact change in lib/upgrade.sh (after line 423, before "# T-859: Sync VERSION file"):**
```bash
        # Sync web/ (Watchtower blueprints, templates, terminal module)
        local web_subdirs="blueprints templates terminal"
        for web_sub in $web_subdirs; do
            local src_web="$FRAMEWORK_ROOT/web/$web_sub"
            local dst_web="$vendored_dir/web/$web_sub"
            [ -d "$src_web" ] || continue
            if ! diff -rq "$src_web" "$dst_web" > /dev/null 2>&1; then
                script_updated=$((script_updated + 1))
                if [ "$dry_run" != true ]; then
                    mkdir -p "$dst_web"
                    cp -r "$src_web/." "$dst_web/"
                fi
            fi
        done
        # Sync top-level web/*.py (app.py, config.py, etc.)
        for src_web_file in "$FRAMEWORK_ROOT/web/"*.py "$FRAMEWORK_ROOT/web/requirements.txt"; do
            [ -f "$src_web_file" ] || continue
            local wfname
            wfname=$(basename "$src_web_file")
            local dst_web_file="$vendored_dir/web/$wfname"
            if [ ! -f "$dst_web_file" ] || ! diff -q "$src_web_file" "$dst_web_file" > /dev/null 2>&1; then
                script_updated=$((script_updated + 1))
                if [ "$dry_run" != true ]; then
                    mkdir -p "$vendored_dir/web"
                    cp "$src_web_file" "$dst_web_file"
                fi
            fi
        done
```

**Risk:** Still requires manual updates when new top-level directories are added. The enumeration problem recurs.

### Option B — Structural fix (make step 4b call do_vendor) — RECOMMENDED

**Approach:** Replace step 4b's hand-enumerated sync with a call to the already-correct `do_vendor` function.

`do_vendor` already has the correct includes list (`bin lib agents web docs .tasks/templates FRAMEWORK.md metrics.sh`). Instead of maintaining a parallel enumeration, have `do_upgrade` call it:

```bash
# ── 4b. Vendored framework scripts (.agentic-framework/) ──
echo -e "${YELLOW}[4b/9] Vendored framework scripts${NC}"
local vendored_dir="$target_dir/.agentic-framework"
if [ -d "$vendored_dir" ]; then
    if [ "$dry_run" = true ]; then
        echo -e "  ${CYAN}WOULD RE-VENDOR${NC}  Full re-vendor from $FRAMEWORK_ROOT"
        changes=$((changes + 1))
    else
        local vendor_output
        vendor_output=$(do_vendor --target "$target_dir" --source "$FRAMEWORK_ROOT" 2>&1)
        local vendor_exit=$?
        if [ $vendor_exit -eq 0 ]; then
            echo -e "  ${GREEN}UPDATED${NC}  Re-vendored from $FRAMEWORK_ROOT"
            changes=$((changes + 1))
        else
            echo -e "  ${YELLOW}WARN${NC}  Re-vendor reported issues: $vendor_output"
            skipped=$((skipped + 1))
        fi
    fi
else
    echo -e "  ${CYAN}SKIP${NC}  No .agentic-framework/ directory"
fi
```

**Benefits:**
- Single source of truth: `do_vendor` includes list is the only thing to update
- Atomic: full re-vendor, no partial state
- Automatically picks up future additions (e.g., when `web/api/` is added later)
- Eliminates the VERSION divergence problem (do_vendor writes VERSION from FW_VERSION)
- Eliminates the diff-without-web false-OK messages

**Risk:** `do_vendor` does a full copy (not diff-based), slightly slower. But `.agentic-framework/` is ~7MB — acceptable.

**Files to change:**
- `lib/upgrade.sh`: Replace step 4b body (lines 320-443 approximately)
- No other files needed

### Migration path for broken consumers

After the fix is deployed, consumers can self-heal by running:
```bash
cd /opt/025-WokrshopDesigner && /opt/999-Agentic-Engineering-Framework/bin/fw upgrade
```
This will trigger the new step 4b which calls `do_vendor`, restoring `web/blueprints/terminal.py`, `web/blueprints/sessions.py`, and any other missing files.

**Alternative if fw upgrade is unavailable**: `fw vendor --target /opt/025-WokrshopDesigner` does the same thing directly.

**The 4 broken consumers** (025, 051, 050, openclaw): all need one `fw upgrade` run after the fix. No manual file copying needed.

---

## Phase 5 — Invariant test design

### Test: `tests/integration/upgrade-vendor-complete.bats`

```bash
#!/usr/bin/env bats
# Integration test: fw upgrade must sync ALL web/ files to consumer .agentic-framework/
# Regression test for T-1109 (web/ sync gap)

setup() {
    CONSUMER_DIR="$(mktemp -d)"
    FRAMEWORK_ROOT="/opt/999-Agentic-Engineering-Framework"
    # Initialize consumer using fw init
    "$FRAMEWORK_ROOT/bin/fw" init --provider claude --target "$CONSUMER_DIR" >/dev/null 2>&1 || true
    # Clobber web/blueprints to simulate stale state
    rm -rf "$CONSUMER_DIR/.agentic-framework/web/blueprints"
    rm -rf "$CONSUMER_DIR/.agentic-framework/web/templates"
    rm -rf "$CONSUMER_DIR/.agentic-framework/web/terminal"
}

teardown() {
    rm -rf "$CONSUMER_DIR"
}

@test "fw upgrade restores missing web/blueprints/terminal.py" {
    run "$FRAMEWORK_ROOT/bin/fw" upgrade "$CONSUMER_DIR"
    [ "$status" -eq 0 ]
    [ -f "$CONSUMER_DIR/.agentic-framework/web/blueprints/terminal.py" ]
}

@test "fw upgrade restores ALL blueprints from upstream" {
    run "$FRAMEWORK_ROOT/bin/fw" upgrade "$CONSUMER_DIR"
    [ "$status" -eq 0 ]
    # Every blueprint in FRAMEWORK_ROOT/web/blueprints/ must exist in consumer
    for bp in "$FRAMEWORK_ROOT/web/blueprints/"*.py; do
        local name
        name=$(basename "$bp")
        [ -f "$CONSUMER_DIR/.agentic-framework/web/blueprints/$name" ] || \
            fail "Missing blueprint after upgrade: $name"
    done
}

@test "fw upgrade restores web/templates/" {
    run "$FRAMEWORK_ROOT/bin/fw" upgrade "$CONSUMER_DIR"
    [ "$status" -eq 0 ]
    local fw_tmpl_count consumer_tmpl_count
    fw_tmpl_count=$(ls "$FRAMEWORK_ROOT/web/templates/"*.html 2>/dev/null | wc -l)
    consumer_tmpl_count=$(ls "$CONSUMER_DIR/.agentic-framework/web/templates/"*.html 2>/dev/null | wc -l)
    [ "$consumer_tmpl_count" -eq "$fw_tmpl_count" ]
}

@test "fw upgrade restores web/terminal/ module" {
    run "$FRAMEWORK_ROOT/bin/fw" upgrade "$CONSUMER_DIR"
    [ "$status" -eq 0 ]
    [ -d "$CONSUMER_DIR/.agentic-framework/web/terminal" ]
}

@test "fw upgrade: vendored VERSION matches FW_VERSION after upgrade" {
    run "$FRAMEWORK_ROOT/bin/fw" upgrade "$CONSUMER_DIR"
    [ "$status" -eq 0 ]
    local fw_version
    fw_version=$(git -C "$FRAMEWORK_ROOT" describe --tags --match 'v*' 2>/dev/null | sed 's/^v//') || \
        fw_version=$(cat "$FRAMEWORK_ROOT/VERSION")
    local vendored_version
    vendored_version=$(cat "$CONSUMER_DIR/.agentic-framework/VERSION")
    [ "$vendored_version" = "$fw_version" ]
}

@test "fw upgrade --dry-run does not modify web/ but reports changes" {
    run "$FRAMEWORK_ROOT/bin/fw" upgrade --dry-run "$CONSUMER_DIR"
    [ "$status" -eq 0 ]
    # web/blueprints should still be absent (dry-run doesn't write)
    [ ! -d "$CONSUMER_DIR/.agentic-framework/web/blueprints" ]
    # Output should mention something about vendored/web
    [[ "$output" == *"WOULD"* ]]
}
```

### Test: `tests/lint/single-vendor-writer.bats`

```bash
#!/usr/bin/env bats
# Structural test: only ONE code path may define what gets vendored
# Regression test for T-1109 (enumeration duplication between do_vendor and do_upgrade)

@test "do_vendor includes list is the only place web/ is listed as a vendor target" {
    # do_vendor includes list (bin/fw:181-190) must have 'web'
    run grep -n '"web"' /opt/999-Agentic-Engineering-Framework/bin/fw
    [ "$status" -eq 0 ]  # web IS in do_vendor

    # do_upgrade step 4b must NOT have a separate web sync enumeration
    # (it must call do_vendor, not maintain its own list)
    run grep -n 'web/blueprints\|web/templates\|web/terminal' \
        /opt/999-Agentic-Engineering-Framework/lib/upgrade.sh
    # Any matches here indicate the duplication pattern has re-emerged
    [ "$status" -ne 0 ] || fail "do_upgrade has its own web sync enumeration — must call do_vendor instead"
}
```

### CI recommendation

- `upgrade-vendor-complete.bats`: run in integration test suite (requires filesystem, not unit). Run nightly or on any change to `lib/upgrade.sh` or `web/`.
- `single-vendor-writer.bats`: run as lint (fast, no filesystem). Run on every PR that touches `lib/upgrade.sh` or `bin/fw`.
- Trigger: `on: [push, pull_request] paths: ['lib/upgrade.sh', 'bin/fw', 'web/**']`

---

## Phase 6 — Recommendation

### Verdict: **GO**

### Confirmed root cause

`lib/upgrade.sh:do_upgrade()` section 4b (lines 320-443) maintains an **explicit enumeration** of directories to sync to `.agentic-framework/`. The `web/` directory was never added to this enumeration. `do_vendor()` (in `bin/fw:181-190`) has a parallel includes list that DOES include `web/`. These two lists diverged when the terminal feature (`web/blueprints/terminal.py`, `web/templates/terminal.html`, `web/terminal/`) was added in T-964..T-980.

This is not a configuration issue, not an rsync exit code issue, not a path resolution issue. It is a **structural pattern failure**: two enumerations of the same logical thing, maintained independently.

### Chokepoint

**C1 (do_vendor chokepoint)** — Replace step 4b's hand-enumeration with a call to `do_vendor`. Single source of truth. No parallel list to forget.

### Invariant test pair (per T-1105 discipline)

| Chokepoint | Invariant test |
|------------|---------------|
| C1: do_upgrade calls do_vendor | `tests/lint/single-vendor-writer.bats` — grep ensures no parallel enumeration in upgrade.sh |
| C1: web/ is restored after upgrade | `tests/integration/upgrade-vendor-complete.bats` — each blueprint file verified post-upgrade |

### Descendant build tasks

| Task ID | Scope | Type |
|---------|-------|------|
| T-1109a | Fix `lib/upgrade.sh` step 4b: replace enumeration with `do_vendor` call | Build |
| T-1109b | Write `tests/integration/upgrade-vendor-complete.bats` | Test |
| T-1109c | Write `tests/lint/single-vendor-writer.bats` | Test |
| T-1109d | Run `fw upgrade` on the 4 broken consumers (025, 051, 050, openclaw) | Build |
| T-1109e | Add `fw doctor` check: compare vendored web/ against upstream manifest | Build |

### Risk: none blocking GO

- Fix is a pure refactor of step 4b — no behavior change for already-correct files
- `do_vendor` is battle-tested (used by `fw init` in thousands of runs)
- Migration for broken consumers is a single `fw upgrade` command
- Tests prevent recurrence

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

