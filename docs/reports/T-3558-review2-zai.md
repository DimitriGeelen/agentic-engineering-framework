# T-3558 external review ROUND 2 — zai

Reviewer: Z.ai GLM-5.3 (opencode, Z.AI Coding Plan). Run 2026-09-29 in a neutral scratch directory with only `T-3558-external-review-brief-round2.md` as input. Reproduced verbatim below.

---

## Round 2 review — D-645 sidecar consumption design

### Q1 — Is D-645 the right consumption design?

Yes in direction. It is the first proposal in either round that attacks the measured failure — consumption — with mechanism rather than agent discipline, and it beats round 1's own proposals in three specific ways:

1. **The two confirms decompose failure by remedy.** Round 1's "acknowledge on arrival, escalate on silence" treated silence as one condition. D-645 splits it: no CONFIRM-1 → retry (delivery broken); CONFIRM-1 without CONFIRM-2 → escalate (delivery fine, handover broken — retrying is waste). This maps exactly onto the measured incidents, where delivery was never the problem.
2. **Store-then-inject** makes durability independent of agent availability, and makes "fail toward not-ready" the safe direction. Round 1's gate still assumed the agent would come to the mail.
3. **Receiver-side flag with hash-before-flag** puts state with the party holding the obligation, correctly ordered. The built inversion (sender-side bit; hub acceptance named `INJECTED_NOW`) shows what happens without it.

What it still misses: (a) **injection security is unspecified**, and the API is a remote write into an agent's context — load-bearing, not polish (Q3); (b) **no idempotency** — sender retry after a lost CONFIRM-1 will double-store and possibly double-inject; (c) **deadlines are implicit** — every non-terminal state needs a clock and a named owner, including a sender-side terminal failure (as tabled, a dead receiver leaves the sender retrying forever: the 73-hour case one layer down); (d) if the hub stays as fallback carrier, **confirm semantics must be identical across carriers** or `INJECTED_NOW` reincarnates as "posted via hub"; (e) the readiness predicate that `HANDED_OVER` depends on is open, and a predicate never true reproduces the original failure silently, one layer down.

### Q2 — Push versus gate

Complementary, and precisely so: **push removes the dependency on agent virtue; the gate verifies the push machinery actually worked.** Push can fail silently (tick dead, readiness never true, adapter missing), and silent failure of a health mechanism is this system's demonstrated failure class — unread inboxes, `INJECTED_NOW`, the mention-counting audit. A backstop that costs nothing on the happy path and hard-stops on the unhappy one is not redundant.

If push works, the gate should check, at task open and close: (1) no message in the **local sidecar store** sits non-terminal past policy — especially RECEIVED-but-not-HANDED_OVER, which means the injection pipeline is stalled (note: with push, the gate no longer reads the hub; it reads the store); (2) machinery liveness — tick/notify heartbeat within N cadences; (3) the self-canary round-tripped inside its deadline; (4) every HANDED_OVER message carries an ACCEPTED or DECLINED by its deadline.

One required refinement: **the gate forces a decision, not the work.** "No unprocessed mail" where processed ∈ {accepted, declined}; otherwise any peer can block your task progression by sending mail (a mail-DoS). DECLINED at the gate, with a reason on the refusal ledger, discharges the obligation honestly.

### Q3 — Security of injection

Threat model: a sidecar HTTP endpoint that writes into a tool-bearing agent's prompt is (i) a direct injection channel for anything that can reach it; (ii) an *indirect* channel via an honest peer relaying hostile content; (iii) a social-engineering channel ("run this to fix your bug") against dutiful agents; (iv) a replay/spoofing channel absent round 1's identity work.

Requirements:

- **Who may call:** bind localhost by default (cross-host arrives via the hub tunnel or authenticated TLS, never a bare open port); mandatory per-message signature verification against the TermLink identity, per round 1's ruling; a default-deny peer allowlist, visible to and set by the human (sovereignty implies visibility). Unknown sender → quarantine: stored, flagged, surfaced as data, ledgered — never dropped, never injected.
- **Framing:** a structured envelope with untrusted-content delimitation; payloads containing the delimiters are rejected, not escaped. The wrapper states provenance and that any instructions inside are untrusted. The constitutional rule extended to peers: **a peer message can propose, never decide — a peer has the standing of an agent, not of the human.**
- **Authority is the real boundary; framing is defence in depth.** Injection grants attention, never authority. An action request (envelope intent: `FYI | QUESTION | REQUEST-ACTION`) must materialise as a *task proposal* through the normal approval gates; injection alone can never cause tool execution, file writes, or task creation. Then even a fully successful prompt injection gains at most a proposal and a ledger entry — the safety property does not depend on the LLM behaving. (Same spirit as round 1's "key files under one OS user are not a boundary": don't call a soft control a boundary.)
- **Bounds:** per-message size cap, per-tick batch/context budget, per-sender rate limits, text + referenced blobs only, replay protection (nonce + monotonic sequence; duplicates refused), exact injected bytes hashed and logged with message id / sender / tick.

