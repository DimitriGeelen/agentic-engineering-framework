#!/usr/bin/env bats
# T-3049 — a card's `location:` is not always a filesystem path.
#
# Two checks ask "is this card's file still there" and both joined a URL onto
# PROJECT_ROOT, producing $PROJECT_ROOT/https://host/path, which never exists:
#   agents/fabric/lib/drift.sh:59-64   (the `fw fabric drift` CLI)
#   agents/audit/audit.sh:~1664        (the daily orphan count)
# A hosted service has no file to be missing, so the check declines the question
# instead of answering no.
#
# Zero cards in THIS repo carry a URL location, which is exactly why it survived:
# the framework repo is where the check runs daily and the one place it cannot
# fire. Consumers registering saas-account cards saw it permanently.
#
# Both sites are tested, because fixing one leaves the CLI and the audit
# reporting different orphan counts for one corpus.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
DRIFT="$FRAMEWORK_ROOT/agents/fabric/lib/drift.sh"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

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
    printf 'id: %s\nname: "%s"\ntype: script\nlocation: %s\n' "$1" "$2" "$3" \
        > "$P/.fabric/components/$1.yaml"
}

# Run the CLI's orphan loop against the fixture corpus.
run_drift() {  # run_drift <drift.sh path>
    # Drives the real do_drift. ensure_fabric_dirs is stubbed (it belongs to the
    # agent's own bootstrap, not to the logic under test) and no
    # watch-patterns.yaml exists, so section 1 is skipped and section 2 — the
    # orphan loop — is what runs.
    bash -c '
        PROJECT_ROOT="'"$P"'"
        FABRIC_DIR="'"$P"'/.fabric"
        COMPONENTS_DIR="'"$P"'/.fabric/components"
        CYAN=""; NC=""; GREEN=""; YELLOW=""; RED=""; BOLD=""
        ensure_fabric_dirs() { :; }
        source "'"$1"'"
        do_drift 2>&1
    '
}

# Run the audit's orphan counter — the real embedded python, extracted verbatim
# so a divergence between this test and the shipped code cannot hide.
run_audit_count() {  # run_audit_count <audit.sh path>
    python3 - "$P" "$1" <<'PY'
import sys, re, subprocess
proj, audit_path = sys.argv[1], sys.argv[2]
src = open(audit_path).read()
# Pull the orphan-count python block out of the shell heredoc-ish -c string.
m = re.search(r'drift_result=\$\(python3 -c "\n(.*?)\n" 2>&1\)', src, re.S)
assert m, "orphan-count python block not found — did audit.sh change shape?"
body = m.group(1).replace('\\"', '"').replace('\\$', '$')
# The block sets PROJECT_ROOT itself from a shell interpolation, so substitute
# there rather than prepending — a prepended assignment is overwritten and the
# whole harness then runs against the real repo, silently.
assert "'$PROJECT_ROOT'" in body, "PROJECT_ROOT interpolation not found"
prog = body.replace("'$PROJECT_ROOT'", repr(proj))
r = subprocess.run([sys.executable, "-c", prog], capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip())
PY
}

# =============================================================================
# A1/A2 — a URL location is not a missing file, at BOTH sites
# =============================================================================

@test "A1 — drift.sh does not flag an https:// location" {
    card saas-billing "Billing SaaS" "https://billing.example.com/account"
    run run_drift "$DRIFT"
    [[ "$output" != *"file missing"* ]]
}

@test "A2 — the audit orphan count does not count an https:// location" {
    card saas-billing "Billing SaaS" "https://billing.example.com/account"
    run run_audit_count "$AUDIT"
    [ "$output" = "1 0" ]     # 1 registered location, 0 orphaned
}

@test "A1 — http:// and other schemes too, not just https" {
    card a "Plain HTTP" "http://internal.example/x"
    card b "Some service" "ssh://host/repo.git"
    run run_drift "$DRIFT"
    [[ "$output" != *"file missing"* ]]
}

# =============================================================================
# A3 — nothing else is loosened
# =============================================================================

@test "A3 — a genuinely deleted repo-relative file still flags" {
    # The whole point of the check. If this goes quiet the fix is a regression
    # dressed as a bugfix.
    card gone "Deleted thing" "lib/no-such-file.sh"
    run run_drift "$DRIFT"
    [[ "$output" == *"file missing"* ]]
}

@test "A3 — the audit still counts a genuinely deleted file" {
    card gone "Deleted thing" "lib/no-such-file.sh"
    run run_audit_count "$AUDIT"
    [ "$output" = "1 1" ]
}

@test "A3 — an existing repo-relative file is still clean" {
    mkdir -p "$P/lib"
    printf 'x\n' > "$P/lib/real.sh"
    card real "Real thing" "lib/real.sh"
    run run_drift "$DRIFT"
    [[ "$output" != *"file missing"* ]]
}

@test "A3 — a malformed single-slash http:/ is still treated as a path" {
    # The skip requires a real :// separator. A typo'd location is a broken path,
    # not an external referent, and must keep flagging — otherwise the fix
    # silences exactly the mistakes it should surface.
    card typo "Typo" "http:/internal.example/x"
    run run_drift "$DRIFT"
    [[ "$output" == *"file missing"* ]]
}

@test "A3 — an absolute path still resolves unjoined (T-1673 cross-repo cards)" {
    mkdir -p "$TMP/other"
    printf 'x\n' > "$TMP/other/thing.sh"
    card cross "Cross repo" "$TMP/other/thing.sh"
    run run_drift "$DRIFT"
    [[ "$output" != *"file missing"* ]]
}

# =============================================================================
# A4 — mutation
# =============================================================================

@test "A4 — mutation: removing the drift.sh skip flags the URL again" {
    card saas-billing "Billing SaaS" "https://billing.example.com/account"
    sed 's#\[a-zA-Z\]\*://\*) continue ;;#[a-zA-Z]*://*) : ;;#' "$DRIFT" > "$TMP/m.sh"
    if cmp -s "$TMP/m.sh" "$DRIFT"; then false; fi          # the substitution must have landed
    run run_drift "$TMP/m.sh"
    [[ "$output" == *"file missing"* ]]
}

@test "A4 — positive control: the mutant still passes a clean path" {
    # Required by L-616. A mutant that failed to source would print nothing and
    # also not say "file missing" — indistinguishable from a working skip. This
    # proves the mutant runs and still does the part the mutation did not touch.
    mkdir -p "$P/lib"
    printf 'x\n' > "$P/lib/real.sh"
    card real "Real thing" "lib/real.sh"
    sed 's#\[a-zA-Z\]\*://\*) continue ;;#[a-zA-Z]*://*) : ;;#' "$DRIFT" > "$TMP/m.sh"
    run run_drift "$TMP/m.sh"
    [[ "$output" == *"Orphaned cards"* ]]
    [[ "$output" != *"file missing"* ]]
}

@test "A4 — mutation: removing the audit skip counts the URL again" {
    card saas-billing "Billing SaaS" "https://billing.example.com/account"
    sed "s#if re.match(r'^\[a-zA-Z\]\[a-zA-Z0-9+.-\]\*://', loc):#if False:#" \
        "$AUDIT" > "$TMP/ma.sh"
    if cmp -s "$TMP/ma.sh" "$AUDIT"; then false; fi
    run run_audit_count "$TMP/ma.sh"
    [ "$output" = "1 1" ]
}
