---
id: T-3041
name: "AEF under multiple uids — de-rooting the framework's shared state"
description: >
  Inception: AEF under multiple uids — de-rooting the framework's shared state

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-16T16:32:07Z
last_update: '2026-08-16T16:45:08Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-16T16:34:22Z'
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
cost_estimate_proposed:
  - ts: '2026-08-16T16:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3041: AEF under multiple uids — de-rooting the framework's shared state

## Problem Statement

AEF was built, and has run for its entire life, as `root`. Every assumption about
who can write what has been true by accident: there is only one principal and it
can write everything.

That assumption is now breaking. A Codex agent running as `dimitri-mint-dev` could
not reach the local TermLink hub (`srwxr-xr-x root root` — connecting to a Unix
socket needs the write bit) while a *remote* host authenticated in fine over TCP.
**When remote access is easier than local, the local path is not using the auth
model.** Three hub processes now exist on this box because each uid that could not
reach an existing hub silently started its own.

The question is not "how do we chmod this socket". It is: **what does AEF have to
become for agents running as different users to be first-class?** Asked now
because non-root agents have already arrived, and every additional one fragments
the substrate further and silently.

Full artifact: `docs/reports/T-3041-multi-uid-aef.md`.

## Exploration Plan

| Spike | Question | Time-box | Output | Status |
|---|---|---|---|---|
| IW-2 | Does shared group + setgid + umask hold, or convert clean failures into silent lost updates? | 1 session | `docs/reports/T-3041-lost-update-spike.md` | **done** — measured, A rejected |
| IW-3 | Which `.context/` state is genuinely shared vs per-principal? | 1 session | `docs/reports/T-3041-write-site-inventory.md` | **done** — 27 dangerous sites |
| IW-1 | Which users are agent runtimes; is root staying a principal? | operator input | — | **open** (does not gate GO) |

Both spikes were dispatched to isolated TermLink workers and told explicitly that
disproving the hypothesis was a real result. IW-2 duly disproved half of it.

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

- **IW-1: Which users are agent runtimes, and is `root` staying a principal at all?**
  confidence: 0
  disposition: deferred
  rationale: >-
    Operator-only by construction — this is a policy decision about the host and
    the fleet, not a fact discoverable from the code, so it is asked rather than
    guessed. It forks IW-7's scope and the size of step 4, but it does NOT gate
    the GO: steps 1-3 (A-minimal unblock, E on the 27 dangerous sites, B on the
    genuinely per-principal state) are correct under either answer, because E's
    append-only shape is uid-independent by design — that is the whole reason it
    was chosen over A. What the answer changes: "root stays, others join" keeps
    the identity model small (a registry reconciling uid / sender_id / origin /
    focus key); "no agent runs as root" makes it a real migration touching cron,
    systemd units, Watchtower, and /opt ownership, and would also un-reject
    Candidate F if the end state is fully containerised. Revisit trigger: the
    operator's answer, at which point IW-7 re-scopes and step 4 gets sized.
  <!-- Operator-only. Determines whether the end state is "root + others share a
       group" (A) or "no agent runs as root" (a much larger migration: cron,
       systemd units, Watchtower, /opt ownership). Everything downstream forks
       on this answer, so it is asked first and not guessed. -->

- **IW-2: Does a shared POSIX group + setgid + umask actually hold, or does it
  convert hard failures into silent lost updates?**
  confidence: 3
  disposition: answered
  rationale: >-
    Measured, not argued. docs/reports/T-3041-lost-update-spike.md — 2 real uids,
    200 iterations each, 4 replications. It does NOT hold: temp+mv under
    group+setgid lost exactly 200/400 updates every run with 400/400 writes
    reporting success and zero errors; in-place RMW left the file structurally
    unparseable in 3 of 4 runs; the append-only control passed 400/400 with no
    group at all. Two corrections to my own framing, both recorded in artifact
    §5c: (a) A does not even grant the shared write it trades safety for, because
    mktemp hard-codes 0600 and rename(2) preserves it — the aggregate lands
    0600 owned by the last writer and locks the other principal out; (b) the
    "today it fails loudly" premise was overstated — E4b/E4c show the framework
    already losing updates silently today whenever root is the writer, since root
    bypasses DAC. A generalises an existing silent-loss mode rather than creating
    one. Verdict: A rejected for rows 5/6 on evidence; E confirmed as the spine.
  <!-- The concern is specific, not vague: `.context/working/*` files that are
       rewritten wholesale via temp+mv are single-writer by construction. Today a
       second principal gets a clean EACCES. Group-writable, it gets a successful
       write that silently discards the other principal's state. That is strictly
       worse for D2/Reliability, and it is why A is not recommended alone. Needs a
       spike: two uids, concurrent `fw context focus` + counter writes, measure
       lost updates. -->

