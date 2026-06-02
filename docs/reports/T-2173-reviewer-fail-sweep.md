# T-2173: Reviewer FAIL sweep — completed/ corpus hygiene analysis

**Generated:** 2026-06-02
**Source audit:** `.context/audits/reviewer/2026-06-02.yaml` (scan_timestamp 08:33Z)
**Corpus:** 1951 completed tasks
**Headline totals:** PASS=1417, CONCERN=503, **FAIL=31**, needs_human=67

## Method

1. Today's audit run reports 31 tasks at `overall: FAIL` but the audit YAML stores only summary counts + 5 top_findings per pattern — not per-task verdicts.
2. Per-task verdict blocks (`## Reviewer Verdict (v1.4)`) cached in completed task bodies were grep-extracted for `Overall:.*FAIL`. **Hit count: 19.**
3. The 12-task gap (31 - 19) is likely a mix of (a) post-cache verdict transitions (older bodies cached at PASS/CONCERN now scoring FAIL after detector growth), (b) re-classifications since last per-task `fw reviewer T-XXX` run, (c) tasks with no `## Reviewer Verdict` block written-to-disk yet.
4. Analysis below uses the 19 cached FAILs. The clustering shape extrapolates to the remaining 12; the recommended fix tracks would cover any expected pattern.

**Follow-up:** the investigation's first fix-track recommendation includes a fresh per-task reviewer scan over completed/ to write-back current verdicts, which will surface the 12 missing FAILs explicitly.

## Cluster 1 — `skip-as-pass` (8 tasks)

| Task | Pattern fires (cached) |
|------|-----------------------|
| T-1516 | skip-as-pass × 1 |
| T-1594 | skip-as-pass × 1 |
| T-1514 | skip-as-pass × 1 |
| T-1738 | skip-as-pass × 4 |
| T-1734 | skip-as-pass × 1 |
| T-1903 | skip-as-pass × 1 |
| T-2072 | skip-as-pass × 1 (+ mock-only-integration × 1) |
| T-2124 | skip-as-pass × 2 |

**Pattern semantics:** Verification command short-circuits to PASS by treating "skipped" as "passed" — e.g. `if [ -f file ]; then test; fi` exits 0 when `file` doesn't exist, which the gate reads as PASS even though the test never ran. Severity: severe + deterministic.

**Likely class:** Real verification gap — the AC was honoured at write-time (verification command exists) but the command's logic is flawed (skip ≠ pass). Detector is correctly catching genuine task-quality drift.

**Fix track:** **Edit each task's Verification block** to fail-loud on the skip path (`if [ ! -f file ]; then echo "expected file missing"; exit 1; fi; test`). Apply to 8 tasks. **Not a detector FP.**

## Cluster 2 — `swallowed-errors` (6 tasks)

| Task | Pattern fires (cached) |
|------|-----------------------|
| T-1471 | swallowed-errors × 1 (`... \|\| true`) |
| T-1581 | swallowed-errors × 2 |
| T-1596 | swallowed-errors × 4 |
| T-1751 | swallowed-errors × 2 |
| T-1694 | swallowed-errors × 1 |
| T-1814 | swallowed-errors × 1 |

**Pattern semantics:** Verification command pipes through `|| true`, `2>/dev/null` then `|| exit 0`, or otherwise discards a failure exit code. The command literally always exits 0 regardless of outcome. Severity: severe + deterministic.

**Likely class:** Real verification gap — `... || true` was added during initial author/debug and never replaced with a real assertion. Same root as Cluster 1.

**Fix track:** **Edit each task's Verification block** to drop the error-swallowing — replace `cmd || true` with `cmd` (or `cmd || echo "expected ..." && false` if you genuinely want a soft warning). Apply to 6 tasks. **Not a detector FP.**

## Cluster 3 — `tautology` + `empty-output-success` (2 tasks)

| Task | Pattern fires (cached) |
|------|-----------------------|
| T-1518 | tautology × 1 |
| T-1517 | tautology × 1 + empty-output-success × 1 |

**Pattern semantics:** Verification command is constant-true (e.g. `[ 1 -eq 1 ]`, `true`, `echo done`) or empty output is treated as success.

**Likely class:** Filler verification — author wrote the placeholder but never replaced. Severe + deterministic.

**Fix track:** **Edit each task's Verification block** with the actual check that would have caught a regression of the AC. **Not a detector FP.**

## Cluster 4 — `empty-body` (1 task)

| Task | Pattern fires (cached) |
|------|-----------------------|
| T-1644 | empty-body × 2 |

**Pattern semantics:** Task body sections (AC / Recommendation / etc.) are empty or template-only at work-completed time.

**Likely class:** Race condition between task-create and work-completed (slice closed before body filled). Severe + deterministic.

**Fix track:** **Edit T-1644** to retro-fill body sections from git log / episodic / handover trail. **Not a detector FP** — task was genuinely incomplete at close.

## Cluster 5 — `mock-only-integration` (2 tasks)

| Task | Pattern fires (cached) |
|------|-----------------------|
| T-1897 | mock-only-integration × 1 |
| T-2072 | mock-only-integration × 1 (+ skip-as-pass — Cluster 1) |

