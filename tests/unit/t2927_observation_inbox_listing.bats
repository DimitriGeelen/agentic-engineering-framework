#!/usr/bin/env bats
# T-2927 — the handover's observation-inbox section listed 1 of 112 pending
# observations, and said nothing about the other 111.
#
# Both sites in agents/handover/handover.sh split the inbox with
#
#     re.split(r'\n  - ', content)
#
# the 2-space list indent that patterns.yaml uses. inbox.yaml puts its entries
# at column 0. T-2514 named that exact mismatch and repaired it in audit.sh;
# these two sites were never swept — which is L-533 ("a sibling sweep with no
# enumerating guard cannot distinguish 'converted the ones we found' from
# 'converted all of them'") landing a second time, on a different idiom, after
# the learning that describes it was already written down.
#
# Reported by 832 (DM rail 545) from their vendored copy. Two things differ in
# ours and both make it worse:
#   - the listing emitted 1 entry, not 0. Zero could read as "nothing pending";
#     a single well-formed row under a "112 pending" heading reads as a section
#     that worked.
#   - the URGENT_OBS site is not latent here. It returned 1 against a true count
#     of 3, so the "run fw note triage BEFORE starting new work" escalation was
#     firing on a third of the evidence.
#
# The fix parses the YAML instead of guessing its indentation, and adds the
# mismatch line 832 argued for in their §2 — which is the more durable half.
# A wrong regex is one bug; a listing block that can emit nothing under a
# non-zero count without saying so is the reason nobody noticed for months.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HANDOVER="$FRAMEWORK_ROOT/agents/handover/handover.sh"
    FIXTURE="$BATS_TEST_TMPDIR/inbox.yaml"

    # Column-0 entries, exactly as .context/inbox.yaml writes them.
    cat > "$FIXTURE" <<'YAML'
observations:
- id: OBS-001
  text: first pending observation
  status: pending
- id: OBS-002
  text: second pending observation
  status: pending
  urgent: true
- id: OBS-003
  text: a resolved one that must not be listed
  status: resolved
- id: OBS-004
  text: third pending observation
  status: pending
YAML
}

# Runs the SHIPPED listing block — the bytes between the heredoc markers in
# handover.sh — rather than a re-typed copy. L-533's second compounding cause
# was a regression test that re-implemented the writer's logic locally and so
# could only ever check what its author already knew about; it stayed green
# through eleven weeks of corruption. If someone edits the block in
# handover.sh, this executes the edit.
_run_shipped_listing_block() {
    local inbox="$1" claimed="$2"
    local block
    block=$(awk '/# List pending observation summaries\./,0' "$HANDOVER" \
            | awk "/python3 << 'PYEOF'/{flag=1;next} /^PYEOF\$/{flag=0} flag")
    [ -n "$block" ] || { echo "could not extract the listing block from handover.sh" >&2; return 1; }
    INBOX_FILE="$inbox" PENDING_OBS="$claimed" python3 -c "$block"
}

# ── The defect, measured before the repair ───────────────────────────────────

@test "t2927: the OLD split lists 1 of 112 against the real inbox" {
    # Anti-vacuity. Reconstructs the pre-fix extraction and requires it to lose
    # almost everything against the live inbox, so the fixed version below is
    # demonstrably fixing something. Skips loudly rather than passing if the
    # real inbox is not available — a silent skip would read as "reproduced".
    local real="$FRAMEWORK_ROOT/.context/inbox.yaml"
    [ -f "$real" ] || skip "no live inbox to reproduce against — defect NOT reproduced"

    run python3 -c "
import re, sys
c = open('$real').read()
blocks = re.split(r'\n  - ', c)
listed = 0
for b in blocks[1:]:
    if 'status: pending' not in b:
        continue
    if re.search(r'id: (OBS-\d+)', b) and re.search(r'text: \"(.*?)\"', b):
        listed += 1
print('%d %d' % (listed, c.count('status: pending')))
"
    [ "$status" -eq 0 ]
    local listed claimed
    listed=$(echo "$output" | awk '{print $1}')
    claimed=$(echo "$output" | awk '{print $2}')
    [ "$claimed" -gt 50 ]          # a meaningful denominator, not an empty inbox
    [ "$listed" -lt "$claimed" ]   # ...and the old form loses most of it
}

# ── The repair ───────────────────────────────────────────────────────────────

