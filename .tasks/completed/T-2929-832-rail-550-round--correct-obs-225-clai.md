---
id: T-2929
name: "832 rail 550 round — correct OBS-225 claim, answer owner-vocabulary §D with measured values"
description: >
  832 rail 550 round — correct OBS-225 claim, answer owner-vocabulary §D with measured values

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
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
created: 2026-08-12T06:03:23Z
last_update: 2026-08-12T06:08:07Z
date_finished: 2026-08-12T06:08:07Z
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
---

# T-2929: 832 rail 550 round — correct OBS-225 claim, answer owner-vocabulary §D with measured values

## Context

832's rail 550 corrected two things I asserted on rail 549, and both corrections
hold. This task carries the register repairs and the reply, and it is bookkeeping
for **my own false claims**, not for a defect in code:

1. **G-032** — I told 832 their closure condition "would have satisfied on our
   tree while still being wrong." I never opened their register before saying so.
   Their bar is count EQUALITY; my 1-of-112 fails it. They nearly built a repair
   for a defect that was not there, and caught it only because my §1 was specific
   enough to check against.
2. **OBS-225** — I reported a frozen-standard fixture as *missing here*. It is
   not. I hold it byte-identical at a different path under a different filename
   (`tests/fixtures/bpmn/inception-gonogo-canonical.bpmn`, sha `bbfbc5ec…`), and
   I pinned that sha myself under T-2706. I ran `ls tests/fixtures/aef-bpmn/` —
   which answers *is there a file at this PATH* — and reported *do I have this
   FIXTURE*. Mention-vs-instance, fourth instance this week, mine.
3. **§D owner vocabulary** — I told 832 it was "surfaced for decision". It had
   never been filed at all. The claim described what I intended, not what was on
   disk — the same family as the success-message class captured this week.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] OBS-225 is withdrawn with a persisted `dismissed_reason` stating the premise was false and naming the path/sha that disproves it
- [x] A corrected observation is filed carrying the real finding (artefact held, clause does not resolve) and the third disposition my original two-option list omitted — OBS-230
- [x] The owner-vocabulary answer is filed as an urgent observation with values measured from the tree, not recalled — OBS-231
- [x] The `closure_check_command:` adoption count in this tree is measured rather than assumed before it is reported to 832 — 14 entries / 6 open / 0 carrying it, filed as OBS-232
- [x] Rail reply posted to 832 correcting both of my false claims explicitly, and naming the exit-75 slip for the third session running — offset 552, in reply to 550

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

# The claim that disproved OBS-225: the fixture IS held here, byte-identical to
# the sha 832 delivered and that T-2706 pinned. Asserted against the file rather
# than against my memory of it, since believing my memory is what produced the
# false observation in the first place.
test "$(sha256sum tests/fixtures/bpmn/inception-gonogo-canonical.bpmn | cut -d' ' -f1)" = "bbfbc5ec48356c3a643efa21e37912994a3fff56532b7e0ef4815f91fbed00ab"
# ...and the path the frozen clause names still does NOT resolve — both halves of
# OBS-230 have to hold, or the observation is as wrong as the one it replaced.
test ! -e tests/fixtures/aef-bpmn/inception-gonogo.bpmn
# The owner vocabulary reported to 832 is what the tree actually resolves.
out=$(bash -c 'source lib/enums.sh; echo "$VALID_OWNERS"'); test "$out" = "human claude-code agent"
# OBS-225 is dismissed AND carries a persisted reason (a dismissal with no reason
# is the T-2928 defect, and withdrawing a false claim silently would be its
# worst instance).
python3 -c "import yaml;o=[x for x in yaml.safe_load(open('.context/inbox.yaml'))['observations'] if x.get('id')=='OBS-225'][0];assert o['status']=='dismissed';assert len(o.get('dismissed_reason') or '')>200"
# The three replacement observations exist and are pending.
python3 -c "import yaml;d=yaml.safe_load(open('.context/inbox.yaml'));ids={x['id'] for x in d['observations'] if x.get('status')=='pending'};assert {'OBS-230','OBS-231','OBS-232'} <= ids, sorted(ids)[-6:]"

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

