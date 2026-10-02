**The check has unlisted coverage gaps and read-only false positives.** I confirmed scanner results and detector comparisons with read-only Python probes. I did not execute bypasses against project files or rerun the fixture-writing Bats suite because the sandbox is read-only.

**1. Coverage**

These examples assume an existing `.tasks/active/T-9999-test.md`. Each command is a single Bash tool-call string.

| Case | Why both layers miss it | Accepted residual? |
|---|---|---|
| Tick introduced in a merge commit | Attached `sed -e'…'` escapes target detection; history explicitly excludes merges. | **No.** Non-merge scope appears in the design description, but merge-only ticks are not listed as an accepted residual. |
| Tick accompanied by a fabricated green annotation | Sed’s `w` command is unrecognized; the detector excludes annotated ticks without validating the annotation. | **No.** This needs neither a forged tick-ledger row nor a human identity. |
| Re-tick a previously acknowledged criterion | Attached `-e` escapes detection; any existing matching ledger digest authorizes every subsequent tick of that criterion. | **No.** No ledger forgery is necessary. |
| Tick in a second Human section | Attached `-e` escapes detection; the detector extracts only the first Human section. | **No.** Multiple sections are not a documented residual. |

Concrete commands and prerequisites:

- **Merge-only tick:** `topic` must be a divergent, cleanly mergeable branch; neither parent contains the tick.

  ```bash
  git merge --no-ff --no-commit topic && sed -i -e's/^- \[ \]/- [x]/' .tasks/active/T-9999-test.md && git add .tasks/active/T-9999-test.md && git commit -m 'T-9999: merge'
  ```

- **Fabricated annotation:** the source contains an unchecked Human criterion. This changes it and appends a green annotation without recording provenance.

  ```bash
  cp .tasks/active/T-9999-test.md /tmp/t3695-source.md && sed -n 's/^- \[ \] \(.*\)/- [x] \1\n  **Reviewer verdict:** green/;w .tasks/active/T-9999-test.md' /tmp/t3695-source.md && git add .tasks/active/T-9999-test.md && git commit -m 'T-9999: tick'
  ```

- **Acknowledgment reuse:** the criterion was legitimately acknowledged previously, then unticked; its task ID and text remain unchanged.

  ```bash
  sed -i -e's/^- \[ \]/- [x]/' .tasks/active/T-9999-test.md && git add .tasks/active/T-9999-test.md && git commit -m 'T-9999: retick'
  ```

- **Second Human section:** the file ends with an unchecked criterion beneath a second `### Human` heading, separated from the first section by `## Other`.

  ```bash
  sed -i -e'$s/^- \[ \]/- [x]/' .tasks/active/T-9999-test.md && git add .tasks/active/T-9999-test.md && git commit -m 'T-9999: tick final criterion'
  ```

The attached-expression bug is in [shell_write_scan.py:285](/opt/999-Agentic-Engineering-Framework/lib/shell_write_scan.py:285): `-eEXPR` does not set `has_e`, so the sole filename operand is discarded as though it were the expression. Sed without `-i` returns without inspecting `w` or substitution `w` flags.

History exclusions and reusable digest coverage are in [human_ac_ticks.py:190](/opt/999-Agentic-Engineering-Framework/lib/human_ac_ticks.py:190); first-section extraction and annotation exemptions are in [human_ac_ticks.py:75](/opt/999-Agentic-Engineering-Framework/lib/human_ac_ticks.py:75).

The annotation exemption is expressly described, but its supposed validation elsewhere is incomplete: [verdict_ledger.py:2895](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:2895) can return clean for an absent ledger and otherwise checks annotations only for tasks represented in its applied records. A fresh fabricated annotation is not necessarily caught there either.

A scanner miss alone is insufficient for this finding: an ordinary, unannotated tick committed in a non-merge commit **is** reported. Likewise, the brief’s script/runtime-path residuals ordinarily remain detectable after commitment.

**2. False positives**

These read-only commands returned scanner hits:

| Command | Incorrect classification |
|---|---|
| `grep '>' .tasks/active/T-9999-test.md` | Quoted search pattern becomes a write-redirection token. |
| `git show HEAD:.tasks/active/T-9999-test.md` | `git show` is treated as restoring a file. |
| `git cat-file -p HEAD:.tasks/active/T-9999-test.md` | Object inspection is treated as a write. |
| `awk 'NF > 0' .tasks/active/T-9999-test.md` | Numeric comparison is treated as potentially writing inline code. |
| `python3 -c 'from pathlib import Path; print(Path(".tasks/active/T-9999-test.md").read_text())'` | All inline Python mentioning a guarded path is refused. |
| `cat .tasks/active/T-9999-test.md; python3 -c 'print(1)'` | A guarded-path mention in another segment contaminates unrelated inline code. |

Also, `tar -cf /tmp/tasks.tar .tasks` is blocked as extraction, although it only reads task files and writes an unrelated archive.

**3. Acceptance criteria**

| AC | Result | Reason |
|---|---|---|
| AC1 | **MET** | RCA records six reproductions and distinguishes the active-task gate states. |
| AC2 | **NOT MET** | Ordinary `sed -i -e'EXPR' task.md` is allowed because the scanner discards the target. |
| AC3 | **NOT MET** | Legitimate reads such as `grep '>' task.md` are refused; unrelated archive writes are also blocked. |
| AC4 | **MET** | Both the block message and CLAUDE.md state script/runtime-indirection limitations and reference T-2742. |
| AC5 | **NOT MET** | Merge-only ticks, fabricated annotations, acknowledgment reuse, and second-section ticks escape reporting. |
| AC6 | **MET** | Required fixture tests, controls, and audit tests exist with substantive assertions and no mid-test negations; the brief reports 24/24 green, which I could not independently rerun here. |
| AC7 | **MET** | Both hook registrations exist, the calculated baseline matches, and `bin/fw vendor self --check` returned success. |
| AC8 | **NOT MET** | The required review file is absent, and this review does not yield the required PASS. |

**4. Test assertions**

All **24 tests contain meaningful outcome assertions**; I found no vacuous test or silent-skip path.

However, the brief’s statement that *every write vector executes and proves a Human tick* is inaccurate:

- Tests 1–6 prove a real tick before asserting refusal.
- Test 7 executes `mv` and `dd`, but only checks refusal for append.
- Test 8 executes the `cd` and glob vectors; its remaining vectors only assert refusal.
- Test 9 only asserts refusal for the endpoint, ledger, acknowledgment CLI, and checkout.
- Tests 10–24 assert relevant exit statuses, messages, file state, or provenance outcomes.

Additionally, [assert_vector_ticks:55](/opt/999-Agentic-Engineering-Framework/tests/unit/t3695_human_ac_tick_bash.bats:55) overwrites the command’s exit status before checking it. Its subsequent file-state assertion prevents vacuous success, but a partially successful command that ticks and then fails still passes.

No files were changed. The read-only sandbox also prevented writing a review artifact or generating the required committed handover.

VERDICT: FAIL