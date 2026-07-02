---
id: T-1819
name: "seed peer-consult-prompts.yaml — framework-half runtime gap + joint smoke-readiness
  with TermLink T-1636"
description: >
  T-1818 shipped the subscriber loop but the runtime prompts map .context/peer-consult-prompts.yaml
  is missing — without it every event resolves to miss. Seed the map with a default-fallback
  entry + at least one explicit channel/addressee binding, and coordinate with TermLink-side
  T-1636 emitter status so the joint smoke-test slice is sequencable.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [tests/unit/test_peer_subscribe.py]
related_tasks: [T-1818, T-1804, T-1797]
arc_id: orchestrator-rethink
created: 2026-05-13T23:01:36Z
last_update: '2026-06-11T22:23:59Z'
date_finished: 2026-05-13T23:10:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1819: seed peer-consult-prompts.yaml — framework-half runtime gap + joint smoke-readiness with TermLink T-1636

## Context

T-1818 (framework-half of v2 peer-consult slice 1) shipped subscriber + spawn-bridge but
`.context/peer-consult-prompts.yaml` is missing. `lib/peer.py:_load_prompts` returns `{}`
when the file is absent, so `resolve_addressee` always returns (None, None), causing every
real `inbox.queued` event to be miss-logged. Result: subscriber is functionally a no-op
post-T-1818, even if TermLink-side T-1636 (emitter) ships.

This task: (1) seed the map with at least one fallback entry so the subscriber routes
real events, (2) re-confirm TermLink-side T-1636 status via dispatch so the joint
smoke-test slice (next) is sequencable, (3) extend unit-test coverage to pin the
loaded-map path (current tests inject prompts via fixture, not from disk).

## Acceptance Criteria

### Agent
- [x] `.context/peer-consult-prompts.yaml` exists and parses via `lib/peer.py:_load_prompts` returning ≥1 entry with required keys (`workflow`, `name`, and at least one of `addressee`/`channel`).
- [x] Seed includes both specific channel-prefix routes (design / escalation / triage) AND a broad `dm:` fallback that catches unmatched DM channels — per Evolution, explicit-addressee entry was dropped (no stable long-lived addressee exists; placeholder would mislead).
- [x] `tests/unit/test_peer_subscribe.py` extended with a test that reads the seeded file from disk (no fixture override) and verifies `resolve_addressee` returns a non-None workflow for a representative event.
- [x] All existing peer_subscribe tests still pass (no regression) — 12/12 PASS.
- [x] TermLink-side T-1636 status re-confirmed via `fw termlink dispatch --project /opt/termlink` and result captured at `/tmp/tl-dispatch/t1636-recheck/result.md`; summary copied to this task's `## Evolution` section.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

test -f .context/peer-consult-prompts.yaml
python3 -c "from lib.peer import _load_prompts; p = _load_prompts(); assert len(p) >= 1, f'empty prompts map: {p}'; assert all('workflow' in v and 'name' in v for v in p.values()), f'missing keys: {p}'"
python3 -m pytest tests/unit/test_peer_subscribe.py -v
bin/fw reviewer T-1819 2>&1 | grep -q "Overall:.*PASS"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-05-14 — addressee-binding example dropped: not needed for slice-1 routing

- **What changed:** AC#2 asked for "at least one explicit-addressee binding example". Reviewed the use-case: explicit-addressee entries are valuable when one session ID is a stable consult endpoint (e.g. a long-lived planning agent). Slice 1's actual flow is channel-driven: TermLink emits `dm:design-*` / `dm:escalate-*` style channels and the responder is picked by topic, not by who you are. No long-lived stable addressee exists yet — adding one as a placeholder would be misleading documentation. Seeded with four channel-prefix entries (design / escalation / triage / dm-fallback) which exercise both the specific-prefix and broad-fallback paths.
- **Plan impact:** AC#2 satisfied by the broad `dm:` fallback (which IS a "default-fallback entry") + three specific channel routes. Explicit-addressee path is still exercised by existing fixture tests (`test_resolve_addressee_by_session_id`); the disk-loading test exercises the channel path the seed actually uses.
- **Triggered:** No new sub-task. Future explicit-addressee entries (e.g. a dedicated review-agent session) added by their own task when filed.

### 2026-05-14 — TermLink T-1636 status re-confirmed: unstarted, ~1.5-2h to ship

