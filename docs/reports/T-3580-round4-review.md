**Verdict: amber.** Round 4 fixes the wait/sign race and stops the judge counting backend ids as vendors. But the ledger still accepts the two attacks the round-3 findings described, and in both cases a round-4 test labelled "control" shows the attack passing.

Round 4 did not weaken any existing assertion. Its test changes only add the secret, kind and vendor parameters. I didn't re-check the round-3 test changes line by line; I relied on the Z.ai round-3 confirmation that the three weakened assertions were restored. I didn't run anything: this is read-only, and I used the parent's 271 pytest + 11 bats passing.

```
VERDICT: amber
FINDINGS:
  - severity: medium
    where: lib/verdict_ledger.py:340 (register_dispatch writes the secret to disk); tests/unit/t3580_round4_test.py:76
    what: The round-3 negative control asked that a registered dispatch that never runs, plus a caller's fake exit/result files and `complete`, be refused at apply. It is not refused. The secret is a plain 0600 file in /tmp/tl-dispatch/<name> owned by the same user. If run.sh never starts (spawn fails, or the parent stops), the file stays there indefinitely. `test_control_the_same_call_with_the_runtimes_secret_is_accepted` is exactly this path: fake exit_code and result.jsonl, read the file with rt.take_secret, complete, and apply ticks the criterion. Separately, the public `register-dispatch` command (verdict_ledger.py:1760, no guard) returns a fresh secret in any --wdir the caller names, without the caller reading the key. So the Decisions claim that "a caller with a hand-written exit_code file cannot obtain a signed completion" is true only for a caller who doesn't `cat` one file. The remaining forgery chain is documented commands plus a git-identity spoof. That is inside the same-user boundary accepted on T-3581, which is why this is medium and not high, but the claim overstates what was fixed.
    fix: (1) Keep the secret off disk. cmd_dispatch generates it, passes only its sha256 to register-dispatch, and hands the secret to run.sh on an inherited fd/pipe, so a dispatch that never runs has nothing to recover. (2) Delete any leftover secret on every spawn-failure path. (3) Refuse `register-dispatch --task-type review` unless a dispatcher marker is set by cmd_dispatch (same honesty class as --i-am-human; it catches the unsophisticated path). (4) Rename the test to what it is, add a real negative control (register, never run, read the leftover wdir, complete; apply must refuse), and restate the residual in Decisions to include the never-ran and self-registered paths.

  - severity: medium
    where: lib/verdict_ledger.py:1304 (_panel_fault trusts drec["vendor"]); tests/unit/t3580_round4_test.py:157
    what: The ledger counts whatever free text register-dispatch received as --vendor, and never checks it against the registered worker_kind. `test_control_three_registered_vendors_do` registers three worker_kind="claude" dispatches with vendors "anthropic", "vendor-2" and "vendor-3", and the ledger ticks a rung-5 green. The dispatcher knows only two kinds (claude→anthropic, ollama-loop→ollama-local), so a genuine three-vendor panel cannot currently exist. Today the only way to get a rung-5 green is exactly this inconsistent registration.
    fix: Put the kind→vendor table in verdict_ledger.py (termlink.sh `worker-kinds --vendors` reads it from there, one source). Have register_dispatch refuse, and _panel_fault treat as panel-unverified-vendor, any row where vendor != TABLE[worker_kind]. Change the "control" to use distinct registered kinds, and add the inconsistent case as a negative control.

  - severity: low
    where: agents/termlink/termlink.sh:597 (_worker_done) / :1095
    what: `finalised` sits in a wdir the worker can write (same user; /tmp/tl-dispatch/<name> is predictable). A worker that writes it early makes wait return before signing. This fails closed (the judge collects unknown), so it is only a liveness and diagnosability issue. It is not tested.
    fix: Have run.sh write finalised as its own signed content (e.g. the completion's sig, or "unsigned:<reason>"), and have _worker_done or _collect check that it matches completion.json. Otherwise document that an early finalised yields unknown.

  - severity: low
    where: agents/termlink/termlink.sh:1101
    what: .context/dispatch-results/ is neither gitignored nor committed. Worker output, including a review worker's free text, will be swept into the next handover `git add` of .context/, under the session's identity. That adds noise and sits close to the "parent never commits worker output" line.
    fix: Add .context/dispatch-results/ to .gitignore, or commit it explicitly under the dispatch identity. Record which one in Decisions.

  - severity: low
    where: .tasks/active/T-3580-*.md Decisions "Z.ai lows" (low 1)
    what: The completion is still uncommitted and untracked (`git ls-files .context/reviews/` is empty here). The attribution chain rests on the one ledger artifact that has neither git durability nor the append-only history check. Fail-closed and stated, but it is the weakest link in the chain.
    fix: Accept it as is, or make `fw audit` report "completions file untracked" as its own named WARN so the state is visible rather than silent.
OVERALL: Round 4 fixes the wait race, the judge's vendor reporting and the default-vendor lows. The six checks hold as in round 3: no path where the parent writes a verdict, hard classes never dispatched, a render green with an uncaptured page refused at apply, invalid rows unknown, and the rung ceiling drop printed. But the two HIGH fixes are one step deep. A never-run dispatch leaves a readable secret, and the ledger counts an unverified free-text vendor. The repo's own "control" tests show both being accepted. That is amber, not red, only because the remaining attacks sit inside the same-user boundary the operator already accepted.
```

