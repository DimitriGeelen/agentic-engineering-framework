# arc-012 ultrareview — W5 `cli-surface`

Slice: `bin/fw`, `web/blueprints/tasks.py`, `policy/prompts/landing-mode.md`,
`VERSION`, seven `.fabric/components/*.yaml` cards.
Branch reviewed: `arc012-ultrareview` (full post-change files read, not diffs alone).

Line numbers are against `git show arc012-ultrareview:bin/fw` /
`:web/blueprints/tasks.py`.

---

### F1. Doctor's turn-driver check is reachable only from one branch of the wrapper-ledger check, so the arc's central question goes unasked in three of four ledger states

- **Severity:** high
- **Confidence:** confirmed (traced)
- **Location:** `bin/fw:2441` (inside `case "$_crl_ev" in start|iterate)`)
- **Failure scenario:** the whole `lib/continuous-mode.sh` probe — the only
  instrument that answers "is the turn driver armed?" — sits inside the
  `start|iterate)` arm of the `continuous-run.jsonl` case. Concrete state: the
  operator arms the loop with `fw continuous arm --hours 4 --iterations 3`, but
  launches the session with plain `claude` (or the ledger was never written —
  see F9). `.context/working/continuous-run.jsonl` is absent, so doctor takes the
  `else` branch at `bin/fw:2510` and prints
  `SKIP Continuous-run loop never recorded … so this is expected`, exits 0, and
  **never evaluates `.continuous-mode.yaml` or `.next-directive.yaml` at all**.
  The same hole exists for the `exit)` arm (`bin/fw:2486`) and the `EMPTY`/`*`
  arms: a wrapper that stopped hours ago plus a turn driver whose directive
  lapsed in June produce a single WARN about the wrapper and total silence about
  the driver. The inverse also holds — a lapsed directive with a healthy wrapper
  is only caught when the ledger's *last* line happens to be `start`/`iterate`.
- **Why it survives review:** the block carries an unusually good comment
  explaining that the wrapper ledger and the turn driver are different questions
  with different answers — and then places the answer to the second question
  inside the arm where the first one is already green. Reading the comment, you
  assume the check is unconditional.
- **Suggested fix:** hoist the `fw_continuous_cli status` probe out of the `case`
  so it runs on every doctor pass, and print its verdict as its own line
  independent of the ledger's state.

---

### F2. Any non-zero exit from `fw continuous status` is reported as "the TURN DRIVER is not armed", including exits that mean the probe could not read

- **Severity:** high
- **Confidence:** confirmed (traced; exit codes read from `lib/continuous-mode.sh`)
- **Location:** `bin/fw:2444-2450`
- **Failure scenario:** `if _crl_live=$(fw_continuous_cli status 2>/dev/null)`
  treats every non-zero status as "not armed". `fw_continuous_cli` returns **2**
  on an unrecognised option and **4** when `pyyaml` is unavailable
  (`lib/continuous-mode.sh`: `print("fw continuous: pyyaml unavailable",
  file=sys.stderr); sys.exit(4)`). Concrete input: a host or container where the
  framework's Python has no PyYAML (a documented degradation elsewhere in this
  same repo — `fw_continuous_note_task_completed` explicitly no-ops on
  `ImportError`). Doctor then prints
  `WARN …but the TURN DRIVER is not armed — the loop takes no turns` on a loop
  that is in fact armed and taking turns. Worse, the diagnostic line
  (`sed -n 's/^  Reason (live): /…/p'`) prints **nothing**, because on exit 4 the
  message went to stderr and stderr was discarded by `2>/dev/null` — so the
  operator gets a WARN with no reason. The remediation offered,
  `bin/fw continuous arm --hours N --iterations N`, then resets
  `current_iteration: 0` and `tasks_completed: 0` on a run already in progress,
  silently extending both ceilings.
- **Why it survives review:** the exit-code contract is genuinely elegant
  (`status` exits 0 iff ARMED), and the call site reads like a correct use of it.
  The bug is that the contract has **three** classes of non-zero and the call site
  has two branches. This is L-575 — the principle the same block cites twelve
  lines earlier for the designer check — applied to the designer check but not to
  this one.
- **Suggested fix:** branch on the exact exit code: `0` → ARMED, `1` → not armed
  (print the reason), anything else → a distinct `SKIP … could not evaluate` line
  that captures stderr instead of discarding it.

---