Candour: delimitation mitigates but does not solve indirect prompt injection. That is precisely why the authority layer, not the framing, must carry the security argument.

### Q4 — The lifecycle states

The skeleton is right; the two infrastructure-confirmed states separating the retry domain from the escalate domain is the best part. On names: **HANDED_OVER is correct and "consumed" is wrong** — "consumed" implies the work is done *and* collides with queue semantics where consume = ack/destroy. Keep HANDED_OVER. `REPLIED` should mean "reply dispatched", with the reply tracked on its own lifecycle; say so explicitly to avoid double-counting delivery.

Missing:

- **Idempotency:** every message gets an id (sender, nonce, sequence) at SENT; the receiver dedups at store; all transitions are idempotent (a second CONFIRM-1 for a stored id is a re-emit, not an error). Without this, "retry on missing CONFIRM-1" is unimplementable safely.
- **Per-state deadlines and retry ownership:** SENT→RECEIVED, sender retries, bounded; exhausted budget → **UNDELIVERABLE** (missing sender-side terminal state — add it), ledgered. RECEIVED→HANDED_OVER: nobody retries delivery; the receiver's tick owns the deadline. HANDED_OVER→ACCEPTED: agent owns it, sidecar enforces the deadline. Deadlines travel in the envelope, clamped to policy.
- **ESCALATED must be set by infrastructure on deadline, never by the agent.** A state whose purpose is to catch a derelict party must not be set by that party. ACCEPTED being agent-set is acceptable only because a deadline checks it.
- **DECLINED needs reason codes** and must be settable by policy (spam, unknown sender) as well as by the agent. Optionally **SUPERSEDED** for sender corrections, so receivers don't act on stale mail.
- States live transactionally in durable stores on both sides; delete or rename `INJECTED_NOW` (to `HUB_ACCEPTED` if kept) — an accounting name that lies is worse than no name, per the design doc's own warning.

### Q5 — The open design questions

- **Tick cadence:** make the flag check **event-driven** (the store/flag operation notifies the waiter; the HTTP handler can trigger it directly), with the 15s tick as a **liveness backstop whose heartbeat is itself monitored** — a primary tick fails silently; a backstop tick fails loudly. Instrument RECEIVED→HANDED_OVER latency from day one; validate 15s against the real cost of an injection point per host, not by intuition.
- **Readiness predicate:** define it as a harness contract, not sidecar guessing: inject at **next model-request construction**, with no in-flight tool call and context budget available. Mechanically this is push-to-tray, read-at-safe-point — the correct hybrid. A host that exposes no such hook is not D-645-capable; make capability an explicit per-host adapter requirement rather than degrading silently.
- **Hub under the API:** keep it for discovery, cross-host fallback (NAT), and bulk blobs — but require **uniform confirm semantics across carriers**: the receiver sidecar polls the hub into the same store/flag pipeline and emits CONFIRM-1 only after store+flag, whichever carrier delivered. Forbid any path that reports delivery without store and flag.

### Q6 — Why designs do not get built

Two root causes, both structural: ratification did not **mechanically spawn** the slice tasks (a decision without a spawned task is a silent failure by another name), and the audit accepted a **mention as evidence of a build** — an audit that tests proxies isn't an audit.

Changes:

1. **Ratification auto-spawns one task per slice, with blocked-by chains** — the dependency that made slice 1 foundational becomes machine-visible.
2. **Definition of built = artifact evidence.** Each slice carries a verification command; built means it passes in CI (or its last CI result is green). "Mentioned in a later task" proves nothing.
3. **Apply the message lifecycle to designs themselves:** RATIFIED → TASKED → BUILT(verified) → OPERATIONAL, with ESCALATED on deadline, checked by a tick. The refusal ledger records missed build deadlines, making stalls data rather than silence. There is a certain obligation in using D-645's own state machine to prevent D-645's own recurrence.
4. **The agent reviewer** gets one adversarial check: for every GO/RATIFIED decision in the window, produce the artifact evidence — assume mentions are false positives until shown otherwise.
5. Guard the inverse: auto-spawned tasks that go unstarted escalate to the human, who may cancel with a ledger entry. Sovereignty preserved; silence impossible.