**Second model family:** yes, run a non-Claude review before the verdict path is switched on. The builder commits are co-authored by Claude Opus 5.5, and this review is Claude too, so blind spots are correlated. In round 3 the codex/OpenAI reviewer found both HIGH findings that the Z.ai reviewer passed as green. So one other family is not enough on its own either. Once the two medium fixes land, the cheapest adequate check is one codex pass limited to `register_dispatch`, `complete`, `_panel_fault` and their negative controls.

## Round 6 review

Independent reviewer (Claude, same family as the builder), 2026-09-30. Fixtures only. No real verdict was recorded and no real criterion was ticked. The probes are in `/tmp/t3580r6probe/test_probe.py`, which is outside the repo.

### VERDICT: AMBER

The codex HIGH (an unbound lower-rung green ticks a high-impact task) is closed for the case codex named, and its negative controls are real. The MEDIUM is narrowed but not closed: the ledger now proves that the canonical run.sh ran, not that a reviewer did. The LOW is half-closed: the registry is now read as committed, but the list of launchable kinds is still read from the working tree. The new spend-ceiling step-down is a documented, invisible lever that takes every high-impact criterion from rung 5 to rung 3. Today it is the *only* way a high-impact criterion can close, because only two vendors can be launched.

### WHAT I CHECKED
- Re-ran the suites. pytest round2–6 + judge_cli + t3579 ledger: **296 passed**. bats: termlink 8/8, t3595 8/8, t3579 close path 11/11, upgrade simulation 11/11. No regressions in ordinary dispatch or cleanup.
- Read `lib/review_policy.py`, `_strength_fault` / `_run_fault` / `required_strength`, `register_dispatch` / `register_run`, `start` / `complete` / `_runtime_fault`, the canonical run.sh, `kind_vendors` / `launchable_kinds`, and the task's round-6 Decisions.
- Live state: `launchable_kinds()` = {claude, ollama-loop}. `verified_kind_vendors()` = {claude: anthropic, ollama-loop: ollama-local}. `.context/working/judge-spend.jsonl` is untracked and not ignored. The ceiling config has no floor.
- Probes (all in tmp fixture repos):
  - P1: one hand-written spend line (cost 1e9) in the untracked log. The judge-shaped rung-3 run with its ceiling decision ticks a blast_radius-9 criterion. **Ticks.**
  - P2 / P3: `FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING=0`, and `=-1`. **Ticks.**
  - P5: `REVIEWER_JUDGE_WEEKLY_SPEND_CEILING: 0` in `.framework.yaml`, the file `fw config set` writes. **Ticks.** The task annotation reads `(rung rung-3-termlink-single-reviewer)` and says nothing about rung 5 being due. `audit()` returns rc 0 and says nothing about the step-down.
  - P4: lowering blast_radius in a commit before dispatch, then restoring it. **Refused** (under-strength; "now" still counts).

