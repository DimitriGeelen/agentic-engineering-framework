#!/usr/bin/env bats
# T-4705: the T-4692/T-4697 "Files this upgrade created or changed" list and its
# single `git add` line must print for a VENDORED consumer upgraded from an
# EXTERNAL framework clone, run from a cwd outside the consumer.
# Origin: dimitri-mint-dev be.9 report (sidecar 3294edcf) — no list, no git add line.
# t4692_upgrade_commit_list.bats covers an unvendored consumer upgraded from inside it.

load ../git_fence   # T-3610: hook installs must not walk up into a repo above the temp dir

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    S="$BATS_TEST_TMPDIR"
    PROJ="$S/proj"
    mkdir -p "$S/home" "$PROJ"
    git init -q "$PROJ"
    (cd "$PROJ" && env -u PROJECT_ROOT -u FRAMEWORK_ROOT HOME="$S/home" FW_VERB_TELEMETRY=0 \
        "$FW_ROOT/bin/fw" init . --provider claude >"$S/init.log" 2>&1)
    [ -x "$PROJ/.agentic-framework/bin/fw" ]
    # fw init made the bootstrap commit. Now make the vendored copy an OLDER
    # framework revision: one runtime file differs, and the vendor stamp records
    # that content as framework-written (otherwise T-3850 refuses it as a local edit).
    echo "# older vendored revision" >> "$PROJ/.agentic-framework/lib/upgrade.sh"
    python3 - "$PROJ/.agentic-framework" <<'PY'
import hashlib, json, os, sys
root = sys.argv[1]
stamp = os.path.join(root, ".fw-vendor-stamp.json")
d = json.load(open(stamp))
d["files"]["lib/upgrade.sh"] = hashlib.sha256(open(os.path.join(root, "lib/upgrade.sh"), "rb").read()).hexdigest()
json.dump(d, open(stamp, "w"), indent=1)
PY
    git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qam "T-000: older vendored revision"
    [ -z "$(git -C "$PROJ" status --porcelain)" ]
}

_upgrade_from_outside() {
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT HOME="$S/home" FW_VERB_TELEMETRY=0 \
        bash -c "cd '$S' && '$FW_ROOT/bin/fw' upgrade '$PROJ'"
}

@test "T-4705 vendored consumer, external clone, cwd outside: list and one git add line print" {
    _upgrade_from_outside
    [ "$status" -eq 0 ]
    [[ "$output" == *"change(s) applied"* ]]
    [[ "$output" != *" 0 change(s) applied"* ]]
    [[ "$output" == *"Files this upgrade created or changed"* ]]
    [[ "$output" == *"vendored  .agentic-framework/"* ]]
    printf '%s\n' "$output" | grep -F 'git add -- ' > "$S/add"
    [ "$(wc -l < "$S/add")" -eq 1 ]
    grep -qF '.agentic-framework/' "$S/add"
}

# T-4724: dimitri-mint-dev be.15 — the reason line printed at the very end, after
# the doctor advisory. The list and its reason line come from one call; pin that
# call between the change counters and Next steps.
_line_of() { printf '%s\n' "$output" | grep -nF -m1 "$1" | cut -d: -f1; }

@test "T-4724 file list prints under the change counters, before Next steps" {
    _upgrade_from_outside
    [ "$status" -eq 0 ]
    applied=$(_line_of "change(s) applied")
    list=$(_line_of "Files this upgrade created or changed")
    next=$(_line_of "Next steps:")
    [ -n "$applied" ] && [ -n "$list" ] && [ -n "$next" ]
    [ "$applied" -lt "$list" ]
    [ "$list" -lt "$next" ]
}

# T-4712: dimitri-mint-dev be.11 — hundreds of vendored files behind, and an earlier
# upgrade left them uncommitted. The re-run re-vendors the same bytes, so "content
# changed since the snapshot" dropped every vendored file and the list came out empty.
_vendored_count() {
    printf '%s\n' "$1" | sed -n 's/.*vendored  \.agentic-framework\/ (\([0-9]*\) file(s)).*/\1/p'
}