@test "t2927: every pending observation is listed, resolved ones are not" {
    run _run_shipped_listing_block "$FIXTURE" 3
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    [[ "$output" == *"OBS-001"* ]]
    [[ "$output" == *"OBS-002"* ]]
    [[ "$output" == *"OBS-004"* ]]
    [[ "$output" != *"OBS-003"* ]]   # resolved
}

@test "t2927: urgent entries carry the [URGENT] prefix" {
    run _run_shipped_listing_block "$FIXTURE" 3
    [[ "$output" == *"[URGENT] OBS-002"* ]]
    [[ "$output" != *"[URGENT] OBS-001"* ]]
}

@test "t2927: unquoted text is listed — the old form required quotes and dropped the rest" {
    # The old extraction matched `text: "(.*?)"`, so an entry whose text was not
    # double-quoted was skipped even when the split happened to find its block.
    # None of the fixture's entries are quoted; all three must appear.
    run _run_shipped_listing_block "$FIXTURE" 3
    [[ "$output" == *"first pending observation"* ]]
}

# ── The mismatch check: the half that keeps this visible next time ───────────

@test "t2927: listing fewer than the claimed count SAYS so" {
    # Claim 10 pending against a fixture holding 3. The block must not render a
    # tidy 3-item list under a "10 pending" heading — the count and the list
    # disagreeing is itself the finding, and nothing else in the handover
    # reports it.
    run _run_shipped_listing_block "$FIXTURE" 10
    [ "$status" -eq 0 ]
    [[ "$output" == *"Listed 3 of 10 pending"* ]] || {
        echo "no mismatch line — a short list still reads as complete" >&2
        echo "$output" >&2
        return 1
    }
}

@test "t2927: no mismatch line when the list is complete" {
    # The counterpart. A warning that fires on every handover is a warning
    # nobody reads.
    run _run_shipped_listing_block "$FIXTURE" 3
    [[ "$output" != *"Listed 3 of 3"* ]]
}

@test "t2927: an unparseable inbox reports itself instead of rendering empty" {
    echo "observations: [this is: not: valid: yaml" > "$BATS_TEST_TMPDIR/broken.yaml"
    run _run_shipped_listing_block "$BATS_TEST_TMPDIR/broken.yaml" 7
    [ "$status" -eq 0 ]
    [[ "$output" == *"Could not read the observation inbox"* ]] || {
        echo "parse failure rendered as an empty section — the T-2926 swallow shape" >&2
        return 1
    }
}

# ── The enumerating guard (L-533): no N+1th site ─────────────────────────────

@test "t2927: no source file splits an observation/inbox read on the 2-space indent" {
    # Shape-derived, no allowlist. L-533's prescription: when you fix N
    # instances of a class in one file, ask what would fail if there were an
    # N+1th. A guard that names the two sites we happen to know about answers
    # nothing about the third.
    #
    # Judged per occurrence: the split idiom is only wrong when the code around
    # it is reading observations. lib/harvest.sh uses the same idiom correctly
    # against patterns.yaml, which genuinely is 2-space indented (pinned by the
    # next leg), so a blanket ban on the idiom would be a false positive that
    # gets suppressed and then ignored.
    cd "$FRAMEWORK_ROOT"
    local violations=""
    local f
    while IFS= read -r f; do
        # Strip whole-line comments FIRST. agents/audit/audit.sh carries this
        # exact pattern inside a comment that explains the T-2514 fix — a
        # detector that flags its own documentation is a detector nobody keeps.
        # (Same mention-vs-instance trap that made T-2926's leg 5 red on its
        # first run, and that 832 flagged for anyone grepping without reading.)
        local hits
        hits=$(grep -nE "re\.split\(r'\\\\n  - '" "$f" 2>/dev/null \
               | grep -vE '^[0-9]+:[[:space:]]*#' || true)
        [ -n "$hits" ] || continue

        local ln
        while IFS= read -r ln; do
            local num ctx
            num=${ln%%:*}
            # Window around the occurrence: what file is this block reading?
            ctx=$(awk -v a="$((num-20))" -v b="$((num+10))" 'NR>=a && NR<=b' "$f")
            if echo "$ctx" | grep -qiE 'inbox|observation'; then
                violations="${violations}${f}:${num}"$'\n'
            fi
        done <<< "$hits"
    done < <(find agents lib bin web -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null)

    [ -z "$violations" ] || {
        echo "observation/inbox read splitting on the 2-space indent (inbox.yaml is column-0):" >&2
        echo "$violations" >&2
        return 1
    }
}

