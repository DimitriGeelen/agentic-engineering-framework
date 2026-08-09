#!/usr/bin/env bash
# agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844).
#
# Origin: T-1828/T-1834 incident — an Azure DevOps PAT was committed to framework
# history at 79e3361d (T-1736 spike). GitHub mirror blocked for 9+ hours.
# The framework had no structural gate against secrets reaching commits.
#
# This module is invoked by the pre-commit hook installed by
# agents/git/lib/hooks.sh:install_hooks. It can also be run standalone:
#
#   secret-scan.sh scan-staged       Scan git staged diff (the hook's mode)
#   secret-scan.sh scan-tree         Scan the entire working tree (audit mode)
#   secret-scan.sh scan-file <path>  Scan a specific file
#
# Configuration:
#   .secret-scan-patterns   TSV catalogue (name<TAB>regex)
#   .secret-scan-allowlist  One regex per line; matching findings suppressed
#
# Optional escalation:
#   If `gitleaks` is on PATH, run it as a second pass and treat any finding
#   as a match. The baseline regex catalogue is the always-on guarantee.

set -u
set -o pipefail

# Resolve the project root in framework / consumer / arbitrary cwd shapes.
_secret_scan_project_root() {
    # If PROJECT_ROOT is set by the caller, trust it.
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && { echo "$PROJECT_ROOT"; return; }
    # Else walk up from cwd looking for a .git or FRAMEWORK.md / .framework.yaml
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] || [ -f "$dir/FRAMEWORK.md" ] || [ -f "$dir/.framework.yaml" ]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

# Resolve the secret-scan config dir: prefer project-local files in the project
# root, fall back to a vendored .agentic-framework/ copy for consumers.
_secret_scan_config_dir() {
    local root="$1"
    if [ -f "$root/.secret-scan-patterns" ]; then
        echo "$root"
        return
    fi
    if [ -f "$root/.agentic-framework/.secret-scan-patterns" ]; then
        echo "$root/.agentic-framework"
        return
    fi
    # No config — return root anyway; the scanner will report "no patterns".
    echo "$root"
}

# Build the allowlist regex (pipe-joined) from the allowlist file.
_secret_scan_build_allowlist() {
    local allow_file="$1"
    [ ! -f "$allow_file" ] && { echo ""; return; }
    # Strip blank lines + comments; pipe-join the rest with '|'.
    local _joined
    _joined=$(grep -v '^[[:space:]]*$' "$allow_file" 2>/dev/null \
              | grep -v '^[[:space:]]*#' \
              | tr '\n' '|' \
              | sed 's/|$//')
    echo "$_joined"
}

# Check whether a given "filepath:linecontent" string matches the allowlist.
_secret_scan_is_allowed() {
    local hit_line="$1" allow_re="$2"
    [ -z "$allow_re" ] && return 1
    echo "$hit_line" | grep -qE -e "$allow_re"
}

