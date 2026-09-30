**VERDICT: RED**

Round 7 closes several specific round-6 routes, but the new environment validator permits executable shell substitutions, and history-based enforcement is inconsistent with judge planning. I would not mark the round-6 findings fully closed.

No real verdict was recorded, no criterion was ticked, and no repository file was changed. The sandbox also denies temporary writes, so I could not append this review.

**WHAT I CHECKED**

Read both round-6 reports, the seven named commits, the relevant implementation and tests, and the T-3580 Decisions.

Execution:

- Full round-7 pytest attempt blocked: no writable temporary directory.
- Bats blocked: `BATS_TMPDIR (/tmp) is not writable`.
- **Five fixture-free round-7 tests passed**, with 57 deselected.
- Ran in-memory probes against actual policy and validation functions, substituting input providers where filesystem fixtures were unavailable.
- Verified all six files vendored by `e107da08d` match their source counterparts at that commit.

I cannot independently confirm the builder’s **378 pytest / 86 Bats** totals.

| Requested probe | Assessment |
|---|---|
| 2020 ceiling decision for a new run | In-memory probe refused the mismatched registration clock. Old spend computed as zero. Caller-supplied decisions removed. |
| Untracked spend | Source and test inspection: committed cost-ledger input replaces the untracked log. Fixture execution blocked. |
| Ceilings 0, −1, NaN, infinity, 50 | Actual `apply_ceiling` retained rung 5 for each, even with large spend. |
| `.framework.yaml` ceiling 0 | Actual config-policy path, with substituted file contents, returned “below the floor 100.” |
| `--env PATH`, base URLs, steering keys | Explicit keys are excluded by both allowlists. New shell-value bypass described below. |
| Brief changed after registration | Prompt hash comparison closes the direct edit-before-start case. Launch-time mutation remains possible through the environment bypass. |
| Mixed revisions / one kind under multiple vendors | Registration and panel validation now enforce one run revision and registry hash. Fixture execution blocked. |
| Cleanup between `exit_code` and `finalised` | Changed branch now calls `_worker_done`; source and targeted test cover the identified interval. Bats execution blocked. |
| Risk lowered and left lowered | Ledger consults historical frontmatter. Judge does not; reproduced the disagreement in memory. |

**FINDINGS**

**1. MEDIUM — Environment validation accepts executable shell values**

**Where:** [lib/verdict_ledger.py:348](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:348), `_launch_fault`, and the generated runtime’s subsequent sourcing of `env.sh`.

**What:** `_env_fault` checks keys using `shlex.split`, but does not establish that values are inert shell literals. This accepted input returned no fault:

```bash
export GIT_AUTHOR_NAME="$(printf ENV_CODE_EXECUTED >&2)"
```

Executing that same input in Bash printed `ENV_CODE_EXECUTED`.

A process able to edit the dispatch directory can therefore put executable code in an allowlisted value. The runtime sources it **after** `start` checks `prompt.md`. That code can change the prompt before the worker reads it, without reading the signing key.

This is **not** an injection through ordinary `--env` values: the dispatcher’s `%q` quoting protects that route. It is a bypass of the newly added registration/start checks on `env.sh`. The Decisions claim that `start` refuses a changed environment is too strong: the environment is neither hashed nor constrained to non-executable data.

**Fix:** Store environment overrides as data and load validated key/value pairs without shell evaluation. Bind that data to registration. Add a negative control containing command substitution and a positive control containing literal shell metacharacters.

**2. MEDIUM — Judge planning ignores the new history-max requirement**

**Where:** [lib/reviewer/judge_cli.py:253](/opt/999-Agentic-Engineering-Framework/lib/reviewer/judge_cli.py:253), `judge`, and [lib/verdict_ledger.py:1617](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:1617).

**What:** The judge still calls `review_policy.required_rung` with current frontmatter only. The ledger now takes the historical maximum.

With current blast radius 0 and historical blast radius 9, the actual functions returned:

