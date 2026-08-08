---
id: T-2877
name: "arc-017 Half A: human onboarding curriculum, interleaved and ungated, routing
  to corpus maps"
description: >
  Build the human-facing onboarding curriculum for arc-017. Half B (the refusal invariant)
  shipped under T-2815 and was verified live under T-2720; this is the remaining half
  of the arc headline mechanic. Curriculum must sit ALONGSIDE the agent prologue,
  be readable but never gate agent work, and ROUTE to corpus maps (fw corpus explain
  / Watchtower /designer) rather than embedding content that will drift from them.

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-08-08T17:36:48Z
last_update: 2026-08-08T20:04:24Z
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
  - ts: '2026-08-08T17:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T17:45:11Z'
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

# T-2877: arc-017 Half A: human onboarding curriculum, interleaved and ungated, routing to corpus maps

## Context

arc-017 Half A. Half B (the refusal invariant, `check-onboarding-gate.py`) shipped under
T-2815 and was verified live under T-2720. This is the other half of the headline mechanic:

> a new operator finishes the agent prologue and immediately starts working their own first
> real task, **with the human curriculum sitting alongside and readable but never blocking
> them**

**What the "agent prologue" actually is:** the seeded onboarding set — `lib/seeds/tasks/`
`greenfield/` (T-001…T-005) and `existing-project/` (T-001…T-006), each carrying
`tags: [onboarding]`, `owner: agent`. `fw init` copies them into `.tasks/active/`. The T-532
block in `check-active-task.sh:571` refuses all non-onboarding work until every one reaches
`work-completed`. That set is agent-facing and stays exactly as it is — this task does not
touch a single acceptance criterion in it.

**The gap:** there is nothing for the *human* during that window. The operator watches an
agent work through five tasks whose bodies are written agent-to-agent, and learns the
framework by inference or not at all.

### Design — three constraints, taken from the arc description

1. **Interleaved, not adjacent.** A separate `docs/onboarding-for-humans.md` is a document
   nobody opens at the moment it would help. The curriculum goes *inside each seeded task*
   as a `## For the Operator` section, so it surfaces in Watchtower `/tasks/T-00N` at
   precisely the step the agent is on.
2. **Ungated, structurally — not by policy.** The section is prose with **zero checkbox
   markers**. P-010 counts `- [ ]`; `check-onboarding-gate.py` reads only the `### Human`
   subsection (`agents/context/check-onboarding-gate.py:62`, regex terminates at the next
   `##`). A `##`-level prose section is invisible to both. It cannot gate because there is
   nothing in it for a gate to read — not because a rule says it must not.
3. **Routes, never embeds.** Each section points at a promoted corpus map by id
   (`fw corpus explain <id>`, Watchtower `/designer`) instead of restating what the map
   says. Six promoted maps exist: `aef-task-lifecycle`, `aef-session-lifecycle`,
   `aef-inception-flow`, `aef-tier0-escalation`, `aef-audit-cron`, `aef-dispatch-loop`.
   Embedded prose drifts from the map silently; a dangling pointer is catchable, and AC 3
   catches it.

**Why the routing constraint is the load-bearing one:** CLAUDE.md already routes the task
lifecycle to `aef-task-lifecycle` rather than describing it twice. This applies the same
rule to the curriculum, which is the only reason it can be maintained by anyone other than
its author.

## Acceptance Criteria

### Agent
- [x] Every seeded onboarding task in **both** sets (`greenfield/` 5, `existing-project/` 6)
      carries a `## For the Operator` section: what the agent is doing at this step, why it
      matters to the human, and what the human can do meanwhile — written for someone who
      has never seen the framework
- [x] Zero checkbox markers (`- [ ]` / `- [x]`) inside any `## For the Operator` section,
      and each seeded task's total AC count is **unchanged** from before this task —
      asserted mechanically, so "ungated" is measured rather than asserted
- [x] Every corpus-map id named in the curriculum resolves to a real promoted map; no
      section restates map content instead of routing to it
- [x] `check-onboarding-gate.py` returns rc=0 for all 11 seeded tasks after the change (the
      curriculum must not make a seeded task refusable), and the T-532 block's behaviour is
      unchanged
