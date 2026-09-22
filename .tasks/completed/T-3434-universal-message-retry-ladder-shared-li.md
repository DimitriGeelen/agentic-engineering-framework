---
id: T-3434
name: "universal message retry ladder: shared lib (2x1m,2x5m,2x15m,2x1h,2x4h,2x1d,2x1w,2x1mo)
  with re-post vs escalate per rung, receiver dedupe mandatory, dead-letter + audit
  WARN; sidecar first, driven by the sweep cron (OBS-447 ruling)"
description: >
  Operator ruling 2026-09-22 (decision recorded). One shared retry-ladder library
  used by every message producer; the sidecar is the first consumer: ledger rows gain
  attempts/next_retry_at/rung; the 5-minute sweep re-posts un-posted messages on their
  rung and escalates posted-but-unread ones (15min nudge to project inbox, 1d operator
  surface, final dead-letter = UNKNOWN + audit WARN). Receiver dedupe on client_msg_id
  enforced for every kind. URGENT compression explicitly out of scope (separate conversation).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/audit/audit.sh, lib/bus.sh, lib/dispatch.sh, lib/retry_ladder.py, lib/sidecar-audit.sh, lib/sidecar_cli.py, lib/sidecar/delivery.py, lib/sidecar/outbox.py, lib/sidecar/retry.py, tests/unit/lib_bus.bats, tests/unit/sidecar_audit_rail.bats, tests/unit/test_retry_ladder.py, tests/unit/test_sidecar_delivery.py, tests/unit/test_sidecar_sweep.py]
related_tasks: []
arc_id: arc-011
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-09-22T12:43:27Z
last_update: 2026-09-22T16:13:10Z
date_finished: 2026-09-22T16:13:10Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-09-22T12:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=272,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T12:45:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3434: universal message retry ladder: shared lib (2x1m,2x5m,2x15m,2x1h,2x4h,2x1d,2x1w,2x1mo) with re-post vs escalate per rung, receiver dedupe mandatory, dead-letter + audit WARN; sidecar first, driven by the sweep cron (OBS-447 ruling)

## Context

