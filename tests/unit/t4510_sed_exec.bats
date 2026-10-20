#!/usr/bin/env bats
#
# T-4510 (SECURITY, G-121): the read-only allowlist admitted sed on the argument that
# its only write routes (-i, w FILE) are gated by the outer raw-text rules. GNU sed
# also RUNS commands: the `e` command (`e CMD`, `1e CMD`) and the `e` flag of `s`.
# Reported by ring20-dashboard (msg af2bbc85).
#
# Fix: agents/context/lib/safe-commands.sh _fw_sed_runs_command — options are a
# whitelist (-f/--file hide the script; unknown or ambiguous long options fail
# closed), and every script is judged by lib/shell_write_scan.py sed_script_risk, a
# command-by-command sed parser in which regexes, replacements and `a` text are data.
# Classification only: nothing here is executed.
#
# `! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
# `if cmd; then false; fi`.

load helpers/known_cwd

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    known_cwd_setup
    source "$ROOT/agents/context/lib/safe-commands.sh"
}

teardown() { known_cwd_teardown; }

_refused() {
    local c
    for c in "$@"; do
        if is_bash_safe_command "$c"; then echo "SAFE (expected gated): $c"; return 1; fi
    done
}

_safe() {
    local c
    for c in "$@"; do
        is_bash_safe_command "$c" || { echo "gated (expected SAFE): $c"; return 1; }
    done
}

@test "T-4510: the probe's sed lines are NOT SAFE" {
    _refused "sed 'e touch pwned' F" "sed '1e touch pwned' F" "sed 's/a/b/e' F"
}

@test "T-4510: e command with addresses, negation and blocks is NOT SAFE" {
    _refused "sed '/x/e' F" "sed '1!e x' F" "sed -e '1{e x' -e '}' F" "sed '\$e x' F" \
        "sed -n '1,3e x' F" "cat F | sed 'e x'"
}

@test "T-4510: the e flag of s, with any delimiter and option form, is NOT SAFE" {
    _refused "sed -n 's/a/b/ge' F" "sed -E 's/a/b/e' F" "sed -e 's/a/b/e' F" \
        "sed 's|a|b|e' F" "sed -ne 's/a/b/e' F" "sed --expression='1e x' F" \
        "sed --expr='1e x' F" "sed -n -e 1p -e 's/a/b/e' F" "sed 's/[/]/x/e' F"
}

@test "T-4510: a script the text does not show, or an unknown option, is NOT SAFE" {
    _refused 'sed -f P F' 'sed --file=P F' 'sed "$S" F' 'sed --s 1p F' 'sed -X 1p F' \
        "sed -'f' P F"
}

@test "T-4510: an e inside a regex, replacement, y or a text is data" {
    _safe "sed 's/e/E/g' F" "sed '/e/d' F" "sed 'y/e/E/' F" "sed '1a text with e' F" \
        "sed -n '/re/p' F" "sed 's/a/b/;b/e' F" "sed 's/x/\\e/' F"
}

@test "T-4510: ordinary read-only sed and the G-121 controls stay SAFE" {
    _safe "sed -n 1p F" "sed -E 's/(a)/\\1/' F" "sed -n '1,5p;\$p' F" "sed '\$d' F" \
        "sed '/<!--/,/-->/d' F" "sed -n -e 1p -e '\$p' F" "sed --quiet 1p F" \
        "sed -nE 's/x/y/p' F" "sed 's/^[[:space:]]*//' F" \
        "git grep pattern" "awk '{print \$1}' F"
}

@test "T-4510: sed_script_risk parses the script, not the characters" {
    run python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
bad = ["e x", "1e x", "s/a/b/e", "s/a/b/w f", "w f", "1{e x\n}", "s/[/]/;b/e", "v"]
good = ["s/e/E/g", "/e/d", "y/e/E/", "1a e", "$p", "1,5p;$p", "s/a/b/;b/e", "s|a|e|g"]
out = [b for b in bad if not s.sed_script_risk(b)] + [g for g in good if s.sed_script_risk(g)]
print(out); sys.exit(1 if out else 0)' "$ROOT/lib"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}
