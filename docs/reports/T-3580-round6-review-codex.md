## VERDICT

**RED — the original bypasses are substantially narrowed, but ceiling authorization still permits an under-strength review, and cleanup can race completion signing.**

No real verdict was recorded, no criterion was ticked, and no repository files were changed. This report is printed only because the sandbox also denies temporary-directory writes.

## WHAT I CHECKED

Read the prior Codex findings, four round-6 commits, shared policy, ledger, judge, generated runtime, round-6 tests and supporting fixtures, task Decisions, CLAUDE.md delegation paragraph, IW-7 design, cleanup logic and upgrade inclusion paths.

Execution results:

- **Pytest blocked before collection:** no writable temporary directory.
- **Bats blocked before execution:** `BATS_TMPDIR (/tmp) is not writable`.
- All three key Python modules passed in-memory syntax compilation.
- Read-only, in-memory probes exercised the actual ceiling validator and reproduced the stale-clock and non-finite-number findings below. Only configuration/log input providers were substituted; validation logic was unchanged.

Consequently, I cannot independently confirm the builder’s reported test counts or an end-to-end application result.

**Prior findings:**

| Finding | Round-6 assessment |
|---|---|
| Lower-rung, unbound green | Original path closed by shared `_strength_fault` at record and apply. Ceiling exception remains defective. |
| Registration/start impersonation | Original direct Python start/complete path closed by shared runtime checks. |
| Working-tree vendor declarations | Closed for a registry present at the reviewed revision; fallback and cross-revision consistency remain concerns. |

The important negative controls are meaningful: the application test bypasses record-time enforcement and then restores validation before apply; runtime refusal tests exercise actual checks; vendor tests distinguish committed declarations from launchability. However, source-string assertions and `not hasattr(bind_dispatch)` are implementation checks, not behavioral proof. Three-vendor positive controls explicitly simulate future launchable adapters; they do **not** demonstrate three real vendors executing today.

## FINDINGS

### 1. HIGH — A new run can reuse an old ceiling decision

**Where:** `lib/review_policy.py:213–240`, `lib/verdict_ledger.py:791–815`, `_strength_fault`.

**What:** `verify_ceiling_decision` accepts the decision’s caller-supplied `as_of` without comparing it with the signed run’s registration time. Public `register_run` signs that supplied decision.

My probe supplied:

- `as_of = 2020-01-01T00:00:00Z`
- One corresponding historical spend entry of 10,001
- Ceiling 10,000; due rung 5; granted rung 3

The actual validator returned `''`—accepted—while `weekly_spend` returned `0.0`.

Thus historical expenditure can justify a **new** lower-rung run without editing the spend log or reading the signing key. Record and apply share this same acceptance condition. This is distinct from preserving a legitimately authorized old review: the missing check lets an old decision authorize a newly registered run.

**Fix:** Compute the decision during registration, or validate its timestamp and log boundary against registration time. Preserve legitimate historical decisions after registration. Add record/apply controls for a new run using an expired spend window.

### 2. MEDIUM — Non-finite monetary values fail open

**Where:** `lib/review_policy.py`, `ceiling`, `_spent`, `apply_ceiling`, `verify_ceiling_decision`.

**What:** Monetary inputs accept `NaN` and infinity. With a ceiling of `"nan"` and zero spend, the actual policy returned rung 3 instead of rung 5:

> `reviewed at rung 3, weekly spend ceiling reached (spent 0 of nan); rung 5 was due`

The comparison `abs(spent - recorded_spent) > tolerance` also cannot reject a NaN reliably. Some malformed numeric decision fields raise exceptions instead of producing a controlled refusal.

**Fix:** Require finite, appropriately bounded numeric values; validate decision fields and nonnegative log counts before arithmetic. Invalid financial state must refuse a reduction. Cover NaN, infinity, negative counts and malformed fields.

### 3. MEDIUM — Cleanup can delete a review runtime before it signs completion

**Where:** `agents/termlink/termlink.sh:443`, particularly the early `exit_code` branch; generated `run.sh` completion sequence.

**What:** Cleanup immediately classifies any directory containing `exit_code` as finished. The runtime writes `exit_code` **before** completion signing and `finalised`.

Cleanup during that interval can delete a live runtime’s directory, result stream and completion files. `_worker_done` has stronger finalization checks, but cleanup bypasses them on this branch.

T-3595 fixes deletion of the entire dispatch root; this remaining per-worker race can still destroy an ordinary review’s evidence. The likely outcome is refusal or lost results, not an unauthorized green.

**Fix:** Apply the runtime/finalization checks before selecting review directories for deletion. Test with a runtime deliberately paused after `exit_code` and before completion signing.

### 4. MEDIUM — Vendor provenance lacks one immutable registry binding for the whole panel

**Where:** `lib/verdict_ledger.py:399–415`, `register_run`, `_panel_fault`.

**What:** Two source-level gaps remain:

- When the registry comes from an external framework checkout, `_registry_blob` reads that checkout’s **current HEAD**, not an immutable revision recorded with the dispatch.
- Each panel seat re-derives its vendor at its own reviewed revision. The run does not bind all seats to one reviewed revision or registry snapshot. Registry-only commits under other task references are not rejected by `_stale_fault`.

The latter permits a construction in which the same launchable kind is mapped to different vendor names across committed revisions and those names are counted separately. This requires registry commits, which Decisions correctly identify as a trusted boundary, but the ledger’s claim that one kind cannot become multiple panel vendors needs qualification. I could not run the full fixture reproduction here.

**Fix:** Pin the reviewed revision and resolved registry repository/commit/blob in the run; require every seat to use that binding. Pin the external-framework fallback too. Add a mixed-revision, same-kind panel negative control.

### 5. LOW — Step-down visibility and documentation exceed enforcement

**Where:** `lib/reviewer/judge_cli.py:448`, `lib/review_policy.py:213`, CLAUDE.md delegation paragraph, T-3580 Decisions.

**What:** Normal judge output displays the step-down and instructs the worker to mention it. The ledger does not require or generate that disclosure in the verdict. My accepted stale-decision probe also had an empty `note`.

CLAUDE.md still describes slice 3 as future work and the verdict path as effectively off. Earlier Decisions describe registration-issued secrets and CLI-only authentication; later entries supersede these but leave contradictory operational descriptions.

**Fix:** Generate structured due/granted/reason disclosure from validated policy in verdict/application output. Update CLAUDE.md and explicitly mark historical Decisions as superseded.

## GUIDANCE

**Keep this round red** until stale-decision authorization, numeric validation and the cleanup race are fixed and exercised with writable temporary fixtures. Add immutable panel-wide registry binding or explicitly narrow the provenance guarantee and obtain acceptance for that remaining limitation.

The runtime change deserves credit within the accepted T-3581 boundary: direct callers now encounter the same authentication checks as CLI callers. Nevertheless, parent argv plus current script bytes is an honesty check, not process attestation. Same-user argv spoofing, script replacement, Python patching, environment manipulation and key access remain possible. Those are within the stated accepted forgery boundary; they are not grounds to demand a separate security architecture here.

Likewise, fabricated spend entries remain possible through the explicitly acknowledged mutable-log boundary. **Reusing historical spend through an unchecked decision clock is a separate validation defect**, not something that requires defeating that boundary.

Before approval, rerun the requested pytest/Bats suites and vendor-only upgrade simulation. Static inspection shows the new policy module and registry are included in vendoring, but it does not establish dispatch, cleanup or upgrade regression safety.