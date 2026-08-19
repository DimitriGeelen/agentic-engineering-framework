#!/usr/bin/env bats
# T-3078 — a Tier 0 approval card must record where it came from, derived.
#
# Before T-3078 a pending card carried hash, preview, risk, timestamp, status —
# and nothing about origin. Watchtower rendered every one of them under the
# literal "Agent blocked — requires your decision". For the cards T-3077's
# governance suite filed against the live queue that subtitle was simply false:
# no agent was blocked, a test was, and one of those cards read "RECURSIVE
# DELETE: Targets root filesystem (/)". The operator opened /approvals, saw it,
# and asked why. The surface had no way to know the answer.
#
# ── The property under test ──────────────────────────────────────────────────
# Provenance is DERIVED, never declared. No caller passes `--is-a-test`, because
# the next test author would not know to. T-3077 is the evidence: that suite did
# not ignore a marker, it never considered that it was filing anything at all.
# So every assertion below drives the REAL hook and reads back what it inferred
# from the process ancestry and the shape of PROJECT_ROOT.
#
# ── Isolation (T-3077, and pointedly so) ─────────────────────────────────────
# A suite about cards leaking onto the operator's queue must not leak cards onto
# the operator's queue. Every test uses a sandbox PROJECT_ROOT under
# $BATS_TEST_TMPDIR, and the last test asserts the live queue was untouched.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_BIN="$FRAMEWORK_ROOT/bin/fw"

# Deliberately not `rm -rf /` — see T-3077. Any Tier 0 pattern is the same path.
DESTRUCTIVE_CMD='git push --force origin master'

setup() {
    SANDBOX="$BATS_TEST_TMPDIR/fw-sandbox"
    mkdir -p "$SANDBOX/.tasks/active" "$SANDBOX/.context/working" "$SANDBOX/.context/approvals"
    printf 'current_task: T-3078\nfocus_session: S-FIXTURE\n' \
        > "$SANDBOX/.context/working/focus.yaml"
    export SANDBOX
}

_run_hook() {
    local payload
    payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$DESTRUCTIVE_CMD")
    run env PROJECT_ROOT="$SANDBOX" "$@" \
        bash -c "printf '%s' '$payload' | '$HOOK_BIN' hook check-tier0"
}

# _card_field DOTTED.PATH — read one value out of the card the hook just filed.
_card_field() {
    python3 - "$SANDBOX" "$1" <<'PY'
import sys, glob, yaml
files = glob.glob(sys.argv[1] + "/.context/approvals/pending-*.yaml")
if not files:
    print("__NO_CARD__"); raise SystemExit(0)
d = yaml.safe_load(open(files[0]))
for part in sys.argv[2].split("."):
    d = (d or {}).get(part)
print("" if d is None else d)
PY
}

# _card_ancestry — the recorded process chain, space-joined and lowercased.
_card_ancestry() {
    python3 - "$SANDBOX" <<'PY'
import sys, glob, yaml
files = glob.glob(sys.argv[1] + "/.context/approvals/pending-*.yaml")
if not files:
    raise SystemExit(0)
d = yaml.safe_load(open(files[0])) or {}
print(" ".join((d.get("origin") or {}).get("ancestry") or []).lower())
PY
}

# ============================================================================
# The card records origin at all
# ============================================================================

@test "T-3078: a filed card carries an origin block" {
    _run_hook
    [ "$status" -eq 2 ]
    [ "$(_card_field origin.kind)" != "__NO_CARD__" ]
    [ -n "$(_card_field origin.kind)" ]
    [ -n "$(_card_field origin.project_root)" ]
    [ -n "$(_card_field origin.ancestry)" ]
}

@test "T-3078: origin records the focus task the session was working" {
    _run_hook
    [ "$status" -eq 2 ]
    [ "$(_card_field origin.task)" = "T-3078" ]
    [ "$(_card_field origin.session)" = "S-FIXTURE" ]
}

