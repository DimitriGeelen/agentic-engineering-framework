#!/usr/bin/env bats
# T-4705: the T-4692/T-4697 "Files this upgrade created or changed" list and its
# single `git add` line must print for a VENDORED consumer upgraded from an
# EXTERNAL framework clone, run from a cwd outside the consumer.
# Origin: dimitri-mint-dev be.9 report (sidecar 3294edcf) — no list, no git add line.
# t4692_upgrade_commit_list.bats covers an unvendored consumer upgraded from inside it.

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
