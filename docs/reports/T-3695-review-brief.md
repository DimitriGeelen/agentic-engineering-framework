# T-3695 review brief — Human-AC tick guard extended to Bash

**Task:** `.tasks/active/T-3695-check-human-ac-tick-guards-only-writeedi.md`
**Commit under review:** `f98c019d6` (plus any later `T-3695:` commits)
**Threat:** an agent ticks a `- [ ]` box under `### Human` in a `.tasks/` file. CLAUDE.md:
"NEVER check a `### Human` AC. Only the human may verify and check these boxes."

## Design in one paragraph

Three layers. (1) **PreToolUse Bash** — `agents/context/check-human-ac-tick.py:check_bash`
calls `lib/shell_write_scan.py:scan`. Under agent control (`CLAUDECODE=1` or `AI_AGENT`)
any shell write whose target is a path with a `.tasks` component, or the ledger
`human-ac-ticks.jsonl`, exits 2. The write is refused whatever it changes, because a shell
command's result cannot be diffed before it runs. (2) **PreToolUse Write|Edit** — the
existing positional diff, plus: a rise in the count of ticked Human boxes blocks (an
appended ticked line was invisible to the zip), and the ledger cannot be written.
(3) **Post-hoc** — `lib/human_ac_ticks.py audit`, wired into `agents/audit/audit.sh`,
walks non-merge commits in `<commit that added lib/human_ac_ticks.py>..HEAD` touching
`.tasks/`. It FAILs every Human box that went `[ ]`→`[x]`, was added ticked, or left
`### Human` and reappears ticked, unless a ledger row covers (task, criterion text) or a
`**Reviewer verdict:** green` annotation follows it. The FAIL line says AGENT when the
author/committer is `@aef.local` or the message has a Claude co-author/"Generated with
Claude Code" trailer.

Provenance writers: `fw inception decide` (`lib/inception.sh:tick_inception_decide_acs`),
`fw verify-acs --auto-check --execute` (`lib/verify-acs.sh`), and the operator CLI
`python3 lib/human_ac_ticks.py ack T-XXX --ac N` (refused under agent control without
`--i-am-human`; the Bash guard also refuses typing it). Watchtower's toggle-ac does NOT yet
write a row — follow-up T-3722 (render surface, P-013 needs its own `[REVIEW]`).

## Scanner (lib/shell_write_scan.py) — how a command is read

A bash-style tokenizer (`_tokens`; was shlex until round 2) after decoding `$'..'` and turning
backticks into separators. Segments split on `; && || | & ( ) newline { } !`. Per segment:
write-redirections collected (`> >> >| &> &>> <> >&FILE`; `>&N` skipped), then leading
`VAR=` assignments and wrappers (sudo, env, timeout, nohup, xargs, ...) skipped, so the verb
is the word in command position. Targets: sed/perl/ruby `-i`, awk `-i inplace`, tee, sponge,
sort -o, cp/mv/install/ln/rsync dest (`-t`), dd `of=`, editors, patch, find
`-exec`/`-fprint`, git checkout/restore/apply/am/show/stash naming a task path, tar/unzip
naming one, curl/wget to `toggle-ac`. Each target is resolved (cwd from the hook payload,
tracked through `cd`, `~`, glob expansion, realpath); unresolvable targets (`$VAR`, braces,
xargs/find operands, empty glob) count when the command anywhere mentions a guarded path
(`MENTION_RE`, matched on a quote/backslash-stripped copy). Inline code (`python -c`,
`perl -e`, `bash -c`, `eval`, an interpreter reading stdin/heredoc) is refused when the
command mentions a guarded path. Script form (`python3 x.py ARGS`) is refused only when its
own segment mentions one.

## AC → evidence