```text
judge:  rung 1, default
ledger: rung 5, blast_radius=9 in committed history
```

Consequently, ordinary judge dispatch can select an insufficient review, register it, and spend resources on a result the ledger refuses. Registration computes the ceiling decision using the caller’s `rung_due`; it does not correct that planning discrepancy.

The original lowered-risk acceptance route is narrowed, but the new policy is not integrated end to end.

**Fix:** Use one history-aware requirement calculation for judge planning, registration validation, record and apply. Add a judge-level lowered-and-left-lowered test, including a legitimate ceiling step-down.

**3. MEDIUM — History lookup errors silently discard historical risk**

**Where:** [lib/verdict_ledger.py:1592](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:1592).

**What:** A nonzero `git log` result becomes an empty history; failed `git show` results are skipped. An in-memory probe returning Git status 128 produced `[]`, which is also cached.

For a task whose current and reviewed fields are low, losing the historical high version removes the new protection. This is a fail-open error path, not proof of a practical end-to-end exploit in this environment.

**Fix:** Distinguish “no historical task version” from “history could not be inspected.” Refuse review authorization on the latter and avoid caching incomplete history as valid.

**4. LOW — Numeric validation still has an uncontrolled exception**

**Where:** [lib/review_policy.py:176](/opt/999-Agentic-Engineering-Framework/lib/review_policy.py:176).

**What:** `_money` catches `TypeError` and `ValueError`, but `float(10**400)` raises `OverflowError`. The actual helper reproduced that exception. A JSON integer can carry such a value.

This does not grant a lower rung, but contradicts the Decisions claim of controlled refusal without exceptions.

**Fix:** Catch `OverflowError`; test oversized numeric ledger values. Also cover overflowing aggregate spend explicitly.

**Other requested assessments**

- **Floor 100:** The tested lower values fail closed. A valid ceiling of 100 still permits reduction once committed spend justifies it. The floor bounds the lever; it does not authorize expenditure or prove cost authenticity. Fabricated-but-committed cost entries remain an explicitly documented residual.
- **Focus environment keys:** Refusing caller overrides is defensible because the dispatcher already supplies `FW_SESSION_SCOPED_FOCUS=1` and its own `FW_FOCUS_SESSION_KEY`. Ordinary review dispatch needs no override. These keys affect task isolation even though they select neither executable nor model. Improve the refusal explanation; do not broadly allow every non-model key.
- **Absolute worker path:** Closes worker lookup through caller `--env PATH`. Dispatcher-environment PATH manipulation and unrestricted model selection remain documented residuals. The path is not executable-content attestation.
- **Registry binding:** The mixed-revision construction is addressed. External fallback still resolves the framework’s current HEAD and compares the resulting registry hash; it detects registry movement rather than consistently reopening the originally recorded commit. Runtime/kinds movement can still cause refusal. This is narrower than a fully pinned external framework snapshot.
- **Disclosure:** New applications write the step-down onto the criterion. Ledger audit emits `WARN step-down`, and `fw audit` explicitly surfaces those warnings. This closes the prior visibility gap by inspection; I could not execute the full audit fixture.
- **Docs:** The stale slice-3/off language and superseded Decisions are substantially corrected. Claims that changed `env.sh` is refused and that completion proves execution on the registered brief need qualification pending finding 1.
- **T-3602 files:** Closing inherited lock FD 9 changes suite execution, not T-3580 policy. Its test uses broad `pkill -f "^sleep 60$"`, which could interfere with concurrently running tests using that exact process command. I found no direct T-3580 runtime dependency on these files.

**GUIDANCE**

Fix findings 1–3 before calling this round closed. Address the numeric exception and associated documentation at the same time.

Then rerun the full suites in a writable temporary environment, adding behavioral controls for executable environment values, history-aware judge planning, and Git history failures. Preserve the documented same-user residual boundary, but distinguish those accepted residuals from checks that currently claim stronger enforcement than they provide.