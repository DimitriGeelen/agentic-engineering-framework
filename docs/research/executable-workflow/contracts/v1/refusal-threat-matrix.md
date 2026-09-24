# EWCR Arc 0 — consolidated refusal/threat matrix

**Task:** T-3389 · **Arc:** `ewcr-arc0-contract-evidence` (arc-019) · **Date:** 2026-09-24
**Correlation:** `arc:ewcr-governed-delivery` — the seam correlation 832's operator ruled
on 2026-09-22. `EWCR-ARC0-ATTEST-832` remains readable history for the traffic that
carried this request; it is not the live correlation.

Every blocker finding from the four external reviews of dossier
`99d337126d9e0b9ca9437f1511ecd8e1504103309c6e970003605d2f69ebc9eb`, traced to a refusal
scenario in the frozen `refusal.schema.json` vocabulary, a responsible component, and a
verification fence that either exists or is named as a gap.

This is a **specification** artefact. No runtime code.

---

## 1. Sources

| # | Review | Path | sha256 |
|---|---|---|---|
| 1 | Claude (dispositions) | `../../architecture-c9070637.md` §17 | — (section of the pinned dossier; source review `docs/reports/T-027-claude-aef-review-response.md` in `0503-codex-cli-playground`, reviewing dossier `71465a3db6676f04f3dd120f68ddd25b4241cc86707f61c2cf0c3669b177b82f`) |
| 2 | Z.ai (dispositions + operator decision) | `../../architecture-c9070637.md` §18 | — (as above; source review reviewed dossier `15f1469e8a9ae38a8800449a87401b78b17aa698f719f9205deb1a7b5fcb9b14`) |
| 3 | DeepSeek (`deepseek/deepseek-r1-0528`) | `../../reviews/T-032-deepseek-review-response.md` | `4dae4098b2602b2794525292e1aa3053e0c486b23a67d9c3292ce80dc3a4d8a9` |
| 4 | Mistral (`mistralai/mistral-large-2512`) | `../../reviews/T-032-mistral-review-response.md` | `0eecb8af7be56ba045581167ef66b73fd9d2aa17fcd241f84defc0e7d17bfb0e` |

**Hashes verified at authoring time**, 2026-09-24, with `sha256sum` against the values
832-Workflow-designer published on DM rail `dm:3bba15e681b3a078:d1993c2c3ec44c94` offset 2.
Both match exactly. The two checks are verification lines on T-3389, so they re-run at
every close rather than resting on this sentence.

**Provenance.** The DeepSeek and Mistral files were transferred from
`/opt/0503-codex-cli-playground/docs/reports/` over hub topic `xfer-0503-reviews`
(manifest posted there), by the operator, on 2026-09-24 — after two agent-driven
transfer attempts failed in two different ways. Full record, including why the manual
copy was the route: `../../reviews/PROVENANCE.md`. Claude and Z.ai were transferred
earlier and live as dossier sections, not as separate files; they are not duplicated.

**Why sources 1–2 have no standalone hash.** They are sections of the hash-pinned
dossier, not independent artefacts in this repository. Their disposition tables are the
transferred form — the underlying review responses live only in the sending project. A
row sourced from §17/§18 is a disposition already ruled on, not a raw finding.

---

## 2. The measurement — how many §13 scenarios the current substrate would already fail

**14 of 20 would fail. 1 would pass. 5 are not applicable yet.**

This is the measurement named as missing in `../../questions-and-dispositions.md` §3
("No AEF measurement exists for how many of the 20 acceptance scenarios (arch §13) the
current substrate would already fail").

**Classification rule**, applied uniformly — stated because the count is meaningless
without it:

- **would-fail** — AEF has a live surface that is the nearest analogue of the invariant,
  and that surface violates it today, measurably.
- **would-pass** — AEF has a live surface that already satisfies the invariant.
- **not-applicable-yet** — the invariant's subject (a ratified procedure, an action
  catalogue, a provider adapter, a ledgered deadline event) has no analogue in AEF at
  all. Nothing exists to fail. This is *not* a pass, and counting it as one would be the
  false green this arc exists to prevent.

"Current substrate" means AEF as it runs today: the task gate, the PreToolUse hooks,
TermLink dispatch, the sidecar, Watchtower.