# Core scanner: takes a stream of "filepath:linenumber:linecontent" rows on stdin,
# emits hits to stdout. Returns 0 if no hits, 1 if any hit.
_secret_scan_run_patterns() {
    local patterns_file="$1" allow_re="$2"
    # T-2656 (832 T-276 finding 2, sibling of T-2647): a scanner that runs
    # with no pattern catalogue is a silent no-op — scanner present, data
    # absent. Same contract as the missing-scanner case: unmissable warning,
    # fail-open by default, FW_SECRET_SCAN_STRICT=1 opts into blocking.
    if [ ! -f "$patterns_file" ]; then
        {
            echo ""
            echo "WARNING: SECRET SCAN IS RUNNING WITHOUT PATTERNS — catalogue missing:"
            echo "  $patterns_file"
            echo "Every commit is going through WITHOUT secret pattern matching."
            echo "Fix: refresh the vendored framework payload (ships .secret-scan-patterns):"
            echo "  .agentic-framework/bin/fw upgrade   (framework repo: bin/fw vendor self)"
            echo "Strict mode: set FW_SECRET_SCAN_STRICT=1 to make this block commits."
            echo ""
        } >&2
        if [ "${FW_SECRET_SCAN_STRICT:-0}" = "1" ]; then
            echo "ERROR: Commit blocked — FW_SECRET_SCAN_STRICT=1 and patterns catalogue missing." >&2
            return 1
        fi
        return 0
    fi

    local _hits=0
    local _input
    _input=$(cat)
    [ -z "$_input" ] && return 0

    local _name _re
    while IFS=$'\t' read -r _name _re; do
        # Skip comments + blank lines
        case "$_name" in ''|\#*) continue ;; esac
        [ -z "$_re" ] && continue

        # Find lines matching the pattern. `-e` ensures patterns starting with
        # `-` (e.g. `-----BEGIN ...`) aren't interpreted as grep options. We
        # don't pass `-n` because the awk-prepared input already encodes
        # "filepath:diffline:content"; prefixing grep's own line number would
        # break allowlist regexes anchored at `^`.
        local _matches
        _matches=$(echo "$_input" | grep -E -e "$_re" 2>/dev/null || true)
        [ -z "$_matches" ] && continue

        while IFS= read -r _hit; do
            [ -z "$_hit" ] && continue
            if _secret_scan_is_allowed "$_hit" "$allow_re"; then
                continue
            fi
            printf '  [%s] %s\n' "$_name" "$_hit"
            _hits=$((_hits + 1))
        done <<< "$_matches"
    done < "$patterns_file"

    [ "$_hits" -gt 0 ] && return 1
    return 0
}

