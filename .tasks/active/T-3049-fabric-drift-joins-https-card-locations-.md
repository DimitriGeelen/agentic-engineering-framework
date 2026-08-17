---
id: T-3049
name: "fabric drift joins https:// card locations onto PROJECT_ROOT and reports them
  file-missing"
description: >
  From T-3047 triage M-06 (ring20-management, 2026-05-14). agents/fabric/lib/drift.sh:58-64
  has only an absolute-path branch; any non-/ location becomes $PROJECT_ROOT/$loc
  and fails [ ! -f ]. grep -c http agents/fabric/lib/drift.sh returns 0 — no URL skip
  exists. saas-account cards with URL locations are permanently flagged. The T-2519
  gitignore escape at drift.sh:76 does not catch it. Part 2 of the original report
  (depends_on under .agentic-framework/) is already fixed.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [upstream-pickup, T-3047-triage]
components: []
related_tasks: [T-3047]
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
created: 2026-08-16T22:29:29Z
last_update: 2026-08-17T06:43:04Z
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
  - ts: '2026-08-16T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:45:08Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3049: fabric drift joins https:// card locations onto PROJECT_ROOT and reports them file-missing

## Context

A card's `location:` is assumed to be a filesystem path. Two checks act on that
assumption and neither tests it:

- `agents/fabric/lib/drift.sh:59-64` — branches on `${loc:0:1} = "/"` (absolute,
  T-1673 cross-repo cards) and otherwise joins onto `$PROJECT_ROOT`. So
  `https://example.com/x` becomes `$PROJECT_ROOT/https://example.com/x`, fails
  `[ ! -f ]`, and is printed as `(file missing)` forever.
- `agents/audit/audit.sh:1664` — `os.path.join(PROJECT_ROOT, location)`, same
  question, same wrong answer. `os.path.join` happens to handle the absolute case
  correctly, so this site never needed T-1673's fix and never got its scrutiny.

Neither the T-1673 absolute-path branch nor the T-2519 gitignore escape
(`drift.sh:76`) catches a URL: the first tests only for a leading `/`, and
`git check-ignore` on a URL string returns not-ignored, so the escape hatch
passes it straight through to the warning.

**Zero cards in this repo have a URL location** — verified by grep over
`.fabric/components/*.yaml`. The bug is latent here and live in consumers:
reported from ring20-management, where `saas-account` cards legitimately point at
hosted services. That asymmetry is the reason it survived — the framework repo is
where the check is exercised daily, and it is the one place the bug cannot fire.

Third instance this session of one code shape at multiple sites answering the
same question (cf. T-3053 first-ref-only, T-3052 clobbering `mv`). Fixing only
the site named in the report would leave the audit reporting the count the CLI
no longer reports.

## Acceptance Criteria

### Agent
- [x] **A1 — a URL location is not treated as a missing file.** A card whose
      `location:` is `<scheme>://...` is excluded from the orphaned count and
      from the `(file missing)` output. "Does this file still exist" is not a
      question that has an answer for a URL, so the check declines it rather
      than answering no.
- [x] **A2 — both sites, not just the reported one.** `drift.sh` (the
      `fw fabric drift` CLI) and `audit.sh` (the daily orphan count) agree.
      Fixing one leaves the two surfaces reporting different numbers for the
      same corpus, which is worse than both being wrong.
- [x] **A3 — nothing else is loosened.** A genuinely deleted repo-relative file
      still flags. An absolute path (T-1673 cross-repo cards) still resolves
      unjoined. A gitignored missing file is still exempt (T-2519). A path that
      merely *contains* a colon, or a malformed `http:/single-slash`, is still
      treated as a path — the skip requires a real scheme separator.
- [x] **A4 — pinned by mutation.** Removing the URL skip at each site turns a
      distinct test red, with a positive control (L-616) proving the harness can
      still tell a hit from a miss.

### Human
- [ ] [REVIEW] Confirm the consumer-visible change in audit output is wanted.

  **Why you and not the agent:** this ships to every consumer project via
  `.agentic-framework/`. Their next `fw audit` and `fw fabric drift` will report
  a *lower* orphan count than the previous run, with no task explaining the drop
  in their repo. That is the intended fix — the dropped entries were false
  positives — but a count moving on its own is exactly the shape an operator is
  trained to distrust, so it is worth you knowing before it lands.

  **Steps:**
  1. `bin/fw fabric drift`
  2. Confirm the "Orphaned cards:" section is unchanged for this repo — it must
     be, since zero cards here carry a URL location.
  3. Decide whether consumers should be told, or whether a silently-correct count
     is fine.

  **Expected:** no change in this repo's output; consumers with `saas-account`
  cards stop seeing permanent `(file missing)` lines.

  **If not:** if this repo's orphan output DID change, the skip is too broad —
  revert `agents/fabric/lib/drift.sh` and `agents/audit/audit.sh` and re-open.


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

