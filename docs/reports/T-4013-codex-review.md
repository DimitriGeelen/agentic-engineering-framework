# T-4013 — independent codex review of 674ce1f63 (gpt via codex exec, read-only, 21,081 tokens)

Found concrete defects, including an approval-boundary weakness. References are to `lib/verdict_ledger.py` at **674ce1f63**.

- **High — operator identity is forgeable (3469–3477, 850).** An agent can unset `CLAUDECODE`, pass `--i-am-human`, or write the exception directly. Any nonempty `approved_by` is accepted—even YAML `null`, because `str(None)` is nonempty. **If the agent can commit**, it can authorize its own modified reviewer configuration without operator approval. Committing alone does not prove human authorization. **Fix:** verify operator signatures or another approval mechanism outside the agent’s writable trust boundary. Otherwise explicitly document that trusted commits, not operator identity, are the boundary.

- **Medium — reapproval can leave the old hash authoritative (849–853, 870, 909–910).** An existing entry with `path: ./agents/termlink/termlink.sh` survives reapproval of `agents/termlink/termlink.sh`. Validation compares normalized paths against the allowlist but detects duplicates using raw strings. Both entries pass; lookup selects the old entry first. Restoring the old bytes remains trusted after the operator approves replacement bytes. **Fix:** canonicalize paths consistently for validation, deduplication, replacement, and lookup.

- **Medium — valid YAML is corrupted by approval (918–928).** With a valid indentless sequence, `vendored_exceptions:\n- path: ...`, the rewrite removes the key but retains its list items, producing invalid YAML. Appending after an existing `...` document terminator also produces invalid YAML. Both cases reproduced in memory. **Fix:** use a YAML-aware round-trip editor; validate the resulting document before an atomic write.

- **Medium — fallback eligibility is too broad (796–803).** Fallback runs after every unsuccessful candidate search, including inside the framework repository, after an external framework-HEAD candidate fails, and when a tracked file exists but is empty/whitespace. A previously approved vendored copy can therefore supply policy despite an intentionally emptied committed file. **Fix:** explicitly require the intended consumer installation layout and absence of tracked files; distinguish missing paths from empty blobs and Git errors.

- **Medium — duplicate YAML keys silently override approval data (839).** PyYAML accepts repeated `vendored_exceptions` or repeated `sha256` fields and uses the last value. A document displaying an approved hash first can actually authorize a later hash. **Fix:** reject duplicate mapping keys throughout the document.

- **Low — status has a check/use mismatch (886–891).** The vendored file is reread after trust evaluation. Replacing it between reads produces `approved-exception` alongside the modified file’s hash. **Fix:** return the checked digest with the trust result.

The added tests omit these cases. The actual trust path hashes and decodes the **same buffer** (868–876), so I found no post-read replacement bypass of that hash check. No files were modified.
