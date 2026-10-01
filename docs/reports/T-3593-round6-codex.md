VERDICT red
HIGH LEFT: YES

1. **Round-5 findings: exact probes closed; self-approval class remains open.** Read-only detector reruns show `git branch -D victim`, `+victim`, and `refs/heads/victim` now produce distinct literal keys. The original `env -u CLAUDECODE bin/fw $'tier\x30' approve` probe now triggers SELF-APPROVAL.

2. **HIGH — Remote branch/tag approval-key collision.**  
   **Where:** `lib/tier0_action.py:157`, `_remote_ref_key()`, and the `prepush` handler.  
   These commands produce identical force-push keys:
   ```bash
   git push -f origin HEAD:refs/tags/x
   git push -f origin HEAD:refs/heads/refs/tags/x
   ```
   The corresponding deletions also collide:
   ```bash
   git push origin :refs/tags/x
   git push origin :refs/heads/refs/tags/x
   ```
   Both refs are valid, distinct Git targets. Removing `refs/heads/` makes branch `refs/tags/x` indistinguishable from tag `x`; pre-push repeats this normalization.  
   **Fix:** Preserve fully qualified ref names throughout classification, approval storage, and pre-push consumption.

3. **HIGH — Fallback approval hashes conflate different filesystem targets.**  
   **Where:** `agents/context/check-tier0.sh`, `COMMAND_NORMALIZED`.  
   `rm -rf ./ "a  b"` and `rm -rf ./ "a b"` are both detected, unmapped commands, but receive identical fallback hashes because whitespace is collapsed inside quotes. Their second operands name different paths.  
   **Fix:** Hash the original command bytes; do not normalize quoted whitespace.

4. **MEDIUM — Encoded typed self-approval still bypasses detection.**  
   **Where:** `check-tier0.sh`, `ansi_c_decode()`.  
   Both probes return `SAFE`:
   ```bash
   env -u CLAUDECODE bin/fw $'tier\0junk'0 approve
   env -u CLAUDECODE bin/fw $'tier\x00junk'0 approve
   ```
   Harmless Bash `printf` probes confirm both arguments expand to `tier0`: Bash truncates the ANSI-C string at NUL, then concatenates the final `0`. The detector retains NUL and subsequent characters. No approval was executed.  
   **Fix:** Match Bash’s NUL truncation semantics and test concatenation after encoded NUL.

5. **Regression assessment and limits.** Ordinary `git status`, fast-forward push text, `fw handover --commit`, and benign ANSI-C `printf` remained `SAFE`; no new ordinary-work over-blocking was observed. The NUL case remains a fail-open path. No additional collision was established for hard-reset, literal local deletion, case, Unicode, symlinks, separators, or remote aliases; this is not exhaustive assurance.

   Bats could not start: `/tmp` is not writable. The builder’s 172-pass claim remains independently unverified. Repository read-only restrictions prevented appending the report or generating a committed handover.