# Public: scan staged content via `git diff --cached`. This is the pre-commit
# hook's primary mode.
scan_staged() {
    local root cfg patterns allowlist
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    patterns="$cfg/.secret-scan-patterns"
    allowlist="$cfg/.secret-scan-allowlist"

    local allow_re
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"

    # Format: walk the staged diff, prefix each added line with file:line:
    # — this gives the regex run a stable "filepath:linenumber:content" shape.
    local diff_stream
    diff_stream=$(git -C "$root" diff --cached -U0 2>/dev/null | awk '
        /^diff --git/ { in_file=0; next }
        /^\+\+\+ b\// { file=substr($0, 7); in_file=1; next }
        in_file && /^@@/ {
            n=split($0, parts, " ")
            for (i=1; i<=n; i++) {
                if (parts[i] ~ /^\+/) {
                    sub(/^\+/, "", parts[i])
                    split(parts[i], lc, ",")
                    line_no=lc[1]
                }
            }
            next
        }
        in_file && /^\+[^+]/ {
            content=substr($0, 2)
            printf "%s:%d:%s\n", file, line_no, content
            line_no++
        }
        in_file && /^[^+-]/ { line_no++ }
    ')

    local rc=0
    if [ -n "$diff_stream" ]; then
        echo "$diff_stream" | _secret_scan_run_patterns "$patterns" "$allow_re" || rc=1
    fi

    # T-2897 name axis, at the gate rather than only at the audit. scan_tree
    # tells you a key was published; this refuses the commit that publishes it.
    # Newly-added paths only: a rename or a content edit to a file whose name
    # was already accepted is not the event we are gating, and re-flagging it on
    # every touch is how a gate gets bypassed by habit.
    local _added _path _base _lower _class
    _added=$(git -C "$root" diff --cached --name-only --diff-filter=A 2>/dev/null)
    while IFS= read -r _path; do
        [ -z "$_path" ] && continue
        _base="${_path##*/}"
        _lower="$(printf '%s' "$_base" | tr '[:upper:]' '[:lower:]')"
        _class="$(_secret_name_classify "$_lower")"
        [ -z "$_class" ] && continue
        _secret_scan_is_allowed "$_path:0:$_base" "$allow_re" && continue
        printf '  [name:%s] %s\n' "$_class" "$_path"
        rc=1
    done <<< "$_added"

    # Optional escalation: gitleaks (best-effort, never blocks if missing)
    if command -v gitleaks >/dev/null 2>&1; then
        local gl_out
        gl_out=$(gitleaks protect --staged --redact --no-banner 2>&1) || {
            # gitleaks exit 1 = findings. Report and mark rc=1.
            echo "  [gitleaks] $gl_out" | head -10
            rc=1
        }
    fi

    return "$rc"
}

# Public: scan the entire working tree (audit mode). Used by the human-AC
# step to surface pre-existing matches that need allowlisting.
scan_tree() {
    local root cfg patterns allowlist
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    patterns="$cfg/.secret-scan-patterns"
    allowlist="$cfg/.secret-scan-allowlist"

    local allow_re
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"

    # Use git grep per pattern — handles binary skip + path filtering natively,
    # and runs entirely in-process (no per-file fork to `file`).
    [ ! -f "$patterns" ] && { echo "secret-scan: no patterns file ($patterns)" >&2; return 0; }

    local _hits=0
    local _name _re _matches
    while IFS=$'\t' read -r _name _re; do
        case "$_name" in ''|\#*) continue ;; esac
        [ -z "$_re" ] && continue
        # git grep flags: -n line nos, -I skip binary, -E extended regex, --no-color
        # Use -e to handle patterns starting with dashes.
        _matches=$(git -C "$root" grep -nIE --no-color -e "$_re" -- ':!.git' 2>/dev/null || true)
        [ -z "$_matches" ] && continue
        # git grep output: "path:lineno:content" — that's already the format
        # _secret_scan_is_allowed expects.
        while IFS= read -r _hit; do
            [ -z "$_hit" ] && continue
            if _secret_scan_is_allowed "$_hit" "$allow_re"; then
                continue
            fi
            printf '  [%s] %s\n' "$_name" "$_hit"
            _hits=$((_hits + 1))
        done <<< "$_matches"
    done < "$patterns"

    # T-2897: the name axis runs inside this same pass, deliberately. Callers
    # print one verdict line for scan-tree ("[PASS] Secret scan: tracked tree
    # clean"), and that line was printed on every audit across a two-month
    # exposure. Wiring the second axis anywhere else would have left the false
    # green exactly where it was — a PASS here now means both axes passed.
    if ! scan_names; then
        _hits=$((_hits + 1))
    fi

    [ "$_hits" -gt 0 ] && return 1
    return 0
}

# ── Name axis (T-2897) ──────────────────────────────────────────────────────
#
# Everything above this line keys on file CONTENT against vendor-prefixed
# credentials (AKIA…, ghp_…, sk-ant-…, -----BEGIN). That is the right shape for
# third-party credentials and the wrong shape for ours: `secrets.token_hex(32)`
# is 64 bare hex characters with no prefix, no vendor and no assignment to
# anchor on. The one class of secret the framework is guaranteed to PRODUCE is
# the class a content scanner is structurally guaranteed to MISS, because
# "carries no third-party fingerprint" is what self-generated means. No number
# of added patterns closes that; only a second axis does.
#
# The axis nothing was reading is filenames. `.fw-secret-key` announced exactly
# what it was, in its name, for the two months it sat in 832's tree while every
# audit printed "[PASS] Secret scan: tracked tree clean" (rail 498). L-521: a
# detector's indexing strategy, not its pattern count, determines what it sees.
#
# Two classes, and the weaker one says so. DEFINITIVE is an exact name or an
# extension that means credential material and nothing else. ANNOUNCED pairs a
# secrecy word with a credential noun and is a heuristic — it is labelled that
# way in the output so a maybe never reads as a certainty.
#
# `token` is deliberately NOT a standalone signal: 832 measured 17 matches on
# their tree and every one was a false positive (token-budget reports, design
# tokens, a CSRF-token RCA). It survives only as the noun half of a pair.
#
# Tracked files only. An untracked key on disk is the normal, correct state —
# that is what the .gitignore rules from T-2896 produce. Only publication is
# the leak.

# The two halves must be DIFFERENT KINDS of word — a qualifier and a noun.
# First cut had `credential` in both lists, so the single word "credentials"
# satisfied the pair by itself and the scan fired on three fabric cards
# describing credential-handling *source* (lib-url-credentials.yaml and
# friends). A pair that one word can complete is not a pair; it is a
# single-word match wearing a pair's clothes, and it re-introduces exactly the
# 17/17 noise 832 measured on bare `token`. Qualifiers here, nouns below.
#
# T-2898: that paragraph was already written when `pass` (noun) went in
# alongside `password` and `passwd` (qualifiers), and `pass` is a substring of
# both — so the single word "password" completed the pair by itself, exactly the
# defect the paragraph forbids, one word over. `passwd-rotation.yaml`,
# `password-reset.yaml` and `password-policy.json` all classified ANNOUNCED.
#
# The repair is 832's (their rail 503, same class in their scanner): the two
# halves must match at NON-OVERLAPPING SPANS of the name. That makes the rule
# structural. Curating the lists apart would fix these three strings and leave
# the rule that permitted them — the next author to add a plausible word to both
# lists brings it straight back, with nothing in the code saying why they
# shouldn't.
#
# So `password`/`passwd` and `pass` STAY IN BOTH LISTS DELIBERATELY. Both words
# genuinely belong in their roles; the span rule is what makes the overlap
# harmless. tests/unit/secret_scan_span_rule.bats fails if the overlap is ever
# curated away, because an empty overlap would make the generative leg pass for
# the wrong reason.
#
# Note what did NOT show the bug: `reset-password.md` and `password_reset_test.py`
# come back clean — via the prose/source extension filter below, not via the pair
# logic. The two cases that would have surfaced this were suppressed by something
# else, and what was left unmasked is `.json`/`.yaml`: config data, the one file
# class no extension filter can exclude because it is where real secrets live.
#
# Space-separated word lists, not regex alternations — the span check needs the
# individual words, and a `|`-joined string cannot tell you which alternative matched.
_SECRET_NAME_SECRECY_WORDS='secret private passwd password auth signing'
_SECRET_NAME_NOUN_WORDS='key token cert creds credential pass'

# True when a qualifier and a noun both occur, at spans that do not overlap.
#
# Masks EVERY occurrence of EVERY qualifier out of the name, then requires a
# noun in what is left. Two properties this has and a first-occurrence split
# does not:
#
#   - The noun cannot be hiding inside a *second* qualifier. Splitting on the
#     first `auth` in `auth-password-policy.json` leaves `-password-policy.json`,
#     where `pass` is found inside `password` — disjoint spans, both of them
#     qualifiers, no noun anywhere in the name. Masking removes all of them.
#   - Masking with a SPACE, rather than deleting, means no noun match can be
#     assembled across the seam a removal would create: no noun contains a space.
#
# The first form of this function shipped with the split-on-first-occurrence bug
# above, and the fixture legs of the test all passed. The generative leg
# (probing every word in both lists, alone and doubled) is what failed and named
# `passwd-passwd` — which is why that leg exists rather than a list of known-bad
# filenames.
_secret_name_pair_disjoint() {
    local lower="$1" q n masked had_qualifier=1
    masked="$lower"
    for q in $_SECRET_NAME_SECRECY_WORDS; do
        case "$masked" in
            *"$q"*) had_qualifier=0; masked="${masked//"$q"/ }" ;;
        esac
    done
    [ "$had_qualifier" -eq 0 ] || return 1
    for n in $_SECRET_NAME_NOUN_WORDS; do
        case "$masked" in *"$n"*) return 0 ;; esac
    done
    return 1
}

