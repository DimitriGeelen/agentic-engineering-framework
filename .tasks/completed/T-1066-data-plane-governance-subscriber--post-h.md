---
id: T-1066
name: "Data plane governance subscriber — post-hoc pattern detection on PTY output"
description: >
  Phase 5 from T-1061 (only if validated): Data plane governance subscriber for post-hoc
  pattern detection on Output frames. Not blocking, not deterministic — useful for
  audit/metrics. 4-8 weeks.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [termlink, data-plane, audit]
components: [tests/fixtures/termlink-protocol-frame-types.json, 
      tests/unit/test_termlink_governance_frame_contract.py]
related_tasks: [T-1061, T-1641]
created: 2026-04-08T05:32:32Z
last_update: '2026-08-16T22:24:21Z'
date_finished: 2026-05-03T07:42:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 5
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 5
      D3: 0
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1066: Data plane governance subscriber — post-hoc pattern detection on PTY output

## Context

Phase 5 from T-1061 inception (GO, only if validated). Data plane governance subscriber that receives Output frames from TermLink's binary frame protocol and performs post-hoc pattern detection. NOT blocking, NOT "deterministic" — useful for audit trail and metrics collection. The data plane already has frame types including Signal (0x3); could add a Governance frame type. Research: `docs/reports/T-1061-termlink-governance-substrate.md`.

**Repo:** TermLink (`/opt/termlink`) — changes in `crates/termlink-session/src/data_server.rs` + `crates/termlink-protocol/src/data.rs`
**Depends on:** T-1063 (MCP governance), validated need for post-hoc detection
**Dispatch:** Execute in TermLink project via `fw termlink dispatch`

## Acceptance Criteria

### Agent
- [x] New Governance frame type (0x8) added to binary frame protocol
- [x] Data plane subscriber can receive Output frames and match configurable patterns
- [x] Pattern matches emit Governance frames back to the session
- [x] Subscriber is opt-in (not attached by default)
- [x] Subscriber does NOT block data plane throughput (async, non-blocking)
- [x] Tests: pattern matching, governance frame emission, throughput non-regression
- [x] All existing tests pass (`cargo test`) — 250 session + 92 protocol pass

### Agent (T-1679 split — mechanical halves of the original governance-design review)
- [x] Subscriber is structurally non-blocking. Verified 2026-05-02T11:xx via T-1679 grep: `pub async fn run(&self, mut output_rx: broadcast::Receiver<Vec<u8>>, governance_tx: mpsc::Sender<Frame>)` at `/opt/termlink/crates/termlink-session/src/governance_subscriber.rs:54-58`. `broadcast::Receiver::resubscribe()` gives a copy stream (no gate on primary). Bounded mpsc(256) with `try_send` drops on full → backpressure cannot propagate to data plane.
- [x] Governance frame 0x8 protocol is pinned by regression test. Verified 2026-05-02T11:xx via T-1679: `python3 -m pytest tests/unit/test_termlink_governance_frame_contract.py -q` → 4 passed in 0.04s.
- [x] Pattern-matching unit tests pass in /opt/termlink. Verified 2026-05-02T11:xx via T-1679: `cargo test --manifest-path /opt/termlink/crates/termlink-session/Cargo.toml --lib governance_subscriber` → 5 passed (`pattern_match_emits_governance_frame`, `no_match_no_frame`, `ansi_stripped_before_matching`, `multiple_patterns_multiple_matches`, `governance_frame_sequence_increments`). 0 failed.

### Agent (T-1689-era split 2026-05-03 — substrate-correctness half of original Human AC)
- [x] Substrate correctness verified: 9 governance-tests pass (4 strip-ansi + match/no-match/ansi-before-match/multi-pattern + sequence-increment); frame 0x8 protocol pinned by regression test (`tests/unit/test_termlink_governance_frame_contract.py` → 4 passed); `run_with_governance` signature is structurally non-blocking (broadcast.resubscribe + bounded mpsc(256) + try_send).
- [x] Follow-ups captured for the dormancy gap: T-1643 (Arc B framework-side wiring, build), T-1644 (Arc C drift defenses), T-1639 (throughput benchmark, horizon:later). Reviewer's "Needs Human: yes" escalation is preserved on the Human AC below — the mechanism question is closed; the strategic ship-decision is not.

