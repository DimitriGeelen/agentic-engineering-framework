---
id: T-2839
name: "fw upgrade turns a local upstream path into a bogus github URL"
description: >
  fw upgrade turns a local upstream path into a bogus github URL

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
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
created: 2026-08-06T21:15:21Z
last_update: 2026-08-06T21:26:33Z
date_finished: 2026-08-06T21:26:33Z
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
  - ts: '2026-08-06T21:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T21:30:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 5
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=5 (body:class-neutral); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2839: fw upgrade turns a local upstream path into a bogus github URL

## Context

Reported from a live by-hand onboarding run on a consumer project. `fw doctor`
reported a FAIL and prescribed `fw upgrade`. `fw upgrade` then died:

```
Upstream URL:  https://github.com//opt/agentic-engineering-framework.git
Resolved via:  .framework.yaml upstream_repo:
  Cloning... FAILED
    remote: Repository not found.
```

The project's `.framework.yaml` carried `upstream_repo: /opt/agentic-engineering-framework`
— an absolute local path, which `git clone` handles natively.

`lib/upgrade.sh:811-814` recognises `https?://`, `ssh://`, `git://`, `file://`
and `git@host:` as URLs and treats **everything else** as GitHub `owner/repo`
shorthand, expanding it to `https://github.com/<value>.git`. An absolute path
starts with `/`, matches no prefix, and gets GitHub glued onto a leading slash —
producing a double-slashed URL that can never resolve.

Two defects, one line:

1. **Local paths are misclassified.** `/abs/path`, `./rel`, `../rel`, `~/path`
   are all valid `git clone` sources and none is GitHub shorthand.
2. **The fallback is silently wrong rather than refusing.** "Not a URL I
   recognise" is treated as positive evidence of GitHub shorthand. The operator
   gets `Repository not found` from GitHub, which points at the wrong system
   entirely — the fault is in local config, and nothing in the error says so.

Defect 2 is the one that costs time: a wrong-but-plausible URL sends the reader
to GitHub to check permissions and repo names.

**Onboarding severity.** This is a dead end, not a detour: `fw doctor` FAILs,
prescribes `fw upgrade`, and `fw upgrade` cannot run. The consumer in question
was stale enough to predate T-2709, so its doctor FAIL was itself a false
positive that a working `fw upgrade` would have cleared. The one command that
would fix the install is the one that breaks.

Out of scope: the stale-consumer false FAIL (already fixed upstream by T-2709,
reaches consumers by upgrading), and whether `upstream_repo` should have been a
local path at all.

## Acceptance Criteria

### Agent
- [x] An `upstream_repo` beginning `/`, `./`, `../` or `~` is used verbatim as a
      clone source — never rewritten to a github.com URL.
- [x] A value that is neither a recognised URL, nor a local path, nor a strict
      `owner/repo` pair (exactly one slash, no leading/trailing slash, both
      segments non-empty) is **refused with a diagnostic naming the offending
      value and where it came from** — not silently expanded.
- [x] The refusal message states that the value came from `.framework.yaml`
      `upstream_repo:` (or the sentinel/flag that supplied it) so the reader
      looks at local config rather than at GitHub. It also says in words that
      this is local configuration and not a problem with any remote.
- [x] Regression test covers: absolute path, `./` relative, `~`, valid
      `owner/repo`, and a rejected malformed value —
      `tests/unit/t2839_upstream_source_classification.bats`, 7/7.
- [x] Existing `owner/repo` shorthand still expands to
      `https://github.com/owner/repo.git` — the T-1634 behaviour is preserved
      (pinned by test 4).
- [x] Classification is applied to **all three** resolution legs (`--from-upstream`,
      `.framework.yaml`, `.upstream` sentinel), not only the one that was
      reported. The rule differing by leg is how this stayed unnoticed.
- [x] `tests/unit/upgrade_fresh_machine_simulation.bats` stays green
      (CLAUDE.md §Consumer-Facing Command Hygiene).

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

bash -n lib/upgrade.sh
out=$(bats tests/unit/t2839_upstream_source_classification.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# CLAUDE.md §Consumer-Facing Command Hygiene — any fw upgrade change must keep this green.
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The origin defect, asserted directly on the shipped function rather than via a test helper.
bash -c 'source lib/upgrade.sh; r=$(_fw_classify_upstream_source "/opt/agentic-engineering-framework") && [ "$r" = "/opt/agentic-engineering-framework" ]'
bash -c 'source lib/upgrade.sh; ! _fw_classify_upstream_source "not a repo" >/dev/null'

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

**Symptom:** `fw upgrade` on a consumer died with
`remote: Repository not found` for
`https://github.com//opt/agentic-engineering-framework.git`, after `fw doctor`
had prescribed `fw upgrade` as the fix for a FAIL.

**Root cause:** `lib/upgrade.sh` classified `upstream_repo` by testing for a
fixed set of URL prefixes and treating the negative as proof of GitHub
`owner/repo` shorthand. An absolute local path matches no prefix, so it was
string-concatenated onto `https://github.com/`, producing a doubled slash.

**Why structurally allowed:** the classification was an inline two-line `if`
inside a 100+ line branch of `do_upgrade` that only executes on the
bare-from-consumer path. It had no direct test and no name. The else-branch was
reachable only by constructing a full consumer + bare invocation, so no unit
test ever exercised it and the fresh-machine simulation (which uses a `file://`
upstream — a *recognised* prefix) took the then-branch every time. The one
input class that breaks it is the one class the suite never supplied.

The deeper error is epistemic and is the reusable part: **the code treated "I
don't recognise this" as positive evidence for a specific alternative.** A
negative match narrows nothing on its own. The same shape produced T-2835
(unknown verb → assume it needs init) and T-2836 (verb absent from help →
assumed absent from the CLI). Refusing is the correct third branch, and it was
missing in all three.

**Prevention:** classification is extracted into `_fw_classify_upstream_source`
— named, directly testable, and applied to all three resolution legs — with a
7-case regression suite covering local paths, tilde, GitHub shorthand, every URL
scheme, and refusal. The unclassifiable branch now returns non-zero and prints
the offending value plus which leg supplied it, so the reader is sent to local
config rather than to GitHub.

**Not prevented:** nothing yet stops the next `fw upgrade` branch from growing
an untested inline classifier. The fresh-machine simulation still only exercises
`file://`. Widening it to a matrix of upstream shapes is the honest follow-on.

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

### 2026-08-06T21:15:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2839-fw-upgrade-turns-a-local-upstream-path-i.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-06d40acd
- **Timestamp:** 2026-08-06T21:33:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T21:26:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