out=$(bats tests/unit/t3049_fabric_url_location.bats 2>&1); echo "$out" | grep -q "^ok 11 " && ! echo "$out" | grep -q "^not ok"
bin/fw fabric drift > /tmp/.t3049-real.out 2>&1 && ! grep -q "file missing" /tmp/.t3049-real.out
grep -q 'a-zA-Z\]\*://\*) continue' agents/fabric/lib/drift.sh
grep -qE "re\.match\(r'\^\[a-zA-Z\]\[a-zA-Z0-9\+\.-\]\*://', loc\)" agents/audit/audit.sh

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

**Symptom:** in consumer projects, fabric cards whose `location:` is a hosted
service URL are reported `(file missing)` by `fw fabric drift` on every run, and
counted as orphaned by the daily audit. Permanently — no action clears them.

**Root cause:** both checks treat `location:` as a filesystem path without
testing that it is one. `drift.sh:59-64` branches on a leading `/` and otherwise
joins onto `$PROJECT_ROOT`, producing `$PROJECT_ROOT/https://host/path`;
`audit.sh` does `os.path.join(PROJECT_ROOT, location)` for the same result. The
check asks "does this file still exist" of something that is not a file, and a
missing answer is scored as "no".

**Why structurally allowed:**

1. **The bug cannot fire where the check is exercised.** Zero cards in the
   framework repo carry a URL location — verified by grep. The daily audit runs
   here, the CLI is developed here, and here it is correct. Only consumers
   registering `saas-account` cards see it. A check whose test corpus lacks the
   failing shape is not being tested for that shape at all.
2. **Two prior fixes made the branch *look* considered.** T-1673 added the
   absolute-path branch; T-2519 added the gitignore escape. Reading `:56-78` you
   see a location-resolution site that has been thought about twice, which reads
   as coverage. Neither catches a URL: T-1673 tests only for a leading `/`, and
   `git check-ignore` on a URL string returns not-ignored, so T-2519's escape
   hands it straight to the warning. **Accumulated special cases are the shape
   most likely to be mistaken for completeness.**
3. **A false positive that never changes is quieter than one that flickers.** A
   permanent `(file missing)` line becomes furniture; the operator learns to read
   past it. Had it appeared intermittently it would have been chased.

Third instance this session of one code shape at multiple sites answering the
same question (T-3053 first-ref-only, T-3052 clobbering `mv`, this). The recurring
lesson is not about paths — it is that **the report names the site where it was
hit, and the sibling site is found only by looking for it.** Here the report named
`drift.sh`; `audit.sh` was never mentioned, and fixing only the named one would
have left the CLI and the daily audit disagreeing about one corpus.

**Prevention** (distinct from the fix):

- Both sites skip `<scheme>://` locations, so the CLI and audit counts agree.
- The skip requires a real `://` separator, so a typo'd `http:/single-slash` is
  still a broken path and still flags — the fix silences a category, not a
  spelling.
- 11 tests, four of which exist purely to prove nothing was loosened: a deleted
  repo-relative file still flags at both sites, an absolute cross-repo path still
  resolves, an existing file is still clean, and the single-slash typo still
  flags.
- Both skips are mutated separately with a positive control (L-616). That control
  earned its place immediately: the first version of the drift harness exited 127
  because `do_drift` is not named `do_fabric_drift`, and every URL assertion
  "passed" on empty output. The control was the only test that failed.

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

**Recommendation:** GO

**Rationale:** The defect is confirmed at both sites by reading the code, and the
fix is a narrow type check — a location with a `<scheme>://` separator is not a
path, so the "does this file exist" question is declined rather than answered
wrongly. Four of the eleven tests exist only to prove nothing was loosened, and
the real corpus is unchanged (`fw fabric drift` output identical before and
after, because zero cards here carry a URL location). The only judgment left is
the cross-project one, which is why it is yours: consumers will see an orphan
count drop with no local task explaining it.

**Evidence:**
- `agents/fabric/lib/drift.sh:59-64` joined `https://...` onto `$PROJECT_ROOT`;
  `agents/audit/audit.sh` did the same via `os.path.join`. Both fixed; a test
  mutates each skip separately and each turns a distinct test red.
- Neither prior escape caught it: T-1673 tests only for a leading `/`, and
  `git check-ignore` on a URL returns not-ignored, so T-2519 passed it through.
- Regression guards green: deleted repo-relative file still flags at both sites,
  absolute cross-repo path still resolves, existing file still clean, and a
  malformed `http:/single-slash` is still treated as a path.
- `bin/fw fabric drift` on this repo: exit 0, zero `file missing` lines, same as
  before the change.
- Reviewer: PASS, no findings. The one escalation is `cross-project-blast`, which
  is the reason this is in front of you rather than closed.


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

### 2026-08-16T22:29:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3049-fabric-drift-joins-https-card-locations-.md
- **Context:** Initial task creation

### 2026-08-17T06:43:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d5105f16
- **Timestamp:** 2026-08-17T06:48:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`