### F3. The Stop hook — the turn driver for the entire loop — is not in doctor's `expected` hook map, so its total absence reports `OK`

- **Severity:** high
- **Confidence:** confirmed (traced; `grep` for `stop-driver` in the whole file
  returns only comment lines)
- **Location:** `bin/fw:2578-2585`
- **Failure scenario:** `expected` lists six scripts (`check-active-task.sh`,
  `check-tier0.sh`, `check-project-boundary.sh`, `budget-gate.sh`,
  `checkpoint.sh`, `error-watchdog.sh`). `agents/context/stop-driver.sh` is not
  among them, and no other doctor check mentions it (`grep -n
  "stop-driver\|Stop hook" bin/fw` → four comment hits, zero assertions). Delete
  the `Stop` entry from `.claude/settings.json`, or let `fw init --provider
  claude --force` regenerate a settings file without it, and `fw doctor` prints
  `OK Hook configuration valid (N hooks in M matchers across K events)`. The
  continuous-run loop then takes exactly one turn per session, forever, with
  every instrument green — the T-3226 defect inverted from false FAIL to false OK
  on the *same* subject.
- **Why it survives review:** T-3226 spent a 25-line comment on this exact hook
  and fixed the path-expansion bug that made it read as missing. Having just read
  that comment, the natural conclusion is that the Stop hook is now the
  best-covered entry in the check. It is in fact the only one whose presence is
  not asserted at all.
- **Suggested fix:** add `'stop-driver.sh': 'Stop'` to `expected`. The existing
  `basename in expected` tracking already handles direct-script hooks, so this is
  a one-line change.

---

### F4. `fw continuous arm` writes two files non-atomically; a failure on the second leaves exactly the enabled-plus-lapsed-directive state the verb was built to prevent

- **Severity:** high
- **Confidence:** confirmed (traced)
- **Location:** `bin/fw:5419` (dispatch) → `lib/continuous-mode.sh`, the `arm`
  tail: `save(sp, state)` … `save(dp, directive)`