| AC | Evidence |
|---|---|
| AC1 reproduction | Task `## RCA`: six payloads, rc=0/rc=0 before the fix; which gate states refused shell writes (`check-active-task.sh:480`, `:1166-1203`). |
| AC2 Bash refused | `check_bash` in `agents/context/check-human-ac-tick.py`; `lib/shell_write_scan.py`; tests 1–9 in `tests/unit/t3695_human_ac_tick_bash.bats`. |
| AC3 reads/unrelated pass | tests 10–12 (cat, grep, sed -n, awk, git diff, `2>&1`, read redirected to /tmp, cp FROM a task file, unrelated sed -i/redirects, `fw task update`, quoted prose). |
| AC4 residual stated | block message text (test 14 greps `script file`, `T-2742`, `fw audit`); CLAUDE.md §Agent/Human AC Split, line after "NEVER check a `### Human` AC". |
| AC5 audit detector | `lib/human_ac_ticks.py`; `agents/audit/audit.sh` block "T-3695"; tests 17–24 (agent identity, trailer, human-without-provenance, ack, added-ticked, verdict, inception decide, ancestry + backdated commit). |
| AC6 bats | 35/35 ok, 0 skip (after round 2). Write-path tests use `assert_vector_refused`: the SAME string is run for real against a mktemp fixture (exit 0 and the Human box becomes `[x]`) and then refused by the hook. Refusal-only (no vector run, stated honestly): the `>>` append (the fixture's append lands after `## Verification`), `s///w` (writes only matched lines — clobbers rather than ticks), `sed -f`, `sort --out`, `gawk --incl`, the toggle-ac curl, ledger write, `ack`, `git checkout`. No mid-test `! cmd`. |
| AC7 registration | `.claude/settings.json` PreToolUse matcher `Bash` → `check-human-ac-tick` (added via `fw hook-enable`); `lib/init.sh` Bash block; `.context/project/enforcement-baseline.sha256`; `bin/fw vendor self --check` clean. |
| AC8 review | this brief + `docs/reports/T-3695-review-codex.md`. |

## Round 1 (codex FAIL) — what changed

| Finding | Fix | Pinned by |
|---|---|---|
| `sed -i -e'EXPR' FILE` dropped FILE (attached `-e`) | `_parse_sed`: GNU clustering, attached/separate `-e/-f/-l`, `--expression=`, `-i[SUF]` | test 10 |
| sed `w FILE` / `s///w` / `e` / `-f` not seen | `SED_WRITE_RE`; such a sed is treated as inline code (refused when the command names a guarded path) | test 10 |
| merge-commit ticks skipped | merges included; a tick counts when it is new relative to EVERY parent | merge tests |
| fabricated `**Reviewer verdict:** green` exempt | `VerdictBacking` (renamed in round 2): id must be a green row for the task in verdicts.jsonl AND an applied tick in applied.jsonl | annotation tests |
| one `ack` licensed every later re-tick | one ledger row = one tick, consumed oldest-first | ack-reuse test |
| only the first `### Human` section read (detector AND Edit-leg hook) | all sections joined, both places | second-section tests |
| FPs: `grep '>'`, `git show/cat-file`, `awk 'NF > 0'`, `tar -c` | non-posix tokenising keeps quoted operators as words; git show/cat-file dropped; awk only print/printf redirection, pipes, system(), close(); tar only when extracting | controls test |
| vector test ignored the command's exit status; some vectors not run with the refused string | `assert_vector_ticks` asserts status 0; `assert_vector_refused` runs and refuses the SAME string | all vector tests |

## Round 2 (codex FAIL) — what changed

| Finding | Fix | Pinned by |
|---|---|---|
| GNU long-option abbreviations (`sed --in-plac`, `--in`, `--expr`) | `_is_long` prefix matching for sed, cp/mv `--target-directory`, sort `--output`, gawk `--include` | "review round 2: GNU long-option abbreviations" |
| a valid verdict replayed after an un-tick | `VerdictBacking`: one `applied.jsonl` tick event exempts ONE tick (consumed oldest-first) | "one applied tick event exempts ONE tick" |
| a valid verdict reused on another criterion | the verdict row's `ac_digest` must equal `verdict_ledger.criterion_digest` of the criterion the annotation sits under | "a verdict is bound to ITS criterion" |
| `grep -e'>'` refused (tokeniser) | shlex replaced by a bash-style tokenizer (`_tokens`): quotes attached to words handled; a quoted operator spelling is a word; here-doc bodies stripped before tokenising | controls test |
| `unzip -l`, `view` refused | unzip extracts only without `-l/-v/-t/-Z/-p/-z`; `view` counts only with `-c/-s/+cmd` | controls test |
| awk `print ($1 > 0)` / `print "a>b"` | string literals and parenthesised expressions removed before the redirect check | controls test |
| scanner exception → hook crash | `scan()` catches any internal error and refuses when the command names a guarded path | — |

**Accepted false positive (deliberate):** inline interpreter code (`python3 -c`, `perl -e`,
`node -e`, heredoc to an interpreter) is refused whenever the command names a guarded path
anywhere, even if it only reads — the text cannot tell a read from a write in arbitrary code,
and narrowing it to the interpreter's own segment would let `echo PATH | python3 -c '…stdin…'`
through. Read task files with cat/grep/sed -n/awk, or split into two tool calls.

## Known residual (deliberately not claimed)

- A script file, a Makefile target, or any program that is not inline in the command text.
- A path assembled at run time from pieces the text does not contain (`'.ta'+'sks'`,
  `printf`, a path read from a file written by an earlier call).
- A same-user agent forging a ledger row via such a route and committing under a human
  identity (T-3581 class). The detector catches accidents and unsophisticated bypasses.
- Watchtower ticks committed by a session FAIL the audit until T-3722 lands (operator `ack`).
- Pre-existing failure, not from this task: `tests/unit/hook_producer_site_parity.bats`
  tests 3/5 name `check-paid-backend` and `check-worktree-governance-write`.
