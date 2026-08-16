---
id: T-2867
name: "fw note silently discards the observation when a sub-verb is typed: 26 lost
  notes"
description: >
  fw note silently discards the observation when a sub-verb is typed: 26 lost notes

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/observe/observe.sh, tests/unit/note_capture_guard.bats]
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
created: 2026-08-08T12:19:03Z
last_update: '2026-08-16T22:25:21Z'
date_finished: 2026-08-08T12:25:52Z
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
  - ts: '2026-08-16T22:25:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2867: fw note silently discards the observation when a sub-verb is typed: 26 lost notes

## Context

`fw note add "a real observation"` captures the word **`add`** and throws the
observation away. Silently, exit 0, with a success message quoting the word it kept.

Found by tripping it: `fw note show OBS-190` created OBS-194 whose entire text is
`show`. That prompted a corpus count rather than a shrug.

**Measured: 26 of 191 observations (13.6%) are bare sub-verbs** — `add` ×16,
`resolve` ×6, `show` ×3, `status` ×1. Every one of those is a *lost observation*:
an agent had something to record, typed a plausible sub-verb, and the text after it
was discarded. 25 of the 26 have already been triaged — so somebody looked at
twenty-five observations that said `add` and processed them without asking why.

**Mechanism, read rather than inferred:**

- `bin/fw:5673` — `note)` execs `agents/observe/observe.sh "$@"`.
- `observe.sh:305` — the dispatch `case` ends `*) do_capture "$@"`, so anything that
  isn't a known sub-verb becomes the note text.
- `observe.sh:58-59` — `do_capture` takes `local text="$1"` and shifts.
- `observe.sh:63-68` — its option loop recognises `--task`, `--tag`, `--urgent`, and
  ends `*) shift`. Every remaining **positional** argument is dropped on the floor.

So `fw note add "text"` → `$1`=`add` falls through to `do_capture add "text"` → text
is `add`, and `"text"` is eaten by `*) shift`.

The catch-all is right in principle — the note text should not need a sub-verb — but
it makes *every* typo a silent capture of the typo, and pairs with an option loop
that discards the actual content.

**Why it survived:** the failure is indistinguishable from success at the call site.
Exit 0, and the confirmation line prints the captured text — which is the wrong text,
but a caller who wrote the note already knows what they meant and does not re-read
it. There is no state in which the tool says "you gave me arguments I did not use".
`fw note --typo` errors correctly (line 300); `fw note typo` does not.

Sibling to T-2860 (top-level `fw <unknown>` had no did-you-mean) — same class one
level down, and not covered by that fix, which handled top-level dispatch only.

**Scope fence:** guard the input path and label the existing junk. The 26 lost texts
are **not recoverable** — they were never written anywhere — and this task does not
pretend otherwise.

## Acceptance Criteria

### Agent
- [x] `fw note add "text"` (and any `fw note <bare-word> "text"` shape) **fails**
      with a non-zero exit and names the correct form, instead of capturing the
      bare word. The error prints what was captured, what *would have been*
      discarded, and the corrected one-liner.
- [x] The guard fires on the general defect, not a blocklist of four words: any
      unused **positional** argument left after the note text is an error, because
      the current code silently discards all of them. Pinned with `frobnicate`,
      a word no blocklist would contain.
- [x] Legitimate usage is unaffected — `fw note "text"`, and `fw note "text"
      --task T-X --tag y --urgent` still capture normally, with the flags consumed.
- [x] Known sub-verbs still dispatch: `list`, `count`, `triage`, `promote`,
      `dismiss`, `--help` are untouched.
- [x] The 26 existing junk entries are marked so they cannot be mistaken for real
      observations by a future reader or by `fw note triage`. Edited surgically on
      raw text, not via `safe_load`→`safe_dump` — that round-trip corrupts unquoted
      ISO timestamps (L-495, 115 of them once). Verified: exactly 52 lines changed
      (26 pairs), zero non-`text:` lines touched.
