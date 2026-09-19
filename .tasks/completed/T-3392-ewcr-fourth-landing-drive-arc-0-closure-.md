---
id: T-3392
name: "EWCR fourth landing drive: Arc 0 closure path, T-3389, and Arc 1 kernel scoping"
description: >
  Landing drive under the STOP FINDING START LANDING mandate. Orient on arc-019, land
  the remaining Arc 0 task (T-3389 refusal/threat matrix), establish what is working
  end-to-end vs designed-only, and raise the operator approvals that Arc 0 closure
  and any Arc 1 (kernel) scope change require. Arc 0 charter forbids runtime implementation,
  so runtime landing is out of scope for this arc and must be escalated, not acted
  on.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:ewcr-arc0-contract-evidence, ewcr, landing-drive]
components: []
related_tasks: []
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
created: 2026-09-19T20:58:07Z
last_update: '2026-09-19T21:00:25Z'
date_finished:
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
  - ts: '2026-09-19T21:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-19T21:00:25Z'
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

# T-3392: EWCR fourth landing drive: Arc 0 closure path, T-3389, and Arc 1 kernel scoping

## Context

Fourth EWCR landing drive (after T-3381, T-3384), under an operator mandate of
"STOP FINDING, START LANDING": every unit ends landed, handed to the operator, or
dropped with a reason.

Arc state at drive start: `arc-019` / `ewcr-arc0-contract-evidence`, 11 tasks, 10
`work-completed`, 1 open (T-3389, `captured/later`). Arc focus already on arc-019
(set 2026-09-17), so no focus switch is required.

**Binding constraint on this drive.** The arc's own charter (`.context/arcs/ewcr-arc0-contract-evidence.yaml`)
reads: *"Draft-only Arc 0 authorized by the human on 2026-08-26 … No runtime
implementation, autonomy expansion, BVP confirmation, bulk task creation, or
supersession of prior DEFER/NO-GO decisions."* The mission's stop condition
("EWCR works end-to-end") therefore **cannot be reached inside arc-019** — the
roadmap (`docs/research/executable-workflow/roadmap-5be23719.md` §2) puts the
runtime kernel in Arc 1, which does not exist as an arc. Creating it is a
Sovereign act. This drive lands what Arc 0 can lawfully land and escalates the
rest rather than acting on it.

## Acceptance Criteria

### Agent
- [x] Status report written to `## Status report` in this file, covering: per-task arc-019 state; what runs end-to-end today vs designed-only; focus drift; and the critical chain to a working EWCR.
- [x] T-3389 (last open Arc 0 task) driven to a terminal state this session — landed, or recorded in `## Dispositions` with a one-line blocked reason. Parked: blocked on an operator transfer, no agent route.
- [x] Arc 0 closure surfaced to the operator (never self-closed — `fw arc close` is agent-refused, T-1671), with the absolute Watchtower link recorded in this file.
- [x] Arc 1 (semantics kernel) recorded in `## Operator actions` as a Sovereign scope decision with a recommendation — proposed, not created.
- [x] Verb mismatches and gate refusals encountered by this drive recorded in `## Verb mismatches and gate refusals`.
- [x] At least one unit landed, not merely reported: T-3393 (traceability matrix + fence) closed 6/6 ACs, 7/7 verification, commit `fae092e9c`.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Status report

**arc-019 task states (11).** Landed: T-3147 (anchor, Fabric overlap measured),
T-3350/T-3351/T-3352 (fence-1 Fabric carding + Unknown resolution), T-3381/T-3384
(prior landing drives), T-3385 (v1 schema freeze), T-3386 (task lifecycle
contract), T-3387 (evidence/idempotency contract), T-3388 (human→script→human
fixture). Open: **T-3389** — `captured/later`, blocked on the operator: it needs
the Claude / Z.ai / DeepSeek / Mistral review findings, which were never in the
transferred packet. Not agent-startable.

