# arc-012 review — W3 close-audit

Reviewer: `arc012-w3-close-audit` (worker 3 of 5)
Slice: `git diff master..arc012-ultrareview` over
`agents/audit/audit.sh`, `agents/designer/designer.sh`, `agents/handover/handover.sh`,
`agents/task-create/update-task.sh`, `lib/audit_timing.py`.
Full post-change files read for every finding below (`git show arc012-ultrareview:<path>`).

---

### F1. The P-011 verification gate skips itself entirely — silently, with no output — whenever its extractor pipeline fails

- **Severity:** critical
- **Confidence:** confirmed (traced and reproduced)
- **Location:** `agents/task-create/update-task.sh:1180-1182`

- **Failure scenario:**
  `verify_cmds=$(extract_verification_block "$TASK_FILE")` followed by
  `[ -z "$verify_cmds" ] && return 0`. The extractor
  (`lib/verification-port.sh:extract_verification_block`) is
  `awk … | python3 lib/comment_strip.py 2>/dev/null | grep -vE … || true`.
  Every failure mode of that pipeline produces the empty string, and the gate
  reads the empty string as *"this task has no `## Verification` section"*.

  Reproduced, three separate inputs:

  1. **One non-UTF-8 byte inside the Verification block.**
     `comment_strip.py` does `sys.stdin.read()` and raises `UnicodeDecodeError`
     (verified: `python3 lib/comment_strip.py < file-with-0xff` → exit 1). stderr
     is swallowed by `2>/dev/null`, the pipeline status by `|| true`. Measured on
     a task file whose block is `false` / `\xff\xfe` / `false`:
     `extract_verification_block` returns a 0-length string, exit 0. The task then
     closes `work-completed` with **zero commands executed and not one line of
     output** — not even "Running 0 verification command(s)".
  2. **`lib/comment_strip.py` absent** (a vendored consumer whose `fw upgrade`
     did not sync it — the file is new-ish and framework-owned). Verified:
     `FRAMEWORK_ROOT=/tmp/no-such-fw` → `LEN=0`. On such a consumer **every**
     task's P-011 gate silently passes, forever.
  3. **`python3` not on PATH.** Same result.

  In all three cases the T-3219 count reconciliation never runs — the early
  `return 0` is 94 lines above it.

- **Why it survives review:** the `[ -z … ] && return 0` line is correct and
  necessary for the legitimate case (a task with no Verification section), and it
  has been there since before this arc. The defect is that "extractor produced
  nothing" and "task has no verification block" are represented by the same value,
  and the extractor's `2>/dev/null … || true` is the very idiom that makes the
  difference unobservable. Everything downstream — the port-literal scan, the
  unjudged-test-run scan, the reconciliation — is skipped too, so there is no
  second surface that could notice.

- **Suggested fix:** distinguish the two states before the early return. The
  cheapest correct form: if the raw task file contains a `^## Verification$`
  heading but the extractor returned empty, refuse (`exit 1`) with the extractor's
  stderr shown, rather than returning 0. Note `update-task.sh:1711` already calls a
  *second, independent* extractor (`static_scan.extract_section(text, "Verification")`)
  a few hundred lines below — disagreement between the two is a free oracle.
  Separately, drop `2>/dev/null` from the `comment_strip.py` leg and check
  `PIPESTATUS`, so a crashing filter cannot be laundered into "clean and empty".

---

### F2. The handover's "Suggested First Action" recency sort is keyed on the raw YAML value including its quote characters — so it is still an ASCII accident, not recency

- **Severity:** high
- **Confidence:** confirmed (reproduced against the live corpus, today)
- **Location:** `agents/handover/handover.sh:1366`

