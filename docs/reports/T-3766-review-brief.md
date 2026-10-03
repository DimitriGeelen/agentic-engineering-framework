# T-3766 — independent review brief

Task: `.tasks/active/T-3766-rca-agents-repeatedly-ask-the-operator-f.md`.
Problem: agents asked the operator for vendor credentials (OpenRouter above all) that the
framework already holds, because the credential LOCATION lived only in prose. Fix: the
location is a registry fact, read by one resolver. All output below is masked; no
credential value appears in this document.

## AC → evidence

### AC1 — RCA with three dated recurrences
- Task file `## RCA`: symptom (2026-10-01 T-3670/L-687; 2026-10-03 T-3751 twice), root
  cause (location only in prose), why structurally allowed (compaction, recall miss,
  boundary gate blocks verification, behavioural learning), prevention.

### AC2 — `credential:` per backend, never a value
- `policy/review-backends.yaml:39-44` (field doc), blocks at `:56` claude-code, `:72` codex,
  `:90` opencode, `:108` local-gpu (`source: none`), `:119` openrouter
  (`env: OPENROUTER_API_KEY`, `files: [/root/.litellm-openrouter.env]`), `:139` antigravity.
  The CLI backends are `source: cli-login` with a `note:` naming the CLI's own login.
- Validation: `lib/review_cost.py:158-161` calls `lib/review_credential.py:72`
  `validate_credential`: allowed keys `source env files note` only; value-looking strings
  refused (`:59` — `sk-/pk-/rk-` prefix or a 32+ char base64/hex run); env must match
  `^[A-Z][A-Z0-9_]{1,63}$`; files absolute, no `..`; cli-login/none need a note and take no
  env/files. `fw audit` WARNs on a backend with no credential block (`lib/review_cost.py:452`).
- `/etc/watchtower/env` (named in history) does not exist on this host
  (`ls: cannot access '/etc/watchtower/'`); not registered.
- Tests: `t3766_review_credential.bats` @test 1 (seeded registry), 2 (`sk-` string refused,
  control loads), 3 (base64 blob + unknown key refused).

### AC3 — one resolver, never prints the value; runners use it
- `fw review credential <backend> [--check] [--source F] [--task T] [--exec -- cmd...]`:
  `lib/review_cost.py` `main` dispatches to `lib/review_credential.py:270`.
- Order: env var first, then each registered file (`resolve`, `:206`). `--source` must be one of
  the registered files (else refused). Files are parsed for exactly the one variable
  (`_read_var`, `:168`), never sourced; must be a regular non-symlink file, not
  group/world-writable, owned by root or the caller, <= 64 KiB. Error messages name the
  variable, files and registry path, never file content.
- Credential blocks come from the registry AS COMMITTED AT HEAD when the registry is in a git
  work tree (`committed_credentials`, `:117`); an uncommitted credential edit is refused.
- `--check` prints source + `**** (N chars)`. `--exec` puts the value only in the child's
  environment (not argv) and rewrites the value to `****` in the child's stdout/stderr
  (`_pump`, `:243`). A backend with `approval_required` needs an approved, unused proposal for
  the focused task (`:302`), checked in the resolver itself.
- Runners: no committed paid-seat runner exists (only reader of `OPENROUTER_API_KEY` outside
  the resolver: `web/llm/manager.py`, deliberately NOT wired — it would make paid calls without
  approval; see task `## Decisions`). Runners launch via `--exec`.
- Live, this host:
  ```
  $ bin/fw review credential openrouter --check
  openrouter: OPENROUTER_API_KEY resolved from file /root/.litellm-openrouter.env: **** (73 chars)
  $ bin/fw review credential codex --check
  codex: credential source cli-login — codex login with the ChatGPT account (~/.codex/auth.json) — the CLI authenticates itself
  $ bin/fw review credential openrouter --exec -- true
  ERROR: backend 'openrouter' is paid: --exec needs an approved, unused proposal for T-3766. ...
  ```
- Tests: @test 4 (env wins), 5 (env empty → file), 6 (file order), 7 (neither → error naming the
  entry), 8 (other content not echoed), 9 (not sourced), 10 (world-writable / symlink refused),
  11 (`--source` arbitrary path refused), 12 (cli-login), 13 (uncommitted credential edit
  refused under git), 14 (paid `--exec` refused without approval, in the resolver AND by the
  check-paid-backend hook via the new match `policy/review-backends.yaml:128`; control
  `--check` passes), 15 (approved: child sees the variable; `printenv` output on stdout and
  stderr is masked). Every resolution test asserts the fake value is absent from captured
  output (`no_value`).

