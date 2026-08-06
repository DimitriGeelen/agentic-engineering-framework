---
id: T-2824
name: "triage and recover the two stranded worktrees before source-only enforcement"
description: >
  triage and recover the two stranded worktrees before source-only enforcement

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-06T11:19:57Z
last_update: 2026-08-06T11:29:50Z
date_finished: 2026-08-06T11:29:50Z
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
---

# T-2824: triage and recover the two stranded worktrees before source-only enforcement

## Context

T-2822/S1 found three live worktrees under `.claude/worktrees/`, two of them stranded
with **43 unlanded commits dormant five weeks** (OBS-174). The operator directed that
these be triaged **before** the T-2822 source-only refusal ships — once writes into a
worktree are refused, reaching this work gets harder, not easier.

Triage established before starting:

- **Source is superseded, not lost.** Strand B's 21 `lib/` + agents/bin changes date
  2026-06-18…07-01; master's versions of the same files are 5–6 weeks newer
  (`lib/paths.sh` master 07-31 vs strand 06-23, `agents/audit/audit.sh` 08-04 vs 06-24).
  Its commit subjects are `T-2481: go live — sync code to origin/master`, i.e. the code
  was travelling *toward* master. Nothing to recover here.
- **Governance artifacts are genuinely absent from master** — verified per path with
  `git cat-file -e origin/master:<path>`.
- **Three recovered task IDs collide with different tasks on master** (T-2505, T-2506,
  T-2428), so they must be re-IDed, not restored in place. Two others (T-2323, T-2324)
  already landed on master under the same IDs and need no recovery.

## Triage decisions, per artifact

| Artifact | Decision | Rationale |
|---|---|---|
| 26 dated handovers | **recovered** | Episodic record of 2026-06-18…07-01, absent on master, no ID collisions. `LATEST.md` deliberately not touched — restoring it would rewind the current pointer. |
| `docs/reports/T-2323-yield-point-granularity-inception.md` | **recovered as-is** | Task `T-2323` exists on master under the same name; only its report was stranded. No collision. |
| `docs/reports/T-2324-disjoint-write-set-policy-inception.md` | **recovered as-is** | Distinct document from master's `T-2324-aef-ic-2-*.md` — carries a four-candidate CSMA/CD analysis master never received. Filename free. |
| `docs/reports/T-2505-worktree-usage-policy.md` | **recovered, renamed** | → `docs/reports/T-2822-prior-art-stranded-worktree-usage-policy.md`. Keeping the `T-2505` name would attach it to an unrelated task on master. It is prior art for T-2822, which answered its question. |
| `.context/pickup/processed/P-051-feature-proposal.yaml` | **recovered as-is** | Path free, historical record. |
| gap `G-083` | **recovered, re-minted → G-074** | Master's gap space runs to G-073; the strand allocated beyond it. Cross-refs rewritten from the stranded `T-2505 C3` to T-2822 slice 2, which now owns the fix. |
| strand gaps `G-071`, `G-072` | **recovered, re-minted → G-075, G-076** | Master's `G-071`/`G-072` are **different gaps**. The split-view collision extends to the gap ID space. |
| strand task `T-2428` | **recovered, re-minted → T-2825** | High-priority remediation for worktree teardown stranding unpushed commits — the second-order instance of the defect that stranded it. Still live: T-2822/S1 measured the same failure ongoing. |
| strand task `T-2505` (inception) | **declined** | Its question — worktree usage policy — was answered by T-2822 with a recorded GO. Re-minting it would file an already-decided question. Its reasoning is preserved as prior art above. |
| strand task `T-2506` | **declined** | Scoped to a specific 2026-07-01 state: branch `t2417-fw-sessions` holding 267 uncommitted changes. That branch and that working tree no longer exist. The *class* it described is preserved as G-074; the instance is gone. |
| strand B source (21 `lib/`, plus `agents/`, `bin/`) | **declined** | Superseded, not lost. Master's versions are 5–6 weeks newer on every file sampled (`lib/paths.sh` 07-31 vs 06-23; `agents/audit/audit.sh` 08-04 vs 06-24), and the strand's commit subjects read `T-2481: go live — sync code to origin/master` — the code was travelling toward master, not away from it. |

## Acceptance Criteria

### Agent
- [x] Every governance artifact absent from master is recovered or explicitly declined, with the decision recorded per path — see the triage table above; all 11 rows disposed
- [x] The three colliding IDs are re-minted, not overwritten: `T-2505`/`T-2506`/`T-2428` on master are untouched; the recovered task was minted through the allocator as T-2825, not hand-written
- [x] `bash agents/git/lib/dup-task-scan.sh scan-worktree` and `scan-staged` both exit 0 after recovery
- [x] Strand-B source files are explicitly NOT recovered — no path under `lib/`, `agents/`, or `bin/` appears in this task's commits
- [x] Dated handovers from both strands are recovered (26); `LATEST.md` left untouched so the current pointer is not rewound
- [x] The gap is present on master after recovery — re-minted as G-074 rather than restored as G-083, because worktree-allocated IDs are not authoritative; G-075/G-076 recovered on the same basis
- [x] Branch pruning is proposed to the operator with counts, and NOT executed under agent authority — see §Recommendation; branch deletion is Tier 0

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

