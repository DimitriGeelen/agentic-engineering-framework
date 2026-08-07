---
id: T-2851
name: "greenfield audit WARNs on fw init's own root commit — T-000 references a task
  that cannot exist"
description: >
  greenfield audit WARNs on fw init's own root commit — T-000 references a task that
  cannot exist

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, lib/traceability.sh, tests/unit/audit_root_commit_traceability.bats]
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
created: 2026-08-07T06:09:42Z
last_update: 2026-08-07T06:16:52Z
date_finished: 2026-08-07T06:16:52Z
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
  - ts: '2026-08-07T06:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T06:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2851: greenfield audit WARNs on fw init's own root commit — T-000 references a task that cannot exist

## Context

`fw init` ends by creating a bootstrap commit so the new project has a resolvable
HEAD over a non-empty tree (`lib/init.sh:742`, the T-2821/T-2827 fix). Its subject
is `T-000: fw init bootstrap commit (…)`. `T-000` is the framework's own
established placeholder for "no real task applies" — `agents/handover/handover.sh:57`
uses the same sentinel — and it exists to satisfy the commit-msg hook, which only
requires the subject to match `T-[0-9]+`.

The audit's traceability check (`agents/audit/audit.sh:2222-2245`) applies a
*different* predicate to the same string: every `T-NNNN` found in a commit subject
must resolve to a file in `.tasks/`. `T-000` never resolves, because no such task
is ever created — by design.

Net effect: **every project `fw init` creates fails its own traceability audit at
its very first commit**, on day zero, before the operator has done anything.
Reported from the live `/opt/001-test-install` onboarding run:
`[WARN] Commit d0a3a22 references non-existent task T-000`.

Same family as T-2740 (greenfield seed drift — a fresh project failing its own
`fw audit`) and the T-2843/T-2844/T-2845 trio: the finding is an artefact of the
CHECKER's assumptions, not a fault in the project being checked.

## Acceptance Criteria

### Agent
- [x] The traceability check exempts commits with **no parent** (root commits), not
      the literal string `T-000`. Scoping to the root commit is what keeps this from
      becoming a general escape hatch: a history has exactly one root commit and it
      predates every task by construction, whereas exempting `T-000` by name would
      let any commit opt out of P-002 traceability by using the sentinel.
      → `lib/traceability.sh:trace_is_root_commit`, wired at `agents/audit/audit.sh`.
- [x] A root commit referencing a non-existent task produces **no** WARN.
      → Measured before/after on the same fixture (`/tmp/tmp.UAIDUZUX0J`, root commit
      `28c9ed5`, subject `T-000: fw init bootstrap commit …`), same `--section
      traceability` invocation:
      - pre-fix audit (`git show HEAD:agents/audit/audit.sh`):
        `[WARN] Commit 28c9ed5 references non-existent task T-000`
      - current audit: `[PASS] All commit task refs resolve to actual tasks`
      This is the operator's reported WARN reproduced and then eliminated, not a
      fixture that merely happens to pass.
- [x] Negative control: a **non-root** commit referencing a non-existent task still
      produces a WARN. Without this, a fix that disabled the check entirely would
      pass the AC above.
      → `tests/unit/audit_root_commit_traceability.bats` tests 3 and 6.
- [x] Regression test `tests/unit/audit_root_commit_traceability.bats` covers both
      directions above and is green. → 6/6 ok, EXIT=0.

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

bash -n agents/audit/audit.sh
out=$(bats tests/unit/audit_root_commit_traceability.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
grep -q 'source "$FRAMEWORK_ROOT/lib/traceability.sh"' agents/audit/audit.sh
grep -q 'trace_is_root_commit "$PROJECT_ROOT" "$commit_sha"' agents/audit/audit.sh
out=$(bin/fw audit --section traceability 2>&1); echo "$out" | grep -q "All commit task refs resolve to actual tasks"

## RCA

**Symptom:** a brand-new project created by `fw init` fails its own traceability
audit at its very first commit — `[WARN] Commit d0a3a22 references non-existent
task T-000` — before the operator has taken any action. Observed live on
`/opt/001-test-install`, 2026-08-07.

**Root cause:** two gates apply two *different* predicates to the same string.
The commit-msg hook requires the subject to **match** `T-[0-9]+`; the audit's
traceability check requires every `T-NNNN` it finds to **resolve** to a file in
`.tasks/`. `fw init`'s bootstrap commit was designed against the first predicate
(`T-000` is the framework's own "no real task applies" sentinel, shared with
`agents/handover/handover.sh:57`) and was never checked against the second. There
is no task file for `T-000` and there is not meant to be one.

**Why structurally allowed:** the bootstrap commit was added by T-2821/T-2827 to
fix a *different* day-zero defect (unresolvable HEAD → empty worktree). Its
verification asked "does the commit succeed and pass the hooks?" — which it does.
Nothing asked the adjacent question, "what does `fw audit` say about the project
this just produced?" The two checks live in different subsystems and no test ran
`fw init` and `fw audit` back to back, so a check-vs-check disagreement was
invisible to both. Same shape as T-2843/T-2844/T-2845: the finding was an artefact
of the CHECKER's assumptions, not a fault in the project being checked.

**Prevention:** `tests/unit/audit_root_commit_traceability.bats` pins both
directions — the root commit is exempt, a non-root commit referencing a missing
task still WARNs — plus a wiring assertion that the audit actually sources and
calls the predicate (a correct lib nothing invokes is the T-2845 shape: green
tests, zero change live).

**Caught during the fix, worth recording:** the first draft of the predicate was
**exactly inverted** and its unit tests would have looked partially green. It used
`git rev-list --parents -n 1 <sha> | cut -d' ' -f2-`, on the assumption that cut
emits an empty field when the line has no delimiter. It does not — cut passes a
delimiter-less line through *unchanged*. So a root commit's lone sha came back
non-empty and read as "has parents", while an unresolvable sha produced empty
output and read as "is root". Had that shipped, the audit would have kept warning
about the bootstrap commit while *silently stopping* warning about genuinely
dangling refs — a strictly worse outcome than the bug being fixed. The negative
control (test 3) is what caught it on the first run.

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

### 2026-08-07T06:09:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2851-greenfield-audit-warns-on-fw-inits-own-r.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-89a17cba
- **Timestamp:** 2026-08-07T06:18:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-07T06:16:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
