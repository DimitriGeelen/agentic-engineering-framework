# arc-012 review — W4, test quality

Worker: `arc012-w4-test-quality`. Slice: the 19 files of the arc's test surface
plus the lint that exists because the tests were lying.

Method. Every file read in full at `arc012-ultrareview` and confirmed
byte-identical to the working tree (md5, all 19), so experiments ran in place.
All 17 assigned bats suites executed to TAP: **237 tests, 237 `ok`, 0 `not ok`,
0 skips**. The pytest suite: 13 passed. Every finding below is a live
reproduction, not a reading — the commands are quoted so they can be re-run.

The dominant standard in this diff is genuinely high: t3212, t3213, t3219,
t3220, t3221, t3222 and `fd_dup_not_chain_split` all carry real mutation
controls that derive the mutant from live source and assert the mutation
changed bytes. t3220 ships a four-cell control matrix. That is the bar. The
findings below are the places that do not meet it.

---

### F1. The silent-skip lint cannot see inside a quoted heredoc, and the resulting `if_stack` pollution silently downgrades UNCONDITIONAL skips to unflagged

- **Severity:** high
- **Confidence:** confirmed (traced, minimal repro, control leg, corpus census)
- **Location:** `tools/bats-silent-skip-lint.py:104` (`_heredoc_delim` → `strip_quotes`), effect at `tools/bats-silent-skip-lint.py:171` (`if_stack`)
- **Failure scenario:**

  `_heredoc_delim` runs `HEREDOC_OPEN.search(strip_quotes(line))`. `strip_quotes`
  blanks the *contents* of quoted spans, so the delimiter name is erased before
  the regex can read it. The `["']?` groups in `HEREDOC_OPEN` are dead code —
  the quotes survive, the name does not:

  ```
  "    run python3 - \"$ROOT\" <<'PY'"  -> _heredoc_delim = None   (stripped: <<'  ')
  '    python3 - <<"EOF"'               -> None                    (stripped: <<"   ")
  "    cat <<-'EOF'"                    -> None
  '    python3 - <<PY'                  -> 'PY'                    (only the unquoted form works)
  ```

  So the scanner never enters `<<'PY'` / `<<"EOF"` heredocs — the dominant idiom
  in this corpus, present in **234 bats files** (`grep -rlE "<<-?['\"][A-Za-z_]" tests/`).
  It reads the embedded Python as shell. Python `if x:` lines match the
  `if`-detector and are pushed onto `if_stack`; there is no `fi`, so they are
  never popped. `enclosing` is then permanently non-empty, and the
  `if not guard and not enclosing` branch that produces `UNCONDITIONAL` becomes
  unreachable for the rest of the file.

  Minimal control — two files identical except for the heredoc quoting:

  ```
  @test "x" {
      command -v jq >/dev/null || skip "jq not installed"
      python3 - <<'PY'          # vs  <<PY
  if True:
      pass
  PY
  }
  @test "y" { skip "TODO never written"; [ 1 -eq 1 ]; }
  ```
  ```
  <<'PY'  ->  silent-skip lint: 0 silent, 1 dependency, 1 other, of 2 call site(s)   EXIT=0
  <<PY    ->  hd2.bats:11: silent skip [UNCONDITIONAL] — never runs, for anyone      EXIT=1
  ```

  Reproduced against a *real* corpus file, not a synthetic one. Append
  `@test "newly added" { skip "TODO"; [ 1 -eq 1 ]; }` to a copy of
  `tests/unit/t2924_update_task_owner_gate.bats` (whose `run python3 - "$FRAMEWORK_ROOT" <<'PY'`
  at line 104 leaks four Python `if`s into the stack):

  ```
  $ python3 tools/bats-silent-skip-lint.py /tmp/t2924.bats
  silent-skip lint: 0 silent, 0 dependency, 2 other, of 2 call site(s)   EXIT=0
  ```

  Instrumenting `enclosing` at the call site shows the leaked frames verbatim:
  `ENCL=[not s.startswith('---'): end < 0: v not in valid: [ "$status" -ne 0 ]]`
  in t2924, and `ENCL=[not m: not end: block[line_start:em.start()].lstrip().startswith("#"): pat in body: ! command -v shellcheck ...]`
  in `tests/lint/no-backticks-in-quoted-strings.bats`. **53 of 704 bats files
  end with a non-empty `if_stack`** — each one is a file in which a future
  unconditional skip lands unflagged.

