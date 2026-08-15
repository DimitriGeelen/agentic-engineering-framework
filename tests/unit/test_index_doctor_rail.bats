#!/usr/bin/env bats
# The doctor/audit rail over the vector index — T-3013 (T-3005 slice 4).
#
# Every verdict here is asserted against a fixture that produces a DIFFERENT
# verdict from the same code. A check verified only in the state it normally
# reports is not verified — this arc has already shipped four instruments that
# were green because they could not be anything else (T-3004), and two more
# caught mid-build in T-3011.
#
# So: stale is proven against fresh, fresh against stale, unknown against both.

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PROJECT_ROOT
    cd "$PROJECT_ROOT"
}

# --------------------------------------------------------------------------
# The three freshness verdicts, each proven against its opposite
#
# Driven through lib/index-health.sh rather than `fw doctor`. An earlier version
# of this file shelled out to doctor five times and took over ten minutes — a
# test that slow is one nobody runs twice, which is the same "instrument that
# never fires" problem this arc exists to fix, one level up. One end-to-end
# doctor smoke test remains below to prove the seam is actually wired in.
# --------------------------------------------------------------------------

verdict() {
    bash -c '
        set -uo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        source "'"$PROJECT_ROOT"'/lib/index-health.sh"
        PROJECT_ROOT="'"$PROJECT_ROOT"'" index_freshness_verdict "$@"
    ' _ "$@"
}

@test "the real index is stale at the default threshold" {
    run verdict 7
    [[ "$output" == WARN\|* ]]
    [[ "$output" == *"days old"* ]]
}

@test "the same index passes when the threshold exceeds its age" {
    # The discriminating half. Were this also WARN, the line would be reporting
    # a constant rather than a comparison.
    run verdict 99999
    [[ "$output" == OK\|* ]]
}

@test "the same index warns again at a zero threshold" {
    run verdict 0
    [[ "$output" == WARN\|* ]]
}

@test "no index at all warns as unknown, never as age zero" {
    # Absence must not render as a number. A 0.0 reads as "built this instant",
    # which is the confusion the whole slice exists to remove.
    run bash -c '
        set -uo pipefail
        source "'"$PROJECT_ROOT"'/lib/config.sh"
        source "'"$PROJECT_ROOT"'/lib/index-health.sh"
        PROJECT_ROOT="'"$PROJECT_ROOT"'" VECTOR_DB_PATH=/nonexistent/t3013/no.db index_freshness_verdict 7
    '
    [[ "$output" == WARN\|* ]]
    [[ "$output" == *"unknown"* ]]
}

@test "doctor is actually wired to the seam and still completes" {
    # Regression guard for the bug this slice hit while being written: the first
    # version killed doctor at line 31 of 113 via an unbound variable, exiting
    # with no error text at all (OBS-255). Length proves the run reached the end;
    # the grep proves the check is present rather than silently dropped.
    run bash -c 'cd "$PROJECT_ROOT" && bin/fw doctor 2>&1 > /tmp/.t3013doc.out; wc -l < /tmp/.t3013doc.out'
    [ "$output" -gt 60 ]
    run grep -c "vector index" /tmp/.t3013doc.out
    [ "$output" -ge 1 ]
}

# --------------------------------------------------------------------------
# The freshness line must not need the embedder
# --------------------------------------------------------------------------

@test "the freshness check makes no embedding call" {
    # Doctor is on the hot path, and a health check that needs a live embedder
    # goes quiet exactly when the subsystem it watches is down. Proven by making
    # any client construction fatal, then asking for the answer anyway.
    run python3 -c '
import sys
sys.path.insert(0, "'"$PROJECT_ROOT"'")
import ollama
def boom(*a, **k):
    raise AssertionError("index_freshness constructed an Ollama client")
ollama.Client = boom
from web.embeddings import index_freshness
f = index_freshness()
assert f["source"] in ("manifest", "db_mtime", "unknown"), f
print("NO_EMBED_CALL", f["source"])
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"NO_EMBED_CALL"* ]]
}

# --------------------------------------------------------------------------
# The canary must stay out of the pre-push path
# --------------------------------------------------------------------------

@test "corpus-health does not run under --section structure" {
    # pre-push runs `--section structure` and already exceeds 180s, blocking
    # every push (OBS-253). Two embed round-trips there would also couple every
    # push to Ollama being reachable. Asserted on the section gate itself rather
    # than by running structure, which would cost the 180s this is about.
    run bash -c '
        SECTIONS="structure"
        should_run_section() { [ -z "$SECTIONS" ] && return 0; echo ",$SECTIONS," | grep -q ",$1,"; }
        should_run_section corpus-health && echo RUNS || echo SKIPPED
    '
    [ "$output" = "SKIPPED" ]
}

@test "corpus-health does run when it is the requested section" {
    # The opposite half — otherwise the test above passes for a section name
    # that simply does not exist anywhere.
    run bash -c '
        SECTIONS="corpus-health"
        should_run_section() { [ -z "$SECTIONS" ] && return 0; echo ",$SECTIONS," | grep -q ",$1,"; }
        should_run_section corpus-health && echo RUNS || echo SKIPPED
    '
    [ "$output" = "RUNS" ]
}

@test "the audit file actually declares a corpus-health section" {
    # Guards the guard: both gate tests above use a local copy of
    # should_run_section, so they would pass even if the section were never added.
    run grep -c 'should_run_section "corpus-health"' "$PROJECT_ROOT/agents/audit/audit.sh"
    [ "$output" -ge 1 ]
}

@test "the corpus-health section is not listed in any pre-push section list" {
    run bash -c 'grep -n "section structure" "$PROJECT_ROOT/.git/hooks/pre-push" | grep -c "corpus-health" || true'
    [ "$output" = "0" ]
}
