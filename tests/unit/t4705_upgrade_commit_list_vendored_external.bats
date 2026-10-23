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