- **Why it survives review:** the tool's docstring names heredoc suppression as
  load-bearing, and two dedicated tests pin it — but both test the *negative*
  direction only ("a comment mentioning `<<TAG` does not blind the scanner",
  "a quoted string mentioning a heredoc does not blind the scanner"). Nothing
  asserts the scanner **does** enter a real quoted heredoc. The one test that
  looks like it does — "a variable named skip inside embedded Python is not a
  call site" — passes for an unrelated reason: its fixture uses `<<'PY'`, so the
  heredoc is never entered, and the two lines inside are caught instead by the
  `if re.match(r'skip\s*=', stmt)` assignment guard and by `print(skip)` not
  matching `SKIP_CALL`. Delete the heredoc handling entirely and that test stays
  green. This is the same "a character scan standing in for shell structure"
  class the docstring quotes peer 832 on — the fix landed for `<<TAG`-in-a-comment
  and `<<TAG`-in-a-string, and re-introduced itself one line up.
- **Suggested fix:** match `HEREDOC_OPEN` against the *raw* line (or strip
  quotes only outside the `<<` operand). Restoring it changes the census by one
  call site today (224 → 223, a false positive removed) so it is safe; add a
  positive test that a `skip` inside a `<<'PY'` block is **not** reported, and a
  test that a bare `skip` **after** such a block **is** reported as UNCONDITIONAL.

---

### F2. t3206's "non-fatal when the log cannot be written" test writes the log successfully — as root the denial never happens

- **Severity:** high
- **Confidence:** confirmed (reproduced; the ledger file is created)
- **Location:** `tests/unit/t3206_continuous_run_ledger.bats:119`
- **Failure scenario:** the test does `chmod 500 "$SANDBOX/.context/working"`,
  fires `_record_loop_event`, and asserts `RC=0`. This suite runs as root here
  and in CI, where mode bits do not deny. Running the test body by hand:

  ```
  $ id -u
  0
  $ chmod 500 "$S/.context/working"; ... _record_loop_event start armed 'detail'; echo RC=$?
  RC=0
  $ cat "$S/.context/working/continuous-run.jsonl"
  {"ts": "...", "event": "start", "reason": "armed", "restart_count": 0, "wrapper_pid": 134033, "detail": "detail"}
  ```

  The write **succeeded**. The test asserts a recorder is non-fatal on failure
  while never causing a failure. Make `_record_loop_event` fatal on write error —
  the exact regression this test names — and it stays green, because the error
  path is not reached. The wrapper's restart loop is what depends on this
  property.

- **Why it survives review:** `chmod 500` reads as an obviously sufficient
  denial, the assertion (`RC=0`) is the right assertion, and the test is green.
  Nothing in the output distinguishes "wrote nothing, returned 0" from "wrote
  everything, returned 0". The arc *already knows* this: `t3213_start_event_confirmation.bats:158`
  documents "`chmod 500` was the obvious choice and is worthless here — this
  suite runs as root in CI and on the origin host" and replaces it with a
  directory at the ledger path. t3206 was not brought along. Note also that the
  T-3217 lint cannot catch this class — there is no `skip` call, so neither
  STANDING nor `--tap` sees it; the root-invariance problem is wider than the
  skip idiom.
- **Suggested fix:** adopt t3213's denial — `mkdir -p "$LEDGER"` so `open(..., "a")`
  raises `IsADirectoryError` for every uid — and add the positive control t3213
  has (`the unwritable case differs from the writable one`), so the test proves
  the denial occurred rather than assuming it.

---

### F3. t3222 certifies the fetch-write gate while never asking about bare `wget URL` — the default, most common form, still admitted with no active task