@test "t2927: the enumerating guard BITES — it flags the pre-fix bytes from git" {
    # A guard that has never gone red is indistinguishable from a guard that
    # cannot go red. Runs the same predicate over the last committed version of
    # handover.sh, where both defective sites are still present, and requires it
    # to find exactly those two — no more (the audit.sh comment must stay
    # unflagged) and no fewer.
    cd "$FRAMEWORK_ROOT"
    local scratch="$BATS_TEST_TMPDIR/prefix/agents/handover"
    mkdir -p "$scratch"
    git show HEAD:agents/handover/handover.sh > "$scratch/handover.sh" 2>/dev/null || \
        skip "pre-fix bytes not retrievable from git — guard NOT proven to bite"

    local f="$scratch/handover.sh" found=0 hits ln num ctx
    hits=$(grep -nE "re\.split\(r'\\\\n  - '" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' || true)
    while IFS= read -r ln; do
        [ -n "$ln" ] || continue
        num=${ln%%:*}
        ctx=$(awk -v a="$((num-20))" -v b="$((num+10))" 'NR>=a && NR<=b' "$f")
        echo "$ctx" | grep -qiE 'inbox|observation' && found=$((found+1))
    done <<< "$hits"

    [ "$found" -eq 2 ] || {
        echo "guard found $found violations in the pre-fix bytes, expected 2" >&2
        echo "if this is 0 the guard is vacuous; if >2 it is over-matching" >&2
        return 1
    }
}

@test "t2927: the guard does NOT flag the comment that documents the defect" {
    # The mention-vs-instance half, stated as its own leg because it is the
    # half that gets lost. agents/audit/audit.sh quotes the defective pattern
    # verbatim to explain T-2514's fix. Flagging it would make the guard's
    # first real-world verdict a false positive on its own documentation —
    # which is how guards get suppressed and then deleted.
    cd "$FRAMEWORK_ROOT"
    run grep -nE "re\.split\(r'\\\\n  - '" agents/audit/audit.sh
    [ "$status" -eq 0 ] || skip "audit.sh no longer carries the explanatory comment"
    # Every occurrence there must be comment-only, hence stripped by the guard.
    run bash -c "grep -nE \"re\.split\(r'\\\\\\\\n  - '\" agents/audit/audit.sh | grep -vE '^[0-9]+:[[:space:]]*#'"
    [ "$status" -ne 0 ] || {
        echo "audit.sh now has a NON-comment occurrence — the guard should flag it:" >&2
        echo "$output" >&2
        return 1
    }
}

@test "t2927: lib/harvest.sh's use of the same idiom is verified, not assumed" {
    # 832 checked this and told us not to re-check. Pinned anyway, because the
    # guard above deliberately lets this site through: if patterns.yaml ever
    # moves to column 0, harvest.sh breaks silently and the guard stays green.
    cd "$FRAMEWORK_ROOT"
    grep -q "re.split(r'\\\\n  - '" lib/harvest.sh || skip "harvest.sh no longer uses the idiom"
    [ -f .context/project/patterns.yaml ] || skip "no patterns.yaml to verify against"
    run grep -qE '^  - id:' .context/project/patterns.yaml
    [ "$status" -eq 0 ] || {
        echo "patterns.yaml is no longer 2-space indented — harvest.sh's split is now wrong" >&2
        return 1
    }
}

@test "t2927: handover.sh's own two sites are clean" {
    # The instances this task repaired. Redundant with the enumerating guard by
    # design — that guard is general and this one names the regression.
    cd "$FRAMEWORK_ROOT"
    run bash -c "grep -nE \"re\.split\(r'\\\\\\\\n  - '\" agents/handover/handover.sh | grep -vE '^[0-9]+:[[:space:]]*#'"
    [ "$status" -ne 0 ] || {
        echo "handover.sh still splits on the 2-space indent:" >&2
        echo "$output" >&2
        return 1
    }
}

@test "t2927: the urgent count comes from parsed YAML, not a text split" {
    cd "$FRAMEWORK_ROOT"
    # The site must read the parsed structure. Anchored on the semantic check
    # rather than on a line number, which moves.
    run grep -A12 'URGENT_OBS=\$(VALIDATE_FILE=' agents/handover/handover.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"yaml.safe_load"* ]]
    [[ "$output" == *"urgent"* ]]
}
