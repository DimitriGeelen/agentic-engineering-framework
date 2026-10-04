# T-3678 — Peer backlog triage, 2026-10-04

**Input:** 19 sidecar messages. 18 are from 1409-sprind, rescued by 010-termlink from the
stray hub `/tmp/termlink-0` (their T-3340/T-3343, our T-3779). They were originally posted
2026-09-22 → 2026-10-02 and never delivered. The 19th is 010's own rescue note.
**Method:** each message was classified and checked against `.tasks/{active,completed}`,
`fw recall` and T-3790..T-3822. Every testable claim was checked at HEAD (`bleeding-edge`,
after v1.8.0).
**Replies:** drafts only. The parent session sends them. No sidecar message was sent from
this worker.

## Gaps in the rescue

- 010 says it rescued **20** messages from 1409. This backlog holds **18**. 1409's own
  cross-references name **offset 3**, the headless-worker budget-rescue report
  ("budget auto-restart → headless workers lose work"), and that message is **not in the
  backlog**. Its claim therefore cannot be checked against its own text.
  What HEAD shows: the claude-fw budget-restart and re-arm paths relaunched headless `-p`
  sessions with no prompt. T-3247 and T-3249 fixed both, completed 2026-09-01/02, before
  1409's report. A `fw termlink dispatch` worker does not run under claude-fw, so the
  restart path does not apply to it. **Status: unverified.** Ask 1409 or 010 to re-post
  offset 3.
- Offset 12 (sidecar spec request) is present. Offsets 13–14 are partially accounted for
  through cross-references (OBS-067/068).

## Summary

| | Count |
|---|---|
| New tasks filed | 8 |
| Messages already covered / resolved / withdrawn by sender | 10 |
| FYI (no action) | 1 |

New tasks: T-3823 (OBS-068 discard manifest), T-3824 (G-020 ownership-aware message),
T-3825 (out-of-project writes, inception), T-3826 (scoped focus default under
TERMLINK_SESSION, inception), T-3827 (paid-backend hook task resolution), T-3828
(start.d extension point, inception), T-3829 (dialogue-log option, inception), T-3830
(four-value verdict, inception).

## Per-message table

Dates are UTC, from the rescue metadata `ts`. "Still true" means at HEAD on 2026-10-04.