- **Failure scenario:**
  `lu = re.search(r'^last_update:\s*(.+)', content, re.M)` then `lu.group(1).strip()`.
  `.strip()` removes whitespace only — not quotes. The `focus_id` read eleven lines
  above deliberately does `.strip(chr(39) + chr(34))`; this one does not.

  This corpus writes `last_update:` in two shapes:
  ```
  366 last_update: '2026-08-17T12:36:09Z'      # single-quoted
   58 last_update: 2026-08-17T12:36:09Z        # bare
  ```
  `'` is 0x27, `2` is 0x32. Under `sort(key=…, reverse=True)` **every bare-dated
  task outranks every quoted-dated task regardless of date.**

  Measured on `.tasks/active/` at review time (305-task candidate pool, 250 quoted /
  55 bare):
  ```
  SHIPPED picks: T-3215  '2026-08-29T23:19:33Z'
  CORRECT picks: T-3227  '2026-08-31T11:15:17Z'   (today; the live focus task)
  shipped top-5: T-3215, T-3174, T-3147, T-2720, T-1719
  ```
  T-1719 — the task the T-3210 comment names as the wrong answer the *old* code
  produced — is still in the top 5. The fix moved it from #1 to #5; it did not
  make the ordering chronological. Every task touched in the last two days ranks
  below 55 stale ones.

- **Why it survives review:** the comment above the sort makes a true statement
  ("ISO-8601 sorts chronologically as text") about a value the code never isolates,
  and the two-pass stable-sort construction is genuinely correct — so the reviewer's
  attention lands on the sort algebra rather than the key. It is also masked in
  everyday use: when `focus.yaml`'s task happens to be in the candidate pool, the
  `focused` branch (line 1368-1370) short-circuits the whole ordering, so the
  fallback is exercised only in the case F9 describes.

- **Suggested fix:** `lu = lu.group(1).strip().strip("'\"")` — mirroring the
  `focus_id` line. Better: parse to a datetime and sort on that, so a third
  serialisation shape cannot reintroduce this.

---

### F3. An audit run killed after the timing flush is recorded as `timed_out: false` — a killed run written down as a clean one

- **Severity:** high
- **Confidence:** confirmed (traced, plus a structural repro)
- **Location:** `agents/audit/audit.sh:6614-6617` (flush) and `:488-492` (TERM trap)

- **Failure scenario:**
  The flush does `section_mark ""` — which sets `_SECTION_MARK_NAME=""` — and then
  writes the record with `timed_out: false`. The TERM trap is guarded by
  `[ -n "${_SECTION_MARK_NAME:-}" ]`. So from line 6615 onward the trap is a no-op:
  a SIGTERM arriving after the flush writes nothing and leaves the `timed_out:
  false` record standing.

  That window is not a sliver. **390 lines run after the flush** (file is 7001
  lines): `=== SUMMARY ===`, the YAML findings write (three `cut` subshells *per
  finding*), the `LATEST-CRON` symlink, the discovery-findings extraction
  (`should_run_section "discovery"` at line 6682 — a section block that executes
  *after* its own timing was declared final), `=== TREND ANALYSIS ===` (globs
  `$AUDITS_DIR/*.yaml`, greps and seds every WARN/FAIL line of up to 14 past audit
  files), the retention `find`, and the `METRICS HISTORY` Python block (corpus glob
  + `subprocess` git calls). This is exactly where a run that is *close* to its
  ceiling will be when the watchdog fires.

  Repro of the structure (`/tmp/trapsim.sh`): watchdog TERMs 1s after the flush,
  script exits 124, on-disk record reads `timed_out=0 killed= total=0`.

  Two consequences, both false greens:
  1. `fw doctor` prints `OK Full-audit headroom: last run Ns of 3000s` for a run
     that was killed.
  2. `total_seconds` systematically **excludes** the post-flush tail, so the very
     fraction doctor warns on (≥0.70) under-counts the run it claims to measure.
     The headroom can read OK while the true wall-clock is over the ceiling.