- **Failure scenario:** `arm` writes `.continuous-mode.yaml` (`enabled: True`,
  `current_iteration: 0`, `last_terminated_reason: None`) and *then* writes
  `.next-directive.yaml` (`filed_at`, `expires_at`, `max_iterations`). If the
  second `save` raises — `.next-directive.yaml` owned by another uid, the
  filesystem full, `os.replace` across a boundary — the exception propagates as a
  Python traceback, the shell sees exit 1, and the first file is already
  committed. Result on disk: `enabled: true` with the **previous**
  `expires_at`, which is the literal 74-day state named in the function's own
  header ("a run can be `enabled: true` and still stop dead on a directive expiry
  from months ago"). The operator sees a traceback, not a status line, and no
  `status` re-check runs on that path.
- **Why it survives review:** each individual `save()` is carefully atomic
  (`mkstemp` + `os.replace`), which makes the sequence look transactional. It is
  not — atomicity per file is not atomicity across two files, and the header's
  promise "Both legs are set together here, or not at all" is not implemented by
  anything.
- **Suggested fix:** write the directive first (the file whose staleness is
  harmless while disarmed), then the state; or wrap both in a `try` that restores
  the prior `.continuous-mode.yaml` on failure and re-prints `status`.

---

### F5. Doctor discards the reason `lib/audit_timing.py` supplies for an unmeasurable record and substitutes one hard-coded cause

- **Severity:** medium
- **Confidence:** confirmed (traced both sides)
- **Location:** `bin/fw:3855-3856` (the `*)` arm of the `_at_out` case)
- **Failure scenario:** `lib/audit_timing.py` emits five shapes;
  `UNMEASURED|<reason>` is one of them, with reasons `str(exc)` (YAML/OS error) or
  `missing/invalid total_seconds or ceiling_seconds`. `bin/fw`'s case has arms for
  `TIMED_OUT|`, `KILLED_EXTERNAL|`, `WARN|` and `OK|` — **no `UNMEASURED|` arm**.
  Concrete input: `.context/audits/full-audit-timing.yaml` exists but its
  `last_run.ceiling_seconds` is `0` or absent (a partially-written record from a
  killed run, exactly the case T-3202 exists for). The module returns
  `UNMEASURED|missing/invalid total_seconds or ceiling_seconds`; doctor falls to
  `*)` and prints `INFO Full-audit timing not measured yet — run 'fw audit' (no
  --section) once to populate …`. The file *is* populated; the advice is wrong;
  the reason the module went to the trouble of computing is thrown away. The same
  arm also catches a genuine Python crash, because the invocation is
  `python3 … 2>/dev/null`.
- **Why it survives review:** the four explicit arms cover the interesting
  classifications and read as exhaustive; `*)` reads as "no file yet", which is
  the common case and is correct for it.
- **Suggested fix:** add `UNMEASURED\|*)` printing the module's own reason, and
  drop `2>/dev/null` (or route stderr into the printed line) so a crash is
  distinguishable from an unmeasured record.

---

### F6. The designer-currency delegation prints a blank line and counts nothing when the delegate produces no output

- **Severity:** medium
- **Confidence:** confirmed (traced; blank-line behaviour verified empirically)
- **Location:** `bin/fw:2268-2274`
- **Failure scenario:** `_dc_out=$(… designer.sh check-currency 2>&1) || true`,
  then `while IFS= read -r _dc_line; do echo -e "  $_dc_line"; done <<< "$_dc_out"`.
  If `_dc_out` is empty — the script exits early under `set -e`, a sourced helper
  aborts, `$AGENTS_DIR/designer/` is missing from a partial vendor — the herestring
  yields one empty line and doctor prints two spaces. No `OK`, no `WARN`, no
  `SKIP`, `warnings` is not incremented, doctor exits 0. Verified:
  `out=""; while IFS= read -r l; do echo "[  $l]"; done <<< "$out"` → one blank
  iteration.
- **Why it survives review:** the block's comment is explicit that "Both skips
  print a line — never silence, which would read as 'current'." That guarantee was
  true when the three branches were inline. Extracting the probe moved the
  guarantee into a second process, and nothing at the call site re-asserts it.
- **Suggested fix:** `if [ -z "$_dc_out" ]; then echo SKIP … "currency probe
  produced no output"; warnings=$((warnings+1)); fi` before the loop.

---

### F7. The WARN detector for the delegated currency probe uses a GNU-only sed escape; on BSD sed the WARN prints but is never counted

- **Severity:** medium
- **Confidence:** plausible (behaviour on GNU sed verified here; BSD sed not
  available in this environment — the divergence is a documented `\x` escape
  incompatibility)
- **Location:** `bin/fw:2272`
- **Failure scenario:** `printf '%s\n' "$_dc_out" | sed 's/\x1b\[[0-9;]*m//g' |
  grep -q '^WARN'`. `agents/designer/designer.sh:46` sets colours
  **unconditionally** — no tty check — so the delegate's output always begins with
  a literal ESC. GNU sed interprets `\x1b`; BSD/macOS sed does not, and treats the
  pattern as the literal `x1b\[…`. Simulated here:
  `printf '\033[0;33mWARN\033[0m x' | sed 's/x1b\[[0-9;]*m//g' | grep -c '^WARN'`
  → `0`, versus `1` with `\x1b`. On macOS, therefore, a designer pin that is
  genuinely behind its origin prints a yellow `WARN` line *and* `fw doctor`
  reports `0 warnings` and exits 0 — a green summary contradicting a red line, in
  a project whose fourth constitutional directive is portability and which ships
  `brew install` instructions. This is the only `\x1b` sed idiom in `bin/fw`.
- **Why it survives review:** it works perfectly on the origin host, and the
  printed WARN line makes the check look effective even where the count is lost.
- **Suggested fix:** use `$'\033'` (bash ANSI-C quoting, portable) or a
  `tr -d '\033'` + bracket-class strip; or have `check-currency` emit a
  machine-readable status on a separate stream and key the count off that.

---

### F8. Doctor's currency gate is anchored at `PROJECT_ROOT` while the delegate defaults to `FRAMEWORK_ROOT`, so the check is unconditionally absent on every vendored consumer

- **Severity:** medium
- **Confidence:** confirmed (both paths read; pin location verified on disk)
- **Location:** `bin/fw:2260` vs `agents/designer/designer.sh:44`
- **Failure scenario:** doctor gates on
  `[ -f "${FW_DESIGNER_PIN_FILE:-$PROJECT_ROOT/policy/designer-pin.yaml}" ]`, with
  **no `else`**. The delegate resolves
  `PIN_FILE="${FW_DESIGNER_PIN_FILE:-${FRAMEWORK_ROOT:-$PROJECT_ROOT}/policy/designer-pin.yaml}"`
  — FRAMEWORK_ROOT first. In this repo the two coincide. In a consumer the pin
  ships inside the vendored framework (verified:
  `.agentic-framework/policy/designer-pin.yaml` exists, and a consumer has no
  `policy/` at its root), so `fw doctor` on that consumer prints **nothing at all**
  for currency, while `fw designer check-currency` run by hand on the same project
  would find the pin and could emit `WARN … behind its origin`. Two surfaces, one
  subject, opposite answers, and the silent one is the one on the daily rail.
- **Why it survives review:** the sibling EXPOSURE check above uses the same
  `PROJECT_ROOT` anchor and documents the silence as deliberate ("Consumers
  without a pin are unaffected"). The currency block inherits the anchor and the
  apparent justification, but its own comment promises the opposite ("never
  silence").
- **Suggested fix:** anchor doctor's gate the same way the delegate does
  (`${FRAMEWORK_ROOT:-$PROJECT_ROOT}`), or drop the gate and let the delegate emit
  its own `SKIP … no pin` line.

---

### F9. The T-3209 process probe matches only two argv shapes and misses the on-PATH wrapper that doctor itself tells operators to launch

- **Severity:** medium
- **Confidence:** confirmed (live process table inspected)
- **Location:** `bin/fw:2499-2504`
- **Failure scenario:** the awk matcher compares argv[0]/argv[1] against exactly
  `$PROJECT_ROOT/bin/claude-fw` and `$PROJECT_ROOT/.agentic-framework/bin/claude-fw`.
  `claude-fw` is installed on PATH as a **copy**, not a symlink — doctor's own
  drift check at `bin/fw:2531` says so ("claude-fw lives in up to four places …
  `~/.local/bin` symlink") and its remediation ends `Then relaunch the session
  with: claude-fw`. A session launched that way shows
  `/bin/bash /root/.local/bin/claude-fw` in `ps`, matching neither pattern.
  Verified on this host: pid `545360` is
  `/bin/bash /home/dimitri-mint-dev/.local/bin/claude-fw` and would not match. The
  probe then returns empty and doctor prints
  `SKIP … No claude-fw wrapper is running for this project either, so this is
  expected. Launch with: claude-fw` — to an operator already inside claude-fw.
  That is verbatim the false attribution T-3209 was filed against, merely
  narrowed. Second instance in the same block: if `ps` is unavailable
  (`command -v ps` fails — a slim container), `_crl_pids` stays empty and the same
  SKIP asserts "No claude-fw wrapper is running" on the strength of a probe that
  never ran.
- **Why it survives review:** the argv-position matcher is a genuinely good fix
  for the substring false positive it replaced, and the comment explaining why
  `pgrep -af | grep -F` is wrong is convincing. It just answers a narrower
  question than the message it gates.
- **Suggested fix:** match on basename `claude-fw` in argv[0]/argv[1] and confirm
  project ownership from `/proc/<pid>/cwd` or the process's `PROJECT_ROOT` env
  rather than from the invocation path; and give the `ps`-unavailable case its own
  "could not check" wording.

---

### F10. `fw test lint`'s silent-skip section is guarded by a file-existence test, so a missing linter is indistinguishable from a clean one — and it is missing right now in the vendored copy

- **Severity:** medium
- **Confidence:** confirmed (both facts verified on disk)
- **Location:** `bin/fw:9330-9341`
- **Failure scenario:** `if [ -f "$FRAMEWORK_ROOT/tools/bats-silent-skip-lint.py" ];
  then … fi` with no `else`. When the file is absent the entire
  `=== Silent-Skip Lint ===` heading, verdict and `_test_exit` contribution
  disappear and `fw test lint` reports pass. Live instance on this checkout:
  `.agentic-framework/bin/fw` **does** carry the block (line 9260 of the vendored
  copy) while `.agentic-framework/tools/bats-silent-skip-lint.py` **does not
  exist** — so `fw test lint` run through the vendored framework today omits the
  lint silently and reports success. The tool itself gets this right internally
  (`return 2` with "a scan that examined nothing must not read as clean"); the
  wrapper defeats that one level up.
- **Why it survives review:** the guard reads as ordinary defensive coding, and
  the comment beneath it discusses exit 2 in detail — which makes the reader
  assume the "nothing was scanned" case is handled. It is handled inside the tool,
  and only when the tool runs.
- **Suggested fix:** `else echo "FAIL silent-skip lint tool missing at …";
  _test_exit=1; fi`, and add `tools/` to whatever `fw vendor self` copies.

---

### F11. landing-mode.md's push criterion reads a section-scoped fail count as if it were a whole-audit verdict

- **Severity:** medium
- **Confidence:** confirmed (traced through `hooks.sh` and `audit.sh`)
- **Location:** `policy/prompts/landing-mode.md` §The Prompt — "Check
  `AUDIT-SCOPE: fails=0` on every push"
- **Failure scenario:** the pre-push hook runs `"$AUDIT_SCRIPT" --section
  structure` (`agents/git/lib/hooks.sh:1112`) and tees its output, so the
  `AUDIT-SCOPE:` line the agent sees on a push is emitted at
  `agents/audit/audit.sh:6977` with `FAIL_COUNT` **for the structure section
  only**. An agent following landing mode literally treats `fails=0` as the
  landing gate for "closed, verified, committed, pushed". A real FAIL in any other
  audit section — cron drift, arcs, drivers, retire_when, the T-1943 registry leg —
  is not in that number, and the run reports a clean landing over it. The rule is
  a number that reports on a strictly narrower subject than the reader assumes,
  which is the arc's own defining failure class, in the prompt written to prevent
  it.
- **Why it survives review:** the string exists, the check is followable, and it
  fails closed when the line is absent — so every property one would test for is
  true. The defect is in what the number *means*, not whether it can be read.
- **Suggested fix:** say "`AUDIT-SCOPE: fails=0` from the pre-push hook covers the
  **structure section only**; run `fw audit` unscoped before declaring the arc
  landed", or point the rule at the unscoped run.

---

### F12. landing-mode.md asserts a gauge enforces the 85% stop; nothing does — the block is at 95%

- **Severity:** medium
- **Confidence:** confirmed (thresholds read from `agents/context/budget-gate.sh`)
- **Location:** `policy/prompts/landing-mode.md` §Operator notes — "On the gauge
  that enforces that stop (T-3204)"
- **Failure scenario:** `budget-gate.sh:110-112` defines
  `TOKEN_WARN=75%`, `TOKEN_URGENT=85%`, `TOKEN_CRITICAL=95%`, and only the
  `critical` arms `exit 2` (block). 85% is `urgent` — a warning, never a block. An
  unattended agent running landing mode reads "the gauge that enforces that stop"
  and "the budget gauge is the only thing that disagrees with it", concludes a
  structural stop exists at 85%, and keeps going on the reasonable assumption that
  it will be halted. It is halted at 95%, in wrap-up-only mode, which is exactly
  the "ends at 97% with uncommitted work" outcome the same paragraph warns about.
  The stop at 85% is pure agent discipline, and the file says otherwise.
- **Why it survives review:** the sentence is about T-3204's *legibility* fix
  (what the percentage is a fraction of), which is accurate; the enforcement claim
  rides along in the section heading and reads as established.
- **Suggested fix:** "the gauge that *reports* that number" — and state plainly
  that nothing blocks until 95%, so the 85% stop is the agent's to honour.

---

### F13. landing-mode.md's replacement verification idiom omits the port-resolution and id-collision controls the framework has already documented as a 371-instance false green

- **Severity:** medium
- **Confidence:** confirmed
- **Location:** `policy/prompts/landing-mode.md` §The Prompt — "`curl -sf "$URL"
  -o "$f" && grep -q "$id" "$f"` is the shape"
- **Failure scenario:** §The Prompt is the part the file's own header says to
  paste, so it is what an agent runs with. It names `"$URL"` with no instruction to
  resolve the port, while the *other* snippet in the file (in §What v4 changes,
  which is not pasted) correctly uses `$(bin/fw watchtower url)`. An agent
  constructing `$URL` as `http://localhost:3000/review/T-152` hits whichever
  project's Watchtower holds that port. Both clauses then pass: `curl -sf`
  succeeds (rc 0, a real 200 from a real server) and `grep -q "T-152"` succeeds,
  because — per this repo's own §Watchtower Port section — "low task IDs collide
  across projects". The bad-id control also behaves correctly (404 → `-sf` → rc
  22), so the control does **not** catch it. Five approval links "verified" against
  a foreign project, again, by the rule written after the last time that happened.
- **Why it survives review:** v4's analysis of rc 23 vs `%{http_code}` is
  correct and complete for the failure it diagnosed, and `-sf` genuinely fixes
  that one. The residual hole is a different mechanism (right status, right bytes,
  wrong *server*) that the framework documents elsewhere but this prompt does not
  import.
- **Suggested fix:** write the URL as `"$(bin/fw watchtower url)/review/$id"` in
  §The Prompt, and add a project-identity control (grep for a string unique to
  this project, not just the task id).

---

### F14. The AC parser injects the heading suffix as a step, so rendered step numbers no longer match the numbers written in the task file

- **Severity:** medium
- **Confidence:** confirmed (parser and template both read)
- **Location:** `web/blueprints/tasks.py:445`
  (`current_content.append(f'**{suffix}**')`)
- **Failure scenario:** `_review_acs.html:64-69` renders steps as
  `<ol>{% for step in ac.steps %}<li>{{ step|safe }}</li>{% endfor %}</ol>`, and
  `_parse_ac_body` strips source numbering with
  `re_mod.sub(r'^\d+\.\s*', '', s)`. An AC written as

      **Steps (Route A — manual):**
      1. cd /opt/999… && bin/fw doctor
      2. Open the /approvals page
      3. Tick the box

  yields `steps == ['**(Route A — manual)**', 'cd …', 'Open …', 'Tick …']`, which
  the browser numbers 1-4. The operator is told "step 2" in a chat handoff and the
  page's step 2 is the shell command that the file calls step 1. With two routes
  (`**Steps (Route A):**` … `**Steps (Route B):**`), T-3224's append-instead-of-
  replace flattens both into a single continuous `<ol>` — so Route B's step 1
  renders as, say, item 6, and the two mutually-exclusive routes read as one
  nine-step procedure. This is the approval surface a human uses to make a
  decision, and it is the same "human decides on a distorted picture" class
  T-3224 was filed for, displaced rather than removed.
- **Why it survives review:** keeping the suffix is clearly right (it is what
  tells two Steps blocks apart), and pushing it into `current_content` is the
  cheapest way to keep it. The distortion only appears when you look at the
  template, which lives in a different file and is not in the T-3224 diff.
- **Suggested fix:** carry the suffix in a separate field (e.g. a `label` on a
  step-group), or emit it as a non-`<li>` heading between groups so the `<ol>`
  contains only steps — and restart numbering per group.

---

### F15. The hook-config `case` has no default arm, so the silent-absence failure the T-3226 comment describes is still reachable, and a non-zero Python exit is misattributed to a missing interpreter

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `bin/fw:2715` and `bin/fw:2719-2723`
- **Failure scenario:** the T-3226 comment states the danger precisely: a stray
  `"` in the double-quoted `python3 -c` string mangles the source, "hook_result
  comes back empty, no case arm matches, and the whole hook check silently prints
  nothing … bash -n still passes, doctor still exits, and the check is simply
  absent rather than red." The mitigation shipped is a comment convention
  ("use single quotes in comments here"). The `case` at 2719 still has only
  `OK|WARN|FAIL` arms and no `*)`, and there is no lint or test enforcing the
  convention — so the next editor who types a double quote in that comment
  reproduces the failure exactly as described. Separately, the
  `|| echo "WARN|Python3 not available for hook validation"` fallback at 2715
  attributes **every** non-zero Python exit — SyntaxError, ImportError, an
  unhandled exception in the loop — to a missing interpreter, and downgrades it to
  a WARN with advice that cannot help.
- **Why it survives review:** the comment is so thorough about the hazard that it
  reads as a fix. It is documentation of an unmitigated hazard.
- **Suggested fix:** add `*) echo "FAIL Hook config: validator produced no
  verdict"; issues=$((issues+1)) ;;` and change the fallback text to name the
  actual condition (`hook validator failed to run`).

---

### F16. `fw continuous` is absent from `fw help` and from CLAUDE.md

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `bin/fw:5419` (dispatch present); help function (no entry);
  `CLAUDE.md` (`grep -n "fw continuous"` → no hits)
- **Failure scenario:** the one verb that arms the arc's headline mechanic is
  discoverable only by tripping the doctor WARN at `bin/fw:2448` — which, per F1,
  fires only inside one branch of one check. CLAUDE.md tells the agent
  "Discover commands via `fw help`"; an agent that follows that instruction cannot
  find `continuous` and will fall back to hand-editing the two YAML files, which
  is the exact failure T-3225 was built to end.
- **Why it survives review:** the verb works, and the doctor message that names it
  is well written — so in the session that built it, it was never undiscoverable.
- **Suggested fix:** one line in the `fw help` command list and one row in
  CLAUDE.md §Quick Reference.

---

### F17. `fw continuous arm --hours` with the value omitted dies with a raw bash unbound-variable error

- **Severity:** low
- **Confidence:** confirmed (reproduced)
- **Location:** `lib/continuous-mode.sh:198` (the `--hours) hours="$2"; shift 2`
  arm), reached via `bin/fw:5431`
- **Failure scenario:** `bin/fw` runs under `set -euo pipefail` (line 12) and
  sources the library, so `$2` unset trips `set -u`. Reproduced:
  `bash -c 'set -euo pipefail; PROJECT_ROOT=/tmp/x; . cm.sh; fw_continuous_cli
  status --hours'` → `cm.sh: line 198: $2: unbound variable`, exit 1. The operator
  gets a library line number instead of the usage string the function already
  contains. (Outside `set -u` the same arm loops forever, because `shift 2` with
  `$# -lt 2` returns non-zero without shifting — verified — so any caller that
  sources this library without `set -u` hangs.)
- **Why it survives review:** every correctly-formed invocation works, and the
  usage string is present and good.
- **Suggested fix:** `--hours) [ $# -ge 2 ] || { echo "fw continuous: --hours
  needs a value" >&2; return 2; }; hours="$2"; shift 2 ;;` for each option.

---

### F18. Fabric bookkeeping: the arc's core module is unregistered, eight new tests are unregistered, one new card is a TODO stub, and the new tool/test pair declares a dependency cycle

- **Severity:** low
- **Confidence:** confirmed (all verified against the branch)
- **Location:** `.fabric/components/` (absences), plus
  `.fabric/components/tools-bats-silent-skip-lint.yaml` and
  `.fabric/components/tests-lint-bats-silent-skip.yaml`
- **Failure scenario:** four separate inaccuracies, all of which mislead
  `fw fabric deps` / `impact` / `blast-radius`:
  1. `lib/continuous-mode.sh` — 274 new lines, sourced by `fw doctor` and
     dispatched to by `fw continuous` — has **no card at all**
     (`git grep -l continuous-mode.sh arc012-ultrareview -- .fabric/` → empty).
     `fw fabric blast-radius` on a change to it reports no downstream, which is
     the check CLAUDE.md tells agents to run before committing.
  2. Eight new test files have no card: `t3202_audit_kill_source`,
     `t3204_budget_cap_legibility`, `t3206_continuous_run_ledger`,
     `t3209_loop_ledger_cause_attribution`, `t3210_handover_suggested_action`,
     `t3212_human_gate_stop`, `t3225_continuous_arm`, `test_ac_body_parser_steps`.
     Seven of the arc's tests were registered and eight were not, so `fw fabric
     drift`'s unregistered count is the only place this shows.
  3. `.fabric/components/lib-audit_timing.yaml` exists but is an auto-stub:
     `purpose: "TODO: describe what this component does"`, `tags: []`. Registered
     and uninformative reads to `fw fabric search` as absent.
  4. The two cards in my slice declare a **mutual** dependency:
     `tests-lint-bats-silent-skip.yaml` has `depends_on: tools/bats-silent-skip-lint.py`
     *and* `tools-bats-silent-skip-lint.yaml` has `depends_on:
     tests/lint/bats-silent-skip.bats` with `type: tested-by` — the only use of
     that type in the whole corpus (census: 1). `depends_on` with an inverted
     type says the tool depends on its test, so editing the test reports the tool
     as impacted. The other six assigned cards are accurate: every `location:`
     path exists at the branch tip, and each `purpose:` matches the file's actual
     content.
- **Why it survives review:** the seven cards that *were* written are unusually
  good — specific, honest about what the controls do — which makes the set look
  complete.
- **Suggested fix:** run `fw fabric register` on the nine unregistered files, fill
  the `audit_timing` stub, and drop the `tested-by` edge (the test-side card
  already expresses the relationship in the correct direction).

---

### F19. `fw continuous arm` leaves `terminated_at` and `completed_task_ids` from the previous run

- **Severity:** low
- **Confidence:** confirmed
- **Location:** `lib/continuous-mode.sh`, the `arm` block
- **Failure scenario:** `arm` clears `last_terminated_reason` and resets
  `tasks_completed` to 0, but does not touch `terminated_at` (set by
  `fw_continuous_note_human_gate`) or `completed_task_ids`. Result: an armed state
  file carrying a `terminated_at` timestamp, which is exactly the "flag says one
  thing, adjacent field says another" ambiguity `last_terminated_reason` was added
  to remove. And because `fw_continuous_note_task_completed` skips any id already
  in `completed_task_ids`, a task closed in run N and re-closed in run N+1 does not
  advance the new run's task ceiling.
- **Why it survives review:** `last_terminated_reason` — the field the header
  argues about at length — *is* cleared, so the reset looks complete.
- **Suggested fix:** clear `terminated_at` and `completed_task_ids` in the same
  `arm` write.

---

## Verdict

| Severity | Count |
|---|---|
| critical | 0 |
| high | 4 (F1-F4) |
| medium | 10 (F5-F14) |
| low | 5 (F15-F19) |

**Do this first: F3 — add `'stop-driver.sh': 'Stop'` to doctor's `expected` hook
map (`bin/fw:2578`).** It is a one-line change, and until it lands the single hook
that drives every turn of the continuous-run loop can be deleted from
`.claude/settings.json` with `fw doctor` printing `OK Hook configuration valid`.
T-3226 fixed the false FAIL on that hook and left the false OK on the same subject
untouched — and a green line about a hook that is gone is strictly worse than the
red line that was wrong, because nobody looks past it. F1 and F2 are the same
shape one layer up and should follow in the same pass.

**Explicitly checked and clean:**

- **Q2 (exposure vs currency independence).** Genuinely independent: exposure
  compares `sha256sum` of a local vendored file against the pin; currency compares
  the pin's `version:` against `git ls-remote --tags` at `source_origin:`. Neither
  reads the other's input, so neither can mask the other. There is now exactly one
  currency implementation — `grep -n "designer-v\*" bin/fw` returns only comment
  lines, and `do_check_currency` is the sole comparator. The three outcomes are
  textually distinct at the source (`SKIP … not checkable`, `SKIP … no designer-v*
  tags`, `SKIP … could not reach origin` / `WARN … behind` / `OK … current`) and a
  SKIP never renders as OK; the version compare is integer-tuple, not lexical, so
  0.10.0 correctly outranks 0.9.0. The three defects I did find in this area are in
  the *plumbing* of the delegation, not the comparison: F6 (empty output → no
  state), F7 (WARN not counted on BSD sed), F8 (silently absent on consumers).
- **`VERSION` 1.6.72 → 1.6.108.** Consistent. The review branch squashes the whole
  arc into one commit (`4c5193367`), and 36 patch bumps across ~40 changed files at
  this repo's per-commit bump cadence is the expected shape. No finding.
- **Six of the seven assigned fabric cards.** Every `location:` resolves at the
  branch tip; every `purpose:` matches what the file actually does (I read each
  target). The `subsystem: tests` / `subsystem: testing` split in the new cards is
  pre-existing corpus heterogeneity (67 vs 23 across existing test cards), not a
  new inaccuracy — not reported. Only the `tested-by` edge is wrong (F18.4).
- **`fw sync` retarget to `FW_DEV_BRANCH`.** Traced: the fallback to `master`
  requires *both* `refs/heads/<dev>` and `refs/remotes/origin/<dev>` to be absent,
  and the chosen target is echoed in the banner and in the final
  `✓ in sync with origin/<dev>` line, so a fallback cannot be mistaken for a
  bleeding-edge reconcile. `PIPESTATUS[0]` is read before any intervening pipeline.
  No finding.
- **`AUDIT_TIMEOUT_WARN_FRACTION` range guard.** `awk 'BEGIN{exit
  !(f+0>0 && f+0<=1)}'` correctly rejects non-numeric input (`f+0` → 0), and the
  enclosing `config_overrides > 0` gate cannot hide a bad value, because setting
  the key is itself an override. No finding.
- **`fw review-queue` DECIDED section (T-3178).** The predicate is imported from
  `lib/decided_unclosed`, `decided_rows` joins both the emptiness test and the
  summary tally, and the DECISIONS/DECIDED passes are complements (no double
  count). The one soft spot — `except: _du = None` degrading to a silently absent
  section — is a deliberate, documented trade-off with a stated rationale, and
  `FW_LIB_DIR` is correctly forwarded so the consumer case works. I did not file
  it, but note that the degradation prints nothing at all; a one-line
  "DECIDED section unavailable" would close it without reintroducing the crash.
