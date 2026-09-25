#!/usr/bin/env bats
# T-3457 — the delegation classifier's act-in-the-world vocabulary covered only
# OUTBOUND-IRREVERSIBLE acts (publish, deploy, release, push, pay), and missed a
# second family that is just as undelegable: acts requiring the operator's own
# machine or their own credentials.
#
# Measured origin (T-3456): `[RUBBER-STAMP] pi /login (Anthropic Pro)` classified
# `deterministic -> REVIEWER` on the strength of the author's prefix. Converted,
# the T-1985 auto-tick rail could tick it satisfied when nobody had logged in —
# a false green on the operator's own account, produced by a scanner that cannot
# observe a login at all. 3 of 16 convertible criteria corpus-wide were this shape.
#
# The rule the vocabulary now encodes: this class is not "irreversible", it is
# **the agent cannot perform it and a static scan cannot verify it happened**.
#
# Both directions are pinned, and the act-in-the-world legs are additionally run
# against the PRE-FIX module read from git — without that control they would pass
# just as happily against the broken vocabulary.

load ../test_helper

PRE_REF="fe13f13a9"   # the commit before this fix; pinned, not HEAD~1

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    git -C "$FRAMEWORK_ROOT" show "$PRE_REF:lib/delegation.py" > "$TEST_TEMP_DIR/pre.py"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Classify one criterion body against a given module copy, printing its class.
# The body travels through argv, never interpolated into python source.
# $1 = module path, $2 = criterion body, $3 = title (default a [REVIEW] probe).
#
# The title matters: _deterministic_reason takes either a
# [RUBBER-STAMP]/[REVIEWER] prefix or a parsed **Expected:** clause. The
# no-false-positive tests below deliberately use the [RUBBER-STAMP] prefix --
# the SAME shape as the T-1701 criteria that caused this task -- so the body's
# vocabulary is the only variable between "stays deterministic" and "becomes
# act-in-the-world". A flat untitled body classifies `unclassified` and would
# have tested nothing; the first draft of this file did exactly that and four
# assertions failed for a reason that had nothing to do with the code.
_classify() {
    run python3 - "$1" "$2" "${3:-[REVIEW] probe}" <<'PYEOF'
import sys, importlib.util
mod_path, body, title = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("d", mod_path)
m = importlib.util.module_from_spec(spec); sys.modules["d"] = m
spec.loader.exec_module(m)
crit = m.Criterion(index=1, subhead="Human", title=title,
                   ticked=False, start=0, end=1, lines=[body])
print(m.classify(crit, render_surface=False, workflow_type="build").cls)
PYEOF
}

LIVE() { echo "$FRAMEWORK_ROOT/lib/delegation.py"; }

# ── The family that was missed ────────────────────────────────────────────

@test "an interactive login is act-in-the-world" {
    _classify "$(LIVE)" "Run pi /login (Anthropic Pro) and confirm the session is authorised."
    [ "$status" -eq 0 ]
    [ "$output" = "act-in-the-world" ]
}

@test "CONTROL: the pre-fix vocabulary called that same login deterministic" {
    # Without this leg the test above proves nothing about the fix.
    _classify "$TEST_TEMP_DIR/pre.py" "Run pi /login (Anthropic Pro) and confirm the session is authorised."
    [ "$status" -eq 0 ]
    [ "$output" != "act-in-the-world" ]
}

@test "installing software on the operator's host is act-in-the-world" {
    _classify "$(LIVE)" "Install pi on the host: npm install -g @badlogic/pi-mono"
    [ "$status" -eq 0 ]
    [ "$output" = "act-in-the-world" ]
}

@test "CONTROL: the pre-fix vocabulary did not catch the install" {
    _classify "$TEST_TEMP_DIR/pre.py" "Install pi on the host: npm install -g @badlogic/pi-mono"
    [ "$status" -eq 0 ]
    [ "$output" != "act-in-the-world" ]
}

@test "package-manager installs are caught across managers" {
    local body
    for body in "Run brew install termlink on the mac" \
                "apt-get install jq on the host" \
                "pip install the package into the venv" \
                "cargo install the binary from source"; do
        _classify "$(LIVE)" "$body"
        [ "$status" -eq 0 ]
        [ "$output" = "act-in-the-world" ]
    done
}

@test "credential entry is act-in-the-world" {
    local body
    for body in "Enter your API key at the prompt and confirm it is accepted" \
                "Paste your token into the settings page" \
                "Complete the 2FA challenge" \
                "Add your ssh key to the remote"; do
        _classify "$(LIVE)" "$body"
        [ "$status" -eq 0 ]
        [ "$output" = "act-in-the-world" ]
    done
}

@test "gcloud/aws-style auth login is caught" {
    _classify "$(LIVE)" "Run gcloud auth login and verify the account is active"
    [ "$status" -eq 0 ]
    [ "$output" = "act-in-the-world" ]
}

# ── No false positives: the convertible set must stay convertible ─────────

@test "a genuinely mechanical grep check is still deterministic" {
    _classify "$(LIVE)" "**Steps:** run grep -q PATTERN file. **Expected:** exit 0." "[RUBBER-STAMP] Confirm the pattern is present"
    [ "$status" -eq 0 ]
    [ "$output" = "deterministic" ]
}

@test "an HTTP status check is still deterministic" {
    _classify "$(LIVE)" "**Steps:** curl the endpoint. **Expected:** HTTP 200 and the body contains ok." "[RUBBER-STAMP] Confirm the endpoint answers"
    [ "$status" -eq 0 ]
    [ "$output" = "deterministic" ]
}

@test "the noun 'installed' in a passive report does not trip the install rule" {
    # `\binstall\b` alone would swallow this. The rule requires a verb-or-command
    # shape, so a criterion REPORTING on an install stays mechanical.
    _classify "$(LIVE)" "**Steps:** run bin/fw doctor. **Expected:** it reports the hook is installed." "[RUBBER-STAMP] Confirm doctor sees the hook"
    [ "$status" -eq 0 ]
    [ "$output" = "deterministic" ]
}

@test "the word 'token' in a budget context does not trip the credential rule" {
    # `\btoken\b` alone would swallow every criterion about token budgets.
    _classify "$(LIVE)" "**Steps:** run bin/fw costs. **Expected:** the token count is greater than zero." "[RUBBER-STAMP] Confirm costs reports tokens"
    [ "$status" -eq 0 ]
    [ "$output" = "deterministic" ]
}

@test "the outbound-irreversible family still classifies (nothing was traded away)" {
    local body
    for body in "Publish the release to the registry" \
                "Run git push to origin master" \
                "Deploy to production"; do
        _classify "$(LIVE)" "$body"
        [ "$status" -eq 0 ]
        [ "$output" = "act-in-the-world" ]
    done
}

@test "the reason string names the real test, not just irreversibility" {
    run grep -c 'the agent cannot perform it and no scan can verify it' "$FRAMEWORK_ROOT/lib/delegation.py"
    [ "$output" = "1" ]
}
