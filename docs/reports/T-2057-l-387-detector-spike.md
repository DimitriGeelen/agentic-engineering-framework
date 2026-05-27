# T-2057 — L-387 SIGPIPE Detector Spike

**Task:** [T-2057](/tasks/T-2057) (Inception)
**Date:** 2026-05-27
**Status:** Spike findings — pre-decide

## Summary

L-387 (`cmd | grep -q PATTERN` under `set -eo pipefail`) has been captured **7 times** in two consecutive autonomous sessions (S-2026-0526..-0527). Each capture had a fix turnaround of ~10 minutes (diagnose, edit, retry close, commit). The class is fully detectable statically. At observed cadence (~3-4 per active autonomous session), a structural detector is well past the L-364/L-417 threshold for codification (≥3 statically-detectable repeats).

## Capture history (this session pair)

| Task | Site | Anti-pattern | Fix |
|------|------|--------------|-----|
| T-1716 | Verification | `bin/fw doctor 2>&1 \| grep -q PATTERN` | Capture-to-tempfile |
| T-1838 | Verification | `cmd \| grep -q PATTERN` | Capture-to-tempfile |
| T-1862 | Verification | `cmd \| grep \| wc -l \| grep -q` | Capture-to-tempfile |
| T-1863 | Verification | Brace-pipe over `fw audit` | Tempfile + `test "$(grep -c ...)"` |
| T-2008 | Verification | `cmd \| grep -q PATTERN` | Capture-to-tempfile |
| T-1701 | Verification | `{ bin/fw doctor \|\| true; } \| grep -E ... \| wc -l \| grep -q "^0$"` | Capture-to-tempfile |
| T-1707 | Verification | `bin/fw doctor 2>&1 \| grep -qE PATTERN` | Capture-to-tempfile |

## Anti-pattern signature

```
<cmd-that-streams-stdout> [2>&1] | grep -q [-E] "<pattern>"
```

OR

```
<cmd> [2>&1] | grep [...] | wc -l | grep -q "^<N>$"
```

The mechanism is the same in both cases:

1. `grep -q` exits 0 on first match.
2. Closing stdin sends SIGPIPE upstream.
3. Upstream (`fw doctor`, `bats`, `fw audit`) is still writing — receives SIGPIPE — exits 141.
4. `set -eo pipefail` returns the rightmost non-zero exit → pipeline exits 141.
5. `update-task.sh`'s verification gate refuses close.

**Safe pattern** (used by ~26 existing tasks via `out=$(cmd ...); echo "$out" | grep -q PATTERN`): capture upstream fully, then grep. No streaming, no SIGPIPE.

## Corpus scan results

Spike command:

```bash
for f in .tasks/active/*.md .tasks/completed/*.md; do
  awk '
    /^## Verification/{flag=1;next}
    /^## [A-Z]/{flag=0}
    flag && /\| grep -q [^|]*$/ && /(fw doctor|fw audit|bats |find |ls .*\*|\| grep .*\| wc)/ {print FILENAME":"NR":"$0}
  ' "$f" 2>/dev/null
done
```

**Population:** 1892 task files have `## Verification` blocks. 44 contain the literal anti-pattern signature in a risky upstream context. ~15 of those are **true L-387 positives** (direct pipe from `fw doctor` / `bats` / `find` into `grep -q`). ~26 are **false positives** (the safe `out=$(cmd); echo "$out" | grep -q` pattern, which incidentally matches the regex but is L-387-immune).

Examples of true positives (would be flagged by detector):

- `.tasks/completed/T-1097-fw-doctor-reconcile-upstreamrepo-vs-runn.md:36` — `bin/fw doctor 2>&1 | grep -cE "FAIL" | grep -q "^0$"`
- `.tasks/completed/T-1190-close-g-035-verify-3-structural-guards-f.md:37` — `bin/fw doctor 2>&1 | grep -q "Quick Reference"`
- `.tasks/completed/T-242-block-built-in-enterplanmode-from-bypass.md:48` — `bin/fw doctor 2>&1 | grep -q "All checks passed"`

Examples of false positives (detector must distinguish):

- `out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Active mode: framework-repo"` — L-387 safe
- `out=$(bin/fw audit ...); echo "$out" | grep -q "CTL-026"` — L-387 safe

**Refined heuristic:** Flag when the line contains both:
- `| grep -q ` (terminal `grep -q` in a pipe), AND
- The upstream of that pipe is NOT `echo "$..."` or `printf "..."` (i.e. is a streaming command like `fw doctor`, `fw audit`, `bats`, `find`, `ls *`, or a `{ ... }`-grouped pipeline).

## Surface decision (open)

Four candidate surfaces for the detector:

| Surface | Pros | Cons |
|---------|------|------|
| **(a) `fw reviewer` pattern** | Author-discoverable, non-blocking, fits existing reviewer agent architecture | Catches issue only at scan time, not at edit time |
| **(b) `fw audit` check** | Daily WARN catches long-tail drift across the corpus | Same as (a) — catches late |
| **(c) PreToolUse hook on Write/Edit of `.tasks/*.md`** | Blocks before commit; tightest feedback loop | Noisy (false positives), may trip on legitimate `grep -q` against short upstream cmds |
| **(d) `update-task.sh` lint at `--status started-work` time** | Catches at task-start; gives author the warning before they invest in the verification block | Same false-positive concern as (c); may surprise on legacy tasks |

**Recommended (preliminary):** (a) + (d) — reviewer pattern as the primary surface (author can run `fw reviewer T-XXX` to validate before close), plus a lightweight advisory in `update-task.sh` at `started-work` time that only warns (does not block) so it's discoverable but not annoying.

**Strong NO:** PreToolUse hook on edit — too noisy.

## Open questions for inception decide

1. Is the ~95% precision target achievable with the refined heuristic? Spike says yes against the 44-line risky set.
2. What's the bypass mechanism? Reviewer overrides already exist (`fw reviewer override add`); same shape for this detector?
3. Should completed/ tasks be scanned too? Argument for: historical patterns inform future templates. Argument against: completed tasks are immutable; warnings are noise.

## Go/No-Go

**GO** if: (a) is feasible against the reviewer pattern framework and (d) costs <1 day of build slice; that builds the detector as a reviewer pattern + an update-task.sh advisory.

**DEFER** if: an upcoming structural change to verification-block runtime (e.g. moving verification commands to a dedicated YAML schema with typed runners) would obsolete this detector.

**NO-GO** if: false-positive rate against the safe `out=$(cmd); echo "$out"` pattern can't be brought below 10%.
