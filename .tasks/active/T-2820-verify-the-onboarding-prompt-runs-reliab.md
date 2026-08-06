---
id: T-2820
name: "verify the onboarding prompt runs reliably end-to-end on published bytes"
description: >
  verify the onboarding prompt runs reliably end-to-end on published bytes

status: started-work
workflow_type: test
owner: agent
horizon: now
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
created: 2026-08-06T06:26:05Z
last_update: '2026-08-06T06:30:12Z'
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
bvp_scores_proposed:
  - ts: '2026-08-06T06:30:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=1
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2820: verify the onboarding prompt runs reliably end-to-end on published bytes

## Context

The operator asked directly: *"CAN WE NOW RELIABLY RUN THE ONBOARDING PROMPT?"*

That is a question about a live surface, so it gets a live answer. Answering it from
"the fixes landed and the tests are green" would be the exact proxy-verification the
operator has already corrected once
([[feedback_verify_live_end_to_end_not_proxy]]) — commit ≠ visible ≠ done.

The run must use **published bytes** (what a consumer actually fetches), a **fresh
environment**, and an **agent driving it**, because the prompt's whole point is that
an agent performs the onboarding. Dispatched to a TermLink worker: independent
process, zero parent context, survives this session's budget.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The prompt text under test is located and quoted from source, not paraphrased
      from memory — the answer is about a specific artefact the operator fires.
- [x] It is executed in a **fresh directory** against **published bytes** (GitHub
      mirror confirmed in sync at `e492f4116`), not against this working tree.
- [x] The environment reproduces a consumer, including **no global git identity** —
      the condition that broke the by-hand path (T-2818) and the one most likely to
      be papered over by running as the framework developer.
- [x] The end state is inspected structurally: project initialised, hooks installed,
      onboarding tasks seeded, and a **governed commit actually lands** (RC=0).
- [x] The verdict distinguishes "the prompt completes" from "the prompt produces a
      working governed project" — those are different claims and only the second one
      answers the operator's question.
- [x] Any failure is reported as a failure, with its exit code, rather than narrated
      around ([[feedback_no_boisterous_overclaim]]) — see the nested-repo result and
      OBS-173.

## Findings

**The prompt under test** (one-step form, the shape the operator fires):

```
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh \
  | bash -s -- <dir> --provider claude
```

### Shape A — new standalone directory: RELIABLE

Run twice today on published bytes, `env -i`, isolated `HOME`, **no global git
identity** (T-2819 demo + this task):

| Check | Result |
|---|---|
| install + init | `RC=0` |
| post-install self-verification | 3/3 steps pass |
| onboarding tasks seeded | 5 (T-001…T-005) |
| commit with no task ref | **refused** by the gate (documented outcome) |
| `fw work-on "…"` | `RC=0`, created + focused T-006 |
| first governed commit | **`RC=0`** |

The identity blocker that used to end this path at `RC=128` is now stated in init's
closing block with a working command (T-2818, shipped today).

### Shape B — project created INSIDE an existing git repo: NOT reliable

`INSTALL_RC=0`, and the commit-msg gate **does** fire (`GATE_RC=1` — T-2812/2813's
fix is working). But every commit prints:

```
WARNING: SECRET SCAN IS NOT RUNNING — scanner missing:
  /tmp/onb-inrepo/outer/agents/git/lib/secret-scan.sh
```

Cause: git resolves hooks to the **outer** repo (`git rev-parse --git-path hooks`
→ `../.git/hooks`), so hooks install into `outer/.git/hooks` and compute
`PROJECT_ROOT=outer` — but the framework was vendored to `outer/inner/.agentic-framework`.
The hook looks for `$PROJECT_ROOT/.agentic-framework/…`, which does not exist.

Worse, the remedy it prints — `cd outer && .agentic-framework/bin/fw upgrade` —
**points at a path that does not exist**, so the operator cannot clear it.

This disables precisely the layer that caught the T-2817 credential leak. Filed as
**OBS-173**; not fixed here (one bug, one task).

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

# Shape A evidence is durable in the repo (the /tmp run dirs are not).
test -s docs/reports/arc-016-byhand-transcript-2026-08-06.log
grep -q 'COMMIT_RC=0' docs/reports/arc-016-byhand-transcript-2026-08-06.log
grep -q 'Ready to work on T-006' docs/reports/arc-016-byhand-transcript-2026-08-06.log
# Shape B is filed rather than silently absorbed.
grep -q 'OBS-173' .context/inbox.yaml
# The structural cause of Shape B, pinned so the claim is checkable from source:
# the pre-commit hook resolves the scanner under PROJECT_ROOT, which for a nested
# project is the OUTER repo, not the directory the framework was vendored into.
grep -q 'PROJECT_ROOT/.agentic-framework/agents/git/lib/secret-scan.sh' agents/git/lib/hooks.sh

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

**Recommendation:** GO — fire the onboarding prompt, **into a new standalone
directory**. Do not create the project inside an existing git repo until OBS-173 is
fixed.

**Rationale:** shape A is verified live twice today on published bytes, in the
consumer's conditions rather than the developer's — including the no-global-identity
state that was the actual blocker. It reaches a governed commit (`RC=0`), which is the
claim that matters; "the installer exits 0" is not the same claim and would have been
true before today's fixes too.

Shape B is a real, currently-live defect, and it is the quiet kind: the commit-msg
gate still fires, so the project looks governed, while the secret scan — the layer
that caught the credential leak in T-2817 — is off on every commit. It is loud in
stderr but its printed remedy names a nonexistent path, so an operator cannot act on
it.

**Evidence:** `docs/reports/arc-016-byhand-transcript-2026-08-06.log`;
this task's Findings table; OBS-173.

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

### 2026-08-06T06:26:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2820-verify-the-onboarding-prompt-runs-reliab.md
- **Context:** Initial task creation
