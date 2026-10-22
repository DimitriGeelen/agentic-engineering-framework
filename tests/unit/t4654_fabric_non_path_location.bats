#!/usr/bin/env bats
# T-4654 — a card's `location:` is a file path only when it looks like one.
#
# T-3049 taught both orphan checks to skip `scheme://` locations. Cards for hosts
# and networks carry other non-path values — an IPv4 address, a CIDR, host:port,
# or descriptive text ("proxmox node pve1") — and both checks still joined those
# onto PROJECT_ROOT and reported a missing file, permanently (ring20 patches
# #19/#20, triage docs/reports/T-4649-ring20-patch-triage.md category 5).
#
# The rule now lives in ONE predicate, agents/fabric/lib/location_kind.py, which
# drift.sh (the `fw fabric drift` CLI) and audit.sh (the daily orphan count) both
# call, so they cannot disagree about one corpus.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
DRIFT="$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
PRED="$FRAMEWORK_ROOT/agents/fabric/lib/location_kind.py"

setup() {
    TMP=$(mktemp -d)
    export TMP
    P="$TMP/proj"
    mkdir -p "$P/.fabric/components"
    git -C "$P" init -q . 2>/dev/null || true
}

teardown() {
    rm -rf "$TMP"
}

card() {  # card <file> <name> <location>
    printf 'id: %s\nname: "%s"\ntype: host\nlocation: "%s"\n' "$1" "$2" "$3" \
        > "$P/.fabric/components/$1.yaml"
}

run_drift() {
    bash -c '
        PROJECT_ROOT="'"$P"'"
        FABRIC_DIR="'"$P"'/.fabric"
        COMPONENTS_DIR="'"$P"'/.fabric/components"
        LIB_DIR="'"$FRAMEWORK_ROOT"'/agents/fabric/lib"
        CYAN=""; NC=""; GREEN=""; YELLOW=""; RED=""; BOLD=""
        ensure_fabric_dirs() { :; }
        source "'"$DRIFT"'"
        do_drift 2>&1
    '
}

# The audit's real embedded python, extracted verbatim (same harness as T-3049).
run_audit_count() {
    python3 - "$P" "$AUDIT" "$FRAMEWORK_ROOT" <<'PY'
import sys, re, subprocess
proj, audit_path, fw = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(audit_path).read()
m = re.search(r'drift_result=\$\(python3 -c "\n(.*?)\n" 2>&1\)', src, re.S)
assert m, "orphan-count python block not found — did audit.sh change shape?"
body = m.group(1).replace('\\"', '"').replace('\\$', '$')
assert "'$PROJECT_ROOT'" in body, "PROJECT_ROOT interpolation not found"
prog = body.replace("'$PROJECT_ROOT'", repr(proj)).replace("'$FRAMEWORK_ROOT'", repr(fw))
r = subprocess.run([sys.executable, "-c", prog], capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip())
PY
}

is_path() { python3 "$PRED" --is-path "$1"; }

# =============================================================================
# P — the predicate, per shape
# =============================================================================

@test "P1 — non-path shapes are not paths" {
    for loc in "https://billing.example.com/x" "ssh://host/repo.git" \
               "192.168.10.5" "192.168.10.0/24" "10.0.0.1:8006" \
               "pve1.lan:8006" "localhost:3000" "proxmox node pve1" \
               "[fe80::1]:22" ""; do
        run is_path "$loc"
        [ "$status" -eq 1 ] || { echo "classified as path: '$loc'"; false; }
    done
}

@test "P2 — path shapes are paths" {
    for loc in "bin/fw" "lib/x.sh" "README.md" "Makefile" "/opt/x/y.py" \
               "./tools/a.py" "agents/fabric/lib/drift.sh" "http:/typo/x" \
               ".context/working/.budget-gate-counter" "v1.2.3/notes.md"; do
        run is_path "$loc"
        [ "$status" -eq 0 ] || { echo "classified as non-path: '$loc'"; false; }
    done
}

# =============================================================================
# D — drift.sh, A — audit.sh: same fixture, same answer
# =============================================================================

@test "D1 — drift.sh does not flag IPv4, CIDR, host:port or descriptive locations" {
    card h1 "Host" "192.168.10.5"
    card n1 "LAN" "192.168.10.0/24"
    card s1 "PVE API" "pve1.lan:8006"
    card d1 "PVE node" "proxmox node pve1"
    run run_drift
    [[ "$output" == *"Orphaned cards"* ]]
    [[ "$output" != *"file missing"* ]]
}

@test "A1 — the audit orphan count skips the same shapes" {
    card h1 "Host" "192.168.10.5"
    card n1 "LAN" "192.168.10.0/24"
    card s1 "PVE API" "pve1.lan:8006"
    card d1 "PVE node" "proxmox node pve1"
    run run_audit_count
    [ "$output" = "4 0" ]
}

@test "D2 — a missing real path still flags in drift.sh beside non-path cards" {
    card n1 "LAN" "192.168.10.0/24"
    card gone "Deleted thing" "lib/no-such-file.sh"
    run run_drift
    orphans=$(awk '/Orphaned cards/{f=1;next} /Stale edges/{f=0} f' <<<"$output")
    [[ "$orphans" == *"→ lib/no-such-file.sh (file missing)"* ]]
    [[ "$orphans" != *"192.168.10.0/24"* ]]
}

@test "A2 — the audit still counts a missing real path beside non-path cards" {
    card n1 "LAN" "192.168.10.0/24"
    card gone "Deleted thing" "lib/no-such-file.sh"
    run run_audit_count
    [ "$output" = "2 1" ]
}

@test "S1 — both sites call the shared predicate and keep no private scheme rule" {
    grep -q "location_kind" "$DRIFT"
    grep -q "location_kind" "$AUDIT"
    ! grep -q '\[a-zA-Z\]\*://\*) continue' "$DRIFT" || false
    ! grep -q "re.match(r'^\[a-zA-Z\]\[a-zA-Z0-9+.-\]\*://', loc)" "$AUDIT" || false
}