@test "T-4712 large vendored diff left uncommitted by an earlier upgrade: the re-run still lists it" {
    # Vendor the consumer from an older framework commit (git archive, never the working tree).
    mkdir -p "$S/old"
    git -C "$FW_ROOT" archive HEAD~300 | tar -x -C "$S/old"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT HOME="$S/home" FW_VERB_TELEMETRY=0 \
        bash -c "cd '$S' && '$S/old/bin/fw' vendor --target '$PROJ' --source '$S/old'"
    [ "$status" -eq 0 ]
    git -C "$PROJ" add -A
    git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm "T-000: vendored from HEAD~300"
    echo "user notes" > "$PROJ/notes-t4712.txt"   # dirty before, not the upgrade's

    _upgrade_from_outside
    [ "$status" -eq 0 ]
    first=$(_vendored_count "$output")
    [ "${first:-0}" -ge 100 ]

    # No commit in between: the second upgrade writes identical vendored bytes.
    [ "$(git -C "$PROJ" status --porcelain -uall -- .agentic-framework | wc -l)" -ge 100 ]
    _upgrade_from_outside
    [ "$status" -eq 0 ]
    [[ "$output" == *"Files this upgrade created or changed"* ]]
    second=$(_vendored_count "$output")
    [ "${second:-0}" -ge "$first" ]
    printf '%s\n' "$output" | grep -F 'git add -- ' > "$S/add"
    [ "$(wc -l < "$S/add")" -eq 1 ]
    grep -qF '.agentic-framework/' "$S/add"
    ! grep -qF 'notes-t4712.txt' "$S/add" || false
}

# T-4717: dimitri-mint-dev be.14 — the consumer is the user's HOME, the upgrade is
# run from a Claude Code Bash tool inside it (FRAMEWORK_ROOT and PROJECT_ROOT
# inherited, FRAMEWORK_ROOT = the consumer's OLDER vendored copy), with the
# framework clone inside HOME and output going to a file, not a tty. The summary
# printed "N change(s) applied" and Next steps, then nothing where the list belongs.
@test "T-4717 consumer is HOME, inherited old vendored FRAMEWORK_ROOT, output redirected: list prints" {
    mkdir -p "$S/old"
    git -C "$FW_ROOT" archive v1.8.15-be.11 | tar -x -C "$S/old"
    run env -u PROJECT_ROOT -u FRAMEWORK_ROOT HOME="$S/home" FW_VERB_TELEMETRY=0 \
        bash -c "cd '$S' && '$S/old/bin/fw' vendor --target '$PROJ' --source '$S/old'"
    [ "$status" -eq 0 ]
    git -C "$PROJ" add -A
    git -C "$PROJ" -c user.email=t@t -c user.name=t commit -qm "T-000: vendored from be.11"
    [ -z "$(git -C "$PROJ" status --porcelain)" ]

    env CLAUDECODE=1 HOME="$PROJ" FRAMEWORK_ROOT="$PROJ/.agentic-framework" PROJECT_ROOT="$PROJ" \
        FW_VERB_TELEMETRY=0 \
        bash -c "cd '$PROJ' && '$FW_ROOT/bin/fw' upgrade '$PROJ'" > "$S/upgrade.log" 2>&1 </dev/null
    grep -q "is the project's vendored copy; upgrading from" "$S/upgrade.log"
    grep -q "change(s) applied" "$S/upgrade.log"
    grep -q "Files this upgrade created or changed" "$S/upgrade.log"
    grep -q "vendored  .agentic-framework/" "$S/upgrade.log"
    ! grep -q "Upgrade file list unavailable" "$S/upgrade.log" || false
    grep -F 'git add -- ' "$S/upgrade.log" > "$S/add"
    [ "$(wc -l < "$S/add")" -eq 1 ]
}

# Unit legs: the list comes from the helper beside the running lib/upgrade.sh, and
# a helper that cannot run leaves one reason line, never nothing.
_t4717_source_upgrade_lib() {
    BOLD=""; NC=""; YELLOW=""; GREEN=""; CYAN=""; RED=""
    source "$FW_ROOT/lib/upgrade.sh"
}

@test "T-4717 FRAMEWORK_ROOT naming a tree without the helper: the running lib's helper still lists" {
    mkdir -p "$S/elsewhere/lib"          # an inherited FRAMEWORK_ROOT the run does not use
    export FRAMEWORK_ROOT="$S/elsewhere"
    _t4717_source_upgrade_lib
    _t4692_before="" _t4717_why=""
    _t4717_commit_list_snapshot "$PROJ"
    [ -z "$_t4717_why" ] && [ -f "$_t4692_before" ]
    echo new > "$PROJ/created-t4717.txt"
    echo created-t4717.txt > "$S/wrote"
    run _t4692_emit_commit_list "$PROJ" "$_t4692_before" "$S/wrote" "$_t4717_why"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       created-t4717.txt"* ]]
    [[ "$output" != *"unavailable"* ]]
}