- [x] The curriculum ships through `fw init` — verified by initialising a throwaway project
      in a sandbox and finding the sections in its `.tasks/active/`, not by reading
      `lib/seeds/`
- [x] Teeth by durable mutation of live source (T-2874): stripping a `## For the Operator`
      section, and pointing one at a non-existent map id, are each caught by the suite

## Measured Behaviour

`fw init` into a throwaway git repo, both inference modes:

| mode | seeded | carry `## For the Operator` | gate rc |
|---|---|---|---|
| greenfield (empty repo) | 5 | **5** | 0 for all |
| existing-project (has `src/`, README) | 6 | **6** | 0 for all |

AC counts per seeded task, before vs after: **identical in all 11** (4,3,4,4,3,3 /
4,5,3,4,3). The curriculum adds 145-217 words per task and zero acceptance criteria.

Routing targets in use — `aef-task-lifecycle`, `aef-session-lifecycle`,
`aef-inception-flow`, `aef-audit-cron`, plus Watchtower `/designer` and `/fabric`. All
resolve (`fw corpus explain <id>` rc=0); the bogus control `aef-deliberately-not-a-map`
returns rc=1, so the check distinguishes rather than merely accepting everything.

The onboarding gate's rc=0 across all 11 is backed by a **positive control**: an
agent-unresolvable onboarding fixture returns rc=2 from the same invocation. Without it,
eleven allows would be indistinguishable from an inert gate.

### Human
- [ ] [REVIEW] The curriculum reads well to someone who has never seen the framework
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (if not already running), then open the URL it prints
  2. Read the `## For the Operator` section on `/tasks/T-2877` first for the design intent, then read the eleven sections themselves at `lib/seeds/tasks/greenfield/T-001…T-005` and `lib/seeds/tasks/existing-project/T-001…T-006`
  3. Read each set in order, as a first-time operator meets them — one per onboarding step
  **Expected:** each section answers *what is happening*, *why it matters to me*, and *what I can do*, without assuming prior framework knowledge; the sequence builds rather than repeats; nowhere does it read as instructions the operator must follow
  **If not:** name the section and which of the three questions it fails to answer — the prose is the deliverable, and rewriting it is cheap

  *Why [REVIEW] and not [REVIEWER]:* the question is whether prose reads well to a newcomer.
  The static scanner does not read for tone or clarity (L-409, T-1947), and the audience is
  explicitly the operator rather than an agent (T-2143), so Agent-AC self-eval does not apply
  either. Everything mechanically checkable about this curriculum is already an Agent AC above.

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

