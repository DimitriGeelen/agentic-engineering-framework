---
id: T-3067
name: "AEF cannot attribute its own chat-arc posts because .framework.yaml has no
  project_name"
description: >
  AEF cannot attribute its own chat-arc posts because .framework.yaml has no project_name

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
created: 2026-08-17T12:10:49Z
last_update: 2026-08-17T12:15:09Z
date_finished: 2026-08-17T12:15:09Z
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
  - ts: '2026-08-17T12:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3067: AEF cannot attribute its own chat-arc posts because .framework.yaml has no project_name

## Context

Found while replying to 832-Workflow-designer on `agent-chat-arc` — the reply
itself tripped it, which is how it was noticed at all:

```
warning: posting to agent-chat-arc without `from_project` —
co-resident agents may be indistinguishable.
```

`termlink agent post` / `agent reply` auto-resolve the poster's project from
`.framework.yaml::project_name`. Our `.framework.yaml` exists and is read — but it
has **no `project_name` key**. It holds `PROTECT_MASTER`, `INCEPTION_COMMIT_LIMIT`,
`NTFY_URL`, `RAIL_IDENTITY_FILE`, all uppercase, because that is the `fw_config`
convention (callers pass uppercase and `fw_config` greps the key verbatim — see the
comment at `.framework.yaml:9-14`). TermLink reads a **lowercase** key, so its
lookup finds nothing and every post this project makes goes out unattributed.

**This is the mechanism behind a finding already confirmed.** 832 reported that all
projects on this host are indistinguishable on the arc, and attributed it to a
shared identity fingerprint — which is true (`agent peers` returns exactly one,
`d1993c2c3ec44c94`, for 39 lifetime posts). But grouping by `from_project` *does*
separate them: 010-termlink 22, 0503-codex-cli-playground 8, 050-email-archive 5,
832-Workflow-designer 2 — and 999-AEF absent entirely. The absence was read as "AEF
has never posted". After this session it is both: AEF had never posted, *and* when
it finally did (offsets 41, 42) the posts carried no `from_project` and so would not
have appeared under AEF even then. Fixing the subscriber (T-3040) without fixing
this would have produced a project that talks and still cannot be found.

**Two things this task does not fix, named so the exclusion is not silent:**

- The warning misnames its own remedy. It says *"Pass `--metadata
  from_project=<id>`"*; there is no `--metadata` flag on either verb — the real one
  is `--project`. Passing the advertised flag produces a clap usage error, which is
  how I initially and wrongly concluded that `agent reply` had no attribution flag
  at all. This is the L-399 / T-1890 bypass-contract-parity class: a message naming
  a mechanism its consumer rejects. The fix is TermLink's, so per §Gap Homing it is
  filed there rather than described here.
- The single shared fingerprint is real and orthogonal. `from_project` is
  self-asserted metadata, not identity; it makes posts *attributable*, not
  *authenticated*. Anything that needs to trust a peer's claim about who it is
  still cannot.

## Acceptance Criteria

### Agent
- [x] `.framework.yaml` carries `project_name` such that TermLink's lookup resolves
      it, with a comment recording why the key is lowercase in a file whose other
      keys are uppercase — otherwise the next person to touch it will "fix" the
      inconsistency and silently re-break attribution.
- [x] `fw config` still parses the file and the existing uppercase keys still
      resolve — a lowercase addition must not disturb the verbatim-grep convention
      the file's own header documents.
- [x] A post from this project no longer emits the `without from_project` warning,
      demonstrated on a real post rather than argued from the config.
- [x] The post appears under this project in `termlink agent stats` grouping, which
      is the observable that was empty before.

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

python3 -c "import yaml; d=yaml.safe_load(open('.framework.yaml')); assert d['project_name']=='999-Agentic-Engineering-Framework', d.get('project_name')"
# The lowercase key must not have disturbed the verbatim-grep convention the rest
# of the file depends on. PROTECT_MASTER in particular arms the master-merge-only
# guard — a silent 0 here would disarm it.
test "$(bin/fw config get PROTECT_MASTER 2>/dev/null | tail -1)" = "1"
test -n "$(bin/fw config get NTFY_URL 2>/dev/null | tail -1)"
# The comment is load-bearing, not decorative: without it the case looks like a
# typo and gets "fixed", and the symptom of that is an absence.
grep -q "LOWERCASE ON PURPOSE" .framework.yaml

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** AEF never appeared in `termlink agent stats` grouping by project,
while four co-resident projects did. Read as "AEF has never posted" — which was
true, and was also not the whole reason.

**Root cause:** TermLink resolves the poster's project from
`.framework.yaml::project_name`, lowercase. Every key in our `.framework.yaml` is
uppercase, because `fw_config` greps keys verbatim and a lowercase key would never
be read by it (the file's own header says so). The two conventions are each
correct for their own reader and silently incompatible where they meet: the file
exists, is found, is parsed, and yields nothing for the key that was asked for.

**Why structurally allowed:** the failure mode is an **absence**. A wrong value
gets noticed because something misbehaves; a missing value produces a post that
succeeds, returns an offset, and simply is not counted under anyone. Nothing
prompts a check. The one surface that did fire — a stderr warning on every post —
misnamed its own remedy (`--metadata from_project=`, a flag that does not exist;
the real one is `--project`), so following the advice produced a usage error and
led me to the wrong conclusion that the verb had no attribution flag at all. A
warning that is right about the problem and wrong about the fix costs more than
silence, because it is followed.

**Prevention:** the comment above the key, pinned by a Verification grep. That is
deliberately modest and I would rather say so than overstate it: it prevents the
specific regression of someone normalising the case to match its neighbours. It
does not prevent the general class — a second consumer reading a differently-cased
key would fail the same way and equally silently. The general fix belongs to
whichever side owns the convention mismatch, and neither side owns both.

Two adjacent defects found in the same sequence are TermLink's, filed there per
§Gap Homing rather than described as ours:

1. The warning names `--metadata from_project=`; the flag is `--project`.
2. `agent reply` sets `metadata.in_reply_to` correctly but takes `--thread` from
   `focus.yaml::current_task`, so replying to a peer's post while focused on your
   own task files the reply under **your** thread. All three of this session's
   replies to 832 returned offsets and timestamps, and none appeared on
   `agent on-thread aef-upstream-findings-2026-08-16`. Sending confirmed three
   times; arrival at the surface a reader would look at, never once — L-602,
   which is already written down here and was still walked into, because the verb
   is called `reply` and behaves like post-with-a-backlink. Recovered by an
   explicit `agent post --thread <theirs>` (offset 44, verified present and
   attributed).

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

### 2026-08-17T12:10:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3067-aef-cannot-attribute-its-own-chat-arc-po.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3fa1a9a1
- **Timestamp:** 2026-08-17T12:15:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-17T12:15:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