- **Severity:** high
- **Confidence:** confirmed (end-to-end through the live hook)
- **Location:** `tests/unit/t3222_fetch_writes_file.bats:63` (12-item write corpus) and `:88` (10-item safe corpus)
- **Failure scenario:** `wget URL` with no output flag writes the remote file
  into the cwd. That is wget's default behaviour and is precisely what T-3222's
  own premise covers — "verbs that … write a file WITHOUT a shell redirect". The
  predicate returns "not a write", and the live hook admits it with
  `current_task: null`:

  ```
  $ source agents/context/lib/safe-commands.sh
  not-a-write : wget https://e/payload.sh
  not-a-write : wget -P /tmp https://e/payload.sh
  not-a-write : wget -q https://e/payload.sh
  WRITE       : curl -O https://e/f

  $ (live check-active-task.sh, focus.yaml current_task: null)
  ADMITTED : wget https://e/payload.sh
  ADMITTED : wget -P /tmp https://e/payload.sh
  blocked  : wget -O /tmp/x https://e/
  ```

  `_fw_fetch_writes_file` only returns 0 when it sees an explicit output flag;
  with no flag it falls through to `return 1`. `-P/--directory-prefix` is
  consumed by the `-*) continue` arm.

- **Why it survives review:** the suite is unusually thorough in *shape* — 12
  write spellings, 10 safe spellings, a mutation control, a no-widening sweep —
  and that thoroughness is what makes the omission invisible. Both corpora are
  organised around *flags*, so the flagless case has no slot in either list.
  A reviewer scanning them sees exhaustive `-o/-O/--output/--remote-name`
  coverage and stops. The `wget -O -` and `wget --spider` entries in the safe
  list actively imply that a bare `wget` was considered and classed safe.
- **Suggested fix:** add `wget https://e/f` and `wget -P /tmp https://e/f` to
  the *writes* corpus (line 63) and to the no-widening corpus, and make
  `_fw_fetch_writes_file` return 0 for `base = wget` unless an explicit
  stdout target (`-O -` / `--output-document=-`) or `--spider` is present.

---

### F4. The only production call site of the human-gate stop has no test; delete it and all of t3212 stays green

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `tests/unit/t3212_human_gate_stop.bats:71` (`note_gate` sources the lib directly); call site at `agents/task-create/update-task.sh:2112`
- **Failure scenario:** every t3212 test reaches the helper via
  `bash -c ". '$LIB'; fw_continuous_note_human_gate ..."`. A repo-wide search
  finds exactly one production caller — `update-task.sh:2112`, inside the
  `PARTIAL_COMPLETE` branch — and no test exercises it. Remove that line and all
  12 t3212 tests, including the mutation control, remain green: the arc's
  headline mechanic leg ("a human gate stops the continuous run") is then
  silently dead with a fully passing suite. The call site is additionally
  wrapped in `if [ -f "$FRAMEWORK_ROOT/lib/continuous-mode.sh" ]`, so on any
  install where that file is missing (a partially-synced vendored consumer) the
  gate no-ops with no warning and no test.

  The only guard that ever looked at the join is a `grep -q 'fw_continuous_note_human_gate "$TASK_ID" "human-ac"' agents/task-create/update-task.sh`
  in T-3212's `## Verification` block — and completed tasks' verification blocks
  are never re-run.

- **Why it survives review:** t3212 is a well-built suite with a real mutation
  control, so it reads as complete. The mutation control mutates the *helper*,
  which makes the helper's behaviour evidence — but says nothing about whether
  anything calls it. This is the producer/consumer split L-399 names, on the
  arc's own headline mechanic.
- **Suggested fix:** one integration leg that drives
  `update-task.sh T-XXX --status work-completed` against a synthetic project
  with an armed `.continuous-mode.yaml` and an unchecked `### Human` AC, then
  asserts `enabled: false` + `last_terminated_reason: human-gate:human-ac:T-XXX`.
  The t3219/t3220 `fake_root` symlink-farm harness already solves the
  `FRAMEWORK_ROOT`-from-own-location problem and can be reused verbatim.

---