- **Why it survives review:** the comment at line 6608 asserts the invariant
  ("Reaching this line means the run was NOT killed by the watchdog — the TERM trap
  owns that path") and it is true *of that line*, just not of the 390 lines after
  it. `section_mark ""` reads as a tidy flush, not as disarming the trap.

- **Suggested fix:** keep the trap armed to the end — replace the
  `-n "$_SECTION_MARK_NAME"` guard with a `_AUDIT_RUN_COMPLETE` flag set on the
  very last line of the script, and let the trap write `timed_out: true` with
  `killed_in_section: "<post-sections tail>"` when that flag is unset. Move the
  `_audit_write_timing_yaml 0` call to the true end of the script so
  `total_seconds` covers the whole run.

---

### F4. `fw doctor`'s audit-headroom line never checks the record's age, and reports a corrupt record as "not measured yet"

- **Severity:** high
- **Confidence:** confirmed
- **Location:** `lib/audit_timing.py:26` (`evaluate`) and `bin/fw:3819-3859`

- **Failure scenario:** two distinct vacuous passes in one check.

  **(a) Staleness is never read.** The record carries `timestamp:` and neither
  `evaluate()` nor the doctor case-statement looks at it. Only *full unscoped*
  `fw audit` runs write the file (by design — see the `AUDIT_TIMING_FILE` comment),
  and the cron jobs are all section-scoped, so in normal operation nothing rewrites
  it for weeks. Concrete: a record written months ago against a smaller corpus and
  a different `ceiling_seconds` yields `OK Full-audit headroom: last run 1729s of
  3000s (58%)` today, on a corpus that would now blow the ceiling. The check reports
  OK about a subject it never measured — the arc's signature class.

  **(b) `UNMEASURED` renders as "not measured yet".** `evaluate()` returns
  `{"status": "unmeasured", "reason": …}` for a file that exists but is corrupt,
  truncated, or missing `total_seconds`/`ceiling_seconds` — and `main()` prints
  `UNMEASURED|<reason>`, which falls into doctor's `*)` arm and prints
  *"Full-audit timing not measured yet — run 'fw audit' (no --section) once to
  populate …"*. Same for `python3 lib/audit_timing.py` failing outright (missing
  PyYAML: `_at_out=$(… 2>/dev/null)` → empty → same arm). The operator is told the
  cause is an absent measurement and sent to re-run the audit; re-running fixes
  nothing, because the file was there all along. This is T-3209's exact shape —
  a cause inferred from an apparent absence — reappearing in the check T-3202 just
  hardened. The `reason` string is computed and then thrown away.

- **Why it survives review:** the fixed-path design is argued carefully in the
  comments, and "latest full run" sounds like a live quantity. The `*)` arm is a
  genuine catch-all whose message is correct for the *common* member of the set it
  catches, which makes the wrong members invisible.

