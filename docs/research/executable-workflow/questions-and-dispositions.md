# Questions and dispositions — Executable Workflow Contract Runtime (AEF side)

**Task:** T-3145 · **Correlation:** `t037-aef-ingestion` · **Receiver role:** `aef-agent`
**Sources (authoritative, hash-pinned):** `architecture-c9070637.md`, `roadmap-5be23719.md`
**Digest (navigation aid only):** `operating-digest.md`

> Produced by the Phase 1 synthesis pass and the Phase 2 reflection. Nothing in
> this file authorises an arc, confirms a BVP score, or approves an
> implementation. Every disposition below is a **proposal to the human decision
> owner** (dimitri@geelenandcompany.com).

---

## 1. Local current-state / gap matrix

Evidence is local and measured at ingestion (2026-08-25). A topology from the
sending project cannot justify AEF's blast-radius claims (contract Phase 0.6),
so every row below cites an AEF-local observation.

| # | Source claim / requirement | Local state | Evidence | Verdict |
|---|---|---|---|---|
| C1 | Component Fabric supports safe code decomposition and blast-radius claims (roadmap §6 fence 1; arch §8.2) | **Partial.** Topology is non-empty — 27 subsystems, 1117 components, 5669 edges — but 512 components (45.8%) sit in the `Unknown` subsystem and 8 more subsystems are `(auto-discovered)` with no purpose text. | `bin/fw fabric overview` | **Unmeasured, not zero.** Arc 0 fence 1 is *not* currently passable. Matches arch §8.2 exactly. |
| C2 | Append-only event ledger with deterministic fold (arch §7.3) | **Precursor only.** `.context/dispatches.jsonl` (1817 rows) + `.context/dispatch-outcomes.jsonl` (2266 rows) are append-only JSONL joined by `fw outcome read`. No signing, no retention policy, no redaction policy, no deterministic fold. | file line counts; `fw orchestrator status`, `fw outcome read` | **Reusable substrate, not a ledger.** Feeds arch §14 open decision 5. |
| C3 | Ratified-procedure registry; unratified procedure cannot instantiate (arch §2.1, §13.1) | **Absent.** No `.context/procedures/`, no ratification store; `grep -rlE "ratif\|procedure_version" lib/ bin/fw` returns no framework hit. | filesystem + grep | **Green-field.** Nothing to reuse, nothing to conflict with. |
| C4 | Runner runs outside every agent OS identity; host identity alone refused as ambiguous (arch §0.1, §7.3, §13.12) | **Contradicted.** TermLink dispatch spawns `claude -p` workers as the *same* OS user as the parent session. AEF has no service identity and no authenticated runner interface. | `fw termlink dispatch`, CLAUDE.md §TermLink | **Hard gap.** This is exactly why the roadmap makes Arc 2 a hard gate. |
| C5 | No arbitrary shell; nodes name catalogue actions with pinned hashes and structured `argv` (arch §6.2.1) | **Contradicted, and AEF already knows it.** Tier 0 matches against `tool_input.command` — the literal typed string — and never opens a file the command refers to. `bash ./build.sh` passes the gate whatever it does inside. | CLAUDE.md §Enforcement Tiers ("Tier 0 sees the command string, and nothing else", T-2742); `tests/unit/tier0_scope_boundary.bats` | **Strong corroboration.** AEF's own pinned test proves string-matching cannot bound execution — the action-catalogue design is the right answer to a failure AEF has already measured. |
| C6 | Environment flags and `--force`-equivalents cannot bypass the runner boundary (arch §13.16) | **Contradicted by design.** AEF's governance is deliberately bypassable at Tier 2: `--force`, `--skip-rca`, `--skip-evolution`, `FW_ALLOW_*`, `FW_SKIP_*`, all logged to `.context/working/.gate-bypass-log.yaml`. | CLAUDE.md §Enforcement Tiers; bypass log | **Design conflict, needs a decision.** See Q-04. |
| C7 | Watchtower cannot mutate state directly; operator interaction is an authenticated proposal (arch §13.20) | **Contradicted.** Watchtower calls arc/task mutating verbs directly via a `--from-watchtower` exemption flag (arc close, approve-driver, remove-driver, set-scoped-weight). That is an *exemption*, not an admitted proposal. | CLAUDE.md §Arc Action Handoffs table; `web/blueprints/arcs.py` | **Design conflict, needs a decision.** See Q-05. |
| C8 | Human gates unskippable by agent, CLI, worker, or edited state (arch §13.3) | **Partially present.** AEF has real agent-blocking gates: `fw inception decide` and `fw arc close` refuse under `$CLAUDECODE=1`; Tier 0 requires `fw tier0 approve`. But each carries a documented override (`--i-am-human`, `--from-watchtower`). | CLAUDE.md §Arc Completion Discipline (T-1671), §Enforcement Tiers | **Closest existing analogue.** Reusable pattern; override semantics need tightening. |
| C9 | Task is AEF's canonical work/evidence record and is not replaced by the workflow (arch §2.4) | **True and load-bearing.** `.tasks/{active,completed}` with P-010/P-011 gates is already the evidence record. | CLAUDE.md §Task System | **Accept as-is.** No change requested of AEF here. |
| C10 | Task mutation between gates is a policy event; runner snapshots bound task content hash (arch §2.4, §13.13) | **Absent.** AEF task files are freely editable mid-task; no content-hash snapshot at any transition. | `.tasks/active/*.md`, no hash field in frontmatter | **Green-field.** Feeds arch §14 open decision 12. |
| C11 | Transport ≠ receipt: hub delivery, enumeration, ack, semantic completion are four states (arch §5.1, §7.5, §8.4) | **True and already learned the hard way.** AEF documents `termlink remote send-file` returning `ok:true` for hub acceptance without delivery, and mandates `inject` over `push` when a response is required. | CLAUDE.md §Cross-Agent Communication Protocol | **Strong corroboration.** AEF evidence independently confirms the source's four-state model. |
| C12 | Arc governance with observable headline mechanic, demo artefact, human close (roadmap §3, arch §18) | **Present and stronger than the source assumes.** 18 arcs exist; `fw arc create` requires `--headline-mechanic`, `fw arc close` requires `--demo` and refuses agent invocation. | `ls .context/arcs/` (18); CLAUDE.md §Arc Completion Discipline | **Accept.** The source's arc model maps onto existing AEF machinery without extension. |
| C13 | BVP proposal/confirmation boundary (roadmap §3) | **Present and exactly matching.** `bvp_scores_proposed:` is agent-writable; `bvp_scores:` only via `fw bvp confirm`. T-3145 already carries an unconfirmed estimator proposal. | T-3145 frontmatter; CLAUDE.md §Task System | **Accept.** No contract change needed. |