out=$(bats tests/unit/onboarding_curriculum_ungated.bats 2>&1); echo "$out" | grep -q '^ok 10 ' && ! echo "$out" | grep -q '^not ok'
# The refusal invariant (Half B) must still hold with the curriculum in place.
out=$(bats tests/unit/onboarding_gate_arc_tag_fp.bats tests/unit/check_onboarding_gate.bats 2>&1); echo "$out" | grep -q '^ok ' && ! echo "$out" | grep -q '^not ok'
# All 11 seeded tasks carry the section.
[ "$(grep -l '^## For the Operator' lib/seeds/tasks/*/T-*.md | wc -l)" -eq 11 ]
# Zero checkboxes inside any operator section — this is what makes it ungated.
python3 -c "import re,glob,sys; bad=[f for f in glob.glob('lib/seeds/tasks/*/T-*.md') for m in [re.search(r'^## For the Operator\s*$\n(.*?)(?=^## )', open(f).read(), re.S|re.M)] if m and re.search(r'^\s*[-*]\s*\[[ xX]\]', m.group(1), re.M)]; sys.exit(1 if bad else 0)"
# Every corpus-map id named in the curriculum resolves.
for m in $(grep -ho 'fw corpus explain [a-z0-9-]*' lib/seeds/tasks/*/T-*.md | awk '{print $4}' | sort -u); do bin/fw corpus explain "$m" >/dev/null 2>&1 || exit 1; done
# Vendored parity — .agentic-framework/ is what a consumer's fw executes (T-2240).
for f in lib/seeds/tasks/*/T-*.md; do diff -q "$f" ".agentic-framework/$f" >/dev/null || exit 1; done

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

**Recommendation:** GO — Half A is built; one Human AC (prose quality) remains.

**Rationale:** all six Agent ACs are ticked and independently measured. The curriculum
exists in both seed sets, ships through `fw init` in both inference modes (verified by
initialising throwaway projects, not by reading `lib/seeds/`), adds zero acceptance
criteria, and every routing target resolves. The only thing left is whether the prose
reads well to a newcomer, which is exactly the judgement a static scan cannot make.

**Evidence:**
- `tests/unit/onboarding_curriculum_ungated.bats` — 10/10, incl. mutation teeth and a
  positive control proving the onboarding gate is live rather than inert
- `fw init` sandboxes: 5/5 greenfield, 6/6 existing-project carry the section
- AC counts per seeded task identical before and after (4,3,4,4,3,3 / 4,5,3,4,3)
- Routing ids all resolve; bogus control `aef-deliberately-not-a-map` returns rc=1
- T-2881 shipped en route — arc-017's Half B invariant was refusing arc-017's own Half A
  task; 12/12 assertions, both call sites fixed together

**What this does NOT close:** the arc keystone T-2720. Half A shipping is not the same as
the headline mechanic firing end-to-end — that needs an operator actually finishing the
prologue with the curriculum alongside. Closing arc-017 on "both halves built" would be the
substrate-vs-deliverable conflation §ACD exists to catch. T-2720 stays open.

## Evolution

### 2026-08-08 — the invariant refused the task that was building its other half

- **What changed:** arc-017's Half B (`check-onboarding-gate.py`, T-2815) refused the edit
  adding a `### Human` AC to T-2877 — Half A's own build task. Root cause was a tag-matching
  conflation: `\bonboarding\b` matches inside `arc:onboarding-curriculum`, because `:` and
  `-` are both non-word characters. Arc membership was being read as membership of the
  T-532 gated set. Not known at filing, and not findable by reading the arc — only by
  working inside it.
- **Plan impact:** none to the curriculum design; the three constraints held unchanged. But
  it forced a detour, and the detour was not optional: the documented override is an env-var
  prefix while the refusal fires on the Write/Edit tool, so there was no agent-reachable way
  through that did not involve corrupting the task's own metadata (mislabel `owner: human`,
  or strip the arc tag) to satisfy a check that was wrong.
- **Triggered:** T-2881 (filed, fixed, closed — 12 assertions, both call sites per L-399).
  Also surfaced that the scan-side twin in `check-active-task.sh` was latent here only
  because `.onboarding-complete` short-circuits the block; in a fresh project it fires.

### 2026-08-08 — "it exists in lib/seeds" is not "it ships"

- **What changed:** AC 5 was deliberately written as *verified by initialising a throwaway
  project, not by reading `lib/seeds/`*. That wording earned itself immediately — the first
  sandbox produced 0/5 tasks carrying the curriculum, and reading the source would have
  reported the work complete.
- **Plan impact:** none, but two false diagnoses were reached and discarded before the real
  one. First a stale vendored `.agentic-framework/` (re-vendored; still 0/5). Then a stale
  *global* framework, which fit the evidence well enough to be worth filing — the init log
  falsified it. The actual cause was the harness: the sandbox was nested inside the
  scratchpad, which already contained an `.agentic-framework/` from an earlier session, so
  `fw init` walked up, saw a consumer project, and vendored from that.
- **Triggered:** nothing filed — it was my test setup, not a framework defect. Recorded
  because the near-miss is the point: a plausible mechanism that fits the evidence is not a
  diagnosis, and the log was the only thing that distinguished them.

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

### 2026-08-08T17:36:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2877-arc-017-half-a-human-onboarding-curricul.md
- **Context:** Initial task creation

### 2026-08-08T17:37:47Z — status-update [task-update-agent]
- **Change:** tags: +arc:onboarding-curriculum

### 2026-08-08T19:29:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