| §13 | Invariant (abbreviated) | Verdict | Nearest live analogue and what decides it |
|---|---|---|---|
| 1 | Unratified procedure cannot create an instance | not-applicable-yet | No procedure registry: `.context/procedures/` does not exist; no `ratified_procedure`/`procedure_version` hit in `lib/` or `bin/fw`. Green-field (matches `questions-and-dispositions.md` C3). |
| 2 | Unresolved action/profile references refused before dispatch | not-applicable-yet | No action catalogue exists; a reference cannot yet be called resolvable. Agrees with `traceability.yaml` #2 (gap, Arc 3 cand 1). |
| 3 | Human gate unskippable by agent, CLI, worker, or edited state | **would-fail** | AEF's real agent-blocking gates exist (`fw inception decide`, `fw arc close` refuse under `$CLAUDECODE=1`) but each carries a documented override: `lib/inception.sh:90,109` (`--i-am-human`). A Human AC is a `[ ]` in a text file that any Write can flip. |
| 4 | Registered script gets typed permitted args; cannot run from another repo/worktree | **would-fail** | Tier 0 matches `tool_input.command` — the literal typed string — and never opens the file the command refers to. Pinned by `tests/unit/tier0_scope_boundary.bats`. No typed argv, no execution-time worktree scoping. |
| 5 | Missing typed input prevents advancement even if a worker claims success | **would-fail** | P-011 is the nearest analogue and does block on authored shell lines — but on *shell lines*, not declared typed outputs, and `agents/task-create/update-task.sh:1174` (`[ -z "$verify_cmds" ] && return 0`) passes an empty block straight through. A task with no `## Verification` advances on the claim alone. |
| 6 | Unmeasured component scope follows visible policy, never zero-impact logic | **would-pass** | T-3068 makes `blast_radius` return `None`, not `0`, when components are unresolved; `lib/bvp.sh:366` prints "blast_radius unmeasured, so no quadrant" and the ranking reports how many tasks lack cost. The absence is displayed, not silently zeroed. The one invariant AEF already satisfies. |
| 7 | Duplicate remote result is idempotent; cannot double-run or double-advance | **would-fail** | `.context/dispatch-outcomes.jsonl` rows carry `dispatch_id, outcome, task_completion_outcome, task_id` — no attempt key, no result key, no dedupe. `fw outcome backprop` appends. |
| 8 | Unsupported provider capability → governed refusal, never silent substitution | not-applicable-yet | No provider adapters, no capability manifests. Agrees with `traceability.yaml` #8 (gap, Arc 3 cand 5/6). |
| 9 | Resume uses a durable, redacted execution envelope with precise provenance | **would-fail** | `fw resume status` is durable-ish (handover + working memory + git + tasks) but there is no redaction anywhere in the resume path — `grep -rn redact agents/resume/ lib/resume*.sh` returns nothing. |
| 10 | Completed instance renders visual trace + linked task, evidence, decisions, component facts, learnings | **would-fail** | Watchtower's task detail page (`web/blueprints/tasks.py:787`) renders the task and its sections, but there is no visual execution trace for any dispatch: `fw resolver explain <dispatch_id>` returns forensic text, not a trace, and the page carries few links into fabric/learnings (4 references total in the blueprint). |
| 11 | Agent-user edits cannot mutate instance state or launch a registered action | **would-fail** | An agent Write/Edit on `.tasks/active/T-*.md` changes `status:` directly. The Tier 1 gate requires a task to *exist*; it does not prevent editing that task's state. |
| 12 | Request carrying only shared host identity refused as ambiguous | **would-fail** | TermLink dispatch spawns `claude -p` workers as the *same OS user* as the parent. AEF has no service identity and no authenticated runner interface (`questions-and-dispositions.md` C4). |
| 13 | Bound-task mutation between gates records hash drift | **would-fail** | No content hash exists anywhere: `grep -rn "ac_digest\|task_hash\|content_hash" lib/*.sh agents/task-create/*.sh` returns nothing. Task files are freely editable mid-task. |
| 14 | Hub-delivered but never-enumerated reply becomes operator-visible and cannot deadlock | **would-fail** | CLAUDE.md:1548 documents the opposite as live behaviour: `termlink remote send-file` returns `ok:true` for hub acceptance, and files are "silently lost to event-only sessions". |
| 15 | Ratification-to-attempt policy/capability drift has a dedicated refusal route | not-applicable-yet | No ratification step exists to drift from. Agrees with `traceability.yaml` #15 (gap). |
| 16 | Env flags and `--force`-equivalents cannot bypass the runner boundary | **would-fail** | Bypass is sanctioned design, not a defect: `--force` (4 occurrences in `agents/task-create/update-task.sh`), `--skip-rca`, `--skip-evolution`, and 10 `FW_ALLOW_*`/`FW_SKIP_*` names in CLAUDE.md, all logged to `.gate-bypass-log.yaml`. This is the C6/Q-04 design conflict, not an oversight. |
| 17 | Recorded deadline survives restart; cannot fire twice or reset its budget | not-applicable-yet | No deadline events. `.context/cron-registry.yaml` is a schedule, not a ledgered absolute deadline with idempotent evaluation. |
| 18 | Cancellation during an in-flight attempt prevents later advancement | **would-fail** | T-577, documented in CLAUDE.md:1522: `termlink run --timeout` deregisters the session but does **not** kill the process — an orphaned `claude -p` agent wrote output 65 minutes after a 900s timeout. Cancellation does not prevent later effect. |
| 19 | Racing proposals admit exactly one envelope; loser gets a preserved refusal | **would-fail** | No compare-and-append: `grep -rn "compare_and_append\|expected_position" lib/*.sh` returns nothing. Converging write-sets are handled by agent discipline, and `fw write-set check` returns exit 2 (undecidable) on every real pair (T-3039). |
| 20 | Watchtower cannot mutate state directly; every interaction is an authenticated proposal | **would-fail** | `--from-watchtower` is an *exemption flag* on mutating verbs, not an admitted envelope — `web/blueprints/arcs.py:984,1040`. This is C7/Q-05. |

