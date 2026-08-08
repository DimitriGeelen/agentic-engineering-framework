---
id: T-2879
name: "Capture-verb exemption covers bare verbs only — real invocation shapes still
  deadlock"
description: >
  Capture-verb exemption covers bare verbs only — real invocation shapes still deadlock

status: started-work
workflow_type: build
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
created: 2026-08-08T18:39:39Z
last_update: '2026-08-08T18:45:12Z'
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
  - ts: '2026-08-08T18:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T18:45:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2879: Capture-verb exemption covers bare verbs only — real invocation shapes still deadlock

## Context

T-2878 exempted the capture verbs from the Bash task gate and pinned it with a bats suite.
Both the fix and the suite used the **bare** verb form. The first real use of it — one minute
after closing T-2878, in the null-focus state T-2878 exists to serve — was BLOCKED.

The invocation was the shape an agent actually types:

    cd /opt/999-Agentic-Engineering-Framework
    bin/fw context add-learning "…" --task T-2878 2>&1 | tail -3
    echo "…"; grep '^current_task' .context/working/focus.yaml

**CORRECTED DIAGNOSIS — my first reading of this was wrong and the measurement says something
wider.** I assumed the `cd` prefix, the `| tail -3` or the trailing `echo`/`grep` was what
failed the compound, on the strength of 832 rail 470's pipeline bound. Measured:

| shape | verdict |
|---|---|
| `bin/fw note "x"` | ALLOWED |
| `bin/fw note "x" \| tail -3` | ALLOWED |
| `cd /opt && bin/fw note "x"` | ALLOWED |
| `bin/fw note "x"; echo done` | ALLOWED |
| `bin/fw note "x" 2>&1` | **GATED** |
| `bin/fw note "x" 2>&1 \| tail -3` | **GATED** |

The pipeline bound was not the cause. **`2>&1` alone is**, and it is not specific to the
capture verbs at all:

| `bin/fw doctor 2>&1` | GATED | `bin/fw doctor` | ALLOWED |
| `git status 2>&1` | GATED | `git status` | ALLOWED |
| `ls -la 2>&1` | GATED | `ls -la` | ALLOWED |
| `grep -n foo bar 2>&1` | GATED | `bin/fw doctor &` | ALLOWED |

**Root cause:** `_fw_chain_split` (safe-commands.sh:45) treats `&` as a chain separator
unconditionally. `bin/fw note "x" 2>&1` splits into `bin/fw note "x" 2>` and `1`. Segment 2
is the bare string `1`, which matches nothing in the allowlist, so the compound fails — the
splitter manufactures an unsafe segment out of a file-descriptor duplication. Verified:

    $ _fw_chain_split 'bin/fw note "x" 2>&1'
    bin/fw note "x" 2>
    1

So the entire safe-list is neutralised by the most common redirect idiom in the codebase.
The blast radius is concentrated exactly where the safe-list is load-bearing: it is only
consulted when there is no active task or the focus has drifted — i.e. the recovery states
where it is the one thing standing between the agent and a deadlock.

Direction is fail-CLOSED (blocks work, permits nothing). By 832 rail 473 §3's argument that
is not automatically the safe direction: a gate that refuses ordinary work trains the agent
to reach for a workaround, and the workarounds available here — drop the `2>&1`, prefix
`FW_SWITCH_FOCUS=1`, put it in a script — are respectively lossy, a logged bypass used for
a false positive, and outside Tier 0's reach entirely (T-2742).

**This is T-2876 IW-2 observed rather than argued.** IW-2 asks whether removing/limiting
safe-list entries relocates a deadlock instead of removing it; it was unmeasured on both
sides and 832 explicitly declined to press their one datapoint into service. Here the
relocation happened to a fix I wrote myself, one minute after shipping it, and the bats
suite stayed green throughout — because the suite tests the shape the fix was designed for.

Second finding, same session: **832 rail 474 §4 is only half-fixed here, and my rail answer
was wrong to say it does not reproduce.** T-2833 anchored drift pattern 3 (`git commit`) to
the `-m`/`--message` flag value. Pattern 2 (`fw context add-*` + `--task T-NNNN`) is still
two independent regexes ANDed, so any command carrying both tokens anywhere — including
inside quoted test payloads or prose — extracts a target that need not be the command's own.
Hit live while diagnosing this task. My earlier measurement missed it because I tested
`fw context add-learning` shapes WITHOUT a `--task` flag, which cannot trip pattern 2.

## Acceptance Criteria

### Agent
- [x] Measured: which compound shapes containing an exempt capture verb are GATED, recorded
      as a table (bare / `2>&1` / `| tail` / `cd &&` / trailing `; echo`), so the boundary is
      a fact rather than the one example that happened to be typed
- [ ] `_fw_chain_split` does not split on an `&` that is part of an fd duplication
      (`2>&1`, `>&2`, `2>&-`), and STILL splits on `&&`, on background `&`, and on `>& file`
      (which is a genuine write and must stay gated)
- [ ] Drift pattern 2 (`fw context add-*` + `--task`) is anchored to the flag value the same
      way T-2833 anchored pattern 3, OR the residual is documented in-file with its reason if
      bash regex cannot express the anchor
- [ ] Rail correction posted to 832: their 474 §4 reproduces on pattern 2, my "does not
      reproduce" was measured only against shapes that cannot trip it
- [ ] Regression coverage for the compound shape, with teeth by durable mutation of live
      source (not `git show HEAD~N:` — T-2874)
- [ ] T-2876 IW-2 updated with this as evidence: relocation is now OBSERVED, not projected,
      and the observation is on our own remedy

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

### 2026-08-08T18:39:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2879-capture-verb-exemption-covers-bare-verbs.md
- **Context:** Initial task creation