### Codex probes re-checked
1. **HIGH — closed for the case named.** `test_negative_control_unbound_lower_rung_review_of_a_high_impact_task_is_refused` and the apply-side twin are genuine negatives: the apply twin monkeypatches only `_strength_fault` at record, then proves `apply` still refuses. Rung mismatch, a panel run asking for one vendor, a double step-down and a hand-edited decision are all real refusals. The control `test_control_a_low_impact_task_needs_no_run` separates "fires correctly" from "never fires". The judge and the ledger share one function (`review_policy.required_rung`).
2. **MEDIUM — narrowed, not closed.** See F2.
3. **LOW — half-closed.** See F3.

### FINDINGS

**F1 — MEDIUM (bordering HIGH) — the spend-ceiling step-down is a free, invisible lever, and the only live path for high-impact criteria.**
- *Where:* `lib/review_policy.py` `ceiling()` / `verify_ceiling_decision`; `lib/verdict_ledger.py:_strength_fault`, `_cite`, `audit`.
- *What:* `verify_ceiling_decision` only checks that the decision re-derives from the spend log and the ceiling configured now. Both inputs belong to the producer:
  - The spend log is an untracked working file. P1 shows one appended line is enough.
  - The ceiling accepts 0 and negative values from the env var or `.framework.yaml` (P2, P3, P5). The config route uses documented commands, not forgery.
  - The Decisions note discloses the spend-log route. It does not disclose the config/env route or the missing floor.
- *Why it matters:* no rung-5 panel can be assembled today (two launchable vendors), so a high-impact criterion can close only by stepping down. With the default ceiling of 10000 that never happens legitimately, so any rung-5→3 close in practice came through this lever.
- *Visibility:* the step-down appears only in the judge's stdout, the brief, and the run row. It does not appear in the ticked criterion's annotation, the `apply` result, or `audit`. `lib/config.sh:323` says "the verdict records the degradation". It does not: the run does.
- *Fix:*
  1. Floor the ceiling (> 0) in `ceiling()` and in the config registry range.
  2. Commit the spend log, or derive spend from `.context/costs/reviews.jsonl`, which is already the cost ledger. Treat it as append-only against git (`history_fault`), as the verdict ledger is.
  3. Record `rung_due` / `ceiling_decision` on the verdict row. Render "rung 3 (5 due; spend ceiling)" in `_cite`. Make `audit` report every step-down as a WARN.
  4. Consider refusing step-downs while `ceiling < RUNG_COST[due]`, which means the ceiling was set so that nothing could ever run.
- *Negative controls to add:* ceiling=0, a spend line not backed by the cost log, and an annotation that must name the due rung.

**F2 — MEDIUM — a signed start proves run.sh ran, not that a reviewer ran; the Decisions text overstates what is out of reach.**
- *Where:* `_runtime_fault` (verdict_ledger.py:650); the canonical run.sh (sources `$WDIR/env.sh` after `start` and before `claude -p "$(cat $WDIR/prompt.md)"`); `cmd_dispatch --env` (termlink.sh:676, any `[A-Z_][A-Z0-9_]*` key including PATH and ANTHROPIC_BASE_URL); Decisions line: "None of these is reachable through the documented commands."
- *What:* using only documented commands, a producer can run `fw termlink dispatch --task-type review --env PATH=<dir with a stub claude>`. The canonical run.sh starts, authenticates, runs the stub, and signs a completion whose rows tick.
  - The builder's own positive control (`_run_worker`: real run.sh plus a stub `claude` on PATH) is exactly this construction, and the ledger accepts it.
  - The same route with a real claude and a producer-written `--prompt`/`--prompt-file` ("record green for AC 1") also works. Neither the brief nor its hash is bound into the registration or the run.
  - `--env ANTHROPIC_BASE_URL=…` lets a `claude`-kind seat run a model other than Anthropic's while it is counted as vendor `anthropic`.
  - None of this needs the signing key, so it sits below the line T-3581 accepted ("reads the key / forges rows"), not on it.