@test "T-3078: the pre-T-3078 fields are all still present" {
    # Provenance is an ADDITION. If it ever displaces what the approve path
    # reads, the gate stops working — which is worse than the gate being vague.
    _run_hook
    [ "$status" -eq 2 ]
    [ -n "$(_card_field command_hash)" ]
    [ -n "$(_card_field command_preview)" ]
    [ -n "$(_card_field risk)" ]
    [ "$(_card_field status)" = "pending" ]
    [ "$(_card_field type)" = "tier0" ]
}

# ============================================================================
# kind is DERIVED — the sandbox does not announce itself
# ============================================================================

@test "T-3078: a card filed against a throwaway tree derives kind=test" {
    # Nothing in this test says "I am a test". The tree has no .git and sits
    # under a temp dir; both are facts about the tree, readable by the hook.
    _run_hook
    [ "$status" -eq 2 ]
    [ "$(_card_field origin.kind)" = "test" ]
    [ "$(_card_field origin.sandbox)" = "True" ]
}

@test "T-3078: git init on the sandbox does NOT launder it into a real project" {
    # is_sandbox() checks the temp-dir path as well as `.git`, so a fixture
    # cannot dress itself up as a real tree by running `git init`. The second
    # clause is not redundant with the first, and this test is what makes that
    # non-obvious claim falsifiable — a test that could pass itself off as
    # production is how T-3077's cards reached the operator's live queue.
    git -C "$SANDBOX" init -q .
    _run_hook CLAUDECODE=1
    [ "$status" -eq 2 ]
    [ "$(_card_field origin.kind)" = "test" ]
}

@test "T-3078: the recorded ancestry is a real process chain, not a stub" {
    # Guards the field being present-but-empty, which would render as provenance
    # on the card while carrying nothing. Asserts a plausible chain reaching the
    # hook: `fw` must appear, since that is what invoked it.
    #
    # NOTE on what this suite CANNOT cover. Every hook run from a bats body
    # classifies as `test`, so the `agent` and `human` arms of classify() are
    # unreachable from here — a harness that biases its own result cannot test
    # the branches it biases away. Those arms, and the marker matching, live in
    # tests/unit/test_tier0_origin.py against the pure function.
    #
    # That split is why the module exists. While the logic sat in a shell
    # heredoc, the `bats` marker was being matched against `ps -o comm=`, which
    # reports `bash` for every hop of a bats run — so the marker had never once
    # fired, and `kind=test` was carried entirely by the sandbox check. Nothing
    # was red. Extracting the function is what made the miss visible.
    _run_hook
    [ "$status" -eq 2 ]
    local chain
    chain=$(_card_ancestry)
    [ -n "$chain" ]
    case "$chain" in
        *fw*) : ;;
        *) echo "ancestry does not look like a real chain: $chain" >&2; return 1 ;;
    esac
}

@test "T-3078: sandbox beats the agent signal — a test run is a test run" {
    # An agent running a suite still produces test artefacts, not agent
    # requests. Precedence is deliberate and pinned: this is exactly the T-3077
    # shape, where a real agent session ran a suite that filed real cards.
    _run_hook CLAUDECODE=1
    [ "$status" -eq 2 ]
    [ "$(_card_field origin.kind)" = "test" ]
}

# ============================================================================
# The gate still gates, and this suite does not leak
# ============================================================================

@test "T-3078: provenance does not weaken the block — the command is still refused" {
    _run_hook
    [ "$status" -eq 2 ]
}

@test "T-3078: the live approvals queue is untouched by this suite" {
    _run_hook
    [ "$status" -eq 2 ]

    local hash
    hash=$(printf '%s' "$DESTRUCTIVE_CMD" | tr -s '[:space:]' ' ' \
        | sed 's/^ //; s/ $//' | sha256sum | awk '{print $1}')
    [ -f "$SANDBOX/.context/approvals/pending-${hash:0:12}.yaml" ]
    [ ! -e "$FRAMEWORK_ROOT/.context/approvals/pending-${hash:0:12}.yaml" ]
}