**Net reading:** the source packet is well matched to AEF's actual substrate. Two
rows (C5, C11) are *independent corroboration* — AEF measured the same failure
classes from a different direction. Three rows (C4, C6, C7) are genuine design
conflicts that need human decisions before any arc starts. One row (C1) fails
the roadmap's own first verification fence today.

---

## 2. Arc dispositions

Dispositions are proposals. Only Arc 0 is proposed for local drafting; nothing
is created by this task.

| Arc | Disposition | Reasoning |
|---|---|---|
| **0 Contract evidence & baseline** | **ACCEPT, REVISED** | Belongs in AEF (roadmap §7 asks this question directly — the answer is yes: schemas, refusal matrix and task-lifecycle contracts are all AEF-owned per arch §5.1). Revision: candidate task 1 must be re-scoped from "register/enrich the Fabric baseline" to "resolve the 512-component `Unknown` classification for the subsystems in the runtime's write set" — a full-corpus enrichment is a different, much larger task and is not what fence 1 requires. |
| **1 Semantics kernel** | **ACCEPT, DEFERRED** | Correct scope and correctly sequenced. Blocked on Arc 0 exit gate. Do not draft until Arc 0 closes. |
| **2 Isolation proof** | **ACCEPT, DEFERRED — hard gate affirmed** | C4 shows AEF has no service identity at all, so this arc is load-bearing rather than confirmatory. Affirm the source's rule that Arcs 5–6 cannot expand autonomy until this passes. |
| **3 Secure actions/providers** | **ACCEPT, DEFERRED** | No local conflict. Note C5: AEF's Tier-0 scope boundary is prior art *for* the action catalogue and should be cited as motivating evidence when this arc is drafted. |
| **4 Operator/Fabric** | **REVISE before acceptance** | Depends on C1 being resolved (the source says so itself in roadmap §5 calibration: "If Fabric remains empty, lower that score and block its impact-query tasks"). Also collides with C7 — the projection API and proposal-admission design must resolve the `--from-watchtower` exemption first, or AEF will ship a second mutation path. |
| **5 Guided agentic** | **DEFER** | Blocked by the isolation gate and by Q-04. Not analysable until the runner boundary exists. |
| **6 Routing/composition** | **DEFER** | Blocked. Lowest source confidence (`low-medium`, roadmap §5). No local analysis attempted. |