### AC4 — boundary gate allowlists exactly the registered files, read-only, resolver only
- `agents/context/check-project-boundary.sh:425-476` `_cred_exempt_spans`: a segment whose
  command position is `[path/]fw review credential` (project-local fw only), containing no
  `$ \` < ( )`, may name a registered file **as the value of `--source`**; that exact token is
  blanked for the read-side Pattern 4 only (`:598`). Write patterns 1–3 run on the unblanked
  text. Registered set = `registered_files()` from the committed registry; any error → empty.
- (Round 2: the exemption now requires the ABSOLUTE project fw path as the segment's first word.)
- Live: `/opt/999-Agentic-Engineering-Framework/bin/fw review credential openrouter --check --source /root/.litellm-openrouter.env`
  passes the hook and resolves (masked); `cat /root/.litellm-openrouter.env` is blocked.
- Tests: @test 16 (cat blocked / resolver allowed), 17 (sibling `&& cat`, `$( cat … )`,
  `> file`, bare positional path, unregistered `/root/.ssh/id_rsa` — all blocked), 18 (path not
  in the registry → blocked even as `--source`).

### AC5 — CLAUDE.md, learning, concern
- `CLAUDE.md:1722` (§Review and Dispatch Cost Ruling): registry field, resolver, "Never ask the
  operator for a credential the registry names", names `web/secrets_store.py` as the separate
  Watchtower store.
- Learnings: L-690 (path, pre-existing) + new learning naming the resolver
  (`.context/project/learnings.yaml`, task T-3766).
- Concern `OBS-597` (`.context/concerns.yaml:1678`).

### AC6 — tests
- `timeout 300 bats tests/unit/t3766_review_credential.bats` → 18/18 ok, 0 skip. Hermetic: temp
  registry copy, temp file with a fake value built at run time; the real /root file is never
  read (the boundary tests feed command text only).
- Regression: `t3586_review_cost.bats`, `check_project_boundary.bats`,
  `t2920_boundary_heredoc_strip_order.bats`, `t3076_boundary_termlink_segment_scope.bats`,
  `test_boundary_hook_arguments.bats`, `tier0_scope_boundary.bats` all green;
  `pytest t3580_round5/round8, test_t3587_file_refs` 157 passed.

## Known residuals (documented in `lib/review_credential.py` docstring)
- A command run under `--exec` holds the value and can encode it past the output mask (the
  mask catches accidents, not intent); for paid backends it needs an operator-approved proposal.
- A same-user process can commit a registry change that retargets a credential file; it is then
  attributable in git history, and the target must still pass the file checks and contain the
  named variable.

## Round 1 (codex, VERDICT: FAIL) — findings and fixes

| # | Finding | Fix | Evidence |
|---|---|---|---|
| 1a | Multiline value escapes the line-by-line output mask | Any value with a newline/control character is refused, not echoed (`lib/review_credential.py:267` `_single_line`, applied to env and file values) | @test "R1-1: a multiline env value is refused…" |
| 1b | Validation echoed a rejected `source` value; YAML parser errors quote source text | Credential validation names fields/indices only; YAML errors report the line number only (`lib/review_cost.py:192`, `lib/review_credential.py` `_yaml`) | @test "R1-1: validation and YAML errors never echo…" |
| 2a | Exemption accepted any executable named `fw` (`../../tmp/fw`) | Executable must be exactly this project's fw (`fw`, `bin/fw`, `./bin/fw`, `.agentic-framework/bin/fw`, or those under PROJECT_ROOT) (`check-project-boundary.sh:458`) | @test "R1-2" (`../../tmp/fw`, `/tmp/fw` blocked; `.agentic-framework/bin/fw` control allowed) |
| 2b | Exemption covered `--source` in the CHILD command after `--exec` | Scan stops at `--exec` (`check-project-boundary.sh:472`) | @test "R1-2" (`--exec -- tool --source F` blocked) |
| 3a | Git failure fell back to working-tree credentials | `committed_credentials` (`:134`): registry in HEAD's tree → must match; a git error other than "not a git repository" → refuse; git not runnable with a `.git` ancestor → refuse. (`/` is itself a git work tree on this host, so "any `.git` ancestor" alone cannot be the test.) | @test "R1-3: fails closed when git cannot answer" (fake failing git; no git at all; control resolves) |
| 3b | Symlinked parent directory; lstat/read race | `realpath(f) == f` required; opened with `O_NOFOLLOW`, then `fstat` on the open fd for type/mode/owner/size (`_read_var`/`_parse_var`, `:218`) | @test "R1-3: a symlinked parent directory is refused"; test 10 |
| 3c | A committed registry edit can retarget a credential (commit ≠ authorization) | Not closed by code: a same-user process can commit; documented residual. Bounded by: committed (attributable), regular root/caller-owned non-writable file ≤ 64 KiB, only the one named `NAME=VALUE` read, `--source` limited to registered files, output masked, paid needs approval. | — |
| 4 | Paid `--exec` checked but did not consume the approval | The consuming cost record (with `proposal_id`) is written before the child starts (`:360`) | @test "R1-4: one approval covers one --exec" |

24/24 ok, 0 skip; regression suites green.

## Round 2 (codex, VERDICT: FAIL; report kept as docs/reports/T-3766-review-codex-r2.md) — findings and fixes

| # | Finding | Fix | Evidence |
|---|---|---|---|
| 1 | Unknown credential KEYS echoed in validation errors | Unknown keys are counted, never named; a value-looking key is reported as "a credential key" (`lib/review_credential.py` `validate_credential`, :79) | @test "R2-1" |
| 2 | `PATH=/tmp fw …` and `cd /tmp && bin/fw …` still exempt | Exemption requires the segment's FIRST word to be this project's fw by absolute path (`$PROJECT_ROOT/bin/fw` or `$PROJECT_ROOT/.agentic-framework/bin/fw`); no assignment prefix, no relative name (`check-project-boundary.sh:458`) | @test "R2-2" (PATH, cd, relative, assignment all blocked); positive tests use the absolute path |
| 3a | `ls-tree` + `rev-parse --verify` failures read as "unborn" → working-tree fallback | Only `for-each-ref --count=1` returning rc 0 with no refs counts as unborn; anything else refuses (:165). (`/` on this host is an unborn git repo, which is why the unborn case exists at all.) | @test "R2-3: a git that discovers the repo but fails on HEAD refuses" |
| 3b | Parent component swappable between realpath and open | Path opened component by component from `/` with `O_DIRECTORY|O_NOFOLLOW` relative to the parent fd; final component `O_NOFOLLOW|O_NONBLOCK`; checks on `fstat` of the open fd (:226-236) | R1-3 symlinked-parent test; test 10 |
| 3c | Committed retargeting; credential metadata attachable to an internal backend | `credential.files` is refused by validation unless the backend has `approval_required: true` (:115), so a file credential reaches a child only under an operator-approved, consumed proposal. Credential files must also be private: no group/other read (:255) — an ordinary readable file cannot be named. Residual: a same-user hand edit + commit of `approval_required` (set_backend refuses agents; a hand edit does not), documented. | @test "R2-3: credential.files on an internal backend is refused"; "R2-3: group/world-readable refused (control 0600)" |
| 4 | Consumption not atomic | `log_cost` check-then-append runs under an exclusive `flock` on `.context/costs/.reviews.lock` (`lib/review_cost.py:392`) | @test "R2-4: concurrent paid --exec on one approval: exactly one runs" (4 parallel; 3/3 repeated runs green) |

30/30 ok, 0 skip; t3586_review_cost, check_project_boundary, t3076, t2920, test_boundary_hook_arguments green. Live: real file is private (resolves), masked.

## Round 3 (codex, VERDICT: FAIL; docs/reports/T-3766-review-codex-r3.md) — one finding, fixed, NOT re-reviewed

Round 3 confirmed every round-2 fix and AC1/2/3/5/6 MET; one AC4 finding remained:

| # | Finding | Fix | Evidence |
|---|---|---|---|
| 1 | The `--exec` cutoff scanned text: `'--exec'`, `--ex""ec` are `--exec` to the shell, so a child's `--source FILE` got the exemption | The cutoff is replaced by a strict grammar: the exempt segment must be exactly `<abs fw> review credential <backend-id> [--check] --source <file> [--check]`, and its RAW text may contain no quote, backslash, `$`, backtick, `<`, `>`, `(`, `)`; any other word (`--exec`, `--task`, extras) means no exemption (`check-project-boundary.sh`, "A strict GRAMMAR"). Resolver argparse also has `allow_abbrev=False`. | @test "R3: exemption is a strict grammar…" (absolute-path `--exec`, `'--exec'`, `--ex""ec`, `--ex\ec`, `--task`, extra word, `>` all blocked; two absolute-path controls allowed) |

31/31 ok, 0 skip; boundary and review-cost regression suites green. The three-round review cap is reached, so this fix has NOT had an independent review.
