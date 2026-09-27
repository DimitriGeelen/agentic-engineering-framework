# procAsFit — round 3 of 4 — handback

**Run:** T-3517 (parent orchestration task, TermLink-dispatched round 3)
**Worker agent id:** pf0927-r3
**Repo:** /opt/999-Agentic-Engineering-Framework, branch `bleeding-edge`
**Window:** 2026-09-27, single session
**Predecessor:** `docs/reports/procasfit-2026-09-27-round-2.md` (read in full before
selecting any work, per instruction)

## What round 2 left, and what moved since

Round 2 closed nothing to `work-completed` itself, but staged T-1820 for a single
human tick (owner transferred to human, Agent ACs reclassified with citations,
Human AC added, sovereignty gate correctly refused the agent-initiated close),
reconfirmed the corpus-wide BVP flat-tie a third time, and surfaced (without
touching) `fw review-queue`'s 16-task "READY TO CLOSE" owner:human list.

**Sovereign questions from round 1/2 — status this round:**

1. **BVP v1 heuristic has no differentiating signal for the structural/hygiene
   bug-class family.** Re-verified this round (`fw bvp --quadrant hv-lc`,
   confirmed-only: 0/0; `--include-proposed`: identical 17-task flat tie at BVP
   108/norm 0.40/cost 3.6). **Unchanged, still open** — fourth independent
   reproduction (round 1 → round 3 [T-3481's own selection] → round 1 → round 2 →
   this round).
2. **Should the standalone hygiene backlog get an accumulator arc?** No operator
   answer found. **Unchanged, still open.**
3. **(Round 1's narrower inception-vs-build voi_score/BVP-flatness framing.)**
   Still not filed as its own task, third round running. Per round 2's own note,
   this recurrence is itself worth flagging to the operator rather than filing it
   myself under a different unit of work's evidence trail — carried forward
   unfiled again.
4. **(Round 2's new observation, not yet a formal Sovereign question.)** Is there
   a sanctioned way to batch-surface (not batch-execute) `fw review-queue`'s
   ready-to-close subset more efficiently? Not answered this round — no capacity
   spent on it; named for completeness.

**T-1820 (round 2's staged close):** Not re-touched this round. It is owner:human
now, correctly staged, and completing it is not delegated to agent initiative
regardless of how ready it looks — same boundary round 2 already applied to
itself. Confirmed still `started-work`/`owner: human` in this round's `fw task
list` pull (see Selection below); not re-verified beyond that listing, to avoid
spending capacity re-checking work already correctly left for the operator.

**Predecessor push (b61e32282, round 2's T-1820 commit) and the orchestrator's own
addendum commit (56c05d450):** both were unpushed to `origin/bleeding-edge` when
this round started (4 commits ahead locally). Pushed successfully this round
after waiting out the same pre-push audit-lock contention round 1/2 already
documented (T-3297/T-3324) — ran in the background rather than blocking on it,
confirmed via `git fetch` that origin caught up to local HEAD. No data was at
risk; this is routine commit-cadence hygiene, not a finding.

## Selection (stated before execution, per mandate)

**Objective:** AEF governs its own development (D2 Reliability) — closing a
structural blind spot in the framework's own audit tooling: a rail that exists
specifically to prevent silent-corpus drift (T-1881) was itself blind to an
entire language, and that blindness was measured live (T-3503) to have let two
Python copies of arc membership drift wrong while the rail reported PASS.

**Arc:** none declared on the task itself (`arc_id` empty on T-3516); related to
the ongoing arc-membership audit-rail hardening lineage (T-1880 → T-1881 → T-3502
→ T-3503 → T-3507 → T-3516), tagged `arc, audit, detector`, `related_tasks:
[T-3503, T-3507]`.

**Task:** T-3516 ("invert the T-1881 arc-membership rail to an import allowlist;
close OBS-545 as resolved"). **Quadrant:** same BVP-unselectable flat-tie family
as everything else in the corpus (confirmed above); re-entered via a different
tiebreaker than round 1/2 used. Round 1/2's tiebreaker was "cheapest remaining
work among owner:agent started-work tasks." That set was exhausted this round
(see table below) with no closable work in it, so I widened the search to
**captured, owner:agent** tasks — genuinely unstaged (not yet started) work —
and selected the one with concrete, well-evidenced scope and template (not yet
written) ACs: real problem statement, clear fix direction already sketched by
the task's own author, bounded blast radius (one audit check + one test file),
no fleet/sovereignty/human-judgment dependency.

**Why this one over other captured/agent candidates:** I read T-3378 (config
registry drift — turned out already superseded by a concurrent writer, parked
for the operator's duplicate-close call, not new work) and T-3516 before
choosing. T-3516 had real unclaimed scope; T-3378 did not. I did not exhaustively
read every one of the ~15 other captured/agent tasks in the corpus (T-3410,
T-3471, T-3472, T-3473, T-3487, T-3494, T-3500, T-3513, T-3514, T-3519, T-3339,
T-3376, T-3441) — several of those are visibly Sovereign-flagged (T-3487, T-3500
name themselves `SOVEREIGN`) or BVP-estimator-calibration work in the same
family as Sovereign Question 1 (T-3410, T-3494), and were skipped on that basis
without a full read; the rest were not reached before T-3516 turned out to need
the round's full remaining capacity (see below).

**Activity:** the acceptance criteria required (a) a new audit check in
`agents/audit/audit.sh` closing OBS-546, (b) a pinning test, (c) registering
OBS-545/OBS-546 in `.context/concerns.yaml` (a genuine sub-finding: both IDs were
named in T-3503's task file as "filed" but neither existed in the actual
register — register-first-fix-second had been claimed, not done), and (d)
confirming the executable-bit lesson (T-3317) held. All four done; no activity
outside what the ACs required.

## What closed

**T-3516 → `work-completed`.** Agent-owned, no Human ACs (none were needed — a
mechanical, fully agent-verifiable fix), 6/6 Agent ACs checked, 6/6 Verification
commands passed, reviewer static-scan PASS/no-findings. Closed via
`fw task update T-3516 --status work-completed` — no bypass, no `--force`.

**T-3520 → `work-completed`** (filed and closed within this round). A
one-criterion follow-up task for the OBS-250 trailing-work problem CLAUDE.md
itself documents: `fw task update --status work-completed` clears focus as its
last act, and a vendored-class file I had just edited (`agents/audit/audit.sh`)
needed `fw vendor self` run afterward — but by the time I needed it, there was no
task the sync could run under. Rather than use a bypass, I took the route
CLAUDE.md names as the only non-bypass option ("filing a new task just to run
one command") and filed T-3520, scoped to exactly that one verb call, closed it
the same way. This is itself a second, small piece of evidence for OBS-250's
own open status — filed as evidence in this handback, not re-registered as a
new concern (OBS-250 already exists and already names this exact shape).

## What T-3516 actually did

- Read the existing T-1881 shell-grep check (`agents/audit/audit.sh:1905-1954`)
  and the canonical `lib/arc_membership.{py,sh}` exports to understand the real
  mechanism before designing anything.
- Grepped the full source tree for every `arc_membership` reference (12 files)
  and confirmed all 12 already delegate correctly (import/source the canonical
  module) — the blindness is latent, not active, exactly as T-3516's own
  description said.
- **Found and closed a real design risk before shipping it:** an initial
  file-level "co-occurrence of `arc_id` + corpus-iteration anywhere in the file"
  signal would have false-positived on `agents/context/check-arc-id.py` (single-
  task arc_id resolution, no corpus scan) and — more subtly —
  `agents/termlink/bvp-estimator/estimator.py` (a 3600+-line file that does both
  corpus-iteration and arc_id-resolution, but in unrelated functions >1000 lines
  apart). Verified this concretely by grepping for the actual line numbers
  before writing any check code, not by assumption. Landed on a 60-line
  proximity window instead of file-wide co-occurrence, chosen because the
  canonical implementation's own scan function spans ~15-20 lines — a window
  generous enough to catch a real reinvention, tight enough to exclude
  estimator.py's unrelated distant functions.
- Wrote the check as a `python3 - "$PROJECT_ROOT" <<'PY'` heredoc (matching the
  established idiom already used elsewhere in `audit.sh`, e.g. the
  `bvp_coherence_findings` and `retire_when_findings` blocks) using `tokenize` to
  strip COMMENT tokens (not STRING tokens — a `row["arc_id"]` dict-key access
  still counts as real code) before pattern-matching, specifically to avoid the
  T-3502 class of false positive (a comment that merely names the pattern).
- Validated the exact logic three times before committing to it: (1) a
  standalone scratch script against the live 233-file corpus — zero findings;
  (2) a synthetic true-positive fixture (corpus iteration + arc_id, no
  import) — correctly flagged; (3) a synthetic comment-only fixture — correctly
  not flagged. Then extracted the **literal block from the edited `audit.sh`**
  (not the scratch copy) and re-ran it against the live repo to confirm the
  integration matched the validated design — PASS, 233 files, 0 violations.
- Wrote `tests/unit/audit_ctl_arc_membership_python_import.bats` (6 tests,
  mirroring the existing sibling `audit_ctl_arc_tag_only_pattern.bats`'s
  structure): clean tree, synthetic reinvention, delegating-file exemption,
  comment-only exemption, far-apart (>60 lines) exemption, canonical-file
  exemption. 6/6 pass, 0 skips.
- Registered **OBS-545** (mitigated by T-3507, status: resolved) and **OBS-546**
  (this task's fix, status: resolved) in `.context/concerns.yaml` — both were
  referenced by T-3503 as "filed" but grep confirmed neither ID existed in the
  actual register (highest OBS id present was OBS-256). Closed that gap as part
  of this task rather than filing it as a separate concern, since it is a direct
  instance of the same register-first-fix-second discipline this task was
  already exercising.
- Confirmed `agents/audit/audit.sh` retained its executable bit after the Edit
  (T-3317's exact lesson, surfaced unprompted by `fw work-on`'s own "Related
  knowledge" section — the framework's episodic recall worked as intended here).
- **Governance self-correction, logged not hidden:** made the Edit/Write calls to
  `agents/audit/audit.sh` and the new bats file *before* running `fw work-on
  T-3516` — focus was `null` at the time, yet the Edit/Write tool path let the
  writes through (the Bash-tool gate is evidently stricter than the Edit/Write
  gate for this hook; T-3299 already documents this class of asymmetry from the
  Bash side). Caught it myself, ran `fw work-on T-3516` to set focus/status
  properly before continuing, and did not treat the fact that it wasn't blocked
  as license to keep skipping the verb.
- Hit the G-020 scope gate (Bash-tool path) twice — once for the bats run, once
  for the vendor-sync command under T-3520 — because both tasks started with
  placeholder ACs. Wrote real ACs via the Write/Edit-tool exemption both times
  (the sanctioned route T-3299 documents), never routed around via direct-invoke
  or `--force`.
- Ran `fw vendor self --check`, hit the OBS-250 dead end (focus cleared by
  T-3516's own close), filed T-3520 rather than bypass, scoped the vendor sync
  to only this session's own file via `FW_VENDOR_ONLY`, confirmed byte-identity
  with `diff -q` (not just the tool's own summary line), closed T-3520.

## Arc state: tasks by status and quadrant

Unchanged from round 1/2's finding, reconfirmed a fourth time: `fw bvp
--quadrant {hv-lc,hv-hc}` (confirmed-only) is 0/0 corpus-wide;
`--include-proposed` reproduces the identical 17-task flat tie (BVP 108 / norm
0.40 / cost 3.6). T-3516 and T-3520 are now in `completed/`, both outside the
BVP-ranked set (as everything agent-executable in this corpus currently is).

## What remains in Q1/Q2, per task, with the reason it was not done

| Task | Why not done this round |
|---|---|
| T-3358 (claude-fw exit-detection, root fleet) | Re-attempted the fleet-access half this round with a genuinely different check than round 2's: `mcp__skills__remote_exec_hosts` (read-only) now shows 3/8 hosts reachable (no permission denial this time — round 2's "session-permission-classifier denial" did not reproduce), so I went one step further and tried `mcp__skills__remote_exec_exec` against `proxmox2`. **Same underlying defect as the 2026-09-20 session's own finding: `remote_exec.py: error: unrecognized arguments: --host --command`** — a third-party CLI wrapper bug, not a session-permission issue. Confirmed, not re-attempted further (one hypothesis test, not shotgun debugging); still parked for the operator or a session with a working route to that skill's fix. |
| T-3481 (predecessor 3-round orchestration) | Not re-investigated this round — round 2 already re-checked it with a different instrument (TermLink session registry vs. `dispatches.jsonl`) and confirmed the evidence gap is real. Re-running the same check a third time with no new instrument would not move it. |
| T-2770 (inception: read-only fw query auto-init) | Unchanged — correctly parked at `Recommendation: DEFER`, owner sovereignty boundary, not re-examined. |
| T-3496 (SOVEREIGN: voi_score constant on inceptions) | Unchanged — owner: human, explicit Sovereign question, not touched. |
| T-3487, T-3500 (both self-flagged `SOVEREIGN` in their titles) | Not opened beyond the title — flagged by their own author as requiring an operator ruling; reading further would not change that. |
| T-3410, T-3494 (BVP estimator no-signal-detector gaps) | Not opened beyond the title — same family as Sovereign Question 1 (the estimator's flatness is already the standing open question; these look like instances of investigating *why*, which is closer to research-into-the-Sovereign-question than agent-executable build work). Not confirmed by reading the full task, so flagged as a guess, not a finding. |
| T-100201 (reconcile T-100196/T-2394 master-merge-only contradiction) | Investigated in full — turned out to be **already fully staged** by an earlier session (2026-08-27): Agent ACs done, Human AC written with Steps/Expected, `## Dissolved by T-3185` section present, `Recommendation: GO`. Not new work; needs only the operator's one-line tick. Same shape as round 2's `fw review-queue` finding — not touched, named here as it was investigated this round specifically. |
| The ~15 other captured/owner:agent tasks not read in full (T-3339, T-3376, T-3441, T-3471, T-3472, T-3473, T-3513, T-3514, T-3519) | Not reached — T-3516's investigation + build + two governance-recovery detours (G-020 AC-writing twice, OBS-250 vendor-sync task) consumed the round's remaining capacity after the owner:agent started-work set was exhausted. Flagged for round 4 as the next place to look if the started-work set is still exhausted then. |
| The ~39-task standalone hygiene backlog | Unchanged — structurally unselectable via the sanctioned BVP path (Sovereign Question 1/2). |
| 16-task `fw review-queue` "READY TO CLOSE" list (+ T-100201, now 17) | Unchanged — all owner:human, not delegated to agent initiative. |

## Sovereign questions — priority order

Carried forward from round 1/2, unchanged in substance:

1. **BVP v1 heuristic has no differentiating signal for the structural/hygiene
   bug-class task family** (now independently reproduced four times across
   three prior rounds plus this one, identical numbers each time).
2. **Should the standalone hygiene backlog get an accumulator arc, or is
   arc-less maintenance-by-design intended?** Unchanged.
3. **(Round 1's narrower inception-vs-build voi_score/BVP-flatness framing.)**
   Unchanged, still unfiled — third round naming it without filing it. I am
   making the same call round 2 made (not inventing scope under this round's
   evidence trail) but flag explicitly: if round 4 finds it recurring a fourth
   time, that is no longer ambiguous evidence that it deserves its own task.
4. **(Round 2's batch-surface-not-batch-execute question for `fw
   review-queue`.)** Unchanged, not advanced this round — no capacity spent on
   it.

No new Sovereign question surfaced this round. T-3516's design decisions (the
60-line proximity window, comment-stripping-not-string-stripping, the specific
allowlist) were implementation-detail engineering within a problem the task's
own author had already scoped and directioned ("invert to import allowlist,"
"anchor on imports not text") — I judged this as within agent discretion, not a
new architectural/scope/priority decision requiring the operator, and said so
explicitly in my own reasoning before proceeding (recorded in this handback's
Selection/Activity sections, not just asserted after the fact).

## Gates that refused me, and what I did instead

| Gate | What it refused | What I did |
|---|---|---|
| G-020 scope gate (Bash-tool path) — T-3516 | `bats` test run while T-3516 still had placeholder ACs | Wrote real ACs via the Write/Edit-tool exemption (the sanctioned route), then re-ran. No direct-invoke, no `--force`. |
| G-020 scope gate (Bash-tool path) — T-3520 | `fw vendor self` while T-3520 still had placeholder ACs | Same remedy: real AC via Edit tool, then re-ran. |
| check-active-task (Bash-tool path) — focus null after T-3516's close | `fw vendor self --check` (OBS-250: close clears focus, but the vendored-file sync needs an active task) | Did not bypass (`FW_SAFE_MODE` cannot be set mid-session per CLAUDE.md's own note that it must be set on the process, not as a command prefix). Filed T-3520, the exact non-bypass route CLAUDE.md itself names for this dead end, scoped to one verb call. |
| check-active-task (Bash-tool path) — focus null after T-3520's close | `fw sidecar inbox` (yield-point check) | Re-focused onto T-3517 (the parent orchestration task genuinely still `started-work`/owned by this run) rather than filing a third throwaway task for a single read-only check. |
| Sovereignty (implicit — not a hook, self-governed) | Completing T-100201 myself, despite it being fully staged and looking ready | Did not touch it. Named it as evidence in this handback's Q1/Q2 table, same discipline round 2 applied to `fw review-queue`'s list. |

No `--force`, `--skip-*`, or `FW_ALLOW_*` bypass was used anywhere this round.

## Cost-vs-estimate deltas worth feeding back into calibration

T-3516's `cost_estimate_proposed` (2026-09-26): `tier: 2, effort: 8`,
`blast_radius: unmeasured`. Actual cost: reading ~6 files in full (the T-1881
check, `lib/arc_membership.{py,sh}`, T-3503's RCA, T-3507's outcome, the two
adjacent-risk Python files), three rounds of design validation against the live
corpus plus two synthetic fixtures *before* writing the shipped check, one new
~110-line audit-check block, one new 6-test bats file, two new concerns.yaml
entries, one governance self-correction (retroactive `fw work-on`), and one
follow-on task (T-3520) to close an OBS-250 dead end the close itself opened.
This is a case where `effort=8` (the flat heuristic's generic ceiling) was
closer to right than round 1/2's cheap-tiebreaker candidates — the real cost
driver was **getting the detector's precision right before shipping it**, which
the estimator has no way to see (it counts lines/ACs, not "how many false-
positive classes did the author rule out"). Worth naming for calibration: a
task whose description already sketches the fix direction can still cost far
more than its line-count suggests if the fix is a **detector** (something that
must be precise against an unbounded future input space) rather than a
**one-shot change** — the T-3502 incident this task explicitly cites as its own
cautionary tale is exactly this class, and I spent real capacity specifically
to not repeat it.

A second note, structural rather than cost-related: **OBS-250 is not
theoretical.** This round hit it directly, immediately after a completely
ordinary, well-verified close, on the very next command. The register already
names candidate fixes (widen the focus gate for a grace window, a narrow
allowlist for `fw vendor self`, auto-sync as part of close) with trade-offs; I
did not pick one, per the mandate's binding that a gate refusing me is a
finding to record, not mine to resolve by fiat. Flagging with slightly more
weight than a bare "still open" because this is now at least two independent
live incidents (the original OBS-250 filing, plus this round) hitting the exact
same dead end, which is the kind of recurrence CLAUDE.md's own "Proactive Level
D" guidance says is worth the operator's attention.

## Next unit of work, if round 4 runs against this same state

The owner:agent **started-work** set is exhausted for the fourth time (T-2770,
T-3358, T-3481 all re-confirmed blocked/parked-correctly this round or
round 2). The next productive move for round 4 is the same lateral shift I made
this round: walk **captured, owner:agent** tasks (widen further to
**captured, owner:human but not yet Sovereign-flagged**, if that set is
exhausted too) looking for one with real, well-scoped-by-its-author content and
still-placeholder ACs — that combination is what made T-3516 selectable when
the started-work set was not. The untouched list from this round's table above
(T-3339, T-3376, T-3441, T-3471, T-3472, T-3473, T-3513, T-3514, T-3519) is the
concrete starting point; T-3376 in particular ("unblock 91 stranded commits")
is worth an early look given its stated scale, though I have not verified its
actual content or feasibility. T-100201 needs no further agent work — it is
staged, named to the operator via this handback, and closing it is the
operator's single tick.

## Auditability

Every claim above traces to a command run in this session: `fw sidecar inbox`
(checked at session start, before finishing, and once mid-round after the
focus-cleared incident — empty every time); `git log`/`git status -sb`/`git
fetch` (4-commit gap found and resolved, confirmed via
`git log HEAD..origin/bleeding-edge --oneline` returning empty after push);
`fw bvp --quadrant hv-lc [--include-proposed]` (flat tie reconfirmed);
`fw task list --status started-work --owner agent` / `--status captured --owner
agent`; `fw gaps`; direct file reads of T-3358, T-3378, T-3516, T-3185, T-100201
in full; `mcp__skills__remote_exec_hosts` and `mcp__skills__remote_exec_exec`
(live calls, output captured verbatim above); `grep -rl arc_membership` /
`grep -rl arc_id` across `lib/ web/ agents/ bin/ tools/` (12 + 3 file lists,
verified by reading each); a standalone scratch detector script run three times
(live corpus, true-positive fixture, comment-only fixture — all outputs
captured above); `bash -n agents/audit/audit.sh` (syntax); `git diff --summary`
(executable-bit check); `timeout 60 bats
tests/unit/audit_ctl_arc_membership_python_import.bats` (6/6 ok, 0 skips, run
live, reconfirmed inside the close gate's own P-011 run); `python3 -c "import
yaml; yaml.safe_load(...)"` (concerns.yaml parses); `grep -q "id: OBS-54[56]"`
(both registered); `fw task update T-3516 --status work-completed` (6/6 AC, 6/6
verification, reviewer PASS, no bypass, output captured above); `fw work-on
T-3520` / AC-writing / `FW_VENDOR_ONLY=... fw vendor self` / `diff -q
agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh` (byte-identity
confirmed) / `fw task update T-3520 --status work-completed` (1/1 AC, 1/1
verification, reviewer PASS).

**Commits this round:** T-3516's changes (`agents/audit/audit.sh`,
`tests/unit/audit_ctl_arc_membership_python_import.bats`,
`.context/concerns.yaml`, task move to `completed/`, new episodic) and T-3520's
changes (task move, episodic, vendored `.agentic-framework/agents/audit/audit.sh`
sync) are staged for commit immediately after this handback is written, per the
mandate's "close or park the current task, then write the handback" ordering —
commit/push status to be confirmed in the same operation, not asserted in
advance.
