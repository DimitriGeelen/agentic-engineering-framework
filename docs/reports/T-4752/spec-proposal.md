# T-4752 — proposed spec change: machine-readable conformance mapping (draft for the spec owners)

**Status:** DRAFT proposal. Not applied to `docs/specs/shared-worker-contract-transitions.md`. The spec owners
(AEF, TermLink, ring20) decide. Proposed as v0.3.4. The contract version field stays `wc/0.3`, because nothing
here changes a transition. It adds a reporting format and a table that restates what §6.6 already says.

Sources: ring20 draft `wc-conformance-mapping/0.1` (sidecar 43ffd8bf checker, 520283e9 mapping; stored under
`received/`), ring20's open question (derive `exercises_section3` from the spec), ring20's T8 note (sidecar msg
e6b6dec2, item 4). Review: `review.md`.

## 1. Addition to §6.6 External backends — "Mapping file"

Append after the paragraph **Per-case applicability**:

> **Mapping file.** The mapping is published as one YAML file, format `wc-conformance-mapping/0.1`, kept in the
> backend's repo and sent to the spec owners with each claim. A conformance runner reads it. Shape:
>
> ```yaml
> format: wc-conformance-mapping/0.1
> spec_version: wc/0.3.3          # the spec revision mapped against; must be a wc/0.3 revision
> spec_commit: <commit of the spec text>
> code_commit: <commit of the backend code mapped>
> date: 'YYYY-MM-DD'
> prose: <optional path to the human-readable table>
> declarations:                   # the §6.6 substitutions, one line each
>   backend: <registered name, not hub or local>
>   id_scheme: <id grammar and prefix, §4.1>
>   single_writer: <supervisor_gen + lock, or the lease with holder, expiry, takeover>
>   writer_auth: <credential or channel, §3.2>
>   evidence_channel: <§6.5 signed completion, or channel-bound evidence, §3.2>
>   persisted_at_source: <what sets persisted_at; the worker must not be able to set it>
>   G: <seconds, §2>
>   absent_optional_fields: [worker_binding, registry_epoch_seen, dispatcher.session]   # optional
> cases:                          # every §9 case, exactly once
>   - id: CC-01
>     verdict: PASS | N/A | GAP
>     rationale: <one line>
>     evidence: [<test or code reference>, …]   # required for PASS; allowed on GAP
>     tasks: [<T-N or project:T-N>, …]          # required for GAP
>     note: <optional>
> ```
>
> **Verdicts.** `PASS`: the case runs against the backend's store and matches (§9). `N/A`: allowed only where the
> §9 applicability table (below) says so. `GAP`: the backend does not yet pass the case and names the task that
> will close it. A mapping with any GAP is a progress report, not a conformance claim: the backend conforms only
> when every case is PASS or an allowed N/A. The spec's lowercase `pass`/`n/a` and the file's `PASS`/`N/A`
> are the same values.
>
> **Applicability is the spec's, not the backend's.** Whether a case may be N/A comes from the §9 table. A
> mapping does not declare it. A runner rejects N/A on a case the table marks `no`, and rejects a mapping that
> declares `exercises_section3` (or any equivalent) contrary to the table.
>
> **A mapping is valid when** the format and header fields are present; `spec_version` is a `wc/0.3` revision;
> every declaration is present and non-empty and `G` is a number; the cases are exactly CC-01..CC-25 once each;
> every verdict is one of the three; every case has a rationale; every PASS lists evidence; every GAP names a task;
> and every N/A is on a case the table allows. AEF's reader is
> `tests/conformance/worker-contract/check_mapping.py` (exit 0 valid, 1 invalid, 2 unreadable).

## 2. Addition to §9 — "§9 applicability table"

Insert after the §9 introduction, before CC-01. The same data is `applicability` in `vectors.yaml`. The vectors
file stays the machine source and the spec table is checked against it (one test, so the two cannot drift).

## §9 applicability table