# Source and prose that TALKS ABOUT credentials is not credential material.
# Without this, the scanner fires on secret-scan.sh itself, on the tests that
# pin it, and on the task file describing the incident — and a check that cries
# wolf on its own source gets reverted, which is the real failure mode.
_secret_name_is_prose_or_source() {
    case "$1" in
        *.md|*.rst|*.txt|*.sh|*.bash|*.py|*.bats|*.js|*.mjs|*.ts|*.tsx|*.jsx) return 0 ;;
        *.html|*.css|*.rs|*.go|*.java|*.rb|*.php|*.c|*.h|*.cpp|*.sql|*.bpmn) return 0 ;;
    esac
    return 1
}

# Classify one basename. Echoes the class, or nothing.
_secret_name_classify() {
    local lower="$1"
    case "$lower" in
        .fw-secret-key|id_rsa|id_dsa|id_ecdsa|id_ed25519|.netrc|.pgpass|.htpasswd)
            echo DEFINITIVE; return ;;
        # Bare `credentials` as the whole stem is a credential store by
        # convention. As a compound suffix it is usually prose ABOUT one
        # (url-credentials, strips_upstream_credentials) — which is why it is
        # listed here as exact names rather than left to the ANNOUNCED pair.
        # Known limit, stated rather than papered over: `aws-credentials` and
        # other qualifier-less compounds fall through both classes.
        credentials|.credentials|credentials.json|credentials.yaml|credentials.yml|credentials.ini)
            echo DEFINITIVE; return ;;
        *.pem|*.p12|*.pfx|*.jks|*.keystore|*.ppk|*.key)
            echo DEFINITIVE; return ;;
    esac
    _secret_name_is_prose_or_source "$lower" && return
    if _secret_name_pair_disjoint "$lower"; then
        echo ANNOUNCED
    fi
}