- **Suggested fix:** have `evaluate()` return `age_days` from `timestamp` and add a
  `STALE|` status (WARN: "headroom last measured N days ago — the number below
  describes a corpus that no longer exists"). Split `UNMEASURED` into `absent` and
  `unreadable` and give the latter its own doctor line quoting `reason`.

---

### F5. `kill_source` is derived by the producer using the same inference the consumer labels "derived", but is reported to the operator as "recorded"

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `agents/audit/audit.sh:429-433`; `lib/audit_timing.py:83-95`; `bin/fw:3838-3840`

- **Failure scenario:** `_audit_write_timing_yaml` computes the field it writes:
  ```sh
  if [ "$total" -lt "$AUDIT_TIMEOUT" ]; then echo "  kill_source: external"
  else                                       echo "  kill_source: internal"; fi
  ```
  That is an *inference from the two numbers already in the record*. Nothing
  observes the killer — no signal sender is identified, no watchdog PID is checked,
  no `getppid` is read.

  `audit_timing.py` then treats the mere presence of the field as provenance:
  `if source in ("internal","external"): result["kill_source_derived"] = False`,
  reserving `True` for legacy records where it applies **the identical rule**
  (`"external" if total < ceiling else "internal"`). `bin/fw:3838` uses that flag to
  decide whether to print *"(kill source inferred from total < ceiling — the record
  predates T-3202 and does not state it.)"*.

  Result: for every record written by today's script, doctor **suppresses** the
  inference caveat and the JSON says `provenance=recorded`. The single field whose
  job is to let a reader tell an observation from a deduction reports "observed" for
  a deduction. The failure is legible in the live record on disk right now
  (`.context/audits/full-audit-timing.yaml`: `total_seconds: 900`,
  `ceiling_seconds: 3000`, `kill_source: external`) — a value no instrument measured.

  It is also unsound at the edge it claims to prove: the "internal ⇒ total ≥
  ceiling" direction holds, but the converse used to *write* `internal` does not.
  If the watchdog subshell dies before firing (OOM reap, an errant `pkill sleep`,
  the `sleep` child killed with its parent), an external TERM at `t ≥ ceiling`
  records `kill_source: internal` and doctor emits `FAIL … EXHAUSTED ITS OWN
  CEILING … Raise FW_AUDIT_FULL_TIMEOUT` — precisely the advice T-3202 exists to
  stop giving.

- **Why it survives review:** the reasoning in the comment is genuinely correct
  *as an argument*, and the code implements the argument faithfully. What no one
  compared is the producer's method against the consumer's definition of "derived".
  The two live in different files and different languages.

- **Suggested fix:** either measure it (have the watchdog subshell touch a sentinel
  file immediately before `kill -TERM`, and let the trap report `internal` iff that
  sentinel exists — that is an observation), or stop claiming provenance: emit
  `kill_source_inference: total_lt_ceiling` and have doctor always print the caveat.
  Do not keep a `_derived` flag whose `False` value is unreachable-by-construction.

---

### F6. `_version_gt` reads a non-numeric tag suffix as digits, so a prerelease tag outranks its GA release

- **Severity:** medium
- **Confidence:** confirmed (executed the function)
- **Location:** `agents/designer/designer.sh:308`

- **Failure scenario:** `ai="${a[i]:-0}"; ai="${ai//[^0-9]/}"` deletes non-digits
  *within* a component instead of truncating at the first one. So `0-rc1` → `01` →
  **1**, and `0-hotfix2` → `02` → **2**. Executed:
  ```
  0.10.0 > 0.9.0        : TRUE     (the T-3158 fix works — integer tuple, good)
  1.0.0-rc1 > 1.0.0     : TRUE     <- prerelease beats GA
  0.9.0-hotfix2 > 0.9.1 : TRUE     <- suffix read as a patch number
  ```
  Two consequences in `do_check_currency`:
  - **Bad advice:** origin publishes `designer-v1.0.0` and `designer-v1.0.0-rc1`;
    the pin is current at `1.0.0`. `latest` resolves to `1.0.0-rc1`, so the probe
    WARNs *"designer pin is behind its origin — pinned 1.0.0, newest released
    1.0.0-rc1"* and tells the operator to `fw designer sync --from-tag` onto a
    release candidate.
  - **False green:** the pin sits at `0.12.0-rc1` and the origin has since published
    GA `designer-v0.12.0`. `latest` = `0.12.0-rc1` (it beats `0.12.0` by the same
    rule), `latest == ver`, so the `else` arm prints `OK designer pin current with
    origin (newest released 0.12.0-rc1)` while the GA release sits unconsumed.
    That is T-3119's original bug — releases unconsumed while every instrument
    says OK — reachable through the check written to prevent it.

  Junk tags corrupt the answer the same way: `designer-v99abc` → `99` → becomes
  "newest released", masking the real newest tag.

- **Why it survives review:** the AC that mattered (`v0.10.0` beats `v0.9.0`) is
  satisfied, the comment names the exact lexical trap it avoids, and the digit-strip
  looks like defensive normalisation. Suffixed tags are the case nobody wrote a
  fixture for.