- **IW-3: Which `.context/` state is genuinely shared and which is per-principal?**
  confidence: 3
  disposition: answered
  rationale: >-
    Inventoried, not guessed. docs/reports/T-3041-write-site-inventory.md — two
    variable-resolving scanners plus per-site code reading, every classification
    citing file:line. Counts: 27 dangerous (shared + read-modify-write,
    unprotected), 27 per-principal RMW/truncate (a distinct failure — wrong-agent
    state, not lost update), 29 append-only already safe, 7 lock-protected
    (flock/mkdir, shown not assumed), 11 undetermined and listed as gaps rather
    than guessed. Rows 5/6 of the artifact table are now measured, not inferred.
    27 is the size of step 2 and it is tractable. Three findings beyond the count,
    all in artifact §5d: (a) the ~24-site "L-493 class / atomic write" comment
    sweep is a false-safety surface — it means crash-atomic and is silent on
    concurrency, so grep-based triage will skip the sites that need fixing
    (OBS-301); (b) lib/spawn.py:216-258 (update_outcome_row) erases concurrently-appended
    dispatches.jsonl rows — a live single-uid bug in the ledger CLAUDE.md's own
    dispatch table is computed from, not a de-rooting concern (OBS-300); (c) the
    correct multi-writer pattern already exists complete in-tree at
    lib/bus.sh:120-137 + :198-204 (T-605), so this is 27 sites bypassing a working
    pattern, not a design gap.
  <!-- T-3038 already answered this for focus (shared file + per-key override +
       one resolver + reader fallback). The open part is the inventory: rows 5/6
       of the artifact's table are a guess until each write site is read. The
       append-only JSONL logs (row 7) are already multi-writer safe and need no
       change — lib/outcome.py documents the O_APPEND property explicitly. -->

- **IW-4: Is host provisioning (creating the group, umask, setgid) in `fw init` /
  `fw upgrade`'s remit, or is it operator setup the framework only *checks*?**
  confidence: 3
  disposition: answered
  rationale: >-
    Answered by the evidence rather than by preference, and the answer got easier
    once A-full was disqualified. The framework CHECKS and REPORTS; it does not
    provision. Three reasons, in order of weight. (1) There is now much less to
    provision: IW-2 killed the tree-wide chgrp, so what remains is A-minimal on
    /var/lib/termlink — TermLink's own state dir, not the consumer's repo — plus
    keeping .context/locks/ group-openable, which the framework already creates
    itself (lib/keylock.sh:42) and can therefore mode correctly at creation
    without touching anything it does not own. (2) D4/Portability: chgrp-ing a
    consumer's tree is a host-policy decision the framework has no authority to
    make, and it would need root to do it — precisely the dependency this whole
    inception exists to remove. (3) Demonstrated infeasible, not merely
    undesirable: this session's agent was classifier-blocked from running the
    chmod at all, twice. Any design requiring the agent to provision is already
    known to fail in practice. So: fw doctor grows a check, fw init documents the
    host prerequisite, and the operator runs the one privileged command.
  <!-- Bears on Portability (D4): a framework that chgrps a consumer's tree is
       making a host-policy decision it has no authority to make. Leaning toward
       "fw doctor checks and reports, fw init documents" — but that is a
       disposition to record, not an assumption to bury. Live evidence this
       session: the agent could not perform the chmod itself (classifier block),
       so any design that *requires* the agent to provision is already known to
       fail in practice. -->

- **IW-5: Does the TermLink fix belong upstream, and does that block us?**
  confidence: 3
  disposition: answered
  rationale: >-
    Yes it belongs upstream, and no it does not block us. Gap-homing (T-1333): the
    dual-auth-model defect is in TermLink's code — a Unix socket authorised by
    POSIX mode alongside TCP authorised by HMAC fleet secret, with nothing
    reconciling them — so the fix (SO_PEERCRED on the local path, or drop the
    socket for loopback TCP with the same HMAC) lands in the TermLink repo. Filing
    it here would create a zombie entry nobody who could fix it will read. It does
    not block: A-minimal (chgrp + chmod 0770 on hub.sock) restores local access
    without TermLink changing a line, and it is unaffected by the IW-2 verdict
    because a socket has no read-modify-write shape to lose updates in. Note the
    two are not substitutes — A-minimal stops THIS host fragmenting; only the
    upstream fix stops the next host doing the same thing for the same reason.
  <!-- Gap-homing (T-1333) says the socket/auth-model fix lives in the TermLink
       repo, not here. Confidence 3 because the code is not ours. The real
       question is whether our A+B work is independently useful while that sits
       upstream — believed yes, since group+setgid fixes our side of the socket
       without TermLink changing anything. -->