# Public: scan tracked FILENAMES for credential material.
# Returns 0 if none, 1 if any.
scan_names() {
    local root cfg allowlist allow_re
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    allowlist="$cfg/.secret-scan-allowlist"
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"

    local _hits=0 _path _base _lower _class
    while IFS= read -r _path; do
        [ -z "$_path" ] && continue
        _base="${_path##*/}"
        _lower="$(printf '%s' "$_base" | tr '[:upper:]' '[:lower:]')"
        _class="$(_secret_name_classify "$_lower")"
        [ -z "$_class" ] && continue
        if _secret_scan_is_allowed "$_path:0:$_base" "$allow_re"; then
            continue
        fi
        printf '  [name:%s] %s\n' "$_class" "$_path"
        _hits=$((_hits + 1))
    done < <(git -C "$root" ls-files 2>/dev/null)

    [ "$_hits" -gt 0 ] && return 1
    return 0
}

# Public: scan a specific file.
scan_file() {
    local file="$1"
    [ -z "$file" ] && { echo "usage: scan-file <path>" >&2; return 2; }
    [ ! -f "$file" ] && { echo "scan-file: not found: $file" >&2; return 2; }
    local root cfg patterns allowlist
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    patterns="$cfg/.secret-scan-patterns"
    allowlist="$cfg/.secret-scan-allowlist"
    local allow_re
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"
    awk -v file="$file" '{ printf "%s:%d:%s\n", file, NR, $0 }' "$file" \
        | _secret_scan_run_patterns "$patterns" "$allow_re"
}

# Entry point when invoked as a script.
_secret_scan_main() {
    local cmd="${1:-scan-staged}"
    shift || true
    case "$cmd" in
        scan-staged|scan_staged) scan_staged "$@" ;;
        scan-tree|scan_tree)     scan_tree "$@" ;;
        scan-names|scan_names)   scan_names "$@" ;;
        scan-file|scan_file)     scan_file "$@" ;;
        -h|--help|help)
            cat <<USAGE
secret-scan.sh — Pre-commit secret scanner (T-1844)

Subcommands:
  scan-staged       Scan git staged diff (pre-commit hook mode)
  scan-tree         Scan entire working tree, both axes (audit mode)
  scan-names        Scan tracked FILENAMES only (T-2897 name axis)
  scan-file <path>  Scan a specific file

Configuration:
  .secret-scan-patterns   TSV pattern catalogue
  .secret-scan-allowlist  Suppress known false-positives
USAGE
            return 0
            ;;
        *) echo "secret-scan: unknown subcommand: $cmd" >&2; return 2 ;;
    esac
}

# Only run main when invoked as a script, not when sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ] || [ -z "${BASH_SOURCE[0]:-}" ]; then
    _secret_scan_main "$@"
fi
