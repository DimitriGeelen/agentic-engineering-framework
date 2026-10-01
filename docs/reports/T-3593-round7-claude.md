**VERDICT: red**
**HIGH LEFT: YES**

I ran the five suites (t3593*, t3594*, tier0_*) in a temporary fixture: all 166 tests pass. I ran every probe in that fixture too. Nothing was approved or pushed in the real repo.

**1. Codex's round-6 findings: closed.**
- **Branch vs tag collision:** `HEAD:refs/tags/x` and `HEAD:refs/heads/refs/tags/x` now get different keys, for force-push and for delete. Pre-push uses the ref exactly as git reports it.
- **Quoted whitespace:** the hash is now taken over the raw JSON command bytes, and the test proves `"a  b"` and `"a b"` get different approvals.
- **NUL:** `$'tier\0junk'0`, `\x00`, `\u0000` and `\c@` are all blocked.

**2. The class (different targets, one key).** I tried about 55 spellings and found none at the text level. The new code keys pushes on the full ref (`check-ref-format` without `--normalize`), local deletes on the literal name, rm on the literal operand, and hard-reset on {repo, branch, resolved SHA}. Malformed refs like `refs/heads//x`, `x/` and `x.lock` are left unmapped (exact-text approval instead). Three things can still let one key cover two targets over time:
- **LOW** `tier0_action.py`, `_remote_ref_key`: the push key holds the remote name, not its URL. A `git remote set-url` inside the approval window would point the approval at a different repository. Fix: add the push URL (pre-push gets it as `$2`).
- **LOW** CDPATH is read from the hook's environment, not the Bash tool's shell. If the profile sets CDPATH, `cd lib && rm -rf foo` is keyed to the wrong directory.
- **Deployment:** this repo's own `.git/hooks/pre-push` does not have the T-3594 guard yet. Until `install-hooks` is re-run, pushes are keyed at the text gate only.

**One target, two keys (over-blocking).** Expected cases: `./foo` vs `foo`, a `~`/`HEAD~1` reset. The costly one, **MEDIUM**: an unmapped force push or delete (a `| tail`, or a tag already deleted locally before `git push origin :v1`) needed **3 approvals** in my test. The order was exact text, then pre-push's action approval, then exact text again, because the first was single-use. Fix: when the exact text is approved, also record any push actions in the pending set, or let pre-push take an admitted exact-text push.

**3. Self-approval by typed command: still SAFE. HIGH.**
- **Brace expansion:** `env -u CLAUDECODE bin/fw tier{0..0} approve` passes the gate and, run with `CLAUDECODE=1`, records `approved_by: human`. Same with `t{i..i}er0`, `{tier,}0` and `tie{r,}0`. This is static, like ANSI-C, not a run-time word. Fix: expand braces before the word check, or block any `{`/`[`/`?`/`*` next to a `tier`/`fw` fragment.
- **Line continuation:** `bin/fw tier\` + newline + `0 approve` passes the gate and approves. Fix: strip backslash-newline before dequoting.
- **MEDIUM:** `tier[0]`, `tier?` and `ti*0` are SAFE. They only work if a file named `tier0` exists in the cwd, but brace expansion can create one.
- **MEDIUM (not tested live):** `curl -X POST …/api/approvals/decide` is SAFE at the gate. `web/blueprints/approvals.py:927` writes the approval file with no human check. Its CSRF token can be read with a cookie-jar GET. I did not POST to the live server, because that would approve a real request.

**4. Daily use: passes.** In the fixture, with the generated pre-push hook, these all passed without blocking: a real fast-forward push, an annotated tag push, `git status`, `git -C <project> log`, `fw handover --commit`, `bin/fw handover --commit`, `git push --tags origin` and `git push -u origin HEAD`.

**5. HIGH LEFT: YES** (brace expansion and line continuation self-approval).
