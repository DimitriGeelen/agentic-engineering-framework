---
id: T-3398
name: "arc-020 post-GO follow-up: G-060 ladder rework, cv_index durability, T-3338
  partial-complete, Q-B"
description: >
  TermLink cross-check of arc-020's identity/circuit design surfaced a hub-federation
  defect (G-060), a hub-restart liveness false-negative (cv_index in-memory), confirmed
  T-3338 is legitimately partial-complete (not stranded), and pushed back on Q-B guessing.
  Capture findings, register concerns, route decisions to operator.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [termlink, peer-consult, identity, arc-020]
components: []
related_tasks: [T-3287, T-3338, T-3309, T-3397]
created: 2026-09-21T08:52:00Z
last_update: 2026-09-21T10:42:54Z
date_finished: 2026-09-21T10:42:54Z
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

- **IW-1: Does the restated resolution ladder (host→hub→project→session→agent)
  hold up against G-060 (hubs don't federate)?**
  confidence: 3
  disposition: answered
  rationale: TermLink confirmed directly — every rung addresses a specific,
  address-named entity, never an arbitrary one; that is exactly the case
  G-060 permits. No rework needed. (Finding 6, this file.)

- **IW-2: Does TermLink's cv_index (in-memory presence index) make the
  3-state circuit lifecycle unsound on hub restart?**
  confidence: 3
  disposition: answered
  rationale: TermLink self-corrected an earlier over-broad claim — cv_index
  sits over a durable SQLite log, repopulates in ~30s, and one lookup path
  already falls back to the log. Only fast-path reads (`cv-keys`,
  `subscribe --include-current-value`) are exposed, and only for that
  bounded window. Real but small, not a blocking defect. (Finding 6.)

- **IW-3: Is cross-host reachability (actually connecting to a remote hub)
  an open transport gap?**
  confidence: 3
  disposition: dissolved
  rationale: Solved primitive on TermLink's side (`hub probe`, `channel
  post --hub`, fleet fan-out). The real open item underneath is TRUST
  BOOTSTRAP (can the ladder trust an unpinned hub on the fly, or only
  navigate between hubs that already know each other) — a genuine design
  decision, not a gap in what exists. Deferred to whenever cross-host work
  is actually scheduled; not blocking this inception's closure. (Finding 6.)

- **IW-4: Does the ladder's "hub, do you have this project running here?"
  rung have a real counterpart in TermLink?**
  confidence: 3
  disposition: answered
  rationale: No — TermLink hubs have no concept of "project," no RPC to
  ask one. Real, undesigned gap: AEF must build project-awareness itself,
  presumably on TermLink's presence rail. Deferred as future design work,
  not blocking arc-020's already-shipped slices. (Finding 6.)

- **IW-5: Q-B — the operator's incomplete "termlink or termlink" question
  from the original T-3287 dialogue.**
  confidence: 0
  disposition: deferred
  rationale: Explicitly the operator's unfinished sentence to complete;
  TermLink declined to guess on principle and only confirmed the one
  sub-guess (hub-vs-fleet) that's a load-bearing architectural fact
  regardless of intent. Needs the operator, not further agent inference.

- **IW-6: Is agent-to-agent traffic in this fleet actually cross-host, or
  mostly co-located with cross-host as the exception?**
  confidence: 0
  disposition: deferred
  rationale: Unmeasured. Determines the ladder's real-world shape
  (local-fast-path-plus-exception vs. always-cross-host). Needs operator
  input or fleet telemetry, not something to guess at.

- **IW-7: Is AEF's project-path model (D2/D3 — bound absolute path as
  identity, display-only elision) sound against a real-world failure
  class?**
  confidence: 3
  disposition: answered
  rationale: TermLink independently adopted it for addressing after it
  resolved a live bug on their side (11 misattributed filings from a
  `basename $PWD` inference). Confirmed sound for the addressing/
  provisioning question; TermLink correctly scoped it as NOT answering
  their separate attribution question (worktrees). (Finding 7.)

- **IW-8: Does `lib/aef_address.py` structurally enforce "elision is never
  a wire/identity value," or only by convention?**
  confidence: 3
  disposition: answered
  rationale: Verified directly — `serialize()` refuses an elided project
  value (tested), but `parse()`/`_build()` has no matching guard, so an
  elided string parses successfully today. Real, small, bounded gap.
  Recommended fix: parser-level rejection of any token containing
  `ELLIPSIS`, mirroring the existing serializer test. Not fixed under this
  inception task (Inception Discipline forbids production-code writes
  pre-GO) — candidate for a small standalone build task against arc-020.
  (Finding 7.)

- **IW-9 (T-3338 verification): is T-3338's `status: work-completed`
  while sitting in `active/` a stranded-finalized bug?**
  confidence: 3
  disposition: answered
  rationale: Verified directly — 1 of 6 ACs is a genuinely unchecked
  `[REVIEW]` Human AC (re-run a smoke test, tick the box). Ordinary
  partial-complete gate working as designed, not a crash-before-finalize
  bug. Flagged to the operator, not auto-ticked. (Finding 4.)

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

**7. Our project-path model shared with TermLink; adopted for addressing,
plus one real, verified hardening gap (2026-09-21).** Operator suggested
sharing our D2/D3 project-path approach (full absolute root path = wire
identity, `elide_path()` = display-only, never emitted on the wire) as
input to TermLink's own project-identity problem, framed as something we'd
discussed together, not a request.

**TermLink's reply — this independently resolved a live bug class on
their side.** They had 11 of their own upstream filings misattributed as
project `"root"` instead of `"010-termlink"`, root-caused to a label
helper that falls back to `basename ${PROJECT_ROOT:-$PWD}` when no label
is declared — run from `/`, basename yields `"root"`. Their own learning:
"a fallback that GUESSES an identity is worse than one that refuses."
Our `serialize()`'s hard refusal to emit anything but the full unelided
path is exactly that guard. The distinction that mattered, in their words:
**our path is BOUND (D2: declared, the root the project is bound to), not
INFERRED at call time** — `basename $PWD` is an inference, a declared
absolute path is a declaration. "Declared, not derived" doesn't rule out
paths, it rules out inference.

**Hardening note, and a REAL gap it surfaced — verified directly, not
taken on faith.** TermLink's caution: relying on "elision is forbidden as
identity" as a *documented convention* is the same shape as their own
PL-166 ("payload-level fingerprints are advisory labels only — never
identity claims"), which was documented and still misused as identity for
6+ weeks by readers who had read the doc. Their fix there was making the
real identity structurally unforgeable (T-1427 binds `sender_id` to the
actual signing pubkey, rejects a mismatch with -32014) rather than
depending on every future reader remembering a rule. Their suggestion:
since `"…"` is not a legal path segment, an elided string literally
**cannot parse** as a valid address — that's already a type-level
guarantee if the parser enforces it, not merely a convention, so the
parser should explicitly reject any address containing the ellipsis
(with a comment explaining elision is safe *because* it's unparseable),
not just rely on a docstring warning.

**Checked `lib/aef_address.py` directly: the gap is real.** `serialize()`
refuses to emit a project value containing `ELLIPSIS` — confirmed,
tested (`test_wire_serializer_refuses_elided_project_value`). But
`parse()`/`parse_v9()`/`parse_v4()` → `_build()` has **no equivalent
check** — an elided display string (e.g. copy-pasted from a chat message
or a `termlink list` line into an address field) would parse
successfully today, with nothing catching it on the receiving side. Only
the emit path is guarded; the read path is convention-only, exactly the
PL-166 shape TermLink warned about. **Not yet fixed** — this is a
production-code change to already-`work-completed` arc-020 slices, which
Inception Discipline (CLAUDE.md) forbids writing under this inception
task without a GO. Recommend: a small, bounded, below-the-floor build
task (`_build()` or `parse()` rejects any token value containing
`ELLIPSIS`, one new test alongside the existing serializer test) —
scoped narrowly enough not to need this inception's own GO cycle if filed
as its own build task against arc-020.

**Where TermLink lands on adoption — two separate fields, not one merged
concept.** They adopt our path model for **addressing/provisioning**
as-is: host+hub already pin the address, so the path only needs
uniqueness *within* a host (which a filesystem path has by construction),
and a ladder that starts things needs a real path — "you cannot cd to a
label." But they keep a separate **declared stable label** for
**attribution**: a git worktree is a different absolute path for the same
logical project, so under pure path-identity their two checkouts of one
project would attribute as two different projects, and their
upstream-self-filter (which matches a constant label) would stop
recognizing one of them as theirs — the same 11-filings bug in a new
costume. Explicitly not a flaw in our design — a different question ours
isn't trying to answer. Worth remembering if AEF ever grows worktree-aware
identity: path-as-identity and attribution-label are two different
concerns, and conflating them is exactly where TermLink's bug came from.

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
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO — close this exploration; file the one small bounded
build task it identified; leave two items correctly as open Sovereign
questions rather than blockers

**Rationale:** Originally filed DEFER on genuine evidence gaps (2026-09-21,
same day). Those gaps have since been resolved through direct TermLink
dialogue, verified rather than taken on faith, not just asserted away:

- The resolution ladder itself was restated by the operator and **confirmed
  correct against G-060** by TermLink — no design rework needed (IW-1).
- The cv_index liveness concern was **narrowed from "indefinite false-dead"
  to "≤30s window, most paths already fall back"** by TermLink's own
  self-correction (IW-2) — real, but not a blocking defect.
- Cross-host reachability, originally suspected as an open transport gap,
  **turned out to be solved** — the actual open item is a scoped design
  decision (trust bootstrap) rather than missing capability (IW-3).
- AEF's own project-path model was cross-checked against a real production
  bug class and **independently adopted by TermLink** (IW-7) — validates
  D2/D3 rather than leaving them as an unverified assumption.
- One concrete, small, bounded hardening gap was found and verified
  directly against the source (`lib/aef_address.py`): `parse()` lacks the
  guard `serialize()` already has against elided project values (IW-8).
  This has a clear, narrow fix and a template to follow (existing
  serializer test) — GO-appropriate under the criterion "root cause
  identified with bounded fix path."
- One new, real, but non-blocking design gap was found: the ladder's
  project-rung has no TermLink counterpart (IW-4) — correctly scoped as
  future design work, not something blocking arc-020's already-shipped
  slices or this inception's closure.
- T-3338's ambiguous `work-completed`-in-`active/` state was verified as
  the ordinary partial-complete gate working correctly, not a hidden bug
  (IW-9).

**What remains open is not evidence-thin, it's Sovereign** — Q-B (IW-5)
and the traffic-shape question (IW-6) are the operator's to answer, per
this Mandate's own "Sovereign-questions-surfaced-not-resolved" binding,
not gaps this inception can or should resolve by guessing. DEFER would now
be a confidence hedge against decided evidence, not a genuine evidence gap
— exactly the failure mode CLAUDE.md's DEFER guidance warns against.

**Evidence:**
- IW-1 through IW-9 above, each with confidence and rationale.
- `lib/aef_address.py:233-239` (`serialize()` guard) vs. `lib/aef_address.py:191-217`
  (`_build()`, no guard) — read directly, not inferred.
- 144/144 arc-020 tests passing today (Finding 4, this file).
- Full TermLink dialogue captured verbatim across Findings 1-7.

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

**Decision**: GO

**Rationale**: Originally filed DEFER on genuine evidence gaps (2026-09-21,
same day). Those gaps have since been resolved through direct TermLink
dialogue, verified rather than taken on faith, not just asserted away:

- The resolution ladder itself was restated by the operator and **confirmed
  correct against G-060** by TermLink — no design rework needed (IW-1).
- The cv_index liveness concern was **narrowed from "indefinite false-dead"
  to "≤30s window, most paths already fall back"** by TermLink's own
  self-correction (IW-2) — real, but not a blocking defect.
- Cross-host reachability, originally suspected as an open transport gap,

**Date**: 2026-09-21T10:42:51Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-21T10:42:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Originally filed DEFER on genuine evidence gaps (2026-09-21,
same day). Those gaps have since been resolved through direct TermLink
dialogue, verified rather than taken on faith, not just asserted away:

- The resolution ladder itself was restated by the operator and **confirmed
  correct against G-060** by TermLink — no design rework needed (IW-1).
- The cv_index liveness concern was **narrowed from "indefinite false-dead"
  to "≤30s window, most paths already fall back"** by TermLink's own
  self-correction (IW-2) — real, but not a blocking defect.
- Cross-host reachability, originally suspected as an open transport gap,

### 2026-09-21T10:42:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-50d71218
- **Timestamp:** 2026-09-21T10:42:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-7
     - evidence: `IW-7 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  4. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-8
     - evidence: `IW-8 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-86ed0f19
- **Timestamp:** 2026-09-21T10:42:55Z
- **Overall:** CONTRADICTED
- **Claims:** 4

| Claim | Type | Status |
|-------|------|--------|
| `lib/aef_address.py` | file | ✓ pass |
| `lib/aef_address.py:233-239` | file | ✗ fail — file not found at PROJECT_ROOT |
| `lib/aef_address.py:191-217` | file | ✗ fail — file not found at PROJECT_ROOT |
| `T-3338` | task | ✓ pass |

### 2026-09-21T10:42:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