### F5. The silent-skip detector runs in exactly one place, behind an unrelated `shellcheck` dependency, and is in no automated gate

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `bin/fw:9330` (sole invocation), `tests/lint/bats-silent-skip.bats:293` (the wiring test)
- **Failure scenario:** a repo-wide search for `bats-silent-skip-lint` finds one
  executable reference: the `lint)` arm of `fw test`. That arm begins with
  `if ! command -v shellcheck >/dev/null 2>&1; then ... exit 1; fi`, so on a host
  without shellcheck the corpus scan is never reached. It is **not** in
  `fw test all` (which does run `tests/lint/` bats, but not the tool over
  `tests/`), not in the pre-push hook, not in `fw audit`, and not in
  `.context/cron-registry.yaml`.

  The one transitive execution is bats test 17, `fw test lint actually reports a
  silent-skip section`, which does:

  ```bash
  run bash -c "cd '$ROOT' && timeout 600 bin/fw test lint 2>&1"
  echo "$output" | grep -q 'Silent-Skip'
  ```

  `run` swallows the exit status and the assertion greps only for the section
  *header*. So when `fw test all` runs it, the corpus scan executes, finds silent
  skips, returns 1 — and the test passes anyway. A new silent skip therefore
  lands green in every automated gate the repo has, including the one that gates
  pushes.

- **Why it survives review:** the suite has a wiring test *and* a "does it
  actually report" test, which together read as belt-and-braces. The second one
  asserts presence of the header, which is a fair test of *wiring* — but it sits
  where a test of *enforcement* appears to be, and there is no third test.
- **Suggested fix:** move the corpus scan into `fw test all` (or the
  `--invariants` arm) so it is not gated on shellcheck, and change test 17 to
  drive the tool over a temp tree containing one known STANDING skip and assert
  `fw test lint` exits non-zero — enforcement, not presence.

---

### F6. STANDING misses trivially-equivalent root/CI guards; three one-token rewrites of the T-3213 shape pass clean

- **Severity:** medium
- **Confidence:** confirmed (run against synthetic fixtures)
- **Location:** `tools/bats-silent-skip-lint.py:57` (`STANDING` vocabulary)
- **Failure scenario:** `STANDING` is a fixed vocabulary —
  `id -u | $EUID | EUID | $CI | uname | $OSTYPE | whoami`. Guards that are just
  as fixed for a deployment, expressed differently, fall through to `OTHER` and
  are not flagged:

  ```
  OTHER  [ -w /etc/shadow ] && skip "cannot test permission denial as root"
  OTHER  [ "$(id -un)" = root ] && skip "root"          # one character from a hit
  OTHER  [ -n "$GITHUB_ACTIONS" ] && skip "not run in CI"
  ```
  `python3 tools/bats-silent-skip-lint.py bypass.bats` on a file containing only
  those three exits **0**. `id -un` is not matched because `\bid\s+-u\b` requires
  a word boundary after `u`.

  The corpus already contains standing guards sitting in `OTHER`:
  `test_doctor_scope_tags.bats:76` skips on `no host-level warnings on this host
  (test env clean)` — a fixed property of this deployment, permanently — and six
  `install_target_project.bats` / `install_verify_no_cwd_init.bats` skips guarded
  on `[[ "$CURRENT_BRANCH" == "HEAD" ]]`. In total **175 of 224 call sites (78%)
  land in `OTHER`**, which the static mode does not examine.

  To answer the review's direct question: **a fixed-for-deployment guard cannot
  be dressed up as a probe.** `STANDING.search(cond)` is evaluated before
  `DEPENDENCY.search(cond)`, so `[ "$(id -u)" -eq 0 ] && command -v git >/dev/null && skip`
  still classifies STANDING (verified). The precedence is correct. The gap is
  vocabulary, not ordering. And `command -v docker` is correctly left to `--tap`
  — the tool documents that trade and it holds.

  The lint also **cannot** pass vacuously on an empty scan: `if not rows: return 2`
  with an explicit "this is not a pass" message, and `--tap` has the matching
  `total_ok == 0 -> return 2`. Both verified by their own tests and by hand. The
  one exception is `--census`, which returns 0 unconditionally; nothing wires it
  today, so it is a hazard rather than a defect.

- **Why it survives review:** the docstring argues persuasively for a
  deliberately narrow static mode, and the argument is right. But narrowness was
  scoped by *shape* (two shapes, not ten) while the actual limit is *vocabulary*
  (seven tokens), and the two are easy to conflate when the seven tokens happen
  to cover the origin case exactly.