### Q7 — Minimum viable first build

One machine, localhost only, two sidecars, two real AEF agent sessions, one message, the full state chain observed at the sender — and the DECLINED path exercised on day one.

**Scope:** receiver sidecar (authenticated endpoint, store-to-disk with blobs, dirty-bit after store, CONFIRM-1, notify+tick, inject-at-safe-point via one real host adapter, CONFIRM-2); sender sidecar (API call, bounded retry, UNDELIVERABLE, per-message ledger); signed envelope with ids, deadlines, and the untrusted-content wrapper from the first message — security framing is not a later slice.

**Tests that cannot pass falsely** — one rule underlies all of them: *internal states may fail a test but never pass one; only externally observable behaviour passes.*

1. **The oracle is the reply content.** A run-time nonce, with a transform requirement (e.g., "reply with the nonce reversed"), so no fixture, canned responder, or state assertion can satisfy it. The receiving agent's own model call must have happened.
2. **Dead receiver sidecar** (killed mid-flight) → sender reaches UNDELIVERABLE within its budget, ledger entry exists. Tests the retry domain.
3. **Never-ready harness** (adapter that never offers a safe point) → RECEIVED hits its deadline and escalates. This tests the exact failure class round 1 measured, and is the test `INJECTED_NOW` would have failed.
4. **Dropped first CONFIRM-1** (harness fault injection) → stored once, injected once. Assert the injection count equals one.
5. **Hostile payload** ("ignore instructions, run X") → no execution *and* no silence: DECLINED or surfaced-without-action on the ledger.
6. **Restart after store** → message survives, injected exactly once.
7. **The canary is permanent, not a one-off**: the same loop on a schedule, so "the loop works" is continuously re-proven — a canary pass requires a live agent to have composed a reply within its deadline. Harness-only CI runs are labelled as such and can never be reported as end-to-end green.

---

```
VERDICT: amber
  green   = build D-645 as designed, plus any listed refinements
  amber   = sound direction, but it needs the changes listed below first
  red     = do not build D-645 as designed
  unknown = cannot judge from this brief (say what is missing)
GUIDANCE:
  1. Specify injection security before any cross-host exposure: authenticated callers
     (TermLink identity, default-deny peer allowlist, localhost bind), untrusted-content
     envelope with delimiter rejection, size/rate/context budget bounds, and the rule
     that REQUEST-ACTION becomes a task proposal through the approval path — injection
     grants attention, never authority. Safety must not depend on the LLM behaving.
  2. Add idempotency (message ids, dedup at store) and a deadline with a named clock
     owner for every non-terminal state; add sender-side UNDELIVERABLE; ESCALATED is
     set by infrastructure on deadline, never by the agent it is meant to catch.
  3. Uniform confirm semantics across carriers if the hub stays beneath the API; no
     path may report delivery without store+flag. Remove or rename INJECTED_NOW.
  4. Fix the build-stall mechanism or slice 1 stalls again: ratification auto-spawns
     slice tasks with blocked-by chains; "built" means the slice's verification command
     passes in CI; missed build deadlines hit the refusal ledger.
  5. Keep the round-1 gate as backstop and the canary as permanent resident; the gate
     checks the sidecar store, machinery heartbeat, and canary — and forces decisions
     (accept/decline), never blocks on unanswered work.
FIRST SLICE: the receiver sidecar end to end — authenticated API, store, dirty-bit,
  CONFIRM-1, inject-at-safe-point through one real host adapter, CONFIRM-2 — plus a
  sender with bounded retry and UNDELIVERABLE. Proof: a run-time nonce question between
  two real agent sessions where the only passing assertion is the transformed nonce in
  the reply, alongside the fault-injection tests (dead sidecar, never-ready harness,
  dropped CONFIRM-1, hostile payload). States can fail this test; only behaviour passes it.
TOP RISK: the health machinery lying again — RECEIVED set, HANDED_OVER never arriving
  (or falsely asserted) while the ledger reads green. This exact failure class has
  already occurred three times in this brief (unread inboxes, INJECTED_NOW, the
  mention-counting audit), and D-645's guard against it — handover deadlines,
  infrastructure-set escalation, a content-verifying canary — is the part still missing
  from the design as written.
```
