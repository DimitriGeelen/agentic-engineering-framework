VERDICT: amber

FINDINGS:

  - severity: medium
    where: lib/verdict_ledger.py:627
    what: Audit validation remains incomplete for non-GREEN rows. `_row_fault` returns before checking their introducing commit; schema validation also omits mandatory non-GREEN guidance. A read-only in-memory probe, assuming valid dispatch registration, returned “0 failures” for an uncommitted RED without guidance. This does not authorize closure, but contradicts the advertised audit contract.
    fix: Validate guidance and introducing-commit presence for every outcome before the non-GREEN return; add negative tests.

  - severity: medium
    where: lib/verdict_ledger.py:991
    what: Revalidation still depends on a mutable Markdown annotation. Removing it—or changing `green` to `GREEN`—makes an existing reviewer-derived tick appear hand-ticked. After a failed close has transferred ownership, that tick can survive a later RED. The verdict-ledger audit does not reconcile task ticks with application records, so this residual path is silent.
    fix: Identify reviewer-derived ticks from durable application provenance, cross-check annotations during closure and audit, and require an explicit operator override to convert them into manual approvals.

  - severity: medium
    where: lib/verdict_ledger.py:685
    what: Dispatch registration still does not bind the verdict writer to the worker. Producer-issued dispatches are reasonable, but excluding producer strings from reviewer/commit identities does not establish worker attribution. This is now explicitly documented as unfinished slice 3 work.
    fix: Implement T-3580’s fresh worker/session, completed dispatch, reviewed revision, criterion digest, evidence hashes, exact result contents and matching commit-attribution requirements before enabling normal use.

  - severity: medium
    where: lib/verdict_ledger.py:253
    what: The signing key is untracked, ignored by `.gitignore:37`, and absent in this checkout. Mode 0600 permits every agent running as its owner to read it; `register-dispatch` also exposes signing directly. A coherently fabricated registration and alternate Git identity can still pass audit. The revised same-user disclaimer accurately acknowledges this; “effectively off” is operational, not enforced.
    fix: accept + document, subject to explicit operator acceptance; do not describe registration as proof that an independent review occurred.

PRIOR FINDINGS:

  - OpenAI 1 — mitigated: original identity-only paths blocked; worker attribution deferred explicitly.
  - OpenAI 2 — mitigated: bare forgeries and content substitution rejected; audit completeness remains imperfect.
  - OpenAI 3 — mitigated: normal close retries revalidate; mutable-annotation escape remains.
  - OpenAI 4 — closed: render validation rechecks current eligibility.
  - OpenAI 5 — closed: substantive criterion body is digested.
  - OpenAI 6 — closed: torn lines and missing-digest malformed rows no longer resurrect GREEN.
  - OpenAI 7 — mitigated: substantial adversarial coverage added; remaining gaps above.
  - Z.ai 1 — mitigated: original reproductions blocked; authentic worker attribution remains pending.
  - Z.ai 2 — mitigated: append-only history and audit added; residual audit gaps remain.
  - Z.ai 3 — closed: unrelated GREEN cannot rescue render AMBER.
  - Z.ai 4 — closed: torn-line handling fails closed.
  - Z.ai 5 — mitigated: coverage expanded; not every requested refusal branch is covered.
  - Z.ai 6 — closed: evidence containment and existence are rechecked.
  - Round 2 content substitution/deleted withdrawal — closed for the inspected linear-history cases, including committed and working-file replacements.
  - Round 2 shared audit validation — mitigated: shared validator exists, but non-GREEN validation remains incomplete.
  - Round 2 malformed-object selection — closed.
  - Round 2 unrelated-render GREEN — closed.
  - Round 2 worker attribution — mitigated-and-documented; implementation pending.
  - Round 2 signing-key boundary — mitigated-and-documented.
  - Round 2 missing validator — closed: closure refuses and audit fails.

Reproduction/validation status: Inspection shows pseudonym-without-dispatch, bare appended row, pre-commit GREEN and task-ID-free-only-history cases are refused; invalid appended verdict rows produce audit failures. I could not rerun sandbox reproductions: pytest failed during temporary-directory setup, and Bats refused unwritable `/tmp`. Two filesystem-independent pytest tests passed, shell syntax checks passed, and the live ledger audit reported empty/absent. These are not end-to-end passes.

OVERALL: Conditionally suitable after slice 3 binds worker results, but not an unconditional fail-closed approval: the annotation escape and incomplete audit checks must be fixed or explicitly accepted alongside the documented same-user forgery boundary.