- **Suggested fix:** add `id -un`, `$GITHUB_ACTIONS`, `$JENKINS_URL`, `$USER`,
  `-w /etc`, `/root` and `$CURRENT_BRANCH == "HEAD"`-style checkout-state guards
  to `STANDING`; and print the `OTHER` count in the non-census summary as a
  stated blind spot (it already does — make the *docstring* say 78%, so the
  narrowness is legible as a number rather than a claim).

---

### F7. t3204 asserts the new wording by counting source lines, never by running either gauge

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `tests/unit/t3204_budget_cap_legibility.bats:115` (`grep -c 'echo.*budget cap' >= 3`), `:106`, `:127`
- **Failure scenario:** the deliverable is what an operator *reads*. Every
  wording assertion in the suite is a `grep` over `checkpoint.sh` /
  `budget-gate.sh` source. `grep -c 'echo.*budget cap'` counts `echo` **lines**,
  not emitted messages: move any three of those nine echoes into a branch that
  is never taken — a `[ "$level" = "impossible" ]` arm, a function nothing calls —
  and the suite is green while the operator still sees nothing. Neither gauge is
  executed anywhere in the file. (Checked: the nine `budget cap` echoes are in
  fact reachable today, at warn/urgent/critical in both gauges. The point is
  that the test cannot tell.)

  The same file's `--with-model` legs *are* behavioural and well built —
  including the discriminating "a timestamp AFTER a flag is still honoured"
  case, which separates flag-aware from positional parsing. But the
  **consumer** of that contract is untested: `checkpoint.sh:452` pipes
  `--with-model` output through `cut -f1` / `cut -f2` into `tokens` and `model`,
  and nothing runs `checkpoint.sh status` to confirm the join. That is the shape
  L-399 names and t3213 was written to close for the sibling wrapper.

