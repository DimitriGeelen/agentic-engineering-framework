---
id: T-2941
name: "Rehearse the arc-017 operator trial before handing over its [REVIEW] ACs"
description: >
  Rehearse the arc-017 operator trial before handing over its [REVIEW] ACs

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: [arc:onboarding-curriculum]
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
created: 2026-08-12T12:06:13Z
last_update: '2026-08-16T22:25:24Z'
date_finished: 2026-08-12T12:13:11Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2941: Rehearse the arc-017 operator trial before handing over its [REVIEW] ACs

## Context

T-2720 (arc-017 keystone) is agent-complete and carries two `[REVIEW]` ACs that only the
operator can tick. Both prescribe Steps the operator is expected to execute — AC #1 dumps
eleven `## For the Operator` sections through `sed`/`less`, AC #2 runs `fw init` into a
fresh project and works the seeded tasks in order.

**Nobody has run either.** They were authored from the tree, not from a walk.

This session already found two `[REVIEW]`s (T-2904, T-2905) handed to the operator against
a Watchtower that was six days stale — a verdict taken against a broken substrate looks
like evidence and is worse than no verdict. Handing over a third review whose Steps have
never been executed is the same class, one substrate over. T-358 states the rule directly:
Steps must start from the operator's actual environment, not the agent's.

Scope fence: this task rehearses the **mechanical** half — do the commands run, do the
files exist, does the sequence hold. It does **not** judge the prose. That judgment is the
whole point of the `[REVIEW]` and stays with the operator; nothing here ticks T-2720.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC #1's Steps command runs end-to-end and emits all eleven `## For the Operator`
      sections — the seed set is 5 greenfield + 6 existing-project, and the AC says
      "eleven", so a count mismatch is itself a finding
- [x] AC #2 step 1 (`fw init` into a fresh git repo) completes and seeds `.tasks/active/`
      with the curriculum tasks in readable order
- [x] The two structural claims in AC #1's **Expected** are checked mechanically, so the
      operator's read is reduced to taste alone: (a) no section asks the operator to tick,
      approve or decide anything; (b) sections route to corpus maps rather than restating
      them
- [x] Every finding is recorded with what the operator would have hit, or the rehearsal
      reports explicitly that the path is clean — a rehearsal that cannot fail is not one

## Findings

### F1 — every corpus route in the curriculum is dead in a consumer (BLOCKING, → T-2942)

The curriculum's central design decision, stated in arc-017's own description, is
*"routes to corpus maps rather than embedding content"*. The eleven sections carry **10
`fw corpus explain` invocations across 4 maps** (`aef-task-lifecycle` ×4,
`aef-session-lifecycle` ×4, `aef-audit-cron`, `aef-inception-flow`).

All ten fail for the newcomer. Measured, both sides:

    framework repo   bin/fw corpus explain aef-task-lifecycle          → OK, 73 lines
    fresh consumer   .agentic-framework/bin/fw corpus explain <any>    → rc=2, 4/4

    python3: can't open file '<proj>/.agentic-framework/tools/corpus_explain.py'

Cause: **`tools/` is not vendored, and neither is the corpus store.** A fresh
`.agentic-framework/` contains `agents bin docs lib policy web` + `FRAMEWORK.md
metrics.sh status-transitions.yaml VERSION`. `lib/upgrade.sh` defines exactly six
`_self_vendor_*` helpers — `libs`, `templates`, `policy`, `shim`, `agents`, `web` — and
there is no `_self_vendor_tools`. The reader was never in the vendor set, so this has
never worked in any consumer, not since some regression.

Why it stayed invisible: the routes resolve perfectly **here**, in the framework repo,
which is the only place they were ever exercised. Same shape as the two findings this
session already produced — the four `agents/context/` scripts that look like live hooks
and are wired to nothing (OBS-234), and the Watchtower that answered every liveness probe
while serving deleted bytes (T-2938). *The artefact that certifies is not the artefact
that runs.* Here the split is by **repository**: authored in the tree that can satisfy it,
consumed in the tree that cannot.

This is why the rehearsal was worth doing. Half A shipped 2026-08-08 and its defining
mechanic has been inert in every consumer since — and AC #1 would not have caught it,
because it asks the operator to *read* the sections, and they read correctly.

### F2 — the prescribed trial exercises 5 of the 11 sections (scope mismatch)

AC #1 asks the operator to read **eleven** sections. AC #2's Steps start from
`mkdir` + `git init` + `fw init`, and `lib/init.sh:600-613` positively establishes
greenfield from an empty directory — so the trial seeds the **greenfield 5** only
(`T-001`…`T-005`, confirmed on disk). The six existing-project sections are unreachable
by the prescribed path; they need an init over a directory that already contains code.

