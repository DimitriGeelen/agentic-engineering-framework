**FAIL: two unlisted coverage gaps escape both layers, and common read-only commands are still refused.**

I inspected all requested files and prior reviews, ran read-only scanner probes and in-memory history simulations, and checked vendor synchronization. I did not execute the bypasses against project files or rerun the fixture-writing Bats suite because the sandbox is read-only.

**Round-2 findings**

| Finding | Assessment |
|---|---|
| GNU long-option abbreviations | **Fixed:** `sed --in-plac` is detected; prefix handling also covers the listed copy, sort, and gawk options. |
| Valid verdict replay after unticking | **Fixed:** one applied event permits one tick; subsequent consumption fails. |
| Verdict reused for another criterion | **Fixed:** a different criterion digest receives no exemption. |
| `grep -e'>'` refused | **Fixed:** scanner returns no hits. |
| `unzip -l` and `view` refused | **Fixed:** both original commands return no hits. |
| Awk parenthesized comparisons and string literals | **Fixed:** both original examples return no hits. |
| Scanner exceptions crash the hook | **Partially fixed:** segment-processing exceptions are caught, but `_tokens()` remains outside the `try` in [scan()](/opt/999-Agentic-Engineering-Framework/lib/shell_write_scan.py:590). An injected tokenizer exception still escapes. This limitation alone does not determine the verdict. |

**Coverage: commands both layers miss**

The following are reproductions, not operator instructions. Each is one Bash tool-call string, and each returned `[]` from `scan()`.

**1. Transfer approval between two same-titled criteria.**

Prerequisite: the task starts with these five lines; the Desktop tick is legitimately established:

```text
### Human
- [x] [REVIEW] Check display
  Desktop
- [ ] [REVIEW] Check display
  Mobile
```

```bash
printf '%s' "$(sed -i '2s/\[x\]/[ ]/;4s/\[ \]/[x]/' .tasks/active/T-9999-test.md)" && git add .tasks/active/T-9999-test.md && git commit -m 'T-9999: tick mobile'
```

The [tokenizer](/opt/999-Agentic-Engineering-Framework/lib/shell_write_scan.py:179) treats the double-quoted command substitution as one argument and never examines its executing `sed -i`.

The [history comparison](/opt/999-Agentic-Engineering-Framework/lib/human_ac_ticks.py:174) counts ticks by normalized checkbox title, ignoring the distinguishing body. One tick before and after therefore produces no finding, although Mobile changed `[ ]`→`[x]`. Both `unprovenanced_ticks()` and the history walker returned no findings in controlled in-memory probes.

**Accepted residual or false positive: neither.** The command and target are explicit; no external script, constructed path, forged ledger, or human identity is required.

**2. Tick a task whose filename Git quotes.**

Prerequisite: an existing `.tasks/active/T-9999-café.md` containing an unchecked Human criterion, with Git’s default `core.quotePath=true`.

```bash
printf '%s' "$(sed -i 's/\[ \]/[x]/g' .tasks/active/T-9999-café.md)" && git add .tasks/active/T-9999-café.md && git commit -m 'T-9999: tick'
```

The scanner misses the same double-quoted command substitution.

The [history walker](/opt/999-Agentic-Engineering-Framework/lib/human_ac_ticks.py:295) requests line-oriented `--name-status` without `-z`. Git represents this pathname as `".tasks/active/T-9999-caf\303\251.md"`. The trailing quote makes `endswith(".md")` false, so the file is skipped before reading either blob. A simulation supplying that Git output returned no findings and made zero blob reads.

**Accepted residual or false positive: neither.** Filename quoting is not an accepted limitation.

**Unaccepted false positives**

All three commands produced scanner hits:

| Read-only command | Incorrect refusal |
|---|---|
| `cat .tasks/active/T-9999-test.md # don't edit` | The apostrophe inside a Bash comment is treated as an unbalanced quote. |
| `rsync --dry-run source.md .tasks/active/T-9999-test.md` | Dry-run destination is classified as a write. |
| `patch --dry-run .tasks/active/T-9999-test.md < change.patch` | Dry-run target is classified as a write. |

These are not covered by the brief’s accepted inline-interpreter false positives. The ordinary `cat` example alone satisfies the common-read failure condition.

**Acceptance criteria**

| AC | Result | Reason |
|---|---|---|
| AC1 | **MET** | RCA records six reproductions and the relevant pre-existing gate states. |
| AC2 | **NOT MET** | Explicit `sed -i` inside double-quoted command substitution passes the Bash scanner. |
| AC3 | **NOT MET** | A legitimate `cat` read with a trailing comment is refused. |
| AC4 | **MET** | Block message and CLAUDE.md document script/indirection residuals and T-2742. |
| AC5 | **NOT MET** | Same-title tick transfers and Git-quoted task filenames escape committed-history detection. |
| AC6 | **MET** | Required fixture tests and meaningful assertions exist; the brief reports 35/35 passing, not independently rerun here. |
| AC7 | **MET** | Both registrations exist, the calculated enforcement baseline matches, and vendor self-check succeeded. |
| AC8 | **NOT MET** | This review yields FAIL. |

**Test assertions**

All **35 tests assert a real outcome**: execution status, checkbox state, hook refusal/advisory output, audit findings, or provenance. I found no vacuous test, skip path, or mid-test `! cmd`.

The vector helper checks execution status immediately and tests the same command string against the hook. Refusal-only cases are now explicitly acknowledged in the brief. The suite does not cover quoted command substitution, same-title approval transfers, Git-quoted filenames, or the read-only false positives above.

No files were changed. The read-only sandbox prevented saving this review or generating a committed handover.

VERDICT: FAIL