- **Why it survives review:** for a pure wording change a source grep is a
  defensible instrument, and the suite is careful enough elsewhere (the "CONTROL:
  default stdout is a bare integer" leg is the highest-value test in the file)
  that the static legs read as a deliberate choice rather than an omission.
- **Suggested fix:** one leg that runs `checkpoint.sh status` against a synthetic
  transcript and asserts the emitted line contains `-token budget cap` and a
  `Model:` line — which covers the wording *and* the `cut -f1/-f2` join in one.

---

### F8. t3202's doctor-arm helper swallows its own extraction failure, so the negative-only assertion passes green against an empty extraction

- **Severity:** low
- **Confidence:** confirmed (reproduced by breaking the sed address)
- **Location:** `tests/unit/t3202_audit_kill_source.bats:52` (`_run_doctor_arm`), assertion at `:229`
- **Failure scenario:** `_run_doctor_arm` does `[ -s "$TMP_T3202/arm.sh" ] || return 91`
  and runs the case statement under `bash -c "..." 2>/dev/null`. None of the four
  doctor tests check `$status`, and stderr is discarded. Break the sed address
  (rename the arm in `bin/fw`, reorder the arms, change the indent) and the
  extraction is empty:

  ```
  $ sed -i "s|/^        TIMED_OUT|/^        NOSUCHARM_XYZ|" t3202mut.bats
  $ bats --tap --filter provenance t3202mut.bats
  not ok 1 doctor names the derived provenance when the record does not state it
  ok 2   doctor stays silent about provenance when the record states it
  ```

  Test 2 asserts only `[[ "$output" != *"inferred"* ]]`, which an empty string
  satisfies. It is honest to say the exposure is bounded: the three sibling
  tests assert positives, so a *total* extraction failure reddens the file. The
  finding is that this specific test contributes nothing and would not notice a
  doctor arm that died at runtime.
- **Why it survives review:** it is framed as the negative half of a matched
  pair, and matched pairs are exactly the right pattern. The asymmetry is that
  its partner carries a positive anchor and it does not.
- **Suggested fix:** add `[ "$status" -eq 0 ]` and a positive anchor
  (`[[ "$output" == *"KILLED FROM OUTSIDE"* ]]`) to the `recorded` case, so
  "silent about provenance" is asserted about output that demonstrably exists.

---

### F9. t3202's end-to-end leg deletes and restores the repo's live audit-timing file

- **Severity:** low
- **Confidence:** confirmed (read; not executed destructively)
- **Location:** `tests/unit/t3202_audit_kill_source.bats:236`
- **Failure scenario:** the test reads `.context/audits/full-audit-timing.yaml`
  into `PREV`, `rm -f`s it, runs a real 20-second `audit.sh`, then restores from
  `PREV` at the end. If the test is interrupted between the `rm` and the restore
  — bats timeout, `Ctrl-C`, the harness killing the run, an `assert` before the
  restore — the repo's real timing record is gone, and the next `fw doctor`
  reports a state derived from a truncated audit. Every other test in the arc's
  suite writes only into `BATS_TEST_TMPDIR` (L-599).
- **Why it survives review:** the save/restore is visible and looks complete, and
  the end-to-end value is real — this is the only leg that runs the actual
  script under an actual external kill.
- **Suggested fix:** point `AUDIT_TIMING_FILE` at `BATS_TEST_TMPDIR` for the run,
  or move the save/restore into `setup`/`teardown` so the restore runs even when
  the test body aborts.

---

### F10. `test_defect_class_bodies_exist_and_all_changed` asserts only that bodies changed, not that they changed correctly — and both corpus tests are coupled to the mutable live task tree

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `tests/unit/test_ac_body_parser_steps.py:238` and `:252`
- **Failure scenario:** `test_no_widening_over_active_corpus` **skips every body
  carrying a defect-class marker** (`if _defect_class(body): continue`). Since
  `_defect_class` flags any non-canonical `**Steps|Expected|If not` line as `c1`,
  every body exercising the new behaviour is excluded from the sweep. Those
  bodies are covered only by `test_defect_class_bodies_exist_and_all_changed`,
  whose assertion is `_parse_ac_body(b) != _prefix_parse_ac_body(b)` — *changed*,
  not *correct*. A parser that mangled every suffixed heading into garbage
  satisfies it.

  Both tests read the live `.tasks/active` tree at test time. `assert compared > 1000`
  correctly blocks the vacuous case, but it makes the suite a time bomb: as tasks
  close and move to `.tasks/completed/` the count falls, and the test goes red for
  a reason unrelated to the parser. It also cannot run in any consumer project.
  `assert classes == {'c1','c2'}` has the same coupling from the other side.

  Separately, the field-marker regex `^\*\*(Steps|Expected|If not)([^*:]*?)\s*:\*\*\s*(.*)$`
  excludes `:` from the suffix, so `**Steps (T-1055: reauth):**` — a shape this
  repo's `T-XXX:` conventions make likely — is not recognised. None of the four
  parametrised headings at `:172` contains a colon. (The corpus test would catch
  it if such a body existed today; none does.)
- **Why it survives review:** "swept the whole corpus, 1000+ bodies, no widening"
  is a strong-sounding claim and the sweep is real — the exclusion that removes
  all the interesting cases from it is one `continue` on line 244.
- **Suggested fix:** add a handful of frozen golden fixtures (input → expected
  `(steps, expected, if_not)`) for the defect classes, so correctness is asserted
  against a fixed expectation rather than against inequality with the old parser;
  add a colon-in-suffix parametrisation; and lower `compared > 1000` to a value
  that will not expire, or skip the corpus legs when `.tasks/active` is small.

---

### F11. `lib_preflight.bats` carries three assertions that no implementation can fail

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `tests/unit/lib_preflight.bats:90`, `:96`, `:111`
- **Failure scenario:** `check_shellcheck returns 0 or 1` asserts
  `[[ "$status" -eq 0 || "$status" -eq 1 ]]`; `check_git_identity` the same.
  Both functions can only return 0 or 1, so the assertion is a tautology — it
  fails only on a crash or an `exit 2`. `do_preflight --check-only shows
  dependency check output` asserts a three-way OR
  (`*preflight*` || `*OK*` || `*passed*`), which almost any non-empty output
  satisfies. Delete the bodies of both check functions and replace them with
  `return 0` and all three stay green.

  For the record, the arc's actual change to this file is **correct**: the
  `chmod 444` + root-skip was replaced with a non-existent `PROJECT_ROOT`, and
  `check_write_perms` is a single `[ -w "$target" ]` branch, so the missing-path
  denial takes the *same* branch as the permission denial. The comment saying so
  is accurate. That fix is the right shape and the model for F2.
- **Why it survives review:** the tests are pre-existing and read as
  characterisation ("returns 0 or 1" is honest about what it checks). They sit
  in a file the arc touched, which is the only reason they are in scope.
- **Suggested fix:** assert on the *output* (`OK`/`WARN` marker) and on
  `REQUIRED_MISSING`/`RECOMMENDED_MISSING` contents, driven by a `PATH` from
  which `shellcheck` has been removed, so both branches are reachable.

---

### F12. t3209's "degrades to SKIP rather than crashing" test asserts a string the harness prints, not the block's verdict

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `tests/unit/t3209_loop_ledger_cause_attribution.bats:151`
- **Failure scenario:** the test installs a `ps` that exits 127 and asserts
  `echo "$out" | grep -q "WARNCOUNT="`. That string is emitted by `run_block`'s
  own generated runner (`echo "WARNCOUNT=\$warnings"`), *outside* the `_check`
  function and after it returns. The runner sets no `set -e`, so `_check` can
  fail on every line and the assertion still holds. Despite its name the test
  never checks for `SKIP`, and it cannot detect the block behaving badly on a
  missing `ps` — only a hard `exit` from inside `_check` would redden it.
- **Why it survives review:** the file is otherwise exemplary — it carries two
  explicit CONTROL tests, a matched positive/negative pair for the argv-position
  defect, and a cross-project scoping leg. One weak assertion in that company
  reads as deliberate minimalism.
- **Suggested fix:** assert `[[ "$out" == *SKIP* ]]` and `WARNCOUNT=0`, matching
  the sibling tests, so the test measures the degradation it is named for.

---

## Notes that did not reach finding threshold

- **sed-range extraction has no upper bound.** `t3206`, `t3209` and `t3213` all
  slice the doctor block with
  `sed -n '/# Check: continuous-run loop ledger (T-3206/,/# Check: on-PATH claude-fw drift/p'`.
  If the *end* marker moves or is renamed, the range runs to EOF and the
  "extracted and is substantial" controls (`wc -l > 20` / `> 5`) still pass. In
  practice the resulting block would almost certainly fail to execute, so this
  degrades loudly rather than silently — but an upper bound would cost one line.
- **t3220's `after_guard` is anchored, correctly.** It keys on the phrase
  `unreconciled count is not a failure`; if that drifts, three of four cells
  would go vacuous — but the fourth (`return runs straight past the guard`)
  requires non-empty output and reddens. The matrix is self-anchoring. Verified,
  no finding.
- **`fd_dup_not_chain_split.bats` uses bare `! cmd` three times** (lines in the
  SMOKE and both CONTROL tests) despite the arc-wide L-628 warning. Checked all
  three: each is the **final** command of its test, where bats takes the test's
  status from the last command, so the negation does assert. Not inert. No
  finding — recorded because it looks like one.
- **t3221's second no-widening leg does not assert its mutation changed bytes**
  (`:178` seds without the `[ "$n" -eq 1 ]` guard its sibling at `:161` has), so
  a drifted pattern would make it compare the fixed hook against itself and pass
  with `widened=0`. Its sibling would redden, which is why this is a note.
- **t3225's "MUTATION CONTROL" test is not a mutation** — it is a
  both-directions assertion (unarmed `{}` / armed `block`). The name overstates
  it; the test itself is sound and does discriminate.

---

## Q-by-Q

**Q1 — control legs.** Seven of the nineteen files carry a real mutation control
that derives the mutant from live source *and* asserts the mutation changed
bytes: `bats-silent-skip.bats`, `fd_dup_not_chain_split.bats`, `t3212`, `t3213`,
`t3219` (two), `t3221` (two), `t3222`. `t3220` substitutes a four-cell
exit/return × errexit matrix, which is stronger. `t3210`, `t3209`, `t3206` and
`t3225` have discriminating controls but no mutation; in each the extraction
helper fails loudly on a deleted implementation, so "delete the implementation"
does redden them. **The suites that would survive deletion of what they cover:**
t3204's wording legs (F7 — would survive an unreachable-branch refactor, though
not a deletion), t3212 with respect to its *call site* (F4 — survives deletion
outright), and `lib_preflight`'s three tautologies (F11 — survive replacing the
functions with `return 0`).

