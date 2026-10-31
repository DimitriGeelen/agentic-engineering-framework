# T-4792 AC1 — close-readiness (reviewer evidence)

Revision reviewed: f677b960c503cafe8f10ef26617ea75e44db4304. The working tree had no diff vs that revision for
agents/context/lib/safe-commands.sh, its vendored copy, and tests/unit/t4792_command_substitution.bats.

## Verification section (all 3 lines run, under `set -o pipefail`)
1. `bats tests/unit/t4792_command_substitution.bats > /tmp/.t4792.out 2>&1` → rc=0, 16/16 ok, 0 skips
   (6 gated shapes incl. the four OBS-185 shapes + nested + arithmetic-nested + unbalanced fail-closed;
   curl "$(bin/fw watchtower url)/page", cd $(git rev-parse --show-toplevel), echo "built $(date -u +%F)",
   single-quoted, escaped, $((1 + 2)), X=$(git rev-parse ...), pwd all stay safe).
2. `bash -n agents/context/lib/safe-commands.sh` → rc=0
3. `bin/fw vendor self --check --task T-4792` → rc=0, "vendored .agentic-framework/ in sync with source."

## Agent ACs
- AC1 (measured first) / AC2 (inner commands admitted first): commit 6b23a01aa adds `pwd` to the read-only
  arm; fw watchtower url is covered by T-3096 (curl idiom test 9 passes). Ordering satisfied in the same commit
  (allowlist widening + substitution judging land together, idioms test green).
- AC3: `_fw_command_substitutions` (python3 -I extractor) + recursive check in `is_bash_safe_command`;
  missing OK record → return 1 (fail closed). Read the code: single quotes literal, `\$(` escaped, `$((` skipped
  but contents scanned, nesting via recursion.
- AC4: independent probes (my own, not in the suite) all REFUSED: `echo $((bash deploy.sh) )`,
  `echo $( (bash deploy.sh) )`, `echo "$(echo ")" ; bash x)"`, `echo $(echo \) ; bash x)`, `echo "`bash x`"`,
  heredoc-in-substitution, `echo ${x:-$(bash x)}`, `echo $[$(bash x)]`. Allowed: `ls $(git rev-parse --show-toplevel)`,
  `echo $(echo $(pwd))`. Regression: ran 58 existing bats files referencing safe-commands/is_bash_safe_command →
  rc=0, 765 ok, 0 not ok, 0 skips (subset of the 98-file/1097 claim; consistent with it).
- AC5: commit 58bca2d4f vendors safe-commands.sh; vendor check above passes; owner: human retained.

All Agent ACs ticked and met; Verification passes. Verdict: green.