bash agents/git/lib/dup-task-scan.sh scan-worktree
bash agents/git/lib/dup-task-scan.sh scan-staged
python3 -c "import yaml,sys; c=yaml.safe_load(open('.context/project/concerns.yaml'))['concerns']; ids=[x.get('id') for x in c]; sys.exit(0 if all(i in ids for i in ('G-074','G-075','G-076')) and len(ids)==len(set(ids)) else 1)"
test -f docs/reports/T-2323-yield-point-granularity-inception.md
test -f docs/reports/T-2324-disjoint-write-set-policy-inception.md
test -f docs/reports/T-2822-prior-art-stranded-worktree-usage-policy.md
test -f .context/pickup/processed/P-051-feature-proposal.yaml
ls .tasks/active/T-2825-*.md >/dev/null
# Declined-by-design: no strand source recovered. Empty match must exit 0, so invert.
! git diff --name-only origin/master..HEAD | grep -qE '^(lib|agents|bin|web)/'

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

## Recommendation

**Recommendation:** prune both stranded worktrees and their branches — **operator
action, not agent.** Branch deletion is Tier 0 and this task deliberately stops short
of it.

**Rationale.** Everything worth keeping is now on master. What remains in the two
strands is either superseded source (verified 5–6 weeks stale on every file sampled) or
duplicates of artifacts recovered above. Leaving them in place keeps three live
`.tasks/`+`.context/` forks on disk, which is exactly the state T-2822's GO exists to
prevent, and keeps feeding the duplicate-ID exposure.

**Counts, so the decision is made on numbers rather than on my summary of them:**

| Worktree | Branch | Unlanded commits | Last activity | Recovered from it |
|---|---|---|---|---|
| `inception-gov-payload-mediation` | `worktree-inception-gov-payload-mediation` | 6 | 2026-07-01 | 1 handover, T-2505 report (renamed), G-074 |
| `rca-worktree-push-strand` | `worktree-rca-worktree-push-strand` | 37 | 2026-07-01 | 25 handovers, 2 reports, P-051, T-2825, G-075, G-076 |
| `t100199-close` | `t100199-close` | 0 | 2026-07-09 | nothing — already clean |

**Suggested sequence** (worktree removal first; removing a worktree does not delete its
branch, which is the property that saved this work in the first place):

```
cd /opt/999-Agentic-Engineering-Framework && git worktree remove .claude/worktrees/t100199-close && git worktree remove .claude/worktrees/inception-gov-payload-mediation && git worktree remove .claude/worktrees/rca-worktree-push-strand
```

**Hold the branches.** Deleting `worktree-*` branches is the irreversible half and buys
little — they are cheap, and they are the evidence base for T-2825. Recommend keeping
them until T-2825 has used them for its live-case AC, then deleting under Tier 0.

## RCA

**Symptom.** 43 commits sat unlanded across two worktrees for five weeks, including a
high-priority remediation task and a gap registration, neither of which existed on
master. The operator asked a question in this session whose answer had already been
written — into a tree nobody could read.

**Root cause.** Governance state is tracked content, so every worktree receives a
complete, independently writable copy of `.tasks/` and `.context/`. Work authored there
is real work in a fork nothing reconciles. This is T-2822's finding F1; this task is
its cleanup.

**Why structurally allowed.** Two independent blindnesses compounded. `.git/info/exclude`
lists `.claude/worktrees/`, so `git status` in the main checkout is clean no matter what
sits in them. And `fw doctor`'s `diverged-fork` check (T-100195) watches the *session's*
branch, not siblings. Neither surface was wrong; between them there was no observer.
The ID space forked in the same silence — `T-2505`, `T-2506`, `T-2428`, `G-071`, `G-072`
each name two different things depending on which tree is read.

**Prevention.** Not shipped here, and this task should not be read as closing the class:

- **T-2822 slice 1** (write refusal) stops new governance forks at the source.
- **T-2822 slice 2** (`fw doctor` surfaces sibling worktrees with unlanded counts) is
  the missing observer; **G-074** stays open until it exists.
- **T-2825** (recovered) guards teardown against unpushed commits — **G-076**.
- A cross-view duplicate-ID check, folded into T-2822's slices at the operator's
  direction, would have surfaced `T-2505` on day one instead of week five.

Recovery is not prevention (G-019). This task moved the work; the four items above are
what stop it happening again, and three of them are unshipped.

**Escalation level:** D — the recurrence pattern is not technique or tooling but a
structural decision about where governance state may live, which is why T-2822 was
raised to an inception rather than another fix.

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

### 2026-08-06T11:19:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2824-triage-and-recover-the-two-stranded-work.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a1123ebb
- **Timestamp:** 2026-08-06T11:29:52Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 8
     - evidence: `ls .tasks/active/T-2825-*.md >/dev/null`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `! git diff --name-only origin/master..HEAD | grep -qE '^(lib|agents|bin|web)/'`

### 2026-08-06T11:29:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