**Q2 — silent skips.** The lint **does** catch the exact T-3213 origin pattern
(`[ "$(id -u)" -eq 0 ]; then skip` → STANDING, verified). The probe-vs-standing
line is drawn by two vocabularies with STANDING evaluated first, so a
fixed-for-deployment guard **cannot** be dressed up by adding a `command -v`
(verified). `command -v docker` is deliberately left to `--tap`, and that trade
is sound. It **cannot** pass vacuously on an empty scan — both modes return 2
with an explicit "this is not a pass" message. The real weaknesses are F1 (blind
inside quoted heredocs, corrupting the UNCONDITIONAL classification), F6
(vocabulary gap: `id -un`, `$GITHUB_ACTIONS`, `-w /etc/shadow` all pass clean;
78% of call sites land in the unexamined `OTHER` bucket), and F5 (nothing
automated enforces it).

**Q3 — mock-only integration.** Applied by hand to all nineteen. Two hits: F7
(t3204's wording legs assert on source strings that could be true with the
mechanism broken) and F10 (the pytest no-widening sweep excludes the bodies the
fix touches, leaving them covered by an inequality assertion). Everything else
either invokes the shipped code or extracts and executes it — t3209's `fake_ps`
is a mocked data source, but the file explicitly documents the false positive
that mocking hid and adds the argv-position test that mocking removed, which is
the right response rather than an instance of the defect.