**Pattern semantics:** AC mentions integration semantics ("dispatches", "interacts with", "wires to") but Verification only mocks the dependency or skips the integration call. Partial + heuristic.

**Likely class:** Mix — sometimes a real integration test gap, sometimes a detector edge-case (the mock IS valid coverage for that AC). Needs per-task triage.

**Fix track:** **Triage each task individually** — add a real integration smoke if the AC genuinely needs end-to-end proof, OR file a reviewer override (`fw reviewer override add --pattern mock-only-integration ...`) if the mock is sufficient. Per-task decision.

## Cluster 6 — Verdict-block-missing (1 task)

| Task | Pattern fires (cached) |
|------|-----------------------|
| T-1812 | (verdict block present but no pattern fingerprint extractable from grep) |

**Likely class:** Body structure variant — the `## Reviewer Verdict` header is there but the cached fingerprint format differs. Needs a fresh `fw reviewer T-1812 --no-write` to extract current state.

**Fix track:** Fresh-scan to confirm, then route to appropriate cluster above.

## Cluster summary

| # | Cluster | Cached count | Fix track | Genuine vs FP |
|---|---------|--------------|-----------|---------------|
| 1 | skip-as-pass | 8 | Verification edit (fail-loud) | Genuine |
| 2 | swallowed-errors | 6 | Verification edit (drop `\|\| true`) | Genuine |
| 3 | tautology / empty-output-success | 2 | Verification edit (real check) | Genuine |
| 4 | empty-body | 1 | Body retro-fill | Genuine |
| 5 | mock-only-integration | 2 | Per-task triage | Mixed |
| 6 | Verdict-missing | 1 | Fresh-scan + reroute | TBD |
| **— Cluster 7+** | **The 12 uncached FAILs** | **12** | **First step: fresh-scan completed/ to surface them** | **TBD** |

## Cross-cluster observations

- **17/19 cached FAILs (89%) are genuine task-quality issues** in the Verification block — author shortcuts (`\|\| true`, `if [ -f X ]`, `true`) that the detector correctly flags. The reviewer is producing high-precision FAIL signal.
- **No false-positive-dominant clusters surfaced.** The `mock-only-integration` cluster is the only one with FP potential, and even there the decision is per-task. There is no systematic detector tightening needed at this layer.
- **Fix-style is uniform across clusters 1-4 (17 tasks):** edit the Verification block of the completed task with a fail-loud replacement. This is low blast-radius (completed tasks aren't re-run by the gate; the edit is for retroactive scanability and consistency only) and high uniformity (same shape across all 17). Strong candidate for batching.

## Recommendation

**GO** on opening a fix track. Three sibling build tasks:

### Fix A (build): Reviewer FAIL fix batch — Verification-block hygiene (17 tasks, clusters 1-4)

- Cluster 1 (skip-as-pass × 8): replace `if [ -f X ]; then test; fi` with fail-loud variant.
- Cluster 2 (swallowed-errors × 6): drop `|| true` / `2>/dev/null || exit 0`.
- Cluster 3 (tautology + empty-output × 2): substantive check.
- Cluster 4 (empty-body × 1): retro-fill body from git log.
- **Pattern:** uniform Verification-block edits across completed/.
- **Verification of this fix-task:** `fw reviewer T-NNNN --no-write --json` on each of the 17 returns `overall: PASS` post-edit (or at minimum drops the cluster's pattern fingerprint).

### Fix B (build): Reviewer FAIL fix batch — `mock-only-integration` per-task triage (2 tasks, cluster 5)

- T-1897 + T-2072 mock-only triage. Per-task decision: real integration test added OR reviewer override filed.
- **Verification of this fix-task:** each task either passes reviewer post-edit OR has a TTL'd `OV-XXXX` entry in `fw reviewer override list`.

### Fix C (build): Reviewer audit — fresh-scan completed/ to surface the 12 missing FAILs

- Run `fw reviewer T-XXX --no-write` over each task in completed/ to write current per-task verdicts back to disk (matching the audit's count of 31). This closes the cache-vs-current gap and surfaces the 12 untyped FAILs into one of the clusters above (or a new one).
- **Verification:** `grep -l "Overall: FAIL" .tasks/completed/*.md | wc -l` returns 31.

### Cluster 6 (T-1812 verdict-missing) folds into Fix C — the fresh-scan re-writes T-1812's block and routes to a downstream cluster.

## Decision: GO (Fix A + Fix B + Fix C as sibling build slices)

No detector tightening recommended at this round. The reviewer is producing usable signal; the gap is downstream consumption (the FAILs accumulated because nobody had a "completed-corpus hygiene" cron pulling them up, and the per-task verdict cache silently aged). Fix C closes the cache gap structurally for the next sweep.

## Evidence

- Today's audit summary: `.context/audits/reviewer/2026-06-02.yaml` — totals stanza FAIL=31.
- Cached verdict bodies extracted via `grep -l "Overall:.*FAIL" .tasks/completed/T-*.md` (19 hits).
- Pattern fingerprints extracted via `awk '/## Reviewer Verdict/,/^## [^R]/'` + `grep -oE "\*\*[a-z-]+\*\* \(...\)"` per file.
- No tasks edited in service of this analysis (read-only investigation).