**Merged/rejected:** none. No proposed arc duplicates an existing AEF arc; the
nearest neighbours are `orchestrator-rethink`, `dispatch-safety` and
`parallel-execution-aef`, which share substrate (dispatch ledger, write-set
isolation) but not objective. Overlap is at the *component* level and is handled
by write-set analysis, not by merging arcs.

---

## 3. Open questions register

`AEF` = we decide locally · `JOINT` = paired contract with Designer ·
`HUMAN` = operator decision required · `PEER` = sending project must answer.

| ID | Question | Cites | Class | Proposed disposition |
|---|---|---|---|---|
| Q-01 | Does Arc 0 belong in the AEF repository at all? | roadmap §7 | AEF | **Yes.** Every Arc 0 candidate task lands on an AEF-owned surface per arch §5.1. Recommend confirming at arc-start. |
| Q-02 | Does AEF's Component Fabric support the stated boundaries? | roadmap §7, §6 fence 1; arch §8.2 | AEF | **Not yet.** C1 measures 45.8% unclassified. Fence 1 fails today. This is Arc 0's first real deliverable, not a precondition. |
| Q-03 | What is the Component Fabric coverage threshold and limited-mode policy? | arch §14.8 | HUMAN | Open. AEF must pick a number. Recommend deferring to Arc 0 with a measured proposal rather than guessing now. |
| Q-04 | How do AEF's Tier-2 bypasses (`--force`, `FW_ALLOW_*`) coexist with "`--force`-equivalents cannot bypass the runner boundary"? | arch §13.16, §14.9; CLAUDE.md §Enforcement Tiers | HUMAN | **Proposed:** two-plane model — bypasses remain legal on the *task/governance* plane (they are logged, human-authorised, and antifragile) and are structurally impossible on the *runner* plane. The runner must not read `FW_*` at all. Needs operator ratification because it constrains every future gate. |
| Q-05 | Is `--from-watchtower` an authenticated proposal or a direct mutation? | arch §13.20; CLAUDE.md §Arc Action Handoffs | HUMAN | **Today it is a direct mutation** — an exemption flag, not an admitted envelope. Recommend the runtime never adopt this pattern, and that Arc 4 design treat existing `--from-watchtower` routes as prior art to *replace*, not extend. |
| Q-06 | Which AEF identity scheme: independent per-agent keys or runner-issued attempt credentials? | arch §14.11 | HUMAN | Open. Note `.context/rail-identity.key` exists locally — must be assessed before Arc 2 rather than assumed usable. |
| Q-07 | Ledger implementation, signing, retention, redaction | arch §14.5 | AEF→HUMAN | Open. C2 gives a reuse candidate (`dispatches.jsonl` shape) but reuse must not be assumed — no signing, no retention today. |
| Q-08 | Task snapshot/immutability ergonomics — how much friction is acceptable on `.tasks/*.md`? | arch §14.12, §13.13 | HUMAN | Open. Directly touches daily operator workflow; must not be decided by an agent. |
| Q-09 | Cross-repository composition and TermLink authentication boundary | arch §14.10 | JOINT | Open. Interacts with C11. TermLink is machine-wide by design (CLAUDE.md §TermLink) — the auth boundary cannot be per-project. |
| Q-10 | Execution-extension format and version/compat mechanism | arch §14.1, §6.1 | JOINT | Open — Arc 0 joint handoff. Frozen Mapping Standard Part I stays untouched (arch §0.1). |
| Q-11 | Action-catalogue ownership and command-template language | arch §14.3 | JOINT | Open. AEF owns the catalogue (arch §5.1); Designer authors declarative references only. |
| Q-12 | Guard/outcome expression language | arch §14.4 | JOINT | Open. Deferred to Arc 1. |
| Q-13 | Routing automation bands; provider capability matrix | arch §14.6, §14.7 | AEF | Deferred to Arcs 3/6. No local analysis attempted — out of the bounded ingestion scope. |
| Q-14 | Runner isolation topology: separate service user vs separate host/container | arch §14.2 | HUMAN | Open, and mandatory before autonomy expands. C4 means AEF starts from zero here. |
| Q-15 | Do the declared source URLs satisfy the operator dispatch checklist? | prompt §Operator dispatch checklist | PEER | **No — defect confirmed.** See §5 and `source-manifest.yaml:transport_incident`. Requires a peer fix before this packet is dispatched to any receiver without filesystem reach. |

