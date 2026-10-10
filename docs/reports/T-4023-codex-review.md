# T-4023 design review — codex (2026-10-10)

Read-only review of docs/reports/T-4023-field-evidence-before-release.md at 6b4482130. Prompt: .context/working/t4023-review-prompt.md. Final answer only.

1. **FALSE GREENS**

Ranked by severity:

- **Critical — evidence can describe a different artifact.** A report naming the candidate SHA does not prove the executing framework matches it: vendored files, local edits, stale processes, hooks or PATH can select different code. A forged report can simply copy the expected SHA. **Partially handled:** “Risks” requires matching commits; it lacks measured artifact identity, collector provenance and replay protection.

- **High — disappearing symptoms can mean disappearing visibility.** Renaming an error, breaking the logger, rotating ledgers, disabling the affected path or reducing traffic produces zero recurrences without fixing anything. “What this changes in the candidate shape” calls before/after signature counts a “direct verdict”; that overstates the evidence. **Not handled:** require eligible-event denominators, telemetry-health checks, versioned signature mappings and a positive check that the formerly failing operation now succeeds.

- **High — probes can certify themselves.** An author can supply a probe that checks the implementation’s assumptions, mocks away the failure or passes without reaching the affected path. Exit zero is only meaningful against a valid oracle. **Partially handled:** “Three kinds of feature, three kinds of evidence” distinguishes deterministic checks, but does not require independent review, coverage evidence or demonstration that the probe fails on the buggy baseline.

- **High — unexercised work can disappear from the table.** The candidate enumerates *closed tasks*, while shipped commits can include unfinished tasks, misclassified “internal” changes and indirect consumer effects. A reminder is not completeness enforcement. **Partially handled:** “Candidate shape (one pipeline, three slices)” and “Three kinds…” explicitly reject silence as success, but only for changes successfully enumerated. Derive coverage from the actual release diff.

- **High — small, correlated samples look conclusive.** Five successful events across projects sharing one host, operator and configuration provide little evidence about rare failures or other environments. Ending soak early selects for quick successes. **Partially handled:** minimum counts and soak appear in “Candidate shape”; risk-based thresholds, independence and uncertainty do not.

- **Medium — optimistic judgement becomes green.** Leading questions, agent-authored summaries and rubber-stamped confirmation obscure negative experiences. **Acknowledged, incompletely handled:** “Risks” discounts judged answers; retain actual responses, explicit abstentions and contradictory evidence instead of collapsing them into success.

2. **PROMOTION**

**Critical: whole-candidate promotion is sound; the proposed escape hatch is incomplete.** In “What this changes in the candidate shape,” reverting on a release branch preserves a fast-forward from the *old master*, but destroys the stated invariant that master is always an ancestor of bleeding-edge.

For example, candidate `C` yields release commit `R` containing reverts, while development continues to `D`. After master advances to `R`, neither `R` nor `D` necessarily contains the other. The next release can hit `lib/release.sh`’s divergence refusal. “Revert the revert” does not specify how both histories converge.

**High:** reverts also create an untested combination. A mature change may depend on a reverted change; clean application proves no semantic independence. Evidence for `C` cannot automatically certify `R`.

Better default: revert on bleeding-edge, issue a new numbered candidate, and validate that exact result. Reintroduce deferred work later. This preserves ancestry, at the cost of temporarily removing unfinished work from development. If release branches are retained, explicitly design reconciliation and require fresh integration evidence. Avoiding cherry-picks is reasonable, but reverts do not eliminate dependency risk.

3. **FIELD COST AND TRUST**

**High — “untrusted” is currently a label, not a protocol.** “Candidate shape” needs authenticated project identity, strict schemas, bounded payloads, immutable submissions, deduplication and provenance-linked evidence. Authentication proves who submitted a claim, not its truth. Never execute report text or let it supply verdict rules; treat free-text answers as possible prompt injection.

**Medium — reporting fatigue will corrupt evidence.** Repeated upgrades, disruptive probes, many questions and short deadlines encourage skipped reports or habitual “works.” The “evaluation brief” needs time budgets, safe/idempotent probes, automatic collection, batched questions, retries and visible feedback that reports mattered. Failed upgrades and unreachable reporters must remain visible, otherwise only survivors report.

4. **GAPS**

- **High — recovery:** no known-good pin, rollback drill, migration compatibility or recovery path when the upgrade breaks the reporting channel (“Second lens…”).
- **High — release enforcement:** “Open questions for the operator” leaves blocking unresolved. Missing, invalid, contradictory and stale evidence should block unless explicitly waived; waivers must remain distinguishable from verified success.
- **High — channel isolation:** `lib/release.sh` matches prerelease tags through `v[0-9]*`, can treat an unchanged tagged candidate as “nothing to release,” and publishes with `--latest`. Numbered bleeding-edge releases need separate creation, selection and promotion semantics.
- **Medium — representation and privacy:** testbed membership remains open; require a capability matrix. Define collection consent, redaction, retention and access rules for ledgers and human answers.

5. **VERDICT**

**GO-WITH-CHANGES**, before using this as a production release gate:

1. Bind evidence to measured artifacts and immutable candidate manifests; enforce complete diff coverage.
2. Make recurrence evidence exposure-based and telemetry-validated, with explicit uncertainty and blocking defaults.
3. Preserve branch ancestry through revert-and-recandidate, and add tested rollback plus separate prerelease tooling.