@test "T-4717 a failing report prints one reason line instead of nothing" {
    mkdir -p "$S/bin"
    real=$(command -v python3)
    printf '#!/bin/sh\ncase "$1 $2" in *upgrade_commit_list.py\\ report) echo "boom: cannot read index" >&2; exit 3;; esac\nexec %s "$@"\n' "$real" > "$S/bin/python3"
    chmod +x "$S/bin/python3"
    export FRAMEWORK_ROOT="$FW_ROOT"
    _t4717_source_upgrade_lib
    _t4692_before="" _t4717_why=""
    _t4717_commit_list_snapshot "$PROJ"
    echo new > "$PROJ/created-t4717.txt"
    echo created-t4717.txt > "$S/wrote"
    PATH="$S/bin:$PATH" run _t4692_emit_commit_list "$PROJ" "$_t4692_before" "$S/wrote" "$_t4717_why"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'Upgrade file list unavailable')" -eq 1 ]
    [[ "$output" == *"exit 3"* && "$output" == *"boom: cannot read index"* ]]
    [[ "$output" != *"Files this upgrade created or changed"* ]]
}

@test "T-4717 a failing snapshot is carried to the summary as the reason" {
    mkdir -p "$S/bin"
    real=$(command -v python3)
    printf '#!/bin/sh\ncase "$1 $2" in *upgrade_commit_list.py\\ snapshot) echo "snap broke" >&2; exit 4;; esac\nexec %s "$@"\n' "$real" > "$S/bin/python3"
    chmod +x "$S/bin/python3"
    export FRAMEWORK_ROOT="$FW_ROOT"
    _t4717_source_upgrade_lib
    _t4692_before="" _t4717_why=""
    PATH="$S/bin:$PATH" _t4717_commit_list_snapshot "$PROJ"
    [ -z "$_t4692_before" ]
    [[ "$_t4717_why" == *"exit 4"*"snap broke"* ]]
    : > "$S/wrote"
    run _t4692_emit_commit_list "$PROJ" "$_t4692_before" "$S/wrote" "$_t4717_why"
    [ "$(printf '%s\n' "$output" | grep -c 'Upgrade file list unavailable')" -eq 1 ]
}

@test "T-4717 journalled paths still dirty but unchanged since before: one line, not silence" {
    echo pre > "$PROJ/predirty-t4717.txt"
    python3 "$FW_ROOT/lib/upgrade_commit_list.py" snapshot "$PROJ" > "$S/before"
    echo predirty-t4717.txt > "$S/wrote"
    run python3 "$FW_ROOT/lib/upgrade_commit_list.py" report "$PROJ" "$S/before" "$S/wrote"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 path(s) this upgrade wrote are still uncommitted"* ]]
    [[ "$output" != *"git add"* ]]
}

# T-4723: dimitri-mint-dev be.15 — a consumer whose root is a home directory
# (~697 k untracked files, multi-GB caches). The snapshot listed every untracked
# file and read each one whole to hash it: MemoryError, no file list.
@test "T-4723 huge untracked tree: snapshot and report stay bounded, list only the journalled paths" {
    local big="$S/big" helper="$FW_ROOT/lib/upgrade_commit_list.py"
    git init -q "$big"
    echo tracked > "$big/tracked.txt"
    git -C "$big" add tracked.txt
    git -C "$big" -c user.email=t@t -c user.name=t commit -qm base
    truncate -s 3G "$big/disk.img"           # sparse: cheap to make, 3 GB to read
    python3 - "$big/cache" <<'PY'
import os, sys
for a in range(60):
    for b in range(10):
        d = os.path.join(sys.argv[1], f"a{a}", f"b{b}")
        os.makedirs(d)
        for f in range(10):
            open(os.path.join(d, f"f{f}"), "w").write(f"{a}{b}{f}\n")
PY
    run bash -c "ulimit -v 1000000; python3 '$helper' snapshot '$big' > '$S/big.before'"
    [ "$status" -eq 0 ]
    # untracked directories collapse: a handful of entries, not 6,000
    [ "$(wc -l < "$S/big.before")" -lt 10 ]
    echo new > "$big/cache/a1/new.txt"
    echo upgrade-edit >> "$big/tracked.txt"
    echo foreign >> "$big/cache/a2/b0/f0"       # changed, not journalled
    printf '%s\n' cache/a1/new.txt tracked.txt > "$S/big.wrote"
    run bash -c "ulimit -v 1000000; python3 '$helper' report '$big' '$S/big.before' '$S/big.wrote'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new       cache/a1/new.txt"* ]]
    [[ "$output" == *"modified  tracked.txt"* ]]
    [ "$(printf '%s\n' "$output" | grep -cE '^    (new|modified|vendored) ')" -eq 2 ]
    [[ "$output" != *"disk.img"* ]]
    [[ "$output" != *"f0"* ]]
}