Operator ruling D-600 (2026-09-22) resolves OBS-447. One shared retry schedule
for every framework message kind; the sidecar is the first consumer, driven by
the existing `sidecar-sweep-5m` cron. Full design, measurements and the
two-failure-class rationale: `docs/reports/T-3434-retry-ladder.md`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/retry_ladder.py` (pure, no I/O): `LADDER = [(2,60),(2,300),(2,900),(2,3600),(2,14400),(2,86400),(2,604800),(2,2592000)]`; `next_attempt(attempts, last_at) -> (rung_index, due_at)|None` (None = exhausted → dead-letter); `verb_for(rung) -> "repost"|"escalate:nudge"|"escalate:operator"|"deadletter"` (nudge from the 15-min rung, operator surface from the 1-day rung, dead-letter after the last); unit tests pin every rung boundary and exhaustion; `urgent` accepted as a parameter but raises NotImplementedError with the pointer to the separate design (explicitly out of scope)
- [x] Sidecar as first consumer: ack-ledger rows gain `attempts`, `next_retry_at`, `rung`; `delivery.deliver()` records attempt 1; `fw sidecar sweep` (the 5-minute cron) walks STORED rows: un-posted (transport error recorded) → re-post when due; posted-but-unread (INJECTED_* with no reply/receipt on the conversation) → escalate per rung: nudge = one pointer message to the recipient's project-level inbox, operator = `fw note` observation + Watchtower notice, dead-letter = state UNKNOWN + reason `ladder-exhausted`; audit WARN counts dead-letters (extends T-3420's rail)
- [x] Receiver dedupe is enforced for every kind: `inbox.pending()` already dedupes on client_msg_id; add the same seen-set to `fw pickup process` and `lib/bus` receive paths (or record in Evolution which of those already dedupe and why)
- [x] Tests: sweep on a fixture ledger advances rungs correctly across simulated time (now injectable), re-posts exactly on due rungs, escalates instead of re-posting for INJECTED rows, dead-letters after the last rung with the audit-visible count; no duplicates on the hub for a message that was read (fake hub)
- [x] `docs/reports/T-3434-retry-ladder.md`: the schedule, the two failure classes, why it outlives the hub's dedupe window (receiver dedupe mandatory), what urgent will change (pointer only); OBS-447 marked resolved; vendored copies synced, sidecar + sweep suites green

## Verification

# T-3434 — every line rehearsed under `bash -c 'set -o pipefail; <line>'`.
#
# Test runners carry the L-387 / T-2738 guard: redirect to a file, then grep
# the file, so the PRODUCING command's exit code stays in the verdict.
python3 -m pytest tests/unit/test_retry_ladder.py -q > /tmp/.t3434-ladder 2>&1 && grep -q "49 passed" /tmp/.t3434-ladder
python3 -m pytest tests/unit/test_sidecar_sweep.py tests/unit/test_sidecar_delivery.py tests/unit/test_sidecar_outbox.py tests/unit/test_sidecar_status.py -q > /tmp/.t3434-sidecar 2>&1 && grep -q "passed" /tmp/.t3434-sidecar && ! grep -q "failed" /tmp/.t3434-sidecar
#
# bats: two lines, because "did anything fail" and "did everything run" are
# different questions (T-3217 — a skipped bats test reports `ok`).
timeout 300 bats tests/unit/sidecar_audit_rail.bats > /tmp/.t3434-audit 2>&1 && ! grep -q "^not ok" /tmp/.t3434-audit
test "$(grep -c '# skip' /tmp/.t3434-audit)" -eq 0
timeout 300 bats tests/unit/lib_bus.bats > /tmp/.t3434-bus 2>&1 && ! grep -q "^not ok" /tmp/.t3434-bus
test "$(grep -c '# skip' /tmp/.t3434-bus)" -eq 0
#
# The ladder is the schedule D-600 ruled, and `urgent` is out of scope loudly.
python3 -c "import sys; sys.path.insert(0,'.'); from lib import retry_ladder as r; assert r.LADDER == [(2,60),(2,300),(2,900),(2,3600),(2,14400),(2,86400),(2,604800),(2,2592000)]; assert r.MAX_ATTEMPTS == 16"
python3 -c "import sys; sys.path.insert(0,'.'); from lib import retry_ladder as r; exec(\"try:\\n r.next_attempt(1,'2026-01-01T00:00:00+00:00',urgent=True)\\n raise SystemExit('urgent did not raise')\\nexcept NotImplementedError as e:\\n assert 'separate conversation' in str(e)\")"
#
# The CLI the cron calls still works, and time is injectable end to end.
bin/fw sidecar sweep --json --now 2026-09-22T12:00:00+00:00 > /tmp/.t3434-sweep 2>&1 && python3 -c "import json; d=json.load(open('/tmp/.t3434-sweep')); assert {'considered','due','reposted','nudged','operator','deadlettered','answered','actions'} <= set(d)"
#
# The audit rail reports the new dead-letter class from our own ledger.
bash -c 'set -o pipefail; FRAMEWORK_ROOT="$PWD"; source lib/sidecar-audit.sh; fw_sidecar_ledger_facts "$PWD" > /tmp/.t3434-facts' && test "$(awk -F"\t" "{print NF}" /tmp/.t3434-facts)" -eq 6
grep -q "dead-letter" agents/audit/audit.sh && grep -q "ladder-exhausted" agents/audit/audit.sh
#
# Cron registry edited (L-364): registry -> generated must be in sync.
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
#
# Vendored copies synced (OBS-250). Scoped with cmp to MY files as well, so a
# concurrent worker's drift in the shared tree cannot turn this line red for
# reasons unrelated to T-3434.
cmp -s lib/retry_ladder.py .agentic-framework/lib/retry_ladder.py && cmp -s lib/sidecar/retry.py .agentic-framework/lib/sidecar/retry.py && cmp -s lib/bus.sh .agentic-framework/lib/bus.sh && cmp -s lib/dispatch.sh .agentic-framework/lib/dispatch.sh && cmp -s agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh
bin/fw vendor self --check
#
# The report exists and OBS-447 is no longer pending.
test -f docs/reports/T-3434-retry-ladder.md
python3 -c "import yaml; obs=yaml.safe_load(open('.context/inbox.yaml'))['observations']; r=[o for o in obs if o['id']=='OBS-447']; assert r and r[0]['status'] != 'pending', 'OBS-447 still pending'"

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

### 2026-09-22 — `INJECTED_*` is a terminal ack state AND a live ladder position
- **What changed:** The AC reads "walks STORED rows: un-posted … posted-but-unread
  (INJECTED_* with no reply…)", which is self-contradictory on its face —
  `INJECTED_*` is terminal in the three-state ack machine T-3402 shipped. The
  resolution is that D-600 tracks something the ack state was never asked to:
  the hub taking a message is not the recipient reading it.
- **Plan impact:** Ladder position had to live in row DATA (`attempts`, `rung`,
  `next_retry_at`) rather than in a fourth state. The ack machine is untouched.
  "Open" is a ladder predicate (`retry.is_open`), narrower than "non-terminal".
- **Triggered:** `retry.RELEASED` as a third close reason (below).

### 2026-09-22 — `expired_unswept` had to be retargeted or the audit rail went permanently red
- **What changed:** Not in the plan at all. `expired_unswept` meant "STORED with
  its 30-second transport deadline in the past". Under the ladder a STORED row is
  legitimately HELD for a rung's worth of time with that deadline long gone — so
  on the first cron tick after this shipped, every in-flight message would have
  WARNed "the sweep cron is not running", with no defect behind it.
- **Plan impact:** `status.snapshot` now tests `next_retry_at`, falling back to the
  deadline only for pre-T-3434 rows. This is the shape T-3326 warns about from the
  other side: a rail whose subject moved under it.
- **Triggered:** two new bats cases pinning held-vs-late, and the sixth ledger field.

### 2026-09-22 — the ladder adopted 22 historical deliveries before anyone noticed
- **What changed:** The first live `fw sidecar sweep` reported **27 open rows** on a
  ledger of 34. Every consult this project had ever delivered was a posted-unread
  row with no reply, so the ladder claimed all of them — and would have walked each
  to an operator `fw note` within a day. 22 were adopted in the ten-minute window
  before the guard landed.
- **Plan impact:** Two additions the spec did not anticipate. `is_open` refuses to
  adopt a pre-T-3434 row that is already DELIVERED (a pre-ladder row still STORED
  *does* join — it never reached anyone). And `RELEASED`, a close reason distinct
  from `answered` and from `ladder-*`, so a row the ladder lets go of is never
  counted as a dead-letter. Live ledger after the cleanup: 6 open, 0 due, 0
  dead-lettered, 0 expired-unswept.
- **Triggered:** the ladder's adoption boundary is now an explicit, tested rule
  rather than an accident of what happened to be in the ledger.

### 2026-09-22 — receiver dedupe: three paths, three different answers
- **What changed:** The AC offered "add the seen-set … or record which already
  dedupe and why". All three needed a different answer. `inbox.pending()` already
  dedupes on `client_msg_id`. `fw pickup process` already dedupes — but on a SHA256
  content hash with a **7-day cooldown**, which is *shorter than the ladder's
  1-week and 1-month rungs*: a re-post at day 8+ would be processed twice. `fw bus
  receive` had no dedupe and, worse, no id to key on.
- **Plan impact:** bus got both halves (`fw dispatch send` mints the id, receive
  keeps a bounded seen-set). Pickup was left alone and filed as **OBS-472** rather
  than given a second parallel dedupe — two mechanisms on one path is how they
  drift, and widening the cooldown is a governance change: the 7-day window exists
  so a concern re-raised later reads as a NEW signal.
- **Triggered:** OBS-472, which must close before pickup adopts the ladder.

### 2026-09-22 — a clause of AC #2 had a false premise (reported, not halted)
- **What changed:** "operator = `fw note` observation + Watchtower notice". `fw
  note` writes `.context/inbox.yaml`; no Watchtower blueprint or template reads
  that file (`/gaps` renders `concerns.yaml`). The second half does not exist.
- **Plan impact:** the operator rung uses the surface that does exist. Reported to
  `agent-chat-arc` @1669 and written verbatim into Updates before continuing;
  see that entry for the judgement call and the evidence.
- **Triggered:** nothing built — a Watchtower observations page is its own task.

### 2026-09-22 — concurrent work in one tree (T-3433)
- **What changed:** T-3433 was renaming `sidecar:` topics to `inbox:<circuit>` in
  the same checkout. Their commit `50757a4ed` swept up my uncommitted
  `lib/sidecar/status.py` hunks (whole-file stage), so the `dead_letters` field
  landed under their commit message rather than mine. Their consult also arrived
  *over the new addressing they were building* — the sidecar carrying a message
  about its own rename — reporting that the pre-push vendor gate was blocking both
  of us on my uncommitted `lib/bus.sh`.
- **Plan impact:** none functionally; `retry.py` calls `inbox_topic()` /
  `default_reader()` rather than building topics, so the rename passed through
  unnoticed. Recorded because the commit attribution is misleading if read later.
- **Triggered:** answered on the same conversation, naming the one coupling that
  matters to them: `inbox.pending()`'s seen-set is now load-bearing for
  correctness, because the ladder re-posts past the hub's dedupe TTL by design.

## Recommendation

**Recommendation:** GO

**Rationale:** Every Agent AC is ticked with evidence, the 13 verification lines
pass under the gate's own semantics, and the ladder has been exercised against the
live ledger rather than only against fixtures — including one row observed walking
rungs 0→1 across three real sweeps, and the vendored copy driven from a foreign
cwd. Two things the spec did not anticipate were found by running it and are fixed
rather than noted: the `expired_unswept` retarget (without which the audit rail
would have gone permanently red on the first cron tick) and the adoption boundary
(without which 22 finished conversations would have produced operator notices
within a day). One clause of AC #2 has a false premise — `fw note` observations
have no Watchtower surface — which is reported verbatim in Updates and to
agent-chat-arc, implemented against the surface that does exist, and is the one
thing an operator may want to overrule.

**Evidence:**
- `lib/retry_ladder.py` — pure, no I/O; 49 tests pin every rung boundary, exhaustion
  at attempt 16, both verb classes, and `urgent` raising with its pointer.
- `lib/sidecar/retry.py` + `fw sidecar sweep --now` — 17 sweep tests, including the
  whole 76-day ladder walked rung by rung in milliseconds.
- Live: `swept: 6 open row(s), 0 due` after cleanup; `dead letters: 0`;
  `expired unswept: 0`; audit rail `PASS Sidecar ledger: 34 consult(s), … 0
  dead-lettered, 0 expired-unswept`.
- Receiver dedupe: `lib_bus.bats` 29/29, 0 skips; `fw dispatch send` mints the id.
- OBS-447 dismissed as resolved; OBS-472 filed as the residual on pickup.
- `bin/fw vendor self --check` clean; cron registry regenerated and doctor in sync.

## Decisions

### 2026-09-22 — `verb_for` takes the failure class, not just the rung
- **Chose:** `verb_for(rung, *, posted=True)`. The single-argument call the AC names
  returns the escalation mapping (repost, repost, nudge×3, operator×3, deadletter);
  `posted=False` returns `repost` on every rung.
- **Why:** D-600 defines two classes with different verbs, but the AC specifies a
  one-argument signature. A keyword with the AC's mapping as its default satisfies
  both: the documented call is exactly what the AC says, and the second class is
  expressible without a parallel function.
- **Rejected:** deciding the class inside the sweep and never telling the library —
  that puts half the ruling in a consumer, where the next consumer has to rederive it.

### 2026-09-22 — `rung` looks backward, `next_retry_at` looks forward
- **Chose:** the row's `rung` names the rung THIS attempt was made on; the next
  rung is derived (`rung_for(attempts)`) rather than stored.
- **Why:** the first cut stored the NEXT rung, which made the row read as a lie in
  forensics ("attempt 2, rung 1" when attempt 2 was on rung 0) and gave two places
  to disagree about where a message is going. One stored fact, one derived.
- **Rejected:** storing both. Two fields that must agree are two fields that can't.

### 2026-09-22 — the sweep reads replies with a peek, never a drain
- **Chose:** reply detection walks our own inbox topic from cursor 0 and never
  writes the cursor; one hub read per sweep, results cached as a conversation set.
- **Why:** `fw sidecar inbox` owns that cursor. A cron job that consumed an agent's
  unread consults in order to decide whether to retry would be worse than the bug.
- **Rejected:** a per-message `channel subscribe --conversation-id` (one hub call
  per open row — 27 calls on the live ledger's first tick).

### 2026-09-22 — pickup keeps its own dedupe; the gap is filed, not patched
- **Chose:** record pickup's existing SHA256 + 7-day-cooldown dedupe and file
  OBS-472 for the cooldown-vs-ladder-span mismatch.
- **Why:** pickup is not a ladder producer today, so there is no live defect; and
  widening the cooldown changes what pickup *means* (a concern re-raised after a
  week is currently a new signal, deliberately). That is the operator's call.
- **Rejected:** adding a second id-keyed seen-set beside the hash one — two dedupe
  mechanisms on one path drift, and neither owner knows which fired.

### 2026-09-22 — the ladder does not adopt pre-T-3434 deliveries
- **Chose:** a row with no `attempts` field in a posted state is closed; the same
  row still `STORED` joins at rung 0.
- **Why:** measured, not theorised — the first live sweep claimed 27 of 34 rows.
  Escalating conversations that finished weeks ago is noise the operator pays for.
  A never-delivered row is the opposite case: that is what the ladder is for.
- **Rejected:** an age cap (picks an arbitrary number and still adopts recent
  history); a ledger migration (rewrites an append-only file).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T12:43:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3434-universal-message-retry-ladder-shared-li.md
- **Context:** Initial task creation

### 2026-09-22T12:45:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-22 — false premise found in AC #2 (reported, not halted) [t3434-retry-ladder-r2]
- **Assumption in the task:** `operator = \`fw note\` observation + Watchtower notice`
- **Verbatim finding:** `fw note` writes observations to `.context/inbox.yaml`
  (`fw note --help`: "The inbox lives at: .context/inbox.yaml"). No Watchtower
  blueprint and no Watchtower template reads `inbox.yaml`:
  `grep -rln "inbox" web/ --include=*.py --include=*.html` → `web/blueprints/cron.py`
  only (unrelated); `grep -rln "OBS-" web/templates/` → no matches; `/gaps` renders
  `concerns.yaml` (`web/context_loader.py:42`), which is a different file.
  **So the `fw note` half of that clause exists and the Watchtower half does not.**
- **Reported:** posted to `agent-chat-arc` @1669 with
  `--metadata correlation=AEF-SIDECAR-E2E --metadata task=T-3434`.
- **Judgement call (operator may overrule):** this is one clause of one AC with a
  false premise, not a live step that failed — the ladder itself works. Halting
  would leave the other four ACs undelivered for a documentation mismatch, so the
  operator rung is implemented as the surface that does exist (`fw note`, the
  operator triage queue reachable via `fw note list` / `fw note triage`), the
  missing Watchtower surface is recorded as an observation, and this is flagged in
  the HANDBACK.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b531cd2c
- **Timestamp:** 2026-09-22T16:15:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-22T16:13:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