**Q4 — the false-green fixes.** t3219, t3220, t3221 and t3222 each reproduce
their original bug faithfully: t3219 drives a copy of the real script with the
one `< /dev/null` redirect removed and shows `2/4 passed`; t3220 shows
`return`-without-errexit running past the guard; t3221's mutant admits both
reported shapes and the no-widening sweep pins the other direction; t3222's
mutant re-opens `curl -o`. None is a simplified proxy. The exception is
`bats-silent-skip` (F1): it pins the *shapes* of the T-3213 skip correctly, but
its heredoc legs test only the direction that produces false positives, and its
one embedded-Python leg passes for an unrelated reason — so the detector's
largest blind spot sits underneath a green suite.

**Q5 — coverage gaps.** Named: (a) the `fw_continuous_note_human_gate` call site
in `update-task.sh:2112` — the arc's headline-mechanic leg 4, zero coverage (F4);
(b) bare `wget URL` / `wget -P` in the fetch-write gate (F3); (c) the
`checkpoint.sh status` → `context_tokens.py --with-model` → `cut -f1/-f2` join
(F7); (d) the wording of both gauges at runtime (F7); (e) a colon-bearing AC
heading suffix (F10); (f) the restart leg of the arc's mechanic — t3213 stubs
`claude` as `exit 0`, so `claude-fw`'s actual re-launch after a handover signal
is not exercised by any suite in this slice.

**Q6 — skipped or guarded tests.** None. All 17 assigned bats suites ran to
completion in this environment: **237 tests, 237 `ok`, 0 `not ok`, 0 `# skip`
lines**, confirmed by feeding the captured TAP back through the arc's own
instrument — `python3 tools/bats-silent-skip-lint.py --tap /tmp/all.tap` →
`silent-skip: 0 of 237 passing test(s) were skipped`, exit 0. The pytest suite
ran 13 tests, 0 skipped. Nothing in this slice is quarantined. The uncovered
ground is not skipped tests — it is F2 (a test that runs but exercises the wrong
path) and the gaps in Q5.

---

## Verdict

| Severity | Count |
|---|---|
| critical | 0 |
| high | 3 (F1, F2, F3) |
| medium | 4 (F4, F5, F6, F7) |
| low | 5 (F8, F9, F10, F11, F12) |

**Do first: F2.** It is the cheapest to fix, it is a false green of exactly the
class this arc exists to eliminate, and the correct fix already exists twelve
lines into a sibling file. `tests/unit/t3206_continuous_run_ledger.bats:119`
claims to verify that the loop's event recorder cannot break the wrapper's
restart path when it fails to write — and, as root, it never fails to write.
Replace `chmod 500` with t3213's `mkdir -p "$LEDGER"` denial and add t3213's
positive control. Then F1, because the instrument built to catch this whole
class is itself blind inside the corpus's most common construct, and F3, because
a green t3222 currently certifies a gate that admits `wget https://…/payload.sh`
with no active task.
