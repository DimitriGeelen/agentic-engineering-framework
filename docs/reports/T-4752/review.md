# T-4752 — review of ring20's conformance-mapping draft (`wc-conformance-mapping/0.1`)

Reviewed: `received/wc-mapping-check.py` (sha256 4fbb2bff8659…, 66 lines) and `received/conformance-map-v0.3.3.yaml`
(sha256 4b19629724ea…). Both sha256 prefixes re-checked on 2026-10-26 and still match ring20's stated values.
The checker was read in full before it ran. It was run with `python3 -I` against the received YAML and against
scratch fixtures made from it in a `mktemp -d` dir that was removed afterwards.

## What the code does (safety)

- Reads one file with `yaml.safe_load`, so no object construction. No network, no subprocess, no writes, no
  imports besides `re`, `sys`, `yaml`. Safe to run on untrusted input. It does not close its file handle (harmless).
- Exit 0 = valid, 1 = invalid, 2 = unreadable (OSError, missing argv, YAMLError).

## What it checks

| Rule | Where |
|---|---|
| `format == wc-conformance-mapping/0.1` | line 22 |
| header `spec_version`, `spec_commit`, `code_commit`, `date` present and truthy | line 24 |
| `declarations` has the seven §6.6 keys (`backend`, `id_scheme`, `single_writer`, `writer_auth`, `evidence_channel`, `persisted_at_source`, `G`) | line 27 |
| `cases` ids are exactly CC-01..CC-25, once each | line 32 |
| `verdict` ∈ {PASS, N/A, GAP} | line 37 |
| every case has a `rationale` | line 39 |
| PASS has `evidence` | line 41 |
| GAP names at least one task, `T-N` or `<project>:T-N` | line 43 |
| N/A only with `exercises_section3: false` | line 45 |

## Results

| Input | Result |
|---|---|
| received `conformance-map-v0.3.3.yaml` | `OK ring20: PASS 9, N/A 5, GAP 11`, exit 0 |
| duplicate id (CC-02 renamed CC-01) | INVALID, exit 1 (the message names the missing id CC-02, not the duplicate) |
| PASS with `evidence: []` | INVALID `CC-01: PASS without evidence` |
| GAP with `tasks: []` | INVALID `CC-07: GAP names no task` |
| **CC-01 (a T3/T4/T5 case) set to N/A with `exercises_section3: false`** | **OK, exit 0** |
| PASS with `evidence: "x"` (a string, not a list) | OK |
| `declarations.backend: ''` | OK (prints `OK : …`) |
| a non-mapping entry in `cases` | crash, `AttributeError`, exit 1 from the traceback |
| a case with `id: null` | crash, `TypeError` in `sorted()` |
| top level is a list | crash, `AttributeError` |

The counts differ from the "3 PASS, 5 N/A, 17 GAP" in the task description. That figure was from ring20's earlier
prose table. The YAML is later: it reflects their T-2509..T-2523 work.

## Gaps

1. **N/A on a §3 case is allowed by declaration** (the open question ring20 raised). The backend sets
   `exercises_section3`, so any case can be made N/A. The scratch run above shows CC-01 going N/A with exit 0.
2. **ring20's own mapping fails the spec rule on CC-10.** `vectors.yaml` gives CC-10 (Parent-session loss)
   `subject: transition, rows: [T3], n_a_allowed: false`. §6.6 lists only CC-11, CC-12, CC-17 and CC-18 as
   cases that may be N/A. ring20 marks CC-10 N/A because it has no questions channel or `dispatcher.session`.
   Under §6.6 a case phrased in terms of a missing capability is run with the backend's own equivalent and stays
   PASS or GAP. Their rationale already says "the lifecycle half is covered by CC-01/CC-03". That makes it a PASS
   naming those tests, or a GAP. The declared checker cannot see this; a checker that derives the rule from the
   spec table rejects it.
3. **Malformed input crashes** instead of giving exit 1 with a message: non-mapping top level, non-mapping case,
   null id.
4. **Field types are not checked.** `evidence` and `tasks` can be strings; declaration values can be empty;
   `G` is not checked to be a number.
5. **`spec_version` is not compared with the spec.** A mapping against wc/0.2 passes as long as the field is
   non-empty.
6. **The duplicate message** names the symmetric difference first, so a duplicate that displaces another id is
   reported as "missing". Cosmetic.
7. **A GAP may also carry evidence** (CC-20 does: half done). That is reasonable and is kept. A PASS that also
   names tasks is not checked either way. That is also fine.

The spec text says each case is `pass` or `n/a`. The draft adds GAP, which the spec's §6.6 has no word for
(a case that is neither passing nor allowed N/A means "does not conform"). GAP is the honest third value for a
backend that is mapping on its way to conformance. The proposal keeps it and says what it means.

## What AEF's reader does differently (`tests/conformance/worker-contract/check_mapping.py`)

- Reimplements the rules above. It does not import or copy ring20's file.
- Derives "may be N/A" from `vectors.yaml` (`applicability.n_a_allowed`), the spec table for §9. It ignores a
  declared `exercises_section3`, or refuses it when it contradicts the table.
- Reports malformed input as INVALID with exit 1. It does not crash.
- Checks types: `evidence`/`tasks` are non-empty lists of strings, declarations are non-empty, `G` is a number.
- Checks `spec_version` is `wc/0.3` or a `wc/0.3.N` patch, matching the vectors' `contract_version`.
- Reports duplicate ids and missing ids separately.