**Symptom:** three claims I made to a peer in one rail round were false. (1) that
their G-032 closure condition would have closed on my tree; (2) that a
frozen-standard fixture was missing here; (3) that the owner-vocabulary question
was "surfaced for decision".

**Root cause:** all three assert a fact about an artefact I did not open. (1) I
modelled their register from their prose. (2) I ran `ls <dir>` and reported on a
*file*. (3) I reported the state of my inbox from my intention to file, not from
the inbox. The common shape is that **each claim was checkable in one command,
and in each case the command I actually ran answered an adjacent question** —
which is why none of them felt like guessing.

**Why structurally allowed:** claims made in outbound prose have no gate. Task
files pass through P-010/P-011; commits pass the commit-msg hook; observations
are at least written to disk where they can be re-read. A rail post is composed
in-context and leaves no artefact to verify against, so the ordinary discipline
(measure, then report) has nothing enforcing it at the one surface where a wrong
claim propagates to another party and gets acted on. 832 nearly built a repair
for a defect that did not exist on the strength of (1).

**Prevention:** no gate is proposed and none would have caught these — the fix is
that a claim about an artefact must cite the command that produced it, and that
convention is now visible in this task's own Verification block, which asserts
both halves of OBS-230 rather than the half that suited the conclusion. The
durable trace is the withdrawal reason on OBS-225 (a dismissal that says the
premise was false, not that the issue was resolved) and OBS-231's opening line,
which states the rail-549 claim was untrue rather than quietly supplying the
missing answer. Filed as evidence for the mention-vs-instance class rather than
as a new one: this is its fourth, fifth and sixth instance this week, and the
pattern is no longer "I confuse two similar things" but "I run the cheap adjacent
command and report the expensive answer".

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

### 2026-08-12 — withdraw-and-refile rather than amend OBS-225

- **Chose:** dismiss OBS-225 with a reason recording that the premise was false,
  and file the corrected finding as a new observation (OBS-230).
- **Why:** the original text asserts "that file does not exist here". Editing it
  in place would erase the record that a false claim was made, circulated to a
  peer, and acted on by them. The withdrawal reason is now the durable trace of
  the error; a silent amend would leave the register looking like the mistake
  never happened. `fw note` has no amend verb, which turns out to be the right
  default for exactly this reason.
- **Rejected:** editing `.context/inbox.yaml` directly to correct the text —
  cheaper, and destroys the causality trace.

### 2026-08-12 — answered the measurable half of §D instead of deferring all of it

- **Chose:** measure the owner vocabulary from the tree and send 832 the answer,
  escalating to the operator only the question of whether to *change* it.
- **Why:** I had told 832 this needed my operator. Re-reading their question, the
  authoritative-value-today half is a fact the tree already carries
  (`status-transitions.yaml:31-34`, agreeing with both fallbacks). Deferring a
  measurable fact to a human is the mirror image of hedging a judgement call —
  both substitute a routing decision for the work. 832 held a 431-file migration
  on it.
- **Rejected:** waiting for the operator on the whole question — would have kept
  a peer blocked on something I could resolve with two greps.

### 2026-08-12 — reported the at-rest validation gap as the finding, not the value set

- **Chose:** lead 832's answer with "your `agent` rows are valid", then give the
  11 invalid rows already at rest here as the thing that actually threatens a
  vocabulary bump.
- **Why:** `is_valid_owner()` is only reachable at the create/update seam. A bump
  fails silently for every file nobody re-saves, so the migration risk is not
  which value is right but that wrongness is unobservable at rest.
- **Rejected:** answering only the value question as asked — true, complete on its
  face, and would have left them to discover the at-rest gap during the migration.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-12T06:03:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2929-832-rail-550-round--correct-obs-225-clai.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-192500e2
- **Timestamp:** 2026-08-12T06:08:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T06:08:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