- **IW-6: Can the shared read-modify-write aggregates become append-only +
  derived view, and what breaks in the read path?**
  confidence: 3
  disposition: answered
  rationale: >-
    Mechanism proven and blast radius now measured. IW-2 (spike §4) ran the
    append-only shape under two real uids with NO shared group and got 400/400
    lines, zero torn, zero lost — so the target shape is verified, not assumed.
    IW-3 sizes the read path: 27 dangerous sites to convert, against 29 that are
    already append-only and an in-tree reference implementation at
    lib/bus.sh:120-137 + :198-204 (mkdir test-and-set + same-dir temp/os.replace,
    T-605). What breaks in the read path is bounded and enumerated per-site with
    file:line in the inventory. Two traps recorded for the build slices: the
    ~24-site "L-493 class / atomic write" comment means crash-atomic only and will
    cause grep-based triage to skip real sites (OBS-301), and
    bvp-weight-history.yaml is documented append-only at lib/bvp.sh:1434 while
    implemented as full read-modify-write — it will be mis-triaged as safe.
    Remaining unknown is not the mechanism but 11 undetermined paths (two SQLite
    DBs whose safety turns on journal_mode/busy_timeout, and
    .context/message-archive/** which has no in-repo writer) — those need runtime
    probes, not more static reading, and none of them gate the decision.
  <!-- Candidate E, added after the first pass. `dispatches.jsonl` is already
       multi-writer safe with no group, no lock and no rail, purely because it is
       append-only. The question is whether learnings/decisions/patterns can be
       moved to that shape, and what the compatibility window costs: every
       consumer that currently yaml.safe_load()s the aggregate. Confidence 2 —
       the mechanism is proven in-tree, the blast radius is not yet measured.
       Depends on the IW-3 inventory to size it. -->

- **IW-7: Should AEF have a first-class principal identity, and does it subsume
  `sender_id`, `origin`, and the T-3038 focus key?**
  confidence: 2
  disposition: deferred
  rationale: >-
    Deferred deliberately, and this is an evidence gap rather than a hedge. The
    problem is now better evidenced than when filed — §5b names four identity
    notions that never reconcile (OS uid, TermLink sender_id, dispatch origin,
    T-3038 focus key), and this session produced a live instance: an
    auto-dispatcher (origin systemd:unlabeled-unit) spawned a worker onto T-1719
    while a human session was mid-edit on the same files, with nothing in the
    system able to tell those apart as two principals with a converging write set.
    What is missing is not motivation but SCOPE, and the missing input is IW-1: if
    root stops being a principal the identity model has to span uids, containers
    and remote agents; if root stays and others join, a small registry mapping the
    four existing notions may be enough. Those are different-sized pieces of work
    and picking one now would be guessing. Concretely revisitable: answer IW-1,
    then re-scope. Nothing in the GO recommendation depends on it — it is step 4,
    sequenced after E, and it is flagged in the artifact as the piece most likely
    to be skipped precisely so that deferring it does not quietly become dropping
    it.
  <!-- §5b. Four ad-hoc identity notions already exist and never reconcile.
       Evidence they need to: an auto-dispatcher (origin:
       systemd:unlabeled-unit) spawned a worker onto T-1719 while a human
       session was mid-edit on the same files, and nothing in the system could
       tell those were two principals with a converging write set. Low
       confidence because the right scope is unclear — this could be a small
       registry or a large refactor. -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN** — deciding the shape of the fix and sizing it: the candidate analysis
(A/B/C/E/F/G/D), the two measurement spikes, the write-site inventory, and the
sequencing of the build slices a GO would authorise.

**OUT, explicitly:**
- **Doing any of the build work.** This is an inception. E's 27-site conversion,
  the A-minimal chmod, and the `fw doctor` rail are all separate build tasks
  created *after* a GO.
- **The TermLink socket/auth fix.** Gap-homing (T-1333) — it belongs in the
  TermLink repo. Filing it here would create a zombie entry.
- **T-3042.** The `update_outcome_row` ledger-erasure bug surfaced by the IW-3
  inventory is a live single-uid bug with its own root cause and its own
  regression test. One bug, one task — already filed and dispatched separately.
- **Provisioning the host.** The framework checks and reports (IW-4); creating
  groups and setting modes is the operator's privileged action.
- **The principal-identity model (IW-7).** Real, evidenced, and deliberately
  deferred — it needs IW-1's answer to be scoped, and nothing in steps 1-3
  depends on it.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
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

**Recommendation:** GO — Candidate E as the spine, A-minimal as the unblock,
B where E does not reach; C upstream; F rejected unless IW-1 says "fully
containerised".

**Rationale:**

Forced by evidence, not preference. A non-root Codex agent cannot reach the
TermLink hub on its own host while a remote host authenticates in fine, and three
hubs now exist on this box purely because each uid that could not reach an
existing hub silently started its own (OBS-296). Fragmentation is the default
outcome the moment two agent runtimes run as different users — which is now the
normal case.

**Both evidence gates ran and both changed the answer.** My first pass recommended
a shared POSIX group (A) because the triggering bug was a permission. That framing
was too narrow, and the measurement killed it: under group+setgid, temp+`mv` lost
exactly 200 of 400 updates in every run while reporting 400/400 successful writes
with zero errors and a file that parses cleanly. A also fails to grant the access
it was trading that safety for — `mktemp` hard-codes `0600`, `rename(2)` preserves
it, so the aggregate lands owned by the last writer and locks the other principal
out. The append-only control passed 400/400 with **no group at all**. So the fix is
not to permit concurrent mutation more politely; it is to **stop mutating**.
That is Candidate E, and row 7 of the framework already proves it in-tree.

The work is bounded: **27 dangerous sites**, against a complete multi-writer
pattern that already exists here (`lib/bus.sh:120-137`, T-605). This is 27 sites
bypassing a working pattern, not a design gap needing invention.

**Two corrections to my own filing-time claims**, both recorded in artifact §5c
rather than quietly amended: the "today it fails loudly with a clean EACCES"
premise was overstated — it holds only uncontended, and not at all when root is
the writer, because root bypasses DAC. E4b/E4c measured the framework losing 90
and 200 updates *today*, with no group and no config change. We are not protecting
a working system; we are fixing one that is already silently lossy in half the
matrix. That raises the urgency rather than lowering it.

**Two items jump the queue** because they are true now under a single uid: the
~24-site `L-493 class / atomic write` comment sweep means *crash*-atomic and is
silent on concurrency, so grep-based triage will skip exactly the sites needing
fixes (OBS-301); and `lib/spawn.py:216-258` erases concurrently-appended dispatch
rows in the ledger this framework's own dispatch guidance is measured from
(OBS-300 → **T-3042**, already filed and dispatched).

**Evidence:**

- **IW-2 spike (measured):** `docs/reports/T-3041-lost-update-spike.md` — 2 uids ×
  200 iterations × 4 replications on this host. temp+`mv` under shared
  group+setgid: **400/400 writes succeed, exactly 200 updates silently lost, zero
  errors, file parses cleanly.** In-place read-modify-write: **unparseable in 3 of
  4 runs.** Append-only control: **400/400, zero lost, with no group at all.**
- **A disqualified twice over:** `mktemp` hard-codes `0600`, `rename(2)` preserves
  it — so Candidate A does not prevent the loss *and* does not grant the shared
  write it trades safety for. Setgid fixes the group; the mode denies it.
- **Already broken today:** E4b/E4c — root writing another principal's file loses
  90 and 200 updates respectively with **zero `EACCES`**, because root bypasses
  DAC, then leaves the file `0600 root:root` and locks the other principal out.
  The row-6 lockout is current behaviour, not a proposed change's side-effect.
- **Two of my own claims corrected by the evidence**, recorded in artifact §5c:
  the "clean `EACCES` today" premise (overstated — holds only uncontended, and not
  at all when root is the writer) and "A converts loud failures to silent ones"
  (it generalises an existing silent mode rather than creating it).
- **Rival-hub fragmentation:** OBS-296 — three hub processes on this host, two
  sharing `/var/lib/termlink`, because each uid that could not reach an existing
  hub silently started its own.
- **Socket ground truth:** `/var/lib/termlink/hub.sock` is `srwxr-xr-x root root`
  — a filesystem fact surfacing as an RPC `Permission denied (os error 13)`,
  which is why the peer misdiagnosed it as channel authorization (OBS-297).
- **In-tree precedent for E:** `lib/outcome.py:backprop_outcome` documents the
  `O_APPEND`-under-`PIPE_BUF` atomicity that makes row 7 safe with no rail.
- **Identity collision observed live:** an auto-dispatcher (`origin:
  systemd:unlabeled-unit`) spawned a worker onto T-1719 mid-edit; nothing in the
  system could tell those were two principals with a converging write set (§5b).

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

### 2026-08-16T16:34:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
