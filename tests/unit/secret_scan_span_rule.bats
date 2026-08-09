#!/usr/bin/env bats
# T-2898: the ANNOUNCED pair must match at NON-OVERLAPPING SPANS.
#
# T-2897 wrote the rule down — "a pair that one word can complete is not a
# pair" — and then satisfied it by curating the two word lists by hand. Hand
# curation does not survive the next word. `pass` went into the noun list
# alongside `password` and `passwd` in the qualifier list, `pass` is a substring
# of both, and three config filenames classified as key material.
#
# So the load-bearing test here is the GENERATIVE one. A test pinned to the
# three broken filenames would pass against a fix that special-cased those three
# strings, and would say nothing about the seventh word someone adds next year.
# Leg (c) enumerates both lists at run time, so a future edit is caught by
# construction.
#
# And leg (d) exists because leg (c) has a way of passing for the wrong reason:
# if someone "tidies" the overlap out of the lists, no single word can complete
# a pair regardless of whether the span rule works at all. The overlap is
# deliberate. This asserts it is still there.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    cd "$TEST_TEMP_DIR"
    git init -q .
    git config user.email t@t; git config user.name t
    source "$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
}

teardown() {
    cd /
    rm -rf "$TEST_TEMP_DIR"
    unset PROJECT_ROOT
}

# --- (a) the three that were measured wrong --------------------------------

@test "span-rule: 'password'/'passwd' no longer complete the pair alone (T-2898)" {
    # Config data, not prose — the extension filter cannot save these, which is
    # why this instance was worse than the .md/.py cases it was hiding.
    for n in passwd-rotation.yaml password-reset.yaml password-policy.json; do
        run _secret_name_classify "$n"
        [ "$status" -eq 0 ]
        [ -z "$output" ]
    done
}

# --- (b) and what must still fire ------------------------------------------

@test "span-rule: genuinely separate words at disjoint spans still pair" {
    run _secret_name_classify "private-key-store.dat"
    [ "$output" = "ANNOUNCED" ]

    run _secret_name_classify "auth-token.json"
    [ "$output" = "ANNOUNCED" ]

    # qualifier and noun in either order, and adjacent with no separator
    run _secret_name_classify "token-signing.dat"
    [ "$output" = "ANNOUNCED" ]
    run _secret_name_classify "authcert.dat"
    [ "$output" = "ANNOUNCED" ]
}

@test "span-rule: DEFINITIVE classes are untouched by the span change" {
    run _secret_name_classify ".fw-secret-key"
    [ "$output" = "DEFINITIVE" ]
    run _secret_name_classify "deploy.pem"
    [ "$output" = "DEFINITIVE" ]
    run _secret_name_classify "credentials.json"
    [ "$output" = "DEFINITIVE" ]
}

# --- (c) the generative leg: this is the one that survives the next edit ----

@test "span-rule: NO single word from either list classifies alone (generative)" {
    local w out
    for w in $_SECRET_NAME_SECRECY_WORDS $_SECRET_NAME_NOUN_WORDS; do
        out="$(_secret_name_classify "$w")"
        [ -z "$out" ] || {
            echo "bare word '$w' classified as '$out' — a pair one word can complete"
            return 1
        }
        # and the same word doubled, which is still one kind of word
        out="$(_secret_name_classify "${w}-${w}.dat")"
        [ -z "$out" ] || {
            echo "repeated word '$w' classified as '$out'"
            return 1
        }
    done
}

@test "span-rule: no word of one list completes a pair with a word CONTAINING it" {
    # The actual defect shape: noun `pass` inside qualifier `password`. Probe
    # every containment relationship that exists between the two lists rather
    # than the one instance that was found.
    local q n out
    for q in $_SECRET_NAME_SECRECY_WORDS; do
        for n in $_SECRET_NAME_NOUN_WORDS; do
            case "$q" in
                *"$n"*)
                    out="$(_secret_name_classify "${q}-config.yaml")"
                    [ -z "$out" ] || {
                        echo "noun '$n' inside qualifier '$q' still completes the pair (got '$out')"
                        return 1
                    }
                    ;;
            esac
            case "$n" in
                *"$q"*)
                    out="$(_secret_name_classify "${n}-config.yaml")"
                    [ -z "$out" ] || {
                        echo "qualifier '$q' inside noun '$n' still completes the pair (got '$out')"
                        return 1
                    }
                    ;;
            esac
        done
    done
}

# --- (d) the overlap is deliberate; without it (c) proves nothing ----------

@test "span-rule: the two lists STILL OVERLAP by containment (guards leg c)" {
    # If someone set-differences the lists, legs (c) and the containment leg
    # above both pass trivially and stop testing the span rule. The overlap is
    # what makes them meaningful. `password` and `passwd` genuinely belong in
    # the qualifier list; `pass` genuinely belongs in the noun list.
    local q n found=0
    for q in $_SECRET_NAME_SECRECY_WORDS; do
        for n in $_SECRET_NAME_NOUN_WORDS; do
            case "$q" in *"$n"*) found=1 ;; esac
            case "$n" in *"$q"*) found=1 ;; esac
        done
    done
    [ "$found" -eq 1 ]
}

# --- (e) evidence the legs can go red --------------------------------------

@test "span-rule: the pre-fix predicate DOES fire on all three (legs are not vacuous)" {
    # Every "does not classify" assertion above is worth nothing unless the
    # thing it replaced would have classified. This is the T-2897 logic,
    # verbatim: two independent matches over the whole string, no span
    # awareness. If this ever stops firing, the tests above have stopped
    # discriminating and are passing for some other reason.
    prefix_classify() {
        echo "$1" | grep -qE "$(echo "$_SECRET_NAME_SECRECY_WORDS" | tr ' ' '|')" \
        && echo "$1" | grep -qE "$(echo "$_SECRET_NAME_NOUN_WORDS" | tr ' ' '|')"
    }
    for n in passwd-rotation.yaml password-reset.yaml password-policy.json; do
        run prefix_classify "$n"
        [ "$status" -eq 0 ]
    done
}

# --- and the live tree, with no exemptions ---------------------------------

@test "span-rule: this repo is still clean with an empty allowlist" {
    cd "$FRAMEWORK_ROOT"
    PROJECT_ROOT="$FRAMEWORK_ROOT" run bash "$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh" scan-names
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