**Working end-to-end today.** One thing, and it is real: the contract fence.
`python3 tools/ewcr-contracts-check.py` → `OK: 7 schemas valid (draft 2020-12),
7 examples validate, manifest hashes match`, rc=0, pinned by
`tests/unit/t3385_ewcr_contracts_v1.bats` with control legs. Plus two Arc 0
measurement tools (`ewcr-arc0-unknown-overlap.py`, `ewcr-arc0-coverage-check.py`)
with a recorded falsifier verdict (`arc0-falsifier1-result.md`).

**Designed-only.** Everything runtime: procedure registry, event ledger and fold,
task binding, deadlines, cancellation, compare-and-append, evidence immutability.
`grep -rliE 'ewcr|executable.workflow' web/ lib/ bin/fw agents/` returns **zero
matches** — no route, no CLI verb, no runtime code. Arcs 1–6 do not exist as arcs.

**Focus.** Arc focus has been on arc-019 since 2026-09-17; no drift at arc level.
Task focus was null at session start. Recent off-arc work: T-2668/T-2669/T-2670
(arc-014 supersession reviews, prior mandate) — off-arc by `arc_id`, but their
finding was that all three dissolve *into* arc-019, so they served this arc.

**Gap that blocks closure.** The arc's `headline_mechanic` is: *"operator opens
the Arc 0 page, picks any pilot invariant or review finding, and sees it traced
to a versioned contract, a refusal scenario, a responsible component, and an
executable verification fence they can run."* That surface does not exist, and
`demo_evidence: null`. §13 lists **20** acceptance invariants; the two frozen
contracts name only **10** of them (#3, 5, 7, 9, 11, 13, 16, 17, 18, 20). So
today an operator picking invariant #1, #2, #4, #6, #8, #10, #12, #14, #15 or #19
finds no contract, no refusal scenario and no fence. Per §ACD / G-062 the arc
cannot close without the mechanic demonstrated.

**Critical chain to a working EWCR.** (1) traceability matrix + checker — the
missing Arc 0 evidence surface, filed this drive as NEW SCOPE; (2) T-3389 —
operator transfers the four external reviews; (3) Arc 0 closure — Sovereign;
(4) Arc 1 arc creation — Sovereign; (5) Arc 1 kernel candidates 1–9; (6) Arc 2
isolation proof, the hard gate before anything widens.

## Dispositions

| Task | Disposition | Reason |
|---|---|---|
| T-3389 | **parked, blocked on operator** | Needs the Claude/Z.ai/DeepSeek/Mistral review findings; never transferred (peer-transfer gap). No agent route to obtain them. |

## Operator actions

Recorded here and raised in chat with absolute links. All three are Sovereign;
none was acted on. Routes verified live (HTTP 200) at time of writing.

1. **Close Arc 0.** http://192.168.10.107:3002/arcs/ewcr-arc0-contract-evidence/close
   — `fw arc close` is agent-refused under `$CLAUDECODE=1` (T-1671) and requires
   `--demo`. **Recommendation: close it**, with `docs/research/executable-workflow/contracts/v1/traceability.yaml`
   plus `python3 tools/ewcr-trace-check.py` as the demo artefact: the operator can
   now pick any of the 20 §13 invariants and see contract, section, refusal
   scenario, component and a fence they run themselves. Caveat to weigh: the
   headline mechanic says "opens the Arc 0 **page**" and the trace is a file plus
   a CLI fence, not a Watchtower page. If you read the mechanic strictly, one more
   task is needed (a `/arcs/…/trace` view or `fw ewcr trace` verb); if you read it
   as "can reach the trace and run the fence", it is met today.
2. **Transfer the four external review findings** (Claude, Z.ai, DeepSeek, Mistral)
   → unblocks T-3389, the last open Arc 0 task. No agent route exists to obtain
   them; this is the only thing standing between Arc 0 and 11/11.
3. **Create Arc 1 — semantics-first runtime kernel.** http://192.168.10.107:3002/arcs
   — arc creation is Sovereign. **Recommendation: create it.** Arc 0's charter
   forbids runtime implementation, so "EWCR works end-to-end" is unreachable
   without it. Roadmap §2 scopes it as 9 candidates (registry/validator, ledger +
   fold, task binding, compare-and-append, durable deadlines, cancellation,
   evidence snapshot/hash, idempotency, pilot suite) with a hard exit gate before
   Arc 2's isolation proof. The traceability matrix already names the responsible
   Arc 1 component for all 11 covered invariants, so the arc has a task spine
   waiting for it.

## Verb mismatches and gate refusals

| # | Surface | What happened | Route taken |
|---|---|---|---|
| 1 | `fw work-on --help` | Not a help form — attempted to create a task literally named `--help`, failed on missing `--type`. No task created, focus unchanged. | Used `fw task create --help` instead. |
| 2 | `fw task create` | No `--arc` / `--arc-id` flag despite `arc_id:` being a first-class field. | Tagged `arc:ewcr-arc0-contract-evidence` (the legacy form `fw arc show` still reads). |
| 3 | `check-active-task` (Tier 1) | Refused `fw task show`, `fw task review-batch`, `ls` loops and `curl \| grep` under null focus — not on the read-only allowlist. | Filed T-3392 and set focus; re-ran. No bypass. |
| 4 | `check-active-task` (Tier 1) | Refused a `python3 -c` HTML-extraction one-liner because its regex `<[^>]+>` reads as a shell redirect. | Abandoned the extraction; not needed for the landing. |
| 5 | G-020 build-readiness | Refused work under T-3392 while its ACs were template placeholders. | Wrote real ACs with the Edit tool, as the block message directs. |
| 6 | `fw approvals` | Has no verb to *create* an approval — only `pending`, `status`, `expire`. Tier-0 blocks create them. STEP 4's "create it on the /approvals route" has no agent-side verb. | Recorded operator actions in-task and surfaced links in chat. |

## Evolution

### 2026-09-19 — the arc's blocker was the mechanic itself, not its backlog

- **What changed:** The drive was filed expecting the remaining work to be T-3389 plus closure paperwork. T-3389 turned out to be blocked on an operator file transfer with no agent route, so the backlog was effectively empty — yet the arc still could not close. The real blocker was the `headline_mechanic`: it promises a traceable invariant surface, `demo_evidence` was null, and `grep -rliE 'ewcr' web/ lib/ bin/fw agents/` returned zero. The arc had ten landed tasks and nothing that demonstrated its own stated outcome.
- **Plan impact:** "Land T-3389, then close" was unreachable. The drive re-aimed at the mechanic gap and filed T-3393 as NEW SCOPE. Reading §13 against the contracts then corrected the coverage figure the README asserted (11 covered, not 10) and surfaced two holes in the v1 freeze (#6 evidence-without-contract, #14 no `reason_code` in the enum).
- **Triggered:** T-3393 (landed, `fae092e9c`). Arc 0 closure and Arc 1 creation raised as Sovereign decisions rather than acted on — the mission's stop condition ("EWCR works end-to-end") is unreachable inside an arc whose charter forbids runtime implementation, which is a scope fact, not a blocker to route around.

## Verification

F=$(ls .tasks/*/T-3392-*.md | head -1); grep -q "^## Status report" "$F"
F=$(ls .tasks/*/T-3392-*.md | head -1); grep -q "^## Verb mismatches and gate refusals" "$F"
F=$(ls .tasks/*/T-3392-*.md | head -1); grep -qE "^\| T-3389 \| \*\*parked, blocked on operator\*\*" "$F"
F=$(ls .tasks/*/T-3392-*.md | head -1); grep -qE "https?://[^ ]+/arcs/ewcr-arc0-contract-evidence/close" "$F"
ls .tasks/completed/T-3393-*.md
python3 tools/ewcr-trace-check.py
python3 tools/ewcr-contracts-check.py

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-19T20:58:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3392-ewcr-fourth-landing-drive-arc-0-closure-.md
- **Context:** Initial task creation