- **Suggested fix:** truncate at the first non-digit rather than deleting non-digits
  (`ai="${ai%%[!0-9]*}"`), and skip tags that do not match `^[0-9]+(\.[0-9]+)*$`
  outright rather than coercing them — an unparseable tag should not be able to
  become `latest`.

---

### F7. The gate evaluates each line as an `if` condition, so POSIX suppresses errexit and only the last command of a `;`-chain reaches the verdict

- **Severity:** medium
- **Confidence:** confirmed (executed the real construct)
- **Location:** `agents/task-create/update-task.sh:1243`

- **Failure scenario:** `if ( … eval "$cmd" ) > … ; then`. The subshell is the
  condition of an `if`, so `set -e` is ignored throughout it. Executed against a
  faithful copy of the shipped construct:
  ```
  PASS: cd /nonexistent-dir-xyz; echo ok
  PASS: false; true
  total=3 pass=3 fail=0
  ```
  A verification line whose real assertion is anywhere but the final segment is
  unconditionally green. `cd /nonexistent; <assert>` is worse than useless: the
  `cd` fails, the assertion then runs in the *wrong directory*, and whatever it
  reports is accepted. **2,644 of the corpus's 10,997 verification lines contain
  `;`.**

  Nothing in this diff narrows this. T-3219 added `< /dev/null` (which is correct
  and, as far as I can trace, complete for fd 0 — see the "checked, no finding"
  note below) and a count reconciliation, both of which are about *whether a line
  ran*. Neither is about *whether a line's verdict means anything*. The
  `< /dev/null` comment even documents the reconciliation as guarding the class,
  which invites the reader to assume the verdict path was examined too.

- **Why it survives review:** it is the gate's original shape, not a change, and
  each individual `;`-line looks like a reasonable command. A green line that
  asserts nothing is byte-identical to a green line that asserts everything — the
  same property that let the port-3000 class reach 371 instances.

- **Suggested fix:** run each line through `bash -euo pipefail -c "$cmd"` (as a
  *command*, capturing `$?`, not as an `if` condition), so an early segment's
  failure is the line's failure. That is a behaviour change for existing tasks, so
  pair it with a corpus scan of the 2,644 `;`-lines and a `FW_ALLOW_LAX_VERIFY=1`
  Tier-2 escape for the migration window.

---

### F8. The T-3219 count reconciliation derives both sides from the same string, so it cannot see an extraction-level shrink — the class it was written to catch

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `agents/task-create/update-task.sh:1199` vs `:1276`

- **Failure scenario:** `verify_total=$(echo "$verify_cmds" | wc -l)` and the loop
  is `done <<< "$verify_cmds"`. The comparison is therefore
  *lines-in-the-extracted-string* against *iterations-over-the-extracted-string*.
  It is a genuine and correct guard against the loop *abandoning* the block (the
  stdin-swallow of T-3219, an early `break`, a `continue` on an unexpected blank).
  It is structurally incapable of detecting the block being *smaller than the task
  file says*, because the denominator shrinks in lockstep with the numerator.

  Concretely: F1's total collapse reconciles trivially (0 == 0 — and does not even
  reach the check). So does the T-2921 DOTALL class, whose original symptom was
  literally *"Running 2 verification command(s) / 2/2 passed"* over a three-command
  block. So does any future extractor regression that drops lines. The task-file
  heading count — the only independent measurement available — is never taken.

  This is the "false green guarding against false greens" the directed question
  asked about: for the class where a command *vanishes before counting*, the
  reconciliation passes vacuously.

- **Why it survives review:** the comment's argument ("a denominator is evidence
  only if something compares it to the numerator") is exactly right, and the check
  does what the comment says. What the comment does not say is that both halves of
  the comparison share a single provenance, so the check is a self-consistency
  assertion rather than a cross-check.

