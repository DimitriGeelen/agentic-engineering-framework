VERDICT: red

FINDINGS:

  - severity: high
    where: lib/verdict_ledger.py:404
    what: Introducing-commit provenance binds only the row ID, not its contents. A producer can change a committed RED into GREEN, updating the judgement state while retaining its ID and dispatch. Neither application nor audit checks the committed bytes. An in-memory probe with simulated Git history returned valid approval and audit “0 failures.” No key access or identity change is necessary. Deleting a later withdrawal likewise has no append-only integrity check.
    fix: Verify canonical row contents against their introducing commit on the accepted history; reject duplicate IDs, modifications, deletions and uncommitted replacements. Audit ledger history as well as current rows.

  - severity: medium
    where: lib/verdict_ledger.py:849
    what: Audit does not use the advertised shared validator. It checks required-field presence but skips judgement consistency and most type/content validation; non-GREEN rows bypass further checks. An inconsistent GREEN/unknown judgement failed application but passed audit in the probe.
    fix: Extract shared structural and provenance validation and invoke it for every row from both audit and application. Separate historical integrity from current criterion eligibility so legitimate superseded verdicts remain auditable.

  - severity: medium
    where: lib/verdict_ledger.py:581
    what: Schema corruption can still fail open. A later JSON object naming the same task/AC but missing ac_digest is filtered out before validation, resurrecting the earlier GREEN. The probe confirmed this. Audit detects the malformed row, but closure does not require that audit to pass.
    fix: Validate rows before digest-based selection; block affected criteria when a malformed row cannot safely be excluded.

  - severity: medium
    where: lib/verdict_ledger.py:742
    what: The unrelated-GREEN render bypass remains. lib/delegation.py:534 classifies every non-risk criterion on a render task as render-surface, including unrelated prose criteria. Consequently, one unrelated GREEN satisfies check-render. The test at tests/unit/test_t3579_verdict_ledger.py:654 actually expects AC1 to qualify while AC2 is amber.
    fix: Identify the specific render-review criteria and require their valid approval; add a negative test asserting that unrelated GREEN plus render AMBER fails check-render.

  - severity: medium
    where: lib/verdict_ledger.py:547
    what: A registered dispatch proves registration for a task, not that its worker produced this verdict. Reviewer identity and introducing-commit identities are checked against producers but are not bound to the registered worker. Allowing a producer to dispatch its reviewer is reasonable; the current worker attribution is insufficient.
    fix: Slice 3 must bind a fresh worker/session identity, reviewed revision, criterion digest, evidence and exact verdict contents to the dispatch result; verify that worker’s completion and commit attribution. Record the producer-issuer exception explicitly: the inspected task’s Decisions section is still template-only.

  - severity: medium
    where: lib/verdict_ledger.py:259
    what: The key is ignored by .gitignore:37, untracked, and absent in this checkout. Creation uses mode 0600, which still permits every same-OS-user agent to read it. Moreover, register-dispatch exposes the signing operation directly. The builder correctly disclaims forgery resistance, but “tamper-evident and audited” overstates the result: fabricated signed registrations and alternate Git identities can pass these checks without a forgery warning.
    fix: Accept + document the same-user trust boundary explicitly, including that audit cannot distinguish a coherently fabricated provenance chain. Fix the independently avoidable integrity defects above before acceptance.

  - severity: medium
    where: agents/task-create/update-task.sh:113
    what: A missing verdict module returns success and skips revalidation, allowing existing reviewer-derived ticks to survive. The audit integration also silently skips its ledger check when the module is missing.
    fix: Refuse closure and report audit failure when required verdict validation code is unavailable.

PRIOR FINDINGS:

  - OpenAI 1 — open: independence has stronger prerequisites, but worker attribution remains unbound.
  - OpenAI 2 — open: ordinary incomplete forgeries are rejected; content substitution and incomplete audit validation remain.
  - OpenAI 3 — mitigated: annotated ticks are revalidated normally; missing-module and mutable-annotation limitations remain.
  - OpenAI 4 — closed: current risk classification is checked by render validation.
  - OpenAI 5 — closed: substantive criterion bodies are digested.
  - OpenAI 6 — open: torn JSON fails closed, but malformed objects can resurrect GREEN.
  - OpenAI 7 — open: coverage expanded substantially, but the defects above lack effective negative controls.
  - Z.ai 1 — open: original no-provenance paths are blocked, but registration does not authenticate the verdict writer.
  - Z.ai 2 — open: audit exists, but does not establish row-content integrity.
  - Z.ai 3 — open: risk reclassification is fixed; unrelated-GREEN render satisfaction remains.
  - Z.ai 4 — closed: unparseable trailing lines block affected approvals.
  - Z.ai 5 — open: tests expanded, but several requested refusal branches and the actual unrelated-render negative control remain uncovered.
  - Z.ai 6 — closed: evidence containment and existence are checked at application.

  Reproduction status: `/tmp` writes were denied by this session’s enforced filesystem restrictions; pytest failed before tests ran, so I cannot claim sandbox or end-to-end reruns. Inspection shows the original pseudonym-without-dispatch, bare appended row, pre-commit and task-ID-free-only-history cases are refused; appended invalid rows reach the audit failure path. These controls do not prevent the content-substitution path above. Read-only in-memory probes confirmed the validator discrepancies. The live ledger audit reports empty/absent.

OVERALL: Not safe to enable merely by adding slice-3 provenance-bound rows: content substitution can still authorize closure without an audit failure, below the stated fail-closed, tamper-evident target.