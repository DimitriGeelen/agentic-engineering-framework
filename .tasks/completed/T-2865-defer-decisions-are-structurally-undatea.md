---
id: T-2865
name: "DEFER decisions are structurally undateable: 14/14 invisible to the revisit
  scanner"
description: >
  DEFER decisions are structurally undateable: 14/14 invisible to the revisit scanner

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/revisit-due-scan.sh, agents/handover/handover.sh, 
      tests/unit/revisit_undated_signal.bats]
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
created: 2026-08-08T11:49:00Z
last_update: '2026-08-16T22:25:20Z'
date_finished: 2026-08-08T12:01:56Z
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
  - ts: '2026-08-08T12:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T12:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 4
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=4 (body:framework-level-ux); D4=2 
      (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 4
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=4 (body:framework-level-ux); D4=2 
      (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2865: DEFER decisions are structurally undateable: 14/14 invisible to the revisit scanner

## Context

Adopts the visibility leg of a defect 832 found in their vendored copy and offered
upstream on the DM rail (msg 450). Their incidence was 1 of 1 — they explicitly
declined to call that a percentage ("a rate off a single member is a sample wearing
a proportion") and asked us to measure ours.

**Measured here, 2026-08-08: 14 of 14 active DEFER decisions carry no `revisit_at`.**

At n=14 the proportion is real. And the mechanism is worse than "operators forget
to set the field":

- `lib/inception.sh` contains **zero** occurrences of `revisit_at`. The decide path
  cannot set it. This is a missing seam, not a discipline failure.
- The only writer of `revisit_at` anywhere in the tree is `lib/bvp.sh:1149`
  (the BVP R7 30-day-ahead mitigation) — unrelated to inception deferrals.
- `.tasks/templates/default.md:27` documents the field as *"T-1451: set on DEFER
  decisions to enable G-053 daily revisit scan"*. Specified, never wired.

The consequence is a **false green**, which is why it survived. `revisit-due-scan.sh`
removes its output file when nothing is ripe, and says so deliberately: *"downstream
readers can treat 'file absent' and 'file empty' as the same signal — nothing to
surface."* That collapse is correct for the dated population and catastrophic for
the undated one: `.revisits-due.txt` is currently **absent**, so every handover has
reported "no deferrals pending" over a population of 14. A red line gets noticed at
the next handover; a green line that ranges over an empty set is indistinguishable
from one that ranges over everything. Same shape as the port-3000 class (T-2732).

**Scope fence.** This task ships *visibility only* — the undated deferrals become
surfaced, counted, and triageable. Making `fw inception decide defer` require or
accept `--revisit-at` changes an operator-authority path and is **not** in scope;
it is recorded under `## Decisions` as an open operator decision with the shape
832 proposed. 832 drew the same fence for the same reason.

## Acceptance Criteria

### Agent
- [x] `revisit-due-scan.sh` emits a second, separate signal
      `.context/working/.revisits-undated.txt` for tasks whose `## Decision` block
      records DEFER and which carry no usable `revisit_at`. One line per task,
      same `<id>: <name>` shape. Absent when the set is empty (matching the
      existing file's absent==empty contract).
- [x] The undated signal is a **separate file**, not extra lines in
      `.revisits-due.txt`. That file means "ripe today" and its consumer prints it
      under exactly that heading; a dateless deferral has no date at all.
- [x] `handover.sh` surfaces the undated signal under its own heading
      ("Deferred With No Revisit Date"), distinct from the ripe-revisit heading.
- [x] Bats suite `tests/unit/revisit_undated_signal.bats` drives the **real**
      scanner against a synthetic project root (not a reimplementation), with
      three controls that must stay green: a ripe dated deferral lands in
      `.revisits-due.txt` only; a future-dated one lands in neither; an ordinary
      non-deferred task lands in neither.
- [x] ANTI-VACUITY: the suite is shown to go red on the finding leg when pointed at
      the pre-fix scanner (extracted via `git show HEAD:`), with all three controls
      still green — so the red is the defect and not a broken harness.
      **Shipped as two legs, not one.** The `git show HEAD:` form has real teeth
      today but goes permanently inert once this fix is committed (HEAD then
      carries the fix and it skips) — the orphaned-guard class. So a second,
      durable leg mutates the **live** scanner instead, neutralising the reporting
      line with `:` and asserting the finding goes red while all three controls
      stay green. That one keeps teeth at every future revision.
- [x] Measured incidence recorded in `## RCA` with the predicate used, so the
      number is reproducible rather than asserted.

<!-- No ### Human section. Every AC above is a deterministic file/heading/exit-code
     check. The one arguably-subjective AC — does the new handover heading read
     clearly — has an AGENT audience: the handover banner is what the next agent
     reads at session start to decide what to pick up. Per CLAUDE.md §AC
     Classification Guidance (T-2143 audience axis), subjective + agent-audience
     routes to ### Agent self-eval, not to any Human prefix. No render surface is
     touched (P-013 covers web/templates, web/static, web/blueprints, web/shared.py,
     web/app.py — handover.sh is none of these), so the render-review gate does not
     apply either. -->

<!-- Reference: Human-AC prefix routing, retained from the template for future edits.
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

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The suite passes, with the unjudged-run guard (T-2738): a bats file that prints
# "not ok" still prints "ok 1", so the pass marker alone is not a verdict.
out=$(bats tests/unit/revisit_undated_signal.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The second signal is a separate file, not extra lines in the ripe file.
grep -q 'revisits-undated' agents/context/revisit-due-scan.sh
# The handover heading exists and is distinct from the ripe-revisit heading.
grep -q 'Deferred With No Revisit Date' agents/handover/handover.sh
# The scanner still parses and runs clean against the live corpus (no regression
# on the ripe leg). Exit code is the verdict; no pipe.
bash agents/context/revisit-due-scan.sh

## RCA

**Symptom:** every handover has reported no pending deferrals while 14 active tasks
carried a DEFER decision. `.context/working/.revisits-due.txt` is absent.

**Root cause:** two independent halves that were never joined. `revisit_at` is
specified in `.tasks/templates/default.md:27` and consumed by
`agents/context/revisit-due-scan.sh` + `agents/handover/handover.sh:612`, but no
code path on the *decision* side ever writes it — `lib/inception.sh` has zero
occurrences of the string. The scanner then filters on
`[[ "$revisit_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]` and `continue`s on empty,
so the undated population is skipped before any reporting logic is reached.

**Why structurally allowed:** the scanner's absent-output contract is *deliberately*
lossy — its header comment instructs downstream readers to treat "file absent" and
"file empty" as the same signal. That is right for the dated population it was built
for, and it makes the undated population unobservable rather than under-reported.
There is no state in which the system says "I found deferrals I cannot schedule".
The check is correct over a set the defect cannot inhabit — the recurring class:
green because the population is empty, not because the property holds.

**Measured incidence (reproducible predicate):**

    # active tasks whose ## Decision block records DEFER
    grep -l '^\*\*Decision\*\*:[[:space:]]*DEFER' .tasks/active/T-*.md | wc -l    # 14
    # ...of those, how many carry a real ISO revisit_at in frontmatter
    # (awk-extracted from frontmatter only, same parse the scanner uses)     # 0

14 of 14, 2026-08-08. Comparison point: 832 measured 1 of 1 on their corpus. The
completed corpus holds a further 35 `**Decision**: DEFER` tasks, out of scope here
(the scanner reads `active/` only, correctly — an archived deferral is not pending).

**Prevention:** distinct from the fix. The fix emits the signal; the prevention is
`tests/unit/revisit_undated_signal.bats`, which drives the real scanner and is shown
red against the pre-fix scanner on the finding leg with its three controls green.
Without that teeth check, a green suite over today's corpus would prove only that
the corpus is currently clean.

**Not prevented by this task:** the seam itself. Nothing yet makes a DEFER decision
*produce* a date, so the surfaced count shrinks only by manual triage. That is the
open operator decision recorded under `## Decisions` — deliberately not taken
unilaterally, because it changes an authority path.

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

## Decisions

### 2026-08-08 — separate signal file, not extra lines in `.revisits-due.txt`

- **Chose:** a second file, `.context/working/.revisits-undated.txt`, with its own
  handover heading.
- **Why:** `.revisits-due.txt` means "ripe today", and its consumer prints it under
  exactly that heading. A dateless deferral is not ripe — it has no date at all.
  Widening an existing signal to carry a second meaning is the mechanism that
  produced this ambiguity in the first place; repeating it inside the fix would be
  the T-2137 class over again.
- **Rejected:** appending undated entries to the ripe file with a sentinel date, or
  a marker prefix. Both make every existing consumer's parse conditional on
  something it has no reason to check, and the handover banner would print
  "fires (none)" under a heading that asserts ripeness.
- **Credit:** this is 832's design call, adopted rather than re-derived. Their
  reasoning arrived on the rail and was sound; re-litigating it would have been
  make-work.

### 2026-08-08 — OPEN OPERATOR DECISION: should `decide defer` demand a date?

- **Not taken.** Making `fw inception decide defer` require `--revisit-at` changes an
  operator-authority path — it would refuse a decision the operator is entitled to
  record. That is the operator's call, not the agent's, and 832 drew the same fence
  for the same reason.
- **Shape if wanted:** a required `--revisit-at YYYY-MM-DD` with an explicit
  `--no-revisit-date` escape, so the deliberate indefinite deferral stays sayable.
  Without the escape the gate would force operators to invent dates, which
  manufactures signal rather than capturing it.
- **Found while writing the handover message (T-2865):** `fw task update
  --revisit-at` **does not exist**. Verified two ways — `grep -n revisit
  agents/task-create/update-task.sh` returns nothing, and the flag is absent from
  `fw task update --help`. There is no CLI verb anywhere that sets `revisit_at`;
  the field can only be added by hand-editing frontmatter. This is a *third*
  independent instance of the same seam gap (the field is specified in the
  template, consumed by the scanner and handover, and writable by nothing), and it
  widens the open decision: the question is not only whether `decide defer` should
  demand a date, but whether *any* supported path to set one should exist first.
  Caught because §Copy-Pasteable Commands rule 4 requires verifying a command
  before putting it in front of an operator — the draft banner had already been
  written with the fabricated flag in it.
- **Why it matters for the 14:** this task makes the omission *visible*. The
  surfaced count shrinks only by manual triage until something makes a deferral
  produce a date. Visibility without the seam means the heading is a standing
  backlog, which is the honest state but not a converging one.
- **Recommended:** wire it, with the escape. Fourteen undated deferrals is not an
  operator who wants indefiniteness fourteen times; it is a field nothing ever asked
  for. But that is a recommendation, not a decision.

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

### 2026-08-08T11:49:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2865-defer-decisions-are-structurally-undatea.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a40bda88
- **Timestamp:** 2026-08-08T12:02:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-08T12:01:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
