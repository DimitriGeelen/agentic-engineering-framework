---
id: T-2846
name: "Live e2e run of the fresh-install onboarding prompt on a greenfield project"
description: >
  Live e2e run of the fresh-install onboarding prompt on a greenfield project

status: work-completed
workflow_type: test
owner: agent
horizon:
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
created: 2026-08-07T05:05:13Z
last_update: '2026-08-16T22:25:20Z'
date_finished: 2026-08-07T05:19:27Z
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
  - ts: '2026-08-07T05:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T05:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2846: Live e2e run of the fresh-install onboarding prompt on a greenfield project

## Context

The operator has asked "can we now reliably run the onboarding prompt?" three times
across sessions. Each previous answer was assembled from *component* evidence — this
gate passes, that command exits 0, this consumer upgrades — never from executing
`prompts/aef-fresh-install-onboarding.md` start to finish against a project that did
not exist beforehand. Component evidence cannot answer a question about the whole,
because the failures that reach the operator live in the joins (T-2718–2725, T-2782,
T-2845 are all "each part was green, the assembly was not").

This task runs the prompt as written, in order, on a greenfield directory, and records
what an operator would actually see. It is a **measurement task**: the deliverable is
the transcript and the friction list, not a fix. Anything found gets its own task
(one bug, one task).

Scope fence: no edits to the framework under this task. Fixes are filed, not applied.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every STEP (1–6) of `prompts/aef-fresh-install-onboarding.md` executed in order
      against a directory that did not exist when the run began, with the real command
      output captured — not paraphrased, not reconstructed from a prior session
- [x] Each step recorded with an explicit verdict (CLEAN / FRICTION / BLOCKED) in the
      run log below, including the steps that passed — a friction list that omits the
      clean steps cannot show coverage
- [x] Watchtower identity verified per STEP 5's own warning: the serve log names the
      new project, not another project on this host (a bare `curl` 200 is explicitly
      NOT accepted as evidence)
- [x] Every friction item found is either filed as its own task or recorded in this
      task's Decisions with the reason it was not filed — no finding left only in prose
- [x] The standing question is answered in `## Recommendation` with a direct yes/no
      and the evidence it rests on

## Run Log — 2026-08-07

Target: `<scratchpad>/onb-t2846`, created by this run. Framework bytes: this repo at
`b0898618a` (== mirror master, so equivalent to what a genuinely fresh install pulls).
Commands scoped `env -u FRAMEWORK_ROOT -u PROJECT_ROOT` per the prompt's T-2795 note.

| Step | What it does | Verdict | Evidence |
|------|--------------|---------|----------|
| 1 | Prerequisites | CLEAN | bash 5.2.21, git 2.43.0, python3 3.12.3 — all above floor |
| 2 | Install / freshness | **FRICTION** | SHA comparison works exactly as designed: local `dfb967473` vs mirror master `b0898618a` → correctly reports "different SHA → [ASK]". But the step's own `ls -d ~/.agentic-framework /opt/*/FRAMEWORK.md` is **refused by the T-559 boundary hook** when onboarding runs from inside an existing AEF session. See F1. |
| 3 | `fw init --provider claude` | CLEAN | `44/45 checks OK (1 skipped)`, RC=0, bootstrap commit created. Both `[dogfood]` warnings the prompt tells the agent to expect are now **stale** — see F2. |
| 4a | `fw context init` | CLEAN | Session `S-2026-0807-0509`, 5 onboarding tasks, working memory written, RC=0 |
| 4b | `fw doctor` | CLEAN | **exit 0, 0 FAIL, 2 WARN — both non-project** (`[host]` 341MB global install; unsupervised-session, an artefact of not running under `claude-fw`) |
| 5 | `fw serve` + identity | CLEAN | HTTP 200 **and** serve log names the new project: `Starting Watchtower on port 3199 (project: …/onb-t2846)`. `fw watchtower url` → `http://192.168.10.107:3199`. Identity checked, not just reachability. |
| 6 | Guide into building | CLEAN | The promised "one rule" fires live: P-002 blocks a Write with no active task; T-532 blocks it with a *non-onboarding* task focused. |

### The operator's original failure list, re-measured