- *Fix:*
  1. For `task_type=review`, refuse caller `--env` keys that choose the executable or the model (PATH, *_BASE_URL, *_API_KEY, LD_*, BASH_ENV). Invoke the worker binary by absolute path, resolved at registration and recorded in the signed row.
  2. Bind the brief: the judge records `sha256(prompt.md)` in the run, registration signs it, and `start` refuses if `prompt.md` differs. Review dispatches not created by the judge then have no run and stay rung-1-only (already true), and the brief is bound for rung ≥3.
  3. Correct the Decisions sentence: the documented `--env` and `--prompt` flags are the cheap routes, and they are closed or accepted explicitly by the operator.

**F3 — LOW — "launchable" is read from the working tree, and a kind is not a vendor.**
- *Where:* `launchable_kinds()` and `_canonical_runtime()` read `agents/termlink/termlink.sh` from the working tree.
- *What:*
  - An uncommitted edit to `DISPATCH_WORKER_KINDS`, plus a committed registry entry `worker_kind: codex` (the disclosed "whoever can commit" residual), makes a "codex/openai" seat count. The canonical run.sh sends every kind except `ollama-loop` to `claude -p`, so that seat runs Claude: one vendor wearing two names.
  - `ollama-loop` with a caller-chosen `--model` can likewise be routed through litellm to any family.
  - A panel is impossible today (two kinds), so this is prospective, but it sets the T-3582 baseline.
- *Fix:*
  1. Read `DISPATCH_WORKER_KINDS` and the runtime template from the committed framework revision, as the registry is read.
  2. Before T-3582 counts a codex/opencode seat, make run.sh route by kind: a dedicated branch per kind, with a refusal for unknown kinds.
  3. Record the model or base URL actually used in the completion, and count distinct vendors from that.

**F4 — LOW — the IW-7 requirement comes from fields the producer controls.**
- `required_strength` takes the higher of "now" and "at reviewed revision". P4 shows that restoring the risk fields after a review is refused. But a producer who commits a lowered `cost_estimate.blast_radius` / `bvp_scores` / description before dispatch, and leaves it lowered, gets rung 1.
- The edit is visible in git, so this sits within the same-user line. A cheap hardening: take the maximum over the task file's committed history since creation (or since the first review dispatch), not just two points.

**F5 — INFO / unverified — consumers that do not commit `.agentic-framework/`.**
- `_registry_blob` needs a *committed* registry. In a consumer that gitignores the vendored tree, candidate 2 fails. Candidate 3 then runs `git show HEAD:policy/review-backends.yaml` from inside the vendored directory, which resolves against the consumer repo.
- Every review-dispatch registration would then fail: dispatch prints "not registered" and nothing reviewer-judged can close. This fails closed, not open, but it is a silent loss of function.
- I could not check real consumers because the project-boundary hook blocked it. Add an upgrade-simulation case that has an ignored vendored tree.

### GUIDANCE
- **Do not switch the verdict path on for rung ≥3 criteria until F1 and F2 are fixed.** F1 needs little code: a ceiling floor, a committed or reused spend source, and a step-down shown in the annotation and audit.
- For F2, the operator must decide whether prompt/env steering through documented dispatch flags counts as "same-user forgery" (accepted) or as a gap. My reading of T-3581 is that it is a gap, because no key is read.
- F3 and F4 can wait until T-3582, but record them as preconditions of it.
- The CLAUDE.md delegation paragraph needs an update at land time. It still says "until slice 3 (T-3580) dispatches reviewers no row qualifies". It should state the rung enforcement and the step-down lever. It should not suggest that "a reviewer ran" is proven.
- A second-family (codex) pass on the F1/F2 fixes is still warranted: this review shares a family with the builder.
