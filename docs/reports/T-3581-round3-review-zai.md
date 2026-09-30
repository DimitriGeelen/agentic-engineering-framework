```
VERDICT: amber
FINDINGS:
  - severity: medium
    where: lib/verdict_ledger.py:253-306 (register_dispatch), :63-68 (docstring claim)
    what: The coherent same-user forgery is still fully silent — reproduced end-to-end: producer
          session runs `register-dispatch` itself (no key read needed; first call also CREATES the
          key), records green under a pseudonym, commits the row under a fresh git identity →
          apply ticks, close exits 0, `fw audit` reports "0 failure(s)". This is the documented
          residual gap and is parked on the unticked operator AC, but the docstring's framing
          ("a deliberate act with a trail, not a one-line append") understates it: signing is
          exposed via the CLI, so it is three commands and the false identity leaves no trail
          naming the forger.
    fix: accept + document, with corrected wording ("register-dispatch signs for any caller and
          creates the key on first use"); closure of the attribution gap is T-3580 requirement 6
          (dispatch-completion binding), which must land in slice 3.
  - severity: low
    where: lib/verdict_ledger.py:397-402 (_dispatch_is_producer)
    what: Dispatch ids normalising to <4 chars ("rv-1" → "rv1") skip the worker-identity check;
          verified missed while "rv-77" is caught (test pins only the 4-char case).
    fix: Drop the `len(d) < 4` guard (match on the dispatch-email local part instead), + test.
  - severity: low
    where: lib/verdict_ledger.py:449-513 (load_ledger) vs record():873
    what: The record→commit window is unguarded: an uncommitted RED deleted from the working file
          silently resurrects an earlier committed GREEN (probe: faults=[], tick reapplied, audit
          rc=0). "Uncommitted rows never count" is documented; that uncommitted rows can be
          silently deleted is not. No new capability under the same-user model, but it is a
          fail-open direction in the tamper-evident claim.
    fix: accept + document one line; structurally, slice 3 should commit the row in the same act
          as recording it.
  - severity: low
    where: lib/verdict_ledger.py:289-306 (dispatch_record)
    what: Registration is unauthenticated and first-row-wins with predictable termlink ids
          (task+role), so a pre-registered "review" dispatch can shadow a real one — inside the
          same-user gap but it makes requirement 6 easier to defeat.
    fix: slice 3: restrict registration to the termlink dispatcher path; make dispatch ids random.
  - severity: low
    where: lib/verdict_ledger.py:563-576 (_evidence_fault)
    what: Evidence is path-cited, not content-hashed — paths can be swapped in place. Already
          carried as T-3580 worker-attribution requirement 4.
    fix: slice 3 (content hashes in the dispatch result).
PRIOR FINDINGS:
  OpenAI-r1-1 independence self-asserted — mitigated (dispatch+worker+intro-commit binding; coherent same-user forgery remains, documented)
  OpenAI-r1-2 hand-appended rows honoured — closed (provenance required; audit FAILs, rc=2)
  OpenAI-r1-3 ticks permanent — closed (revalidate every close; withdrawal verified in bats)
  OpenAI-r1-4 render gate no reclassify — closed (shared validator; operator-only greens refused)
  OpenAI-r1-5 title-only digest — closed (body digest, annotations excluded, pin-tested)
  OpenAI-r1-6 malformed lines silently dropped — closed (validate-before-select; torn fails closed)
  OpenAI-r1-7 test gaps — closed (92 pytest + 10 bats, each refusal with a control)
  Zai-r1-1 self-asserted reviewer string — mitigated (as OpenAI-r1-1)
  Zai-r1-2 honour-system rows, no audit consumer — closed (fw audit cross-checks; forged row FAILs)
  Zai-r1-3 unrelated-green render bypass — closed (every render-review criterion needs its own valid green; negative test added)
  Zai-r1-4 torn line fails open — closed (torn blocks affected task; committed corruption faults the ledger)
  Zai-r1-5 test gaps — closed (all four sandbox repros have end-to-end refusals)
  Zai-r1-6 absolute/dangling evidence — closed (relative, inside-repo, existence at record AND apply)
  OpenAI-r2-1 content substitution (RED→GREEN keeping id) — closed (append-only vs git history; repro 5: apply refuses, audit rc=2, sovereignty blocks)
  OpenAI-r2-2 audit skips shared validator — closed (audit uses _row_fault; inconsistent judgement and bad non-green rows FAIL)
  OpenAI-r2-3 digest-filtered malformed row resurrects green — closed (validated before selection; missing-digest/unreadable-ac rows block)
  OpenAI-r2-4 unrelated-GREEN render bypass via delegation.py:534 — closed (render_review_criteria narrows to criteria about rendering; unrelated green + render amber fails, tested)
  OpenAI-r2-5 worker attribution unbound — mitigated (producer-issuer decision + T-3580 six binding requirements recorded; open until slice 3)
  OpenAI-r2-6 key / overstated claims — mitigated (ignored+untracked+0600 same-user confirmed; CLAUDE.md now states exactly what audit catches and that coherent fabrication passes — accurate, see finding 1 on wording)
  OpenAI-r2-7 missing module skips revalidation — closed (close exits 1, audit FAILs; bats 9/10 pin it)
OVERALL: Safe to enable once slice 3 writes provenance-bound rows AND lands the T-3580
worker-attribution requirements — every incoherent forgery I could construct now fails closed
and fails audit, and the one silent path left is exactly the documented same-user coherent
fabrication, which slice 3 can make more deliberate but never impossible, so the unticked
operator AC (accept/reject the residual gap) must remain the gate to green.
```

Question 4 (design): the producer-may-issue decision is sound — refusing producer issuers would break the normal slice-3 flow and adds nothing against a same-user forger who can register under any session label. But it is only sound **together with** the T-3580 requirement list, especially #1 (fresh worker session recorded in the dispatch *result*, not the registry) and #6 (dispatch marked COMPLETED by that worker; row's introducing commit attributed to that worker identity, not merely a non-producer). Without those two, "producer issues dispatch, then writes the verdict citing it" stays silent — that is precisely repro 1b.
