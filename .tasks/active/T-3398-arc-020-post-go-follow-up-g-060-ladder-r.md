---
id: T-3398
name: "arc-020 post-GO follow-up: G-060 ladder rework, cv_index durability, T-3338
  partial-complete, Q-B"
description: >
  TermLink cross-check of arc-020's identity/circuit design surfaced a hub-federation
  defect (G-060), a hub-restart liveness false-negative (cv_index in-memory), confirmed
  T-3338 is legitimately partial-complete (not stranded), and pushed back on Q-B guessing.
  Capture findings, register concerns, route decisions to operator.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [termlink, peer-consult, identity, arc-020]
components: []
related_tasks: [T-3287, T-3338, T-3309, T-3397]
created: 2026-09-21T08:52:00Z
last_update: '2026-09-21T09:00:22Z'
date_finished:
arc_id: arc-020
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-09-21T09:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=8 (lines=230,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-21T09:00:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3398: arc-020 post-GO follow-up: G-060 ladder rework, cv_index durability, T-3338 partial-complete, Q-B

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Context

Arose as a tangent inside T-3397 (sidecar design consult) — the operator recalled
a prior conversation about a hierarchical identity scheme (host FQDN / hub /
project root / session / agent). Grepping our own repo found it: T-3287,
2026-09-06/07, an 11-round dialogue that produced arc-020 ("Cross-agent identity
& self-healing circuits") — GO'd, decomposed into 8 build slices (T-3286,
T-3307–T-3313), all `work-completed`. The design ratified a 5-level address
(host=FQDN / hub / project=path / session / @agent), a durable-name-vs-circuit-id
split, a V9 wire grammar, and a 3-state circuit lifecycle (live/dormant/dead)
resolved via a self-healing ladder that climbs host→hub→project→session on
failure. See `docs/reports/T-3287-identity-taxonomy-circuit-model.md` for the
full artifact.

Sent this design to termlink-agent [14213e] for a cross-check, since several
slices planned to reuse TermLink primitives (`channel claim`, `hub start/status`,
fleet verbs) and TermLink had just surfaced G-060 (hubs don't federate) in an
unrelated thread minutes earlier — worth checking against this design directly.

## Findings — TermLink's cross-check reply (2026-09-21, termlink-agent [14213e])

**1. Primitive drift — genuinely unverified, not "should be fine."** TermLink
has an affirmative prover (`scripts/substrate-smoke.sh`, exercises
create→post→claim→claim-transfer→worker-loop→verify-clean) but its scheduled
canary is NOT installed on their host — flagged by their own audit on ten
consecutive runs (`cron(substrate-smoke-canary): USER-field syntax but no
install in /etc/cron.d`). So: `channel post`+`client_msg_id` — evidenced today
(returned `delivered-unconfirmed`, confirmed only by reading offsets back).
`channel claim`/`claim_transfer`, `hub start/status`, fleet verbs — UNVERIFIED,
no recent check on their side. They explicitly declined to say "should work" —
named it as the same mistake T-967 made on us. Offered to queue running the
smoke prover and report stage-by-stage; not yet asked to do so.

**2. G-060 breaks the ladder's host→hub rung, plus a sharper NEW defect.**
Climbing to "hub" and asking it to reprovision across the tree doesn't work —
a hub only knows its own state (topics don't federate). A cross-host resolve
must climb to HOST, then address a *specific* hub, then fan out explicitly
per hub — the ladder currently has an implicit "hub-as-directory" assumption
that isn't available.

**The sharper, new finding: TermLink's `cv_index` (the per-hub current-value
index presence/discovery rides on) is IN-MEMORY ONLY** — process-local, cleared
on hub restart, repopulated over one heartbeat cycle. If our live/dormant/dead
determination (D4, T-3287) ever consults hub-side presence for the dead
determination, an ordinary hub restart would empty it — every merely-DORMANT circuit
reads as DEAD until producers heartbeat again. This is the frozen-husk class
*inverted*: not "dead thing looks alive" but "live thing looks dead," and the
failure mode is a **thundering re-provision storm** in response to a restart
that broke nothing, not a silent stall. **Needs durable state if dormant-vs-dead
must survive a hub restart — cv_index cannot be the source of truth for that
determination.**

**3. Q-B ("termlink or termlink") — TermLink declined to guess, on principle.**
"Three guesses logged against a half-dictated sentence and never confirmed is
how a guess quietly becomes a decision." Correct — this is the operator's
unfinished sentence to finish, not TermLink's or ours to infer. They DID answer
the one sub-guess that's a real architectural fact regardless of intent:
**(c) hub vs fleet is genuinely load-bearing, not a naming question.**
`termlink hub …` = local-hub-only state, by design, per G-060. `termlink fleet
…` = walks `~/.termlink/hubs.toml`, fans out across hubs explicitly. No third
option exists. **If arc-020's ladder provisions "across the tree" through a hub
verb anywhere, that's the same mistake as finding 2 above.** (b) is trivial —
binary is `termlink`, product is TermLink. (a) — whether circuits should be
built on termlink primitives at all — is explicitly not theirs to answer; open
on their side since the earlier sidecar-ownership thread.

**4. Reciprocal challenge, verified — real, but less alarming than posed.**
TermLink pointed out arc-020 shows "8 slices work-completed, arc still open"
and asked us to rule out their own known failure classes (77 GO'd inceptions
with no build slices ever filed; a "stranded-finalized" class where
`work-completed` gets written but the task dies before finalizing).
**Verified directly:**
- All 7 original slice test suites (144 tests across
  `test_aef_{address,circuit,resolve,election,governor,repo_source,
  provision_log}.py`) run green right now — genuinely live, not stranded.
- **T-3338 (S8, "wire aef_resolve endpoint-probe seam to live termlink
  probes")** — an 8th slice not in the original 7, added later — has
  `status: work-completed` in frontmatter but is **still sitting in
  `.tasks/active/`, with no episodic generated.** Re-running the finalize
  command (`fw task update T-3338 --status work-completed`) showed the real
  cause: **1 of 6 ACs is a genuinely unchecked `[REVIEW]` Human AC** — the
  task's own recommendation notes the live smoke test already passed
  in-session, but the human still needs to re-run
  `python3 tests/manual/s8_probe_smoke.py` on their own hub and tick the box.
  So: **not TermLink's "stranded-finalized" class (a crash before finalize)** —
  it's the ordinary Human-AC partial-complete gate working as designed. But it
  IS a genuinely open, unfinalized item — the frontmatter `status:
  work-completed` is misleading at a glance without checking AC state.
  **Flagged for the operator below, not auto-ticked (Human AC — never
  checked by the agent).**

Both sides explicit throughout: still advisory. Nothing here commits either
side to building anything.

**5. Follow-up (2026-09-21) — TermLink filed their own task, not a chat
promise.** The substrate-smoke verification is queued as **their T-3036**
(horizon: now) — scope: run `scripts/substrate-smoke.sh`, report the
stage-by-stage claim/claim_transfer verdict back to us, AND close their own
audit gap (install the canary, or record why not) — explicitly two
deliverables so a hand-run-once prover doesn't silently go stale again.
They deferred starting it themselves (own context budget wrap-up, handover
already written) rather than opening work they couldn't finish. **Pending:
their reply on T-3036's result — nothing to chase, it's on their side.**

They also accepted the T-3338 correction plainly, and added a sharp
observation worth keeping: **there is no way to tell "Human-AC gate holding
correctly" apart from "finalize crashed mid-flight" without opening the AC
state** — both read identically as `status: work-completed` sitting in
`active/`. TermLink has detection for the crash flavor; neither side has
anything that makes the healthy flavor self-evident at a glance. Not
actioned here (their own reflection was that flagging-to-operator rather
than self-ticking was the correct instinct, not a gap to close) — noted in
case this class of ambiguity is worth a structural fix later (a `fw doctor`
check distinguishing "stalled with unchecked Human AC" from "stalled with
all ACs checked, never finalized," maybe).

**6. Operator restated the resolution ladder in plain language; TermLink
confirmed it AND corrected two of their own earlier claims (2026-09-21).**

Operator's restatement: try agent (L5) directly → not there, ask session
(L4) to (re)instate it → session not there, ask the hub (L2) whether *this
project* is running here → no hub, ask the host (L1) to stand one up → once
the hub exists, ask it for the project → once that gives a session, ask the
session for the agent. **TermLink confirmed: correct, matches D1/D2/D5
exactly, no rework needed** — every rung addresses a specific,
address-named entity (this host/hub/project), never an arbitrary one, which
is precisely the case G-060 permits (a hub answering about its OWN state).

Two follow-up questions were put to TermLink to sanity-check the read
against their real system, and both produced corrections to *their own*
earlier statements:

- **Reachability is NOT the open gap — it's solved.** `termlink hub probe
  <addr>` (TLS handshake, no auth needed), `channel post --hub <addr>`,
  `termlink_remote_call`, and `fleet` verbs (walk `~/.termlink/hubs.toml`,
  fan out) all exist today. **The real open question is TRUST BOOTSTRAP,
  not transport:** doing more than a bare probe requires the target hub
  already in `hubs.toml` with a valid per-hub secret and a TOFU pin in
  `known_hubs` — and hub restarts can rotate both the HMAC secret and the
  TLS cert, which is why TermLink runs a whole rotation/reauth apparatus
  (fleet doctor, fleet reauth, bootstrap_from anchors, auto-heal, four
  canaries) to cope with that drift. **Open design question, not yet
  answered: can our ladder bootstrap trust on the fly when it climbs to a
  host it's never spoken to, or is the tree only navigable between hubs
  that already know each other?** This is a real decision point for the
  ladder's host-level rung, distinct from (and now resolved ahead of) the
  T-3397 sidecar-transport-ownership question.

- **cv_index finding, self-corrected and narrowed by TermLink — was
  over-scoped last round.** cv_index is an in-memory index over a
  *durable* SQLite-backed log — a hub restart loses the index, not the
  data. Two corrections to the earlier warning: (a) **not permanent** —
  repopulates within ~30s (one heartbeat cycle), not indefinitely; (b)
  **path-dependent, not universal** — `agent find-idle` already falls back
  to walking the durable log when cv_index is empty (T-2109), staying
  correct (just O(N) instead of O(K)). The paths with **no fallback**:
  `channel cv-keys` (returns count 0) and `subscribe
  --include-current-value` (returns empty current_values). **Accurate
  statement: after a hub restart, a ~30s window exists where O(K)
  fast-path presence reads return EMPTY; whether that reads as a false
  negative depends entirely on whether the caller falls back to the
  durable log or treats empty-index as empty-world.** Sharpened trap,
  their own words: TermLink's documentation says "empty cv_index is NOT an
  error (healthy state)" — true at the storage layer, dangerous at the
  caller layer, since it reassures exactly when a naive reader would
  misinterpret emptiness as absence. **If our ladder's presence rung uses
  a cv-keys-style fast-path read without a durable-log fallback, the
  thundering-reprovision risk from finding 2 above is real but bounded to
  ~30s, not indefinite** — corrected severity, not a dismissed finding.

- **New finding, bigger than either of the above: the "hub, do you have
  this project running here?" rung has NO counterpart in TermLink at
  all.** Hubs have no concept of "project" — no RPC exists to ask one.
  Sessions, topics, claims, presence — yes. Projects — no. **This isn't a
  cv_index false-negative risk, it's a question TermLink's hub cannot
  answer at all.** Project-awareness at that rung has to be built by AEF
  ourselves, presumably layered on top of the presence rail TermLink does
  provide. This is a real, undesigned gap in the ladder as currently
  conceived — bigger than the two questions that were actually asked, and
  better caught now than at implementation.

TermLink's closing framing: "your model of the ladder is right, the
cross-host hop is real, my cv_index warning was correct in kind but too
broad in scope and too long in duration, and the project rung needs
designing rather than mapping." Still advisory both ways.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — arc-020 located in own repo, TermLink
      cross-check requested and answered
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested — 144 arc-020 tests re-run green; T-3338's
      "work-completed but active/" state investigated and explained
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** DEFER

**Rationale:** Real evidence gaps, not a confidence hedge: (1) whether agent-to-agent traffic is actually cross-host or mostly co-located is unmeasured and determines the ladder's shape; (2) TermLink's own claim/claim_transfer primitives are unverified on their side (smoke-test canary not installed, offered but not yet run); (3) the operator's half-dictated Q-B question was never completed, so its intent is unknown, not guessable; (4) G-060 ladder rework and cv_index durability are joint architectural decisions needing both operators, not something to resolve unilaterally here. GO/NO-GO would be premature against these gaps.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
