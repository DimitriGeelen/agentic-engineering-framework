# T-1420 — Cross-project pickup semantic dedup (G-059)

Research artifact for inception T-1420. Created 2026-04-24. Home: `.tasks/active/T-1420-cross-project-pickup-semantic-dedup--has.md`.

## Problem origin

G-059 was added to `.context/project/concerns.yaml` in the prior session (2026-04-24 AM) after six framework-side duplicate inception pairs were noticed in a single week — all traced to external senders (termlink, ring20-manager) re-sending the same logical concern with drifted envelope bytes. Hash dedup (SHA256 over `pickup_type | summary | source_project`) let all six through because refinements to the summary string broke the hash.

Observed framework-side duplicate inception pairs:
- T-1311 ↔ T-1345
- T-1319 ↔ T-1348
- T-1321 ↔ T-1349
- T-1302 ↔ T-1352
- T-1305 ↔ T-1353
- T-1314 ↔ T-1351

## Dialogue log

**Session S-2026-0424-xxxx, user prompt:**

> proceed until context at 300k, apply framework governance !!! use termlink whwre sensible and possible t1063 is apporved !!

Standing directive reissued after compaction. Prior session, user confirmed "yes do thatg" to filing the G-059 inception. Agent filed T-1420 here. No further substantive dialogue — the inception is well-scoped from the G-059 register entry. The user's role is the GO/NO-GO decision via `fw task review T-1420`.

## Exploration

### Spike A — Quantify triple collisions

Executed 2026-04-24. Scanned 50 envelopes across `.context/pickup/{processed,rejected}/` (3 YAML parse failures excluded; `auto-deferred/` empty on framework side). Grouped by `(source_project, source_task_id, type)`.

**Results:** 42 unique triples, 5 collisions.

| Triple | Count | Location |
|--------|-------|----------|
| (051-vinix24, _empty_, feature-proposal) | 4 | processed × 4 |
| (051-vinix24, _empty_, bug-report) | 3 | processed × 2, rejected × 1 |
| (999-Agentic-Engineering-Framework, _empty_, pattern) | 2 | processed × 2 |
| **(termlink, T-1125, bug-report)** | **2** | **processed × 2 (P-024 + P-029)** |
| **(termlink, T-1123, bug-report)** | **2** | **processed × 2 (P-025 + P-030)** |

**Finding 1 (validates A1):** The two termlink cases are clean proof of the retry pattern — same upstream project, same upstream `task_id`, same type, distinct envelope bytes, both processed. The hash dedup could not collapse them because the summary text drifted between sends.

**Finding 2 (constrains the fix):** Three of the collisions have empty `source.task_id`. A naive triple key would over-collapse these (unrelated envelopes from the same project with no task context). The fix must gate on non-empty `task_id` — if empty, fall through to hash-only.

### Spike C — Current dedup implementation

Read `lib/pickup.sh`:

- **Line 114, `pickup_dedup_hash`:** normalizes `pickup_type | summary | source_project` → SHA256. A 3-field tuple missing `source_task_id`, including `summary` — a drift-sensitive field. Any refinement to the summary ("5+ times" → "5-6 times this week") produces a new hash.
- **Line 119, `pickup_dedup_check`:** applies a 7-day cooldown on stored hashes. Useful for identical retries, useless for drifted ones.
- **Lines 39-49, self-project dedup (G-046 / T-1339):** checks `source_project == local_project AND source_task in .tasks/completed/` → auto-defer. Proves the auto-deferred routing pattern is wired and conventional — the new cross-project second-pass extends it, not invents it.

### Spike D — Implementation sketch

Natural intervention point: extend `pickup_dedup_check` to call a second-pass `pickup_triple_check` after the hash check succeeds. The triple check:

1. Require non-empty `source.task_id` (else skip; let hash-only + review catch it)
2. Scan `.tasks/active/` + `.tasks/completed/` for a task whose originating envelope's triple matched, OR scan `dedup.log` augmented with a triple column
3. If a match exists AND the current envelope doesn't set `supersedes:`, route to `auto-deferred/` with a breadcrumb `T-XXX-upstream.txt` naming the active inception
4. `supersedes: T-XXX` in the new envelope bypasses the triple check (explicit intent)

Alternative: add a triple field to `dedup.log` alongside the hash, then match on `(hash OR triple)`. Preserves the 7-day cooldown semantics for both.

### Spikes B and E — Deferred to build

- **B (false-positive survey):** no observed legitimate same-triple retry in 50-envelope sample. The `supersedes:` hatch is the recovery lane regardless. Fresh survey as part of build B1.
- **E (cross-project scope / termlink parity):** confirm during build B5 whether termlink vendors `lib/pickup.sh` via shim (fix propagates automatically) or runs an independent pickup lib (fix needs backport).

## Build decomposition (after GO)

- **B1** — Add `supersedes:` field to envelope schema + validator. Update `.context/pickup/templates/*.yaml` examples.
- **B2** — Extend `pickup_dedup_check` in `lib/pickup.sh` with a second-pass triple check. Gate on non-empty `task_id`. Route matches to `auto-deferred/` with breadcrumb.
- **B3** — Add `fw pickup auto-deferred list` surface so operators can audit matches.
- **B4** — Regression test: seed two envelopes with same triple + distinct hashes — second lands in `auto-deferred/`. Also: `supersedes: T-XXX` on second envelope lands in active/.
- **B5** — Backport check: does termlink's pickup share `lib/pickup.sh`? If no, open a cross-repo ticket via pickup.

## References

- Register: `.context/project/concerns.yaml` entry `G-059`
- Precedent: `G-046` + T-1339 (self-project dedup), `lib/pickup.sh` lines 39-49
- Dedup code: `lib/pickup.sh` lines 104-150
- Observed pairs: T-1311↔T-1345, T-1319↔T-1348, T-1321↔T-1349, T-1302↔T-1352, T-1305↔T-1353, T-1314↔T-1351