| Their 2026-08-06 paste | This run |
|------------------------|----------|
| `FAIL Hook exercise from /tmp: 15/15 hook(s) failed to resolve` | `OK — 15 hook(s) resolve` |
| `WARN Framework path ambiguity` | absent (T-2843) |
| `WARN Cron registry present but not generated` | absent (T-2844) |
| `WARN Global install … 340MB` | still present, `[host]`-scoped |
| `fw doctor` **exit 2** | **exit 0** |
| `fw upgrade` exit 1 (GitHub slug glued onto local path) | fixed T-2839, verified live prior session |

### arc-017 headline mechanic — demo evidence captured

Both clauses verified live on the greenfield project, not by reading code:

1. *"human curriculum readable but never blocking"* — with a non-onboarding task focused,
   the T-532 gate blocks and lists **T-001, T-003, T-004, T-005**. `T-002`
   (`owner: human`, `workflow_type: inception`, carries `### Human` ACs) is **absent from
   the block list** while remaining present and discoverable in `.tasks/active/`.
2. *"the framework refuses a newly-added agent-unresolvable task"* — writing a
   `tags: [onboarding]` + `owner: agent` + `workflow_type: inception` task is refused by
   `check-onboarding-gate` with `RC=2`, reason `inception-decide-blocked`, and a block
   message naming the three resolutions.

Shipped by T-2815; this run is the first end-to-end wire evidence of it on a project
created from scratch.

### Findings

- **F1 — prompt STEP 2's own command is refused by the T-559 boundary hook.** Filed T-2847.
- **F2 — prompt STEP 3's two `[dogfood]` notes are stale.** Filed T-2848.
- **F3 — greenfield consumer's first commit carries 1011 framework-internal files.** Filed T-2849.

## Recommendation

**Recommendation:** GO — yes, the onboarding prompt now runs reliably end to end.

**Rationale:** Every one of the six steps completed against a project that did not exist
when the run began. `fw doctor` exits **0** with zero project-scope warnings, where the
operator's 2026-08-06 run exited **2** with a FAIL and two project-scope WARNs. All four
of the defects that run exposed are fixed and re-measured here (T-2839, T-2843, T-2844,
T-2845 — plus T-2836 for `fw doctor` missing from `fw help`).

The honest qualifier: **reliable is not frictionless.** Three findings survive, none of
which stop an operator finishing onboarding:

- T-2847 — STEP 2's own command is refused when onboarding runs from inside an existing
  AEF session. The agent must work around the prompt to follow the prompt. This is the
  only finding that touches *reliability of the prompt as written*; it degrades to a
  manual workaround rather than a failure, which is why this is GO and not NO-GO.
- T-2848 — STEP 3 tells the agent to expect two failures that no longer occur. Stale
  workaround text invites an agent to "fix" a healthy install.
- T-2849 — the resulting project is 142MB with 1011 framework-internal files in its
  first commit. Cosmetic to correctness, material to the first impression.

**Evidence:**
- Run log table above — all six steps, with the real command output behind each verdict.
- Watchtower identity verified per STEP 5's explicit warning that a bare `curl` 200 is
  not evidence: serve log names `…/onb-t2846`.
- arc-017's headline mechanic demonstrated live on the greenfield project, both clauses.
- Evidence project retained at `<scratchpad>/onb-t2846` for inspection.

**What this does NOT establish:** the four agent-owned onboarding tasks (T-001, T-003,
T-004, T-005) were confirmed *present and correctly filed*, not *worked to completion*.
Whether an agent can actually clear them unaided is arc-017's keystone question (T-2720)
and remains open.

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

# All three findings were filed as their own tasks, not left in prose (AC 4).
ls .tasks/active/T-2847-*.md .tasks/active/T-2848-*.md .tasks/active/T-2849-*.md > /dev/null
# The run log records every step, including the ones that passed (AC 2).
out=$(cat .tasks/active/T-2846-live-e2e-run-of-the-fresh-install-onboar.md); echo "$out" | grep -q "Run Log"
# The standing question is answered with a direct verdict, not a hedge (AC 5).
out=$(cat .tasks/active/T-2846-live-e2e-run-of-the-fresh-install-onboar.md); echo "$out" | grep -q "Recommendation:. GO"
# The prompt this run exercised still exists at the path the run log names.
test -f prompts/aef-fresh-install-onboarding.md

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

### 2026-08-07T05:05:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2846-live-e2e-run-of-the-fresh-install-onboar.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61f9603b
- **Timestamp:** 2026-08-07T05:19:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `ls .tasks/active/T-2847-*.md .tasks/active/T-2848-*.md .tasks/active/T-2849-*.md > /dev/null`

### 2026-08-07T05:19:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