- **What changed:** Dispatched `t1636-recheck` worker (Haiku, ~30s) against /opt/termlink, T-1819 tag. Result at `/tmp/tl-dispatch/t1636-recheck/result.md`. State: (1) emit NOT landed in `crates/termlink-hub/src/inbox.rs:257` deliver_pending, (2) `inbox.queued` event class constant NOT defined in `termlink-protocol/src/events.rs`, (3) no integration test, (4) ~1.5-2h estimate, (5) joint smoke-test NOT yet ready — both halves must land. No blockers identified; suggested start = inbox_topic module + InboxQueued payload struct.
- **Plan impact:** Joint smoke-test is sequenced AFTER T-1636 ship. Framework-side is now feature-complete for slice 1 (T-1818 subscriber + spawn-bridge + T-1819 seed map + tests). No further framework work needed before joint smoke; only consumer-side observation when TermLink-half lands.
- **Triggered:** No new sub-task in framework. TermLink-side T-1636 carries the build forward. Follow-up "joint smoke-test slice" task should be filed when T-1636 reports work-completed.

## Decisions

### 2026-05-14 — channel-only seed (no explicit addressee in shipped file)

- **Chose:** Seed with four channel-prefix entries (design-consult, escalation-triage, prompt-triage, dm-fallback). No explicit-addressee entry shipped.
- **Why:** No stable long-lived session ID exists yet for the framework-agent role; adding a placeholder addressee would document a contract that doesn't reflect reality. Channel routing is the slice-1 actual flow.
- **Rejected:** (a) Include the current framework-agent session ID as an example — would break on next session restart, mislead readers. (b) Seed with `addressee: PLACEHOLDER` comment — comments work but the AC asked for a real binding, and the binding only makes sense once a real consult endpoint exists.

### 2026-05-14 — broad `dm:` fallback included as the last entry

- **Chose:** Include `dm-fallback: channel: 'dm:'` as the last map entry, routing any unmatched DM channel to `workflows/cheap-research.yaml`.
- **Why:** Without a catch-all, every channel not matching the three specific prefixes (`dm:design-`, `dm:escalate-`, `dm:triage-`) miss-logs. A non-zero miss rate is fine for ambient noise (random DMs), but the slice-1 acceptance was "subscriber routes real events" — a fallback ensures any genuine consult attempt gets routed to *some* responder. Cheap-research is the lowest-cost responder available, matching the "safer than no responder" stance.
- **Rejected:** (a) No fallback — guarantees most events miss; defeats the slice. (b) Fallback to design-dialogue — too heavy a default; cheap-research is the right floor.

## Recommendation

- **Recommendation:** GO (Agent ACs complete; no Human AC required — all checks deterministic)
- **Rationale:** Runtime-gap closed: `.context/peer-consult-prompts.yaml` shipped with 4 channel-prefix entries, parses cleanly via `lib/peer.py:_load_prompts`, resolves the three specific routes + broad `dm:` fallback. Test coverage extended from 11 to 12: new `test_load_prompts_reads_shipped_seed_from_disk` pins the actual on-disk contract (catches deletion + shape regression). All 12 tests pass. Reviewer Overall: PASS, needs_human=no. TermLink-side T-1636 re-confirmed unstarted; joint smoke-test is correctly sequenced as a follow-up slice after T-1636 ships.
- **Evidence:**
  - `.context/peer-consult-prompts.yaml` 4 entries (design/escalate/triage + dm-fallback)
  - `tests/unit/test_peer_subscribe.py` 12 tests PASS (was 11, added disk-load pin)
  - `bin/fw reviewer T-1819` Overall: PASS, Findings: none, Needs Human: no
  - TermLink-side status capture: `/tmp/tl-dispatch/t1636-recheck/result.md` (worker exit 0, ~30s)
- **Headline mechanic:** Framework-half subscriber loop now has a non-empty map; an inbox.queued event hitting channel `dm:design-anything` is resolved to `workflows/design-dialogue.yaml`, name `design-consult`, and dispatched via `fw termlink dispatch` — instead of being miss-logged as previously.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-13T23:01:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1819-seed-peer-consult-promptsyaml--framework.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-21baa506
- **Timestamp:** 2026-06-02T14:59:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 13
     - evidence: `bin/fw reviewer T-1819 2>&1 | grep -q "Overall:.*PASS"`
### 2026-05-13T23:10:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
