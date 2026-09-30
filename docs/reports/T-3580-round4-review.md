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