| Case | Title | Subject | §3 rows exercised | May be N/A |
|---|---|---|---|---|
| CC-01 | Completion racing session end | transition | T3, T4, T5 | no |
| CC-02 | Same race, opposite order | transition | T3, T4 | no |
| CC-03 | Supervisor crash before commit | transition | T3, T4, T5 | no |
| CC-04 | Supervisor crash after commit | transition | T8 | no |
| CC-05 | Duplicate finalisation | transition | T8 | no |
| CC-06 | Retry while the old worker survives | transition | T1, T4, T-RECLAIM | no |
| CC-07 | Stale-attempt write rejected | transition | T3, T5 | no |
| CC-08 | Hub restart | transition | T4, T6, T7a | no (run with the backend's own restart) |
| CC-09 | Partition | transition | T5, T6, T7b | no |
| CC-10 | Parent-session loss | transition | T3 | no (run the lifecycle half; the questions half needs no channel) |
| CC-11 | Answer delivered and acked | capability: answer_channel | — | yes, without an answer channel (§5) |
| CC-12 | Answer TTL expiry bounces | capability: answer_channel | — | yes, without an answer channel (§5) |
| CC-13 | Local backend parity | transition | T3, T8 | no (with a lease: tests the lease) |
| CC-14 | Stale supervisor generation | transition | T-RECLAIM, T3 | no (with a lease: tests the lease) |
| CC-15 | Unknown resolution by operator | transition | T7d, T1 | no |
| CC-16 | Outcome derivation | transition | T3 | no |
| CC-17 | Absence across a registry epoch | capability: registry_epoch | — | yes, without `registry_epoch` (I7) |
| CC-18 | Caller-chosen dispatch id | capability: caller_chosen_ids | — | yes, without caller-chosen `D-<ulid>` ids (§4.1) |
| CC-19 | Paused is terminal, not success | transition | T3, T1 | no |
| CC-20 | Lost attempt seen alive | transition | T5 | no |
| CC-21 | Dispatched never seen | transition | T6b, T3b | no |
| CC-22 | Attested done is not finished work | transition | T7d | no |
| CC-23 | The nonce alone cannot complete | transition | T3 | no |
| CC-24 | Late T5 whose evidence postdates the lost entry | transition | T5 | no |
| CC-25 | Backend-initiated stop | transition | T3, T4 | no |

Rule for the table (restating §6.6 N2): a case whose subject is a §3 row, a forbidden transition, a `fence_reject`
reason or T8 is `no`. Only a case whose subject is the absent capability itself is `yes`.

**Effect on ring20's v0.3.3 mapping.** CC-11, CC-12, CC-17 and CC-18 stay N/A. **CC-10 does not:** it is a T3 case.
ring20's rationale already says the lifecycle half is covered by CC-01/CC-03, so it becomes PASS citing those
tests (or GAP if the parent-session-loss path differs). `exercises_section3` is removed from the format.

## 3. §3.3 T8 and §8 — "already completed" keys on the attempt's own completion record

ring20's note (msg e6b6dec2, item 4, from their T-2512): *"already completed" must key on the attempt's own
completion record; keying on a per-commission output hash looped our retries.*

Proposed text, appended to the **T8** paragraph in §3.3:

> T8 compares against the `evidence_digest` on **this attempt's own** `done` record, found by
> `(dispatch_id, attempt)`. A hash of the output, or any record of another attempt or of the dispatch as a whole,
> is not that record: a match on it does not make the submission T8, and a mismatch on it is not `done_conflict`.
> An attempt with no `done` record of its own is not "already completed" and its write is judged by its own row.

Proposed text, appended to §8.3 (the consumer checklist at the Phase B switch):

> Every legacy "already completed?" check is in the checklist. It moves to the attempt's own completion record. A
> check keyed on the dispatch (or commission) alone, or on an output hash, either answers for a different attempt
> or never answers. ring20 measured the second: a per-commission output-hash key looped its retries.
> (`update_outcome_row`'s last-writer-wins by `dispatch_id`, the T-3960 1c finding, is the AEF instance of the same
> keying.)

## 4. What this does not change

No transition, state, writer or fence reason. `vectors.yaml` keeps its `applicability` blocks; they already encode
the table above, and AEF's reader uses them. The mapping format id stays ring20's `wc-conformance-mapping/0.1`,
minus `exercises_section3`. If the owners prefer to keep the field as informational, the reader already rejects
it when it contradicts the table, so keeping it costs nothing in safety.
