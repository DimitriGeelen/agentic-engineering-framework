# T-4013 — codex follow-up review of ab35a4cb9 (read-only, 22,302 tokens)

No serious new trust bypass found. Findings 2–5 are fixed; finding 6 remains partially unfixed. The documented limitation for finding 1 accurately describes the commit-based boundary.

- **Low — status still mixes two decisions (`lib/verdict_ledger.py:952–958`).** If the first read accepts approved bytes, then the file changes before `_approved_vendored_copy()` runs again, the second check rejects it—but status retains `state="committed"` and the earlier approval explanation alongside the modified digest. An in-memory probe reproduced this. Actual policy consumption still hashes and returns the same buffer; this is misleading status, not a demonstrated execution bypass. **Fix:** derive state, explanation, and digest from one evaluation, including rejection. Add a deterministic replacement-between-checks test.

- **Low — regression tests do not prove findings 2 and 6 (`tests/unit/t4013_vendored_exception_test.py:156,225`).** The noncanonical-path test also passes before the fix: its first entry’s old hash already rejects the current bytes. The status test never changes the file, so the original check/use implementation passes too. **Fix:** for finding 2, restore bytes matching the old alias entry and assert rejection, or directly assert malformed-path refusal; for finding 6, force replacement between reads and verify consistent status.

Remaining checks:

- **Finding 2:** exact canonical-string validation and replacement fix the stale-alias problem; regression coverage is insufficient as described above.
- **Finding 3:** indentless sequences rewrite correctly; document terminators cause refusal without writing. Both added tests would fail before the fix.
- **Finding 4:** fallback now requires the consumer layout and absent tracked paths. Empty tracked-file and external-layout tests distinguish the previous behavior.
- **Finding 5:** strict parsing rejects duplicate keys. Both duplicate-key scenarios would fail before the fix.

The normal committed paths return before the new fallback restrictions. Source inspection and mocked Git probes preserved framework-repository reads, tracked `.agentic-framework/` reads, and external-framework HEAD reads. Dedicated real-Git regression tests for these three success paths would strengthen coverage.

Validation was read-only source review and in-memory probes against `ab35a4cb9`; I did not run the filesystem-writing pytest suite or modify files.
