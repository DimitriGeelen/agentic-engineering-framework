#!/usr/bin/env bats
# T-2901: `application:` must not be born populated.
#
# 832 measured the shape on their tree at 2.3% (rail 491 §1) and left the remedy
# to us, correctly — per L-559 it belongs at the site of GENERATION, which is
# ours. Measured here: 572/604 (94.7%) of learnings carried the literal string
# "TBD" written by the generator itself, 21 (3.48%) were genuinely hand-written.
#
# A field born populated is worse than an absent one. It makes "nobody filled
# this in" textually identical to "someone considered it and this is the answer",
# and no query separates them afterwards — which is why the field went 94.7% dead
# for the entire life of the file without anything noticing.
#
# NOTE ON SHAPE. These legs run against the LIVE repo rather than a synthetic
# project, because `bin/fw` resolves PROJECT_ROOT from cwd and ignores the env
# var — pointed at a temp dir it starts initialising governance there instead of
# reading it. So the count legs are written as a PROPERTY (the listing agrees
# with the rule, whatever the data currently is) rather than as fixed numbers,
# which keeps them honest as learnings accumulate.
#
# The load-bearing leg is (c): a grep over every generation site. (a) and (b)
# verify today's behaviour; only (c) survives someone re-adding a placeholder at
# a NEW site — which is exactly how this reached four sites when the report that
# started it named two.

load ../test_helper

LEARNINGS="$FRAMEWORK_ROOT/.context/project/learnings.yaml"

# --- (a) the reader agrees with the rule, over live data ---------------------

@test "application: --unfilled listing agrees with the placeholder rule" {
    cd "$FRAMEWORK_ROOT"
    run bin/fw learnings --unfilled
    [ "$status" -eq 0 ]

    # Recompute independently and compare ID sets. If the CLI's notion of
    # "unfilled" ever drifts from the documented rule, this goes red without
    # anyone having to guess a count.
    expected="$(python3 - <<'PY'
import os, re, yaml
PLACEHOLDERS = [re.compile(r'^TBD$', re.I),
                re.compile(r'^\[Review and refine\]$', re.I),
                re.compile(r'^Apply when encountering similar .* issues$', re.I)]
p = os.path.join(os.environ['FRAMEWORK_ROOT'], '.context','project','learnings.yaml')
for l in (yaml.safe_load(open(p)) or {}).get('learnings', []):
    v = (l.get('application') or '').strip()
    if not v or any(rx.match(v) for rx in PLACEHOLDERS):
        print(l.get('id','?'))
PY
)"
    n_expected=$(echo "$expected" | grep -c . || true)
    [ "$n_expected" -gt 0 ]

    # every expected id is listed
    while read -r lid; do
        [ -z "$lid" ] && continue
        echo "$output" | grep -qE "^[[:space:]]+${lid}[[:space:]]" || {
            echo "rule says $lid is unfilled; --unfilled did not list it"
            return 1
        }
    done <<< "$expected"

    # and the header count matches
    echo "$output" | grep -q "${n_expected}/"
}

@test "application: a genuinely filled learning is NOT listed as unfilled" {
    cd "$FRAMEWORK_ROOT"
    # IDs that appear ONLY on filled entries. The qualifier is load-bearing:
    # learnings.yaml currently holds 24 DUPLICATE ids (T-2902) — `L-007` is both
    # a TBD row from T-053 and a hand-written row from T-1257. For such an id the
    # listing is genuinely ambiguous and asserting either way would be asserting
    # against corrupt data rather than against this feature.
    filled="$(python3 - <<'PY'
import os, re, yaml, collections
PLACEHOLDERS = [re.compile(r'^TBD$', re.I),
                re.compile(r'^\[Review and refine\]$', re.I),
                re.compile(r'^Apply when encountering similar .* issues$', re.I)]
p = os.path.join(os.environ['FRAMEWORK_ROOT'], '.context','project','learnings.yaml')
ls = (yaml.safe_load(open(p)) or {}).get('learnings', [])
state = collections.defaultdict(set)
for l in ls:
    v = (l.get('application') or '').strip()
    unfilled = (not v) or any(rx.match(v) for rx in PLACEHOLDERS)
    state[l.get('id','?')].add(unfilled)
for lid, s in state.items():
    if s == {False}:          # every entry under this id is filled
        print(lid)
PY
)"
    # there is at least one unambiguously hand-written value, or this proves nothing
    [ -n "$filled" ]

    run bin/fw learnings --unfilled
    while read -r lid; do
        [ -z "$lid" ] && continue
        ! echo "$output" | grep -qE "^[[:space:]]+${lid}[[:space:]]" || {
            echo "$lid has a hand-written application but was listed as unfilled"
            return 1
        }
    done <<< "$filled"
}

# --- (b) birth: the generator emits no such key ------------------------------

@test "application: the learning generator emits no application key" {
    # The awk block in learning.sh is the birth site. Assert on the keys it
    # actually prints rather than on a run, since a run needs a whole project.
    run grep -c 'print "  ' "$FRAMEWORK_ROOT/agents/context/lib/learning.sh"
    [ "$status" -eq 0 ]
    ! grep -q 'print "  application' "$FRAMEWORK_ROOT/agents/context/lib/learning.sh"
}

@test "application: the newest learning on file carries no application key" {
    # Live evidence that the birth path is actually clean, not just the source.
    run python3 -c "
import os, yaml, sys
p = os.path.join(os.environ['FRAMEWORK_ROOT'], '.context','project','learnings.yaml')
ls = (yaml.safe_load(open(p)) or {}).get('learnings', [])
sys.exit(0 if 'application' not in ls[-1] else 1)
"
    [ "$status" -eq 0 ]
}

# --- (c) the leg that survives the next site ---------------------------------

@test "application: NO generation site writes a placeholder value" {
    # 832's report named two sites. There were four. Enumerating beat assuming,
    # and this leg is what holds the enumeration: it scans every shell/python
    # source under our control, not the sites that happened to be known.
    #
    # Excludes .agentic-framework/ (self-vendored copy, refreshed by `fw vendor
    # self`), .claude/worktrees/ (checkouts of other branches) and tests/ (this
    # file names the strings on purpose) — none is an authoring surface.
    cd "$FRAMEWORK_ROOT"
    run bash -c '
        grep -rn "application: *\"\?\(TBD\|\[Review and refine\]\|Apply when encountering similar\)" \
             --include="*.sh" --include="*.py" . 2>/dev/null \
        | grep -v "^\./\.git" \
        | grep -v "^\./\.agentic-framework/" \
        | grep -v "^\./\.claude/worktrees/" \
        | grep -v "^\./tests/"
    '
    [ -z "$output" ]
}

# --- (d) evidence leg (c) can go red ----------------------------------------

@test "application: leg (c)'s grep DOES fire on a planted placeholder" {
    # Without this, leg (c) passing is indistinguishable from its grep being
    # broken — the same false-green class this whole task is about.
    planted="$(mktemp -d)/planted.sh"
    printf 'echo "  application: TBD"\n' > "$planted"
    run bash -c "grep -rn 'application: *\"\?\(TBD\|\[Review and refine\]\)' '$planted'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    rm -rf "$(dirname "$planted")"
}