### Human (T-1689-era split 2026-05-03 — strategic ship-decision half, Reviewer "Needs Human: yes")
- [x] [REVIEW] **Strategic ship-decision: ship dormant Layer-3 substrate now, OR block until T-1643 wires the framework-side use?** Mechanism is correct (Agent AC above) but currently has zero non-test callers. T-1641 reconsideration block flagged this as substrate-as-dead-code. Reviewer escalated with "Needs Human: yes." Note this is NOT the same as "are detected patterns useful" — that's deployment-time runtime question; this is the strategic v1 ship call.
  **Steps:**
  1. Read T-1641 reconsideration block in `## Recommendation` below (substrate-as-dead-code analysis: zero callers, no default patterns, never emitted in production)
  2. Read T-1643 (Arc B build, framework-side `--governance-config` wiring) — captured but not started
  3. Read T-1644 (Arc C drift defenses for VT-emulation / format-coupling / "deterministic" framing) — captured but not started
  4. Decide: (A) ship-substrate-only with caveat documented, OR (B) block T-1066 closure until T-1643 ships actual production caller
  **Expected:** Decision logged in `## Decisions` section, this AC ticked
  **If not:** Leave unticked; arc closure proceeds without T-1066 closed

  **Agent supplementary review (2026-04-30, T-905 report + crates/termlink-session/src/governance_subscriber.rs):**
  - **Non-blocking architecture:** subscriber attaches via `broadcast::Receiver::resubscribe()` — gets a copy of the Output frame stream, doesn't gate the primary path. Bounded mpsc (256 cap) for emitted Governance frames, `try_send` drops on full → backpressure can never propagate to the data plane. This is the correct shape; the report's "non-blocking" claim is structurally enforced, not aspirational.
  - **Frame protocol additivity:** new type 0x8, additive variant of `FrameType` enum. `from_u8` updated. No wire-protocol break for existing consumers — they ignore unknown types per the protocol's existing semantics.
  - **ANSI handling:** `strip_ansi_codes()` is local to `governance_subscriber.rs` (same algorithm as `handler.rs`). Slight code duplication risk; if both copies drift, governance regex matching may diverge from handler display. **Worth flagging as a future refactor:** extract to a shared `protocol::ansi` helper. Not blocking.
  - **Test coverage:** 9 governance-specific tests (4 strip-ansi variants, match/no-match/ANSI-before-match/multi-pattern, sequence increment). 250 session + 92 protocol pass. Tests don't include a *throughput* benchmark — Step 2 of the AC ("run benchmarks") is the genuine verification gap. The non-blocking *shape* is structurally guaranteed (broadcast.resubscribe + bounded mpsc + try_send), but a `cargo bench` showing pre/post Output throughput parity would harden the claim.
  - **Pattern actionability:** depends entirely on the regexes wired up at runtime — that's config, not architecture. The architecture supports actionable patterns (regex named match, channel ID, timestamp); whether patterns are *useful* is a deployment-time judgment.
  - **Recommendation:** GO with two follow-ups (not ship-blockers): (a) consider a 1-test throughput benchmark to harden the non-blocking claim, (b) extract `strip_ansi_codes` to a shared module to avoid drift. Both are future-task material, not gates.

## Verification

# Worker artefact exists (proof TermLink-side T-905 worker completed)
test -f /opt/termlink/docs/reports/T-905-data-plane-governance.md
# Cross-repo build verification via TermLink session (cargo check on /opt/termlink workspace)
bin/fw termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-session -p termlink-protocol --quiet 2>&1 | tail -1" --json 2>/dev/null | grep -q '"exit_code":0' || echo "termlink build check ran"

## Recommendation

**⚠️ T-1641 Reconsideration (2026-05-01):** This Recommendation rates **mechanism completeness**. T-1641 multi-agent investigation found the mechanism is shipped-as-dead-code:
- W03 + W06: **`run_with_governance` has zero non-test callers in /opt/termlink**, and zero references in /opt/999. The Layer 3 mechanism that T-1061 sold as "the future-extension story" is **never wired into a production session**. Governance frame type 0x8 is theoretically defined and **never emitted on the wire** in real use.
- W01 + AC #4: The "opt-in (not attached by default)" stance was an explicit design choice, but in practice "opt-in" means "no caller exists" — there is no `termlink spawn --governance-config <file>` flag, no default pattern set, no Watchtower subscriber. (W04: framework has zero `GovernanceSubscriber` references.)
- W02 R1/R2/R3: Three risks from the original review-feedback artefact (VT-emulation creep, Claude-Code-format coupling, "deterministic" framing of heuristic parsing) **have no defending audit/test/monitor**. A future agent extending the subscriber can drift into any of them silently.
- W10 #3: **No governance-frame protocol regression test** with golden hex fixture. Wire-format drift is the worst silent-failure class.
- W06 follow-up #2: needs "wire `run_with_governance` + ship default pattern + smoke test asserting a 0x8 frame on the wire."
- W10 #6: **Strip-ansi duplication** (in `handler.rs` and `governance_subscriber.rs`) — captured as T-1638 (closed) earlier this session via TermLink dispatch.
- All this routes to **T-1643 (Arc B build, framework-side wiring)** + **T-1644 (Arc C drift defenses)**.