- **Suggested fix:** count a third, independent number — non-blank non-comment lines
  between `^## Verification$` and the next `^## ` **in the raw task file** — and
  reconcile against that. Any disagreement is either an extractor bug or a loop bug,
  and both are things the gate must refuse on.

---

### F9. The T-3210 focus override only fires when the focused task is already in the candidate pool; and its stated premise (a `## Current Focus:` section) does not exist

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `agents/handover/handover.sh:1368` (code), `:1347-1351` (comment)

- **Failure scenario:** `focused = [c for c in candidates if c[3] == focus_id]`.
  `candidates` is filtered to `status: started-work` **and** `horizon: now|next`
  **and** no `**Decision**: DEFER`. So whenever the session's focus is on a task
  that is `captured` (setting focus does not require `started-work`), parked to
  `later` mid-session, DEFERed, or already archived to `completed/`, `focused` is
  empty and control falls through to `candidates[0]` — i.e. straight into F2's
  broken ordering. The handover then hands the next session a different task from
  the one this session was actually on, which is the contradiction T-3210 was filed
  to remove, still reachable through the door the fix left open. In a continuous
  run that resumes across a restart, this is the difference between resuming the
  work and resuming *someone else's* work.

  Second, smaller defect in the same block: the comment justifies the override with
  *"The handover already prints '## Current Focus:' a few sections up; a suggestion
  that names a different task contradicts it in the same document."* Grepping the
  post-change `handover.sh` for `Current Focus` returns **only that comment** — the
  script emits `## Current Arc` (line 782, sourced from `arc-focus.yaml`, a
  different file and a different concept) and no focus section at all. Confirmed
  against the generated artefact: `.context/handovers/LATEST.md` has 26 `##`
  headings; `Current Focus` is not among them. A false stated reason for a real
  change — the T-3220 class. It also means the property that actually matters for
  the loop (the next session lands on the focus task) rests entirely on this one
  line, with no second statement of focus anywhere in the document to contradict or
  corroborate it.

- **Why it survives review:** the override is correct and visibly works in the
  common case (focus on an active `now` task), which is what a reviewer will
  hand-test. The comment's premise reads as a statement about a document the
  reviewer has not opened.