- [x] `tests/unit/note_capture_guard.bats` pins all of the above, including a
      control that a normal capture still works. 7/7.
- [x] ANTI-VACUITY: the guard test is shown red against the pre-fix `observe.sh`
      (extracted with `git show HEAD:`), with the normal-capture control green.
      Observed: `OBS-001 captured: "add"`, **rc=0**, real text absent from the
      inbox. Getting there required a correction — `observe.sh:17` recomputes
      `FRAMEWORK_ROOT` from its own location and overwrites any inherited value, so
      the extracted copy died at `source` time in a temp dir. That non-zero exit
      looked exactly like "the defect leg went red" while proving nothing, so the
      test now runs a smoke check that the extracted script is runnable *before*
      trusting any red from it (OBS-193's class, hit twice in one session).

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

out=$(bats tests/unit/note_capture_guard.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
# The defect shape must be refused. Inverted deliberately: the command is
# EXPECTED to fail, so the gate line passes only when it does.
! bin/fw note add "this must be refused" >/dev/null 2>&1
# The inbox still parses after the 26 in-place edits (L-495 guard).
python3 -c "import yaml; d=yaml.safe_load(open('.context/inbox.yaml')); assert len(d['observations']) > 150"
# All 26 junk entries carry the marker.
[ "$(grep -c 'T-2867 LOST NOTE' .context/inbox.yaml)" = "26" ]

## RCA

**Symptom:** `fw note add "a real observation"` captured the word `add`, discarded
the observation, exited 0, and printed the captured word back as confirmation.

**Root cause:** two correct-in-isolation decisions composing into data loss.
`observe.sh:305` ends its dispatch `*) do_capture "$@"` — right in principle, since
the note text should not need a sub-verb. `do_capture`'s option loop ended
`*) shift` — every positional after the text silently dropped. Together: any typo'd
sub-verb becomes the note, and the actual note becomes nothing.

**Why structurally allowed:** the failure is indistinguishable from success at the
call site. Exit 0; the confirmation line echoes the captured text, which is the
wrong text — but the caller wrote the note and does not re-read it. There is no
state in which the tool says "you gave me arguments I did not use". `fw note --typo`
errors correctly at line 300; `fw note typo` does not. The asymmetry is the bug:
flags are validated, positionals are not.

**Measured incidence:** 26 of 191 observations (13.6%) were bare sub-verbs — `add`
×16, `resolve` ×6, `show` ×3, `status` ×1. Each is a lost note. **25 of the 26 were
already triaged**, so the corpus was read and processed twenty-five times without
anyone asking why an observation said `add`. Consistent with the class: a
low-salience wrong value survives longer than a loud failure.

**How it was found:** by tripping it. `fw note show OBS-190` created OBS-194 whose
text is `show`. The one-off looked like a typo; counting turned it into a class.

**Prevention:** distinct from the fix. The fix collects strays and refuses. The
prevention is `tests/unit/note_capture_guard.bats`, whose anti-vacuity leg runs the
pre-fix script and observes the silent capture directly — so the guard is proven to
catch the behaviour rather than merely to exist. The general-case test uses
`frobnicate` specifically to pin that the guard is not a blocklist.

**Not recovered:** the 26 lost texts. They were never written anywhere — not to
disk, not to a log. They are marked in place as unrecoverable rather than left
looking like real observations.

**Sibling found while testing, deliberately NOT fixed here:** `do_capture` ends
`[ -n "$task" ] && echo …`, so with no `focus.yaml` the note is written correctly
and the script still exits 1 — a success reporting failure, and the first `fw note`
in every fresh project hits it. Different root cause, own task: **T-2868**. One bug,
one task.

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

### 2026-08-08T12:19:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2867-fw-note-silently-discards-the-observatio.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-12914ec8
- **Timestamp:** 2026-08-08T12:25:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 69
     - evidence: `! bin/fw note add "this must be refused" >/dev/null 2>&1`

### 2026-08-08T12:25:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