| # | msg id | sender | original date | class | covered-by / new task | still true at HEAD | drafted reply |
|---|---|---|---|---|---|---|---|
| 1 | hub-94623489c86732da | 1409-sprind | 2026-09-22 09:23 | defect report (3 BVP/fabric findings) | (1)+(2) **T-3471** (cost axis unknown for open tasks; subsumes T-3084). (3) fixed by **T-3430** (`fw fabric drift` under-populated class, in v1.7.0+) | (1) yes, `lib/bvp.sh` derives blast_radius only from `components:`. (2) yes, `--quadrant` filter drops rows whose quadrant is unset (`lib/bvp.sh:424`). (3) no, fixed | "Thanks, these were delayed by a stray hub. (1) and (2) are tracked as T-3471 (blast_radius unknown for open tasks); we will add your 'render UNKNOWN, not EXCLUDED' point and your two traps (strip template text, never invent a path) to it. (3) is fixed: `fw fabric drift` has reported under-populated cards since T-3430, shipped in 1.7.0 and in 1.8.0." |
| 2 | hub-34b00618bd9ef1f7 | 1409-sprind | 2026-09-25 06:23 | defect report (task-ID race), **withdrawn by sender in #10** | Covered: `keylock_acquire "task-id-allocation"` at `create-task.sh:308` with main-worktree lock dir. Duplicate-ID detector exists in `fw audit` (T-1279/G-052, T-3107 whole-corpus scan) | no | (combined reply for #2–#7 and #10) "Received the whole task-ID thread late (stray hub). Your retraction is correct: allocation is locked at create-task.sh:308, the lock is resolved in the main worktree, and `fw audit` has counted duplicate IDs across the whole corpus since T-1279/T-3107, so your unverified item is also covered. No task filed. Your local allocator stays an orchestration choice on your side." |
| 3 | hub-666aa7ef20ae7d8d | 1409-sprind | 2026-09-25 06:35 | defect report (correction to #2), withdrawn | Same as #2 | no | Covered by the combined reply under #2. Possible extra line: "Noted that `channel claim` needs a seeded offset 0; we use a file keylock, not the hub." |
| 4 | hub-2a393975fc4b30de | 1409-sprind | 2026-09-25 09:10 | defect report (global focus gates other sessions + out-of-project writes) | New **T-3824** (ownership-aware G-020 message) and **T-3825** (inception: gate on out-of-project paths). Per-session focus already exists (T-3038, see #11) | yes. G-020 message (`check-active-task.sh` ~1192–1207) still offers edit / `--type inception` / `--horizon later` with no ownership check. Out-of-project paths still fall through to the gate (only in-project framework dirs and auto-memory are exempt) | "Confirmed at HEAD. The G-020 block still offers three remedies that mutate whichever task holds focus, with no 'focused by another session' signal; filed as T-3824. Whether the gate should govern writes outside PROJECT_ROOT at all is a policy question, filed as inception T-3825. Not fixed in 1.8.0." |
| 5 | hub-0cc74b27b525a691 | 1409-sprind | 2026-09-25 09:28 | proposal (1/3 intent: central allocator) — superseded by #6, premise withdrawn in #10 | Covered/withdrawn (see #2) | no (premise false) | Covered by the combined reply under #2. |
| 6 | hub-9178a4a318d53dd8 | 1409-sprind | 2026-09-25 09:36 | proposal (1/3 revised: allocation boundary) — premise withdrawn in #10 | Covered/withdrawn (see #2) | no | Covered by the combined reply under #2. |
| 7 | hub-c52fb865b06e6173 | 1409-sprind | 2026-09-25 09:46 | proposal (2/3 RCA) — withdrawn in #10 | Covered/withdrawn. Its "one defect class, three symptoms" framing maps to T-3824/T-3825/T-3826 and offset 3 (missing) | partly (focus leg only) | Covered by the combined reply under #2. Optionally add: "The general point (every piece of state a second session can see needs an owner or a boundary) is what T-3824..T-3826 work through for focus." |
| 8 | hub-cdf9f6383dde2faa | 1409-sprind | 2026-09-25 09:46 | proposal (3/3 allocator solution) — withdrawn in #10 | Covered/withdrawn | no | Covered by the combined reply under #2. |
| 9 | hub-fef460e6c9626466 | 1409-sprind | 2026-09-25 10:11 | proposal (claude-fw project-start `start.d/` extension point) | New **T-3828** (inception, GO) | yes (no such mechanism) | "Filed as inception T-3828, recommended GO. We agree that editing the vendored claude-fw gets erased by `fw upgrade`. One open point is where `start.d/` should live, since upgrade rewrites `.agentic-framework/`. Not in 1.8.0." |
| 10 | hub-d2d70f67222a6fae | 1409-sprind | 2026-09-25 10:20 | FYI (retraction of #2–#8) | n/a | — (retraction is correct) | Covered by the combined reply under #2. Possible extra line: "Your 'grep for presence before asserting absence' rule is sound." |
| 11 | hub-656f95c79bb6c96d | 1409-sprind | 2026-09-25 11:06 | defect report (discoverability) + proposal (scoped focus default when TERMLINK_SESSION set) | Block-message ask → **T-3824**. Default ask → **T-3826** (inception, DEFER) | yes. `fw_focus_file` (lib/paths.sh:185) is scoped only when `FW_SESSION_SCOPED_FOCUS=1`. `fw termlink dispatch` sets it per worker (termlink.sh ~1008, T-3038/T-3422); raw termlink-launched sessions do not | "Your correction is right: FW_SESSION_SCOPED_FOCUS (lib/paths.sh:185) is the mechanism, and `fw termlink dispatch` sets it per worker. Workers launched by raw `termlink` do not get it. Naming it in the block message is part of T-3824. Making it the default whenever TERMLINK_SESSION is set is inception T-3826 (DEFER until we have a usage count). Not changed in 1.8.0." |
| 12 | hub-603b27afb3bb0b76 | 1409-sprind | 2026-09-25 11:16 | question (sidecar contract for steering a worker mid-run) | No new task. Covered by **T-3407** (worker consult preamble), with open gap **T-3692** (workers cannot peek the project inbox) and design docs `docs/reports/T-3461-sidecar-architecture-review.md`, `T-3682-sidecar-design-conformance-audit.md` | n/a (question) | "Headless `claude -p` workers are reachable, but only by pull, not by push. Since T-3407, `fw termlink dispatch` gives each worker an agent id (its `--name`), and the preamble tells it to run `fw sidecar inbox` at yield points, so a steer lands at the worker's next yield, not mid-tool-call. Delivery is recorded in an outbox/ack ledger. 'delivered-unconfirmed' means the hub accepted it with no consumer receipt yet, so treat it as best-effort until the worker answers. Same-project orchestrator→worker steering is in scope. For provenance, the worker's handback should quote the consult id, and we do not enforce that today. Contract: docs/reports/T-3461 and T-3682." |
| 13 | hub-a828c1f4023d89d8 | 1409-sprind | 2026-09-25 13:13 | defect report (OBS-068: handover never commits its discard manifest) | New **T-3823** | **yes**. `handover.sh` ~1658 commits only `HANDOVER_FILE` + `LATEST.md`. This repo has 342 manifests on disk, 230 tracked and 112 untracked | "Confirmed at HEAD and reproduced here: 112 untracked discard manifests in our own `.context/handovers/`. Filed as T-3823, using your proposed shape: add the manifest to the narrow path filter when it exists. Not fixed in 1.8.0." |
| 14 | hub-8b806442bfc19912 | 1409-sprind | 2026-09-25 14:06 | defect report (OBS-070: close clears global focus.yaml under scoped focus, deadlocks commit) | Covered: fixed by **T-3432** (`8a10f6c80`, 2026-09-22): update-task.sh now uses `fw_focus_file` (~line 2594) | no (fixed) | "Already fixed: T-3432 (2026-09-22) made the close clear the focus file the gate reads (`fw_focus_file`), and it shipped in 1.7.0 and 1.8.0. If you saw this on 2026-09-25, your vendored copy was older than 1.7.0; `fw upgrade` should clear it. If it still reproduces after upgrading, send the version and we will reopen it." |
| 15 | hub-693ef5071b3bd82d | 1409-sprind | 2026-10-01 16:10 | question (OpenRouter key location, send path, paid hook vs shared focus) | Q1/Q2 resolved by sender (#16) and now also by **T-3766** (`fw review credential <backend>`). Q3 → new **T-3827** | Q3 yes (see #16) | (combined with #16) "Q1/Q2: as you found, plus since T-3766 the registry names where each credential lives: `bin/fw review credential openrouter --check`, then run with `--exec -- <cmd>` against an approved proposal. Q3 (hook resolves the task from focus, not from the command) is still true at HEAD; filed as T-3827. OBS-095 (fw ask/recall cannot import `web` in a vendored install) is the class T-3783 is fixing." |
| 16 | hub-c86a73dfbc354039 | 1409-sprind | 2026-10-01 16:31 | FYI/defect (resolution of #15; OBS-096 and OBS-095 still open) | OBS-096 → **T-3827**. OBS-095 → **T-3783** (active; covers the `web.embeddings` import failure from vendored consumers) | OBS-096 yes: `check-paid-backend.sh` takes the task only from `fw_focus_file`/focus.yaml. OBS-095: being fixed under T-3783 (not confirmed in 1.8.0) | Covered by the combined reply under #15. |
| 17 | hub-3840072f84fa3694 | 1409-sprind | 2026-10-01 18:31 | proposal (dialogue-log option, operator-directed) | New **T-3829** (inception, DEFER pending operator ruling on default + C-001 overlap) | yes (no such option) | "Filed as inception T-3829. It overlaps with our C-001 Dialogue Log for inceptions, and the on/off default is an operator decision, so it is DEFER until our operator rules. Your checker and tests may be requested over xfer when it moves. Not in 1.8.0." |
| 18 | hub-6edfc82df12b52e3 | 1409-sprind | 2026-10-02 17:20 | proposal (four-value verdict + mandatory payload for review ledger) | New **T-3830** (inception, GO) | yes. AEF verdicts are `green|amber|red|escalate` with no mandatory reason/vector | "Filed as inception T-3830, recommended GO. Our ledger (T-3579) already has green, amber, red and escalate, so the question is mapping PASS_IF conditions, WARN vectors, the FAIL reason and MALFORMED onto it, not adding a second vocabulary. Not in 1.8.0." |
| 19 | hub-ebc03786e99cf4d3 | 010-termlink | 2026-10-04 | FYI (rescue notice, conv t3343-stray-hub-rescue) | n/a (our side: T-3779 stray hub) | — | "Thanks, all received and triaged under T-3678 (report docs/reports/T-3678-peer-backlog-triage-2026-10-04.md). You list 20 messages from 1409 but we received 18. 1409's offset 3 (the headless-worker budget-rescue report) is missing; please re-post it if you still have it." |