- **Suggested fix:** when `focus_id` is set but absent from `candidates`, do not
  fall through silently — print `Continue {focus_id}` with a one-clause note of why
  it is off-pool ("focus task is horizon:later / captured — confirm before
  resuming"). Either add the `## Current Focus:` section the comment promises, or
  correct the comment.

---

### F10. The branch named in the merge-back nudge is re-derived independently of the branch the divergence was measured against

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `agents/handover/handover.sh:450`; same shape at `agents/audit/audit.sh:2554`

- **Failure scenario:** the numbers come from `fw_branch_divergence`, which picks
  its comparand as `origin/$dev` **if that remote-tracking ref exists**, else
  `origin/master` (`lib/branch-hygiene.sh:336-340`). The name comes from
  `_fw_bh_dev_name`, which returns `$dev` if `origin/$dev` **or `refs/heads/$dev`**
  exists (`:394-396`). The two disagree on exactly one input: **a local
  `bleeding-edge` branch that has never been pushed.**

  On such a repo (a fresh clone that created the dev branch locally; a consumer
  mid-migration), a feature branch 60 commits behind `origin/master` produces:
  > **Merge-back overdue:** `t3227-x` is 60 commits behind origin/**bleeding-edge**
  > … land the strand with `fw integrate run bleeding-edge --push`

  `origin/bleeding-edge` does not exist. The count was measured against
  `origin/master`. The handover asserts a divergence against a ref that is not on
  disk, and the remediation targets a branch the operator cannot push to — and per
  §Copy-Pasteable Commands this line is what SessionStart injects into the next
  session, with the framework's authority behind it.

  `lib/branch-hygiene.sh:381-384` states outright that the two resolvers are *not*
  unified ("they prefer different refs, deliberately"), while `handover.sh:449`
  claims the nudge "has to name the branch the divergence was measured from" — the
  helper it calls does not read that at all.

- **Why it survives review:** on this host `origin/bleeding-edge` exists, so both
  resolvers agree and the output is correct. The divergence only appears on repos
  in a state the framework developer's machine is never in — the same
  fresh-machine class as T-1633.

- **Suggested fix:** have `fw_branch_divergence` emit its comparand on the
  `divergence …` line (`target=origin/master`) and have the consumers parse it,
  rather than re-deriving a name. One measurement, one name.

---

### F11. Timing coverage gaps: the audit preamble is unattributed, and the no-`flock` arm records nothing at all

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `agents/audit/audit.sh:765`, `:775` (unmarked); `:493-510` (fallback arm)

- **Failure scenario:** three related gaps, each of which makes the record answer
  a narrower question than it appears to.
  1. The two single-pass corpus scans at lines 765 and 775 run **before** the first
     `section_mark`. Their time lands in `total_seconds` but in no `sections:`
     entry — measured on the live record: `total 900, sum(sections) 859, delta 41`.
     A reader summing the sections to find the expensive one is 41s short with
     nothing saying so.
  2. A SIGTERM during that preamble hits the trap with `_SECTION_MARK_NAME=""`, so
     **nothing is written** — the run vanishes without a trace. That is precisely
     the T-3070 evidential vacuum this instrument exists to close.
  3. The non-`flock` arm (`else`, line 493) installs an EXIT trap only. There is no
     TERM trap there, so on a host without `flock` — the arm the surrounding
     comment itself flags as "a mac or a slim container is most likely to miss" —
     an external kill leaves no record, and a stale `timed_out: false` record from
     a previous run stands as the current answer.

- **Why it survives review:** the section list looks exhaustive because all 24
  `should_run_section` blocks are marked; the two *unmarked* expensive blocks are
  not section blocks at all, so they are not in the list a reviewer walks.

- **Suggested fix:** `section_mark "preamble"` before line 765; hoist the TERM trap
  above the `if command -v flock` split so both arms carry it; and have
  `_audit_write_timing_yaml` emit `unattributed_seconds: $((total - sum))` so the
  gap is stated rather than left to be discovered by subtraction.

---

### F12. `do_check_currency` advertises an escape hatch it does not implement

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `agents/designer/designer.sh:364`

- **Failure scenario:** the unreachable-origin SKIP prints *"Set
  FW_SKIP_DESIGNER_CURRENCY=1 to skip this probe on offline runs."* The function
  never reads that variable — only `bin/fw:2262` does. So an operator or CI job
  that follows the printed instruction and then runs `fw designer check-currency`
  directly (the standalone verb this task exists to add, and the one the header
  recommends for "CI, cron, manual probe") still pays the 10s `git ls-remote`
  timeout on every invocation. The message is correct only for the caller that
  did not print it.

- **Why it survives review:** the doctor path *does* honour the flag, so testing
  via `fw doctor` confirms the message. The verb is new and its standalone path is
  the one nobody exercised.

- **Suggested fix:** early-return with the SKIP line in `do_check_currency` when
  `${FW_SKIP_DESIGNER_CURRENCY:-0} = 1`, and let doctor's existing branch remain as
  the fast path. Also add `check-currency` to the unknown-verb hint at line 481,
  which still lists only `status|path|sync|install|url|draft`.

---

## Checked and found nothing — with what was checked

These are stated explicitly because "no findings" without evidence of looking is
itself a false green.

- **Q1, the `< /dev/null` fix is complete for stdin.** The redirect is applied to
  the whole subshell at `update-task.sh:1243`, so fd 0 inside it is `/dev/null` and
  the herestring feeding `done <<< "$verify_cmds"` is unreachable from the
  command — including from a forked child (it inherits `/dev/null`), a `while read`
  inside a sourced file (same fd 0), or a command that reopens `/dev/tty` (a
  different device; it cannot reach the loop's descriptor). I could not construct
  an input that lets an eval'd command consume the loop's remaining lines. The
  other stdin-inheriting statements in the loop body (`echo | sed`, `head -5 <file>`,
  the `$(type … && keylock_subshell_close_cmd)` substitution) either take a file
  argument or read a pipe, and none reads fd 0. **The stdin leg of T-3219 is
  closed.** The residual exposure is F7 (verdict semantics) and F8 (population),
  not stdin.

- **Q1, the T-3220 `exit`-vs-`return` comment.** I verified the two claims it
  makes: `set -euo pipefail` is live at `update-task.sh:14`, and the call site is a
  bare statement — so a `return 1` would in fact abort. The comment states the
  measured behaviour, names the earlier revision that got it wrong, and cites the
  test that pins it. No finding; this one is correct.

- **Q3, `total < ceiling` for the internal watchdog.** I traced the ordering: the
  watchdog subshell is armed after lock acquisition, sleeps `AUDIT_TIMEOUT`, and the
  trap runs only once the in-flight foreground command returns — so `SECONDS` at
  trap time is `startup + AUDIT_TIMEOUT + tail ≥ ceiling`. The *direction the
  docstring proves* (internal ⇒ `total ≥ ceiling`) holds. The defect is the
  converse being used to write the field, and the provenance label — F5.

- **Q5, unreachable origin cannot render as OK.** Traced every exit path of
  `if ls=$(… timeout 10 git ls-remote …)`: `timeout` returns 124, a git transport
  failure returns non-zero, a missing `git` returns 127 — all land in the `else`
  SKIP arm with its own distinct wording. An origin that answers but publishes no
  matching tags gets a *third*, separately-worded SKIP. `GIT_TERMINAL_PROMPT=0` +
  ssh `BatchMode=yes` + `ConnectTimeout=5` prevent a credential prompt from
  hanging. **The three states are properly separated; a failure to read the origin
  cannot print OK.** The integer-tuple comparison also passes the stated AC
  (`0.10.0 > 0.9.0` → TRUE, `0.9.0 > 0.10.0` → false). The defect is F6, inside a
  version string, not at the reachability boundary.

- **`extract_verification_block`'s blank/comment claim.** The reconciliation comment
  asserts it "cannot false-positive on blank or comment lines". I checked the
  extractor's trailing `grep -vE '^\s*$|^\s*#|^\s*```'` against the loop's
  `sed 's/^[[:space:]]*//'` trim: GNU grep's `\s` is `[[:space:]]`, so the two agree
  on what counts as blank. I could not construct a line that survives extraction but
  trims to empty in the loop (other than the degenerate `echo`-eats-`-n`/`-e` case,
  which requires a verification line that is literally `-n`). The claim holds.

---

## Verdict

| Severity | Count |
|---|---|
| critical | 1 |
| high | 3 |
| medium | 6 |
| low | 2 |
| **total** | **12** |

**Do first: F1.** It is the only finding that disarms a gate *completely and
silently*, it needs no unusual state to trigger on a consumer (a missing
`comment_strip.py` or no `python3` is enough, forever, for every task), and it sits
upstream of everything else in this arc's close path — the port-literal scan, the
unjudged-test-run scan, and T-3219's own reconciliation are all skipped by the same
early `return 0`. Every other finding in this report describes a gate that reports
the wrong answer; F1 describes a gate that does not run and says nothing at all.

The pattern across F1, F3, F4 and F8 is one shape: **an absence being read as a
clean result.** An empty extraction read as "no verification block"; a disarmed
trap read as "not killed"; a stale or unreadable record read as "never measured";
a shrunken population read as a reconciled count. Wherever this codebase writes
`|| true`, `2>/dev/null`, or `[ -z … ] && return 0` on the path of an instrument,
that is the question to ask.