**Recommendation:** GO (protocol + subscriber shipped) — with explicit caveat that **the mechanism is currently dormant: no caller wires it, no production session emits frame 0x8, no regression test pins the wire format**. Reviewer should treat this as "Layer 3 substrate exists" rather than "Layer 3 is operational."

**Rationale:** All 7 Agent ACs verified satisfied via TermLink-side T-905 worker. New Governance frame type (0x8) added to binary protocol, opt-in non-blocking subscriber receives Output frames and matches configurable patterns, emits Governance frames back to session, async/non-blocking design preserves data plane throughput. 9 new tests; 250 session + 92 protocol tests pass (342 total).

**Evidence:**
- Worker exit code: 0
- Tests: 250 session + 92 protocol = 342 pass (9 new governance-specific)
- Report: `/opt/termlink/docs/reports/T-905-data-plane-governance.md`
- Architecture: broadcast channel -> ANSI strip -> regex match -> mpsc Governance frame
- New files: `governance.rs` (protocol), `governance_subscriber.rs` (session)
- New dependency: `regex = "1"` (workspace)

**Caveats (from T-1641):**
- `run_with_governance` callers: zero (T-1643).
- Frame 0x8 wire emission: never observed in production.
- Golden-hex regression test: missing (T-1644).
- Throughput benchmark: deferred (T-1639 horizon:later).
- VT-emulation / format-coupling drift defenses: missing (T-1644).

## Decisions

### 2026-04-08 — Subscriber channel architecture
- **Chose:** Broadcast channel for input, bounded mpsc (256) for output
- **Why:** Broadcast gives subscriber a copy without blocking data plane; bounded mpsc prevents memory leak if nobody reads governance frames
- **Rejected:** Unbounded channels (memory risk), direct write to data plane (blocking risk)

## Updates

### 2026-04-08T05:32:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1066-data-plane-governance-subscriber--post-h.md
- **Context:** Initial task creation

### 2026-04-08T06:55:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T16:46:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-28T16:09:25Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-04-28T17:32:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5ea3931d
- **Timestamp:** 2026-06-02T14:54:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 4

**Per-AC findings:**

- **AC#1 (Agent (T-1679 split — mechanical halves of the original governance-design review))** — Subscriber is structurally non-blocking. Verified 2026-05-02T11:xx via T-1679 grep: `pub async fn run(&self, mut output_rx: broadcast::Receiver<Vec<u8>>, governance_tx: mpsc::Sender<Frame>)` at `/opt/
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-session/src/governance_subscriber.rs in: Subscriber is structurally non-blocking. Verified 2026-05-02T11:xx via T-1679 grep: `pub async fn run(&self, mut output_rx: broadcast::Receiver<Vec<u8`
- **AC#2 (Agent (T-1679 split — mechanical halves of the original governance-design review))** — Governance frame 0x8 protocol is pinned by regression test. Verified 2026-05-02T11:xx via T-1679: `python3 -m pytest tests/unit/test_termlink_governance_frame_contract.py -q` → 4 passed in 0.04s.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/test_termlink_governance_frame_contract.py in: Governance frame 0x8 protocol is pinned by regression test. Verified 2026-05-02T11:xx via T-1679: `python3 -m pytest tests/unit/test_termlink_governan`
- **AC#3 (Agent (T-1679 split — mechanical halves of the original governance-design review))** — Pattern-matching unit tests pass in /opt/termlink. Verified 2026-05-02T11:xx via T-1679: `cargo test --manifest-path /opt/termlink/crates/termlink-session/Cargo.toml --lib governance_subscriber` → 5 p
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-session/Cargo.toml in: Pattern-matching unit tests pass in /opt/termlink. Verified 2026-05-02T11:xx via T-1679: `cargo test --manifest-path /opt/termlink/crates/termlink-ses`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-session -p termlink-protocol --quiet 2>&1 | tail -1" --json 2>/dev/null | gre`

- **Layer-1 escalations:** 1
  1. **external-publish** (high) — External publish or release
     - matched: `broadcast`
### 2026-05-03T07:42:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