Not a curriculum defect — a gap between the two ACs' Steps. The operator can still judge
all eleven by reading (AC #1), but only five are validated by walking (AC #2). Worth a
second trial arm rather than a rewrite; recorded here so the operator knows the coverage
boundary of their own review rather than discovering it midway.

### F3 — clean: no section gates the operator, and routing is real routing

Both structural claims in AC #1's **Expected** hold mechanically:

- **Nothing asks the operator to tick, approve, or decide.** Zero matches for unticked
  checkboxes or approve/sign-off/decide language across all 237 lines. The "readable
  past, not a gate" property is real.
- **Sections route rather than restate** — 10 route invocations, no map content
  duplicated inline.

Stated positively because a rehearsal that only reports problems hides which parts of the
operator's review are already de-risked. F3 is the half of AC #1 the operator can now skip.

### What this does NOT do

It does not tick anything on T-2720. Whether the prose *reads well to a newcomer* is
exactly the judgment the `[REVIEW]` exists for, and no amount of mechanical checking
substitutes for it. F1 is a prerequisite the operator would otherwise have hit at their
first `fw corpus explain`; F3 narrows what is left to taste.

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

# F1 — the curriculum routes to corpus maps, so the routes must exist to route TO.
# Pins the count, not just presence: a section silently losing its route would
# still pass a >0 check.
test "$(grep -ho 'fw corpus explain [a-z-]*' lib/seeds/tasks/greenfield/T-00*.md lib/seeds/tasks/existing-project/T-00*.md | wc -l)" -ge 10

# F1 — every routed map id resolves HERE. The consumer-side failure is the defect
# (OBS-235, T-2942); this line guards the half that is supposed to work.
for id in aef-task-lifecycle aef-session-lifecycle aef-audit-cron aef-inception-flow; do bin/fw corpus explain "$id" > /tmp/.t2941-ce.out 2>&1 || exit 1; done

# AC #1 — eleven sections, and the AC text says eleven. Guards both directions:
# a seed file added without an operator section, and a section added without a seed.
test "$(grep -l '^## For the Operator' lib/seeds/tasks/greenfield/T-00*.md lib/seeds/tasks/existing-project/T-00*.md | wc -l)" -eq 11

# F3 — the curriculum must stay readable-past, never a gate. An unticked checkbox
# or approval language appearing in a For-the-Operator section breaks the property
# the arc's headline mechanic depends on.
for f in lib/seeds/tasks/greenfield/T-00*.md lib/seeds/tasks/existing-project/T-00*.md; do sed -n '/^## For the Operator/,/^## Acceptance/p' "$f" | grep -qiE '^- \[ \]|sign off|you must (approve|decide)' && exit 1; done; true

# The finding is registered, not just narrated in a task body that will archive.
grep -q 'OBS-235' .context/inbox.yaml

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

### 2026-08-12 — arc-017 is further from its mechanic than "both halves built" suggested

- **What changed:** T-2720 records both halves shipped and stays open only on operator
  judgment. That reading was right about the gate and wrong about the substrate. Half A's
  defining property — *route to corpus maps rather than embed content* — does not work
  anywhere it is consumed, because `tools/` has never been in the vendor set. The
  curriculum is not thin; it points at a reader that isn't shipped.
- **Plan impact:** the arc's closure condition is unchanged (an operator walking the
  mechanic), but the walk cannot succeed today. F1 is a prerequisite of the `[REVIEW]`,
  not a follow-up to it — handing over the review before fixing it would spend the
  operator's attention on a path that breaks at the first routed command.
- **Triggered:** OBS-235 (urgent) and T-2942 (the vendor fix). F2 recorded as a coverage
  boundary on the review rather than a defect — the trial validates 5 of 11 sections, and
  the operator should know that going in.
- **Method note worth keeping:** this was found by *executing* a Human AC's Steps rather
  than reading them. Every mechanical claim in AC #1 held; the failure was one layer below,
  in a command the AC never runs. Rehearsing the operator's path is a different act from
  reviewing the artefact the path leads to.

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

### 2026-08-12T12:06:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2941-rehearse-the-arc-017-operator-trial-befo.md
- **Context:** Initial task creation

### 2026-08-12T12:12:45Z — status-update [task-update-agent]
- **Change:** tags: +arc:onboarding-curriculum

## Reviewer Verdict (v1.5)

- **Scan ID:** R-be5336c0
- **Timestamp:** 2026-08-12T12:13:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 82
     - evidence: `for f in lib/seeds/tasks/greenfield/T-00*.md lib/seeds/tasks/existing-project/T-00*.md; do sed -n '/^## For the Operator/,/^## Acceptance/p' "$f" | grep -qiE '^- \[ \]|sign off|you must (approve|decid`

### 2026-08-12T12:13:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