**Reading the number.** 14/20 is not a defect count. Five of the fourteen (3, 16, 20, and
to a degree 11 and 12) are AEF working exactly as designed — a deliberately bypassable
governance plane, which is the right design for a plane whose bypasses are logged and
human-authorised. They fail the *runner* invariant because the runner invariant is a
different plane. That two-plane reading is Q-04's proposed disposition and remains
operator-owned; this matrix measures against §13 as written, and does not assume Q-04's
answer.

---

## 3. The matrix

One row per blocker finding. **Inclusion rule:** a finding is in scope if it is labelled
`blocker`; or labelled `important`/`improvement` **and** named in its review's
"disqualifying evidence" or "missing primitives" list (it would disqualify the pilot); or
(Claude/Z.ai) carries a disposition that changed the architecture. Everything else is in
§4, named rather than dropped.

`reason_code` and `scenario_refs` are in the terms of `refusal.schema.json` (T-3385);
`scenario_refs` are architecture §13 numbers, 1–20. Where this matrix and
`traceability.yaml` (T-3393) overlap, they agree — see §5.

### 3.1 Claude (`architecture-c9070637.md` §17) — 6 rows

| ID | Source § | Threat | Refusal scenario | Responsible component | Verification fence |
|---|---|---|---|---|---|
| CL-1 | §17 "Runner trust boundary deferred" (Accept) | Work executes inside the agent's own trust domain; nothing distinguishes runner authority from agent authority, so a compromised or mistaken agent is indistinguishable from the runner. | `ambiguous_identity`, `scenario_refs: [12]` | Arc 2 cand 1 — runner isolation proof. No Fabric card: green-field (C4). | `gap:` an integration test that issues a transition request bearing only the host identity and asserts the runner refuses it with a durable `ambiguous_identity` record. |
| CL-2 | §17 "Host-grade rather than per-agent identity" (Accept) | Two agents on one host are indistinguishable to the runner; one can act with the other's authority and the ledger cannot tell them apart. | `ambiguous_identity`, `scenario_refs: [12]` | Arc 2 cand 1 — per-agent authenticated attempt identity. AEF analogue `agents/context/check-active-task.sh` has no identity concept at all. | `gap:` as CL-1, plus a test that two distinct agent identities on one host produce two distinguishable `requested_by.identity` values. |
| CL-3 | §17 "Mutable task binding" (Accept with refinement) | The bound task is edited between gates; the runner advances against content it never approved, so the task record and the executed work diverge silently. | `task_hash_drift`, `scenario_refs: [13, 11]` | Arc 1 cand 3 — task binding + revalidation. | `python3 tools/ewcr-contracts-check.py` — `task-lifecycle-contract.md` §3 "The two revalidation checkpoints" (covered). |
| CL-4 | §17 "Session-owned wait-event correlation" (Accept) | A reply reaches the hub but the target never enumerates it; the instance waits forever on a message that was accepted and lost. | **No reason_code in the frozen enum covers hub-enumeration divergence.** `scenario_refs: [14]`. Flagged: the refusal vocabulary needs an entry before #14 is contractable — v2 work, not an edit here. | TermLink transport boundary; `fw pause` chain as the operator-visible half. | `gap:` a test that a delivered-but-unenumerated reply surfaces to the operator within a bounded time and cannot deadlock the instance. Blocked on the missing reason_code. |
| CL-5 | §17 "Ratification-to-attempt policy drift" (Accept) | Policy or capability changes between the ratification that authorised a procedure and the attempt that runs it; the attempt executes under authority that no longer holds. | `policy_or_capability_drift`, `scenario_refs: [15]` | Arc 3 (capability profiles) with Arc 1 ledger versioning. | `gap:` the reason_code is in the frozen enum but no contract defines the route (agrees with `traceability.yaml` #15). |
| CL-6 | §17 "Structured actions / redaction invariant" (Accept) | An action that escapes to shell bypasses the catalogue entirely; unredacted evidence carries secrets into the ledger. | `command_substitution`, `scenario_refs: [4, 16]` | Arc 1 cand 1 / Arc 3 cand 1 — script contract (unwritten; `traceability.yaml` #4 gap). | Partial: `tests/unit/tier0_scope_boundary.bats` proves the **negative** — string matching cannot bound execution. `gap:` for the positive refusal test and for redaction-profile validation. |

### 3.2 Z.ai (`architecture-c9070637.md` §18) — 5 rows

| ID | Source § | Threat | Refusal scenario | Responsible component | Verification fence |
|---|---|---|---|---|---|
| ZA-2 | §18 "Control plane lacks deployment identity" (Accept with operator choice) | A second component admits envelopes, so two authorities exist and neither re-verifies the other's policy. | `ambiguous_identity`, `scenario_refs: [12, 20]` | Arc 2 cand 1 — exactly one privileged service runner. | `gap:` a test that a second admitting component is refused, not merely discouraged. |
| ZA-3 | §18 "Missing durable time authority" (Accept) | A deadline is lost across restart, or fires twice, or its budget silently resets — so a timeout is not a fact the ledger can be held to. | `direct_state_mutation`, `scenario_refs: [17]` | Arc 1 cand 8 (idempotent evaluation) with cand 5 (durable deadlines). | `python3 tools/ewcr-contracts-check.py` — `evidence-and-idempotency.md` §3.4 (covered). |
| ZA-4 | §18 "In-flight cancellation undefined" (Accept) | An attempt cancelled mid-flight still advances the instance when its result arrives; cancellation is advisory rather than binding. | `cancellation_in_effect`, `scenario_refs: [18]` | Arc 1 cand 8 with cand 6 (cancellation). | `python3 tools/ewcr-contracts-check.py` — `evidence-and-idempotency.md` §3.3 (covered). |
| ZA-5 | §18 "Watchtower authority contradiction" (Accept) | The operator UI writes state directly, so the runner is not the only admitting authority and the ledger has entries it never admitted. | `direct_state_mutation`, `scenario_refs: [20]` | Arc 1 cand 3. Live AEF surface: `web/blueprints/arcs.py` `--from-watchtower`. | `python3 tools/ewcr-contracts-check.py` — `task-lifecycle-contract.md` §4 (covered). |
| ZA-6 | §18 "Workflow Fabric version ambiguity" (Accept) | A procedure reference resolves to a different version than the one ratified, so two instances of "the same" workflow are not the same workflow. | `unresolved_reference`, `scenario_refs: [2]` | Arc 3 cand 1 (bounded action vocabulary) with the Arc 1 registry. | `gap:` `traceability.yaml` #2 records this as uncovered; needs the action vocabulary first. |

### 3.3 DeepSeek (`reviews/T-032-deepseek-review-response.md`) — 3 rows

| ID | Source § | Threat | Refusal scenario | Responsible component | Verification fence |
|---|---|---|---|---|---|
| DS-1 | Finding 1, **blocker**, high confidence — dossier §7.3, §7.5 | Time-of-check/time-of-use on task state: snapshots happen at gates but not *during* node execution, so a task cancelled or mutated mid-script is invisible until the next gate. The runner advances against an invalid task and the operator sees "completed" for work the task no longer authorises. | `task_hash_drift` + `cancellation_in_effect`, `scenario_refs: [13, 18]`. **NEW scenario — operator to accept** for the per-attempt clause, which exceeds §13 #13's "between gates": see §5.1 proposal N-1. | Arc 1 cand 3 (binding + revalidation) with cand 8 (attempt boundary). | Partial: `python3 tools/ewcr-contracts-check.py` covers the two gate checkpoints. `gap:` for the during-attempt check — nothing in v1 contracts it. |
| DS-2 | Finding 2, important, medium confidence — dossier §6.2.2 | Compensation actions carry no idempotency guarantee, so a retried remediation double-alters state when the first success was not recorded. Self-healing amplifies the failure it was invoked to repair. | `stale_position`, `scenario_refs: [7, 18]` | Arc 1 cand 8 — idempotent attempt/result/compensation. | `python3 tools/ewcr-contracts-check.py` — `evidence-and-idempotency.md` §3.1 and §3.3 (compensation runs only for a declared `action_ref`, only against a terminal-failed attempt). Covered. |
| DS-3 | Finding 3, important, high confidence — dossier §6.6.2, §7.5 | Output validation runs before evidence is materialised and redacted, opening a window in which evidence can be altered after validation but before recording. An adversarial or merely racing agent can make the record disagree with what was validated. | `unresolved_reference`, `scenario_refs: [9]` | Arc 1 cand 7 — snapshot/hash/immutability. | `python3 tools/ewcr-contracts-check.py` — `evidence-and-idempotency.md` §1 "Ordering invariant" (covered). |

### 3.4 Mistral (`reviews/T-032-mistral-review-response.md`) — 5 rows

| ID | Source § | Threat | Refusal scenario | Responsible component | Verification fence |
|---|---|---|---|---|---|
| MS-1 | Finding 1, **blocker**, high confidence — dossier §6.5 | Secret-binding resolution has no refusal rules for missing, revoked or mismatched bindings, so an adapter may silently substitute a default credential or fall back to ambient permissions — privilege escalation that leaves no refusal record because no refusal happened. | `unresolved_reference` (missing/revoked) + `capability_unsupported` (mismatched), `scenario_refs: [2, 8]` | Arc 3 cand 5/6 — provider adapters and capability manifests. | `gap:` both #2 and #8 are recorded uncovered in `traceability.yaml`. Needs adapter-specific refusal evidence in the attempt record. |
| MS-2 | Finding 2, important, high confidence — dossier §6.4 | Adapters are not required to declare refusal semantics for unsupported capabilities, so a procedure ratified against one provider behaves differently on another. Portability erodes into provider-specific quirks that nothing names. | `capability_unsupported`, `scenario_refs: [8]` | Arc 3 cand 5/6. | `gap:` refusal-semantics declaration must be validated at ratification; no contract defines it. |
| MS-3 | Finding 3, important, medium confidence — dossier §6.5 | Confused deputy: a binding named for a narrow capability resolves to a credential with broader permissions, and nothing validates the resolved secret against the declared capability profile before execution. | **NEW scenario — operator to accept**: §13 has no scenario for credential-scope validation. `scenario_refs:` none in v1. Nearest existing codes (`scope_mismatch` = repository/worktree scope, `capability_unsupported` = provider capability) name different axes; using either would misfile the threat. See §5.1 proposal N-2. | Arc 3 cand 5/6 with Arc 2 (isolation boundary). | `gap:` blocked on the NEW scenario being accepted. |
| MS-4 | Finding 4, improvement, high confidence — dossier §6.6.2 | No refusal rule when no eligible model satisfies a declared preference, so the runtime may silently substitute a weaker model — degraded or incorrect outcomes attributed to a model the author never chose. | `capability_unsupported`, `scenario_refs: [8]` — §13 #8's "never silent substitution" is the same invariant. | Arc 3 / Arc 6 — routing bands and provider capability matrix (Q-13, deferred). | `gap:` no capability matrix exists to route against. |
| MS-5 | Finding 5, improvement, high confidence — dossier §6.2.1 | No concrete refusal tests for path traversal, shell injection or environment-variable poisoning, so a malformed command can cross the runner's boundary while appearing allowlisted. | `command_substitution`, `scenario_refs: [4, 16]` | Arc 1 cand 1 / Arc 3 cand 1 — script contract. | Partial: `tests/unit/tier0_scope_boundary.bats` measures the current gap — Tier 0 sees the command string only, so `bash ./build.sh` passes whatever it does inside. `gap:` for positive refusal tests per malformation class. |

**Row count: 19** — Claude 6, Z.ai 5, DeepSeek 3, Mistral 5. Every review contributes at
least one row.

---

## 4. Not blockers — deliberately excluded

Named so the operator sees what was left out, not only what was let in.

| Excluded | Review | Why |
|---|---|---|
| ZA-1 "Review-version drift" | Z.ai §18 | A process defect in the review protocol itself, already **corrected** — dossier and protocol are pinned to the same revision. No runtime threat and no refusal scenario; it describes how reviews are conducted, not what the runner must refuse. |
| ZA-7 "Ledger-native competing shape" | Z.ai §18 | Accepted explicitly *as an evolution constraint*, not a pilot requirement — the disposition preserves a path toward smaller admission/executor components "without requiring that decomposition in the pilot". An architectural direction, not a threat with a refusal. |
| DeepSeek "Human decisions required" (task-state monitoring frequency; compensation idempotency policy) | DeepSeek | Operator-owned trade-offs (overhead vs TOCTOU risk; "at most once" vs explicit idempotency keys). The review itself states models cannot weigh operational load. These are inputs to a decision, not findings with a disposition. |
| Mistral "Human decisions required" (secret-binding, provider-adapter and model-routing refusal *policy* choices) | Mistral | Same class: each is a three-way choice (refuse / route to human gate / declared fallback) with a stated trade-off. The *requirement* for a rule is captured as MS-1/MS-2/MS-4; the *choice of which rule* is Sovereign. |
| Claude's "three operator-owned implementation choices" | Claude §17 | §17 states the review "does not decide" them. They are §14 open decisions (runner topology, credential scheme, task-immutability ergonomics), already tracked there and in Q-06/Q-08/Q-14. |
| "What would change this review" lists | DeepSeek, Mistral | Evidence requests that would revise a verdict, not findings against the architecture. They are satisfied — or not — by the contracts this arc ships; tracking them as rows would double-count MS-1..5 and DS-1..3. |
| Both reviews' "Smallest credible first pilot" sections | DeepSeek, Mistral | Pilot *design proposals*, not threats. Their disqualifying-evidence bullets are already the inclusion test applied in §3, so the content is represented; the pilot shape itself is Arc 1/Arc 2 scope. |

---

## 5. Agreement with `traceability.yaml`, and what is new

### 5.1 NEW scenarios proposed — operator to accept

Neither is given a §13 number here. Inventing a number 21 would put a statement into a
frozen section by assertion; the operator accepts or rejects these, and acceptance means
`contracts/v2/`.

**N-1 (from DS-1) — proposed statement:**
> Bound-task mutation or cancellation occurring *during* an in-flight attempt — not only
> between gates — is detected before that attempt's result is admitted; a result whose
> execution began before a cancellation cannot advance the instance.

Why it is not §13 #13: #13 says "between gates". DeepSeek's finding is precisely that the
between-gates window is not the only window, and that the gap between gates is where a
long-running script lives. §13 #18 covers cancellation's *effect* but assumes the
cancellation is observed; N-1 is about observing it.

**N-2 (from MS-3) — proposed statement:**
> A resolved secret binding whose effective privilege exceeds the capability profile
> declared by the node is refused before execution, with the excess named in the refusal
> record.

Why no existing reason_code fits: `scope_mismatch` means repository/worktree scope in
this vocabulary (`traceability.yaml` #4), and `capability_unsupported` means the provider
cannot do the thing. N-2 is the case where the provider *can* do more than it was asked
to be able to do. Accepting N-2 likely requires a new reason_code as well.

**Also flagged, not a new scenario:** CL-4 maps cleanly to §13 #14, but **#14 has no
`reason_code` in the frozen enum**. This matrix reaches that finding independently and it
agrees exactly with `traceability.yaml` #14, which records the same absence and calls it
"itself a finding". Two independent routes to the same gap is corroboration, and the
vocabulary gap is now named from both the invariant side and the review side.

### 5.2 Overlap check — no contradictions found

Every row whose `scenario_refs` touch a §13 scenario that `traceability.yaml` also covers
uses the same `reason_code` and names the same responsible component:

| §13 | This matrix | `traceability.yaml` | Agree? |
|---|---|---|---|
| 13 / 11 | CL-3, DS-1 → `task_hash_drift`, Arc 1 cand 3 | `task_hash_drift`, "Arc 1 cand 3 — task binding + revalidation" | yes |
| 17 | ZA-3 → `direct_state_mutation`, Arc 1 cand 8 + cand 5 | `direct_state_mutation`, "Arc 1 cand 8, with cand 5" | yes |
| 18 | ZA-4, DS-2 → `cancellation_in_effect` / `stale_position`, Arc 1 cand 8 | `cancellation_in_effect`, "Arc 1 cand 8, with cand 6" | yes |
| 20 | ZA-5 → `direct_state_mutation`, Arc 1 cand 3 | `direct_state_mutation`, "Arc 1 cand 3" | yes |
| 9 | DS-3 → `unresolved_reference`, Arc 1 cand 7 | `unresolved_reference`, "Arc 1 cand 7 — snapshot/hash/immutability" | yes |
| 7 | DS-2 → `stale_position`, Arc 1 cand 8 | `stale_position`, "Arc 1 cand 8" | yes |
| 2 | ZA-6, MS-1 → `unresolved_reference`, Arc 3 cand 1 | `unresolved_reference`, "Arc 3 candidate 1" | yes |
| 8 | MS-1, MS-2, MS-4 → `capability_unsupported`, Arc 3 cand 5/6 | `capability_unsupported`, "Arc 3 (candidates 5 and 6)" | yes |
| 12 | CL-1, CL-2, ZA-2 → `ambiguous_identity`, Arc 2 cand 1 | `ambiguous_identity`, "Arc 2 isolation proof (candidate 1)" | yes |
| 15 | CL-5 → `policy_or_capability_drift`, Arc 3 + Arc 1 | `policy_or_capability_drift`, "Arc 3 with Arc 1 ledger versioning" | yes |
| 4 / 16 | CL-6, MS-5 → `command_substitution` / `bypass_input`, Arc 1 cand 1 / Arc 3 cand 1 | #4 gap ("Arc 1 candidate 1 / Arc 3 candidate 1"); #16 `bypass_input`, Arc 1 cand 3 | yes |
| 14 | CL-4 → no reason_code exists | "no reason_code in the frozen enum covers it, which is itself a finding" | yes |

`traceability.yaml` is ratified and was **not edited** by this task. One note on inherited
reasoning rather than a contradiction: DS-3's `unresolved_reference` for §13 #9 is
inherited from `traceability.yaml` #9 rather than derived independently — it is the code
that row declares for the resume/ordering invariant, and this matrix follows it rather
than introducing a competing code for the same scenario.

### 5.3 Where the measurement and the trace differ in kind

`traceability.yaml` answers *"is this invariant contracted?"* — 11 covered, 9 gaps.
§2 above answers *"would today's substrate satisfy it?"* — 14 would-fail, 1 would-pass, 5
not-applicable-yet. The two are orthogonal and disagreement between them is expected, not
a defect: §13 #6 is a `gap` in the trace (no contract freezes it) and a **would-pass** in
the measurement (the behaviour is already correct and measured). A thing can be right
without being promised, and promised without being right.

---

## 6. What this artefact does not do

- It does not disposition the DeepSeek and Mistral findings **on the sending side**. 832's
  register carries Claude and Z.ai disposition tables only; this matrix gives all four
  families an AEF-side disposition, which is what exit-clause 2's arithmetic needs from
  this repository. Whether that satisfies 832's own clause is theirs to rule.
- It does not accept N-1 or N-2. Proposing a scenario is not numbering it.
- It does not edit `traceability.yaml`, the frozen schemas, or `MANIFEST.yaml`'s
  `schemas:` set. Ratified contracts are immutable; change means `contracts/v2/`.
- It ships no runtime code.