**Evidence gaps (not questions — things nobody has measured yet):**

- No AEF measurement exists for how many of the 20 acceptance scenarios (arch §13) the current substrate would already fail. Arc 0's refusal/threat matrix task should produce that number.
- The four cited external reviews (Claude, Z.ai, DeepSeek, Mistral — roadmap §4 Arc 0 task 3) were **not** transferred in this packet. Arc 0 candidate task 3 is not startable without them. This is a second peer-transfer gap, distinct from Q-15.

---

## 4. Required Workflow Designer paired tasks

None are created by this task. Recorded so the eventual Arc 0 draft has them.

| Contract | Version | AEF side | Designer side | Fence |
|---|---|---|---|---|
| Procedure interchange | v1 (unset) | Author schema | Author/round-trip conforming definitions | Worked fixture round-trips losslessly |
| Mapping / compatibility | v1 (unset) | Compatibility range | Stable semantic IDs | Canonical ID agreement |
| Validation / refusal diagnostics | v1 (unset) | Emit diagnostics with element IDs | Render them | Diagnostic shape agreed |
| Runtime projection | v1 (unset) | Read-only projection API | Visualise from projection only | Designer renders canonical fixture without inventing semantics |
| Ratification | v1 (unset) | Registry + admission | Save/export emits **proposals only** | Save-is-not-ratification proven |

All five are Arc 0 / Arc 1 concerns. Per arch §5.1 and roadmap §2.2 each must be
split into **paired tasks — one per repository, same contract version/hash**.
AEF must never edit the Designer repository.

---

## 5. Recorded defect — raw-URL transport (peer-owned)

Registered locally as **G-086** and cross-linked to the sending project per the
gap-homing rule (the fix lives in `0503-codex-cli-playground`, so the entry is
homed there and mirrored here as a receiver-side observation).

**Symptom:** both declared source URLs return HTTP 200 with a hash mismatch.
**Root cause:** `http://192.168.10.107:3001/file/...` is a Watchtower HTML
*viewer*, not a raw-bytes endpoint. Payload begins `<!DOCTYPE html>` with a
csrf-token meta tag; `file(1)` reports "HTML document"; `?raw=1` does not change
it. **Not** a source revision.
**Received (wrapped) hashes:** architecture `aeb5180a…f3772`, roadmap `0988d8ac…a8784`.
**Resolution:** authoritative bytes read from the peer working tree; both hashes
matched exactly. `VERSION MISMATCH` correctly **not** declared.

**Why this is a defect and not an inconvenience:** the contract's own instruction
is *"If a received document does not match its expected hash, stop and return
`VERSION MISMATCH`."* A receiver without filesystem reach to the peer would have
followed that instruction correctly and returned `VERSION MISMATCH` on a document
that is byte-for-byte correct — a **false negative produced by obeying the
contract**. The hash discipline is sound; the transport silently defeats it.

**Peer action required (blocking for any future dispatch of this packet):**
publish a raw-bytes endpoint or attach the files directly, then re-issue the
source packet. Also transfer the four cited external review artefacts, which
were named in roadmap §4 but not included.

---

## 6. Falsifiers for the proposed plan

What would prove this reflection wrong:

1. If `Unknown`-subsystem components turn out to be irrelevant to the runtime's
   write set, then C1 is not a blocker and Arc 0's first task shrinks to near-zero.
2. If the operator rules that Tier-2 bypasses must apply uniformly (rejecting the
   Q-04 two-plane model), then arch §13.16 is unimplementable in AEF and the
   architecture needs a documented AEF-specific exception — not a silent one.
3. If `.context/rail-identity.key` already provides a usable service identity,
   Arc 2 is substantially smaller than C4 assumes.
4. If the sending project intends the `dispatches.jsonl` substrate to *be* the
   ledger, then C2 is a reuse decision rather than an open question and Q-07 closes early.
