---
id: T-2385
name: "RCA: CTL-012-MISSING-DECIDE + D10 — historical inceptions flagged as flipped
  without decide ceremony"
description: >
  Audit WARNs CTL-012-MISSING-DECIDE (T-1902/T-2000/T-1915/T-1905) and D10 decision-without-dialogue
  (T-1902/T-1846/T-1915/T-1905). Classify each FP-vs-real: likely predate the decide-gate
  (T-1259/T-1260) or were decided via an unrecognized path. If FP, scope the detector
  to post-gate tasks; if real, close the flip path.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, governance, inception]
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
created: 2026-06-13T23:08:20Z
last_update: 2026-08-12T02:10:50Z
date_finished: 2026-08-12T02:10:50Z
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
  - ts: '2026-07-07T08:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T08:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-08T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2385: RCA: CTL-012-MISSING-DECIDE + D10 — historical inceptions flagged as flipped without decide ceremony

## Context

Remediation R3 from `.context/working/audit-remediation-plan-2026-06-14.md`. The full audit
emitted:
- `WARN CTL-012-MISSING-DECIDE: Inception T-1902 / T-2000 / T-1915 / T-1905 flipped without decide ceremony`
- `WARN D10: Decision-without-dialogue — T-1902 T-1846 T-1915 T-1905`

All flagged tasks are historical (T-18xx/T-19xx/T-20xx). The likely classification (to be
verified per task) is **FP**: they predate the decide-gate (T-1259/T-1260, which made
`fw inception decide` agent-blocked under `$CLAUDECODE=1`) or were decided via a path the
detector doesn't recognize. Per the just-recorded learning, this RCA is a **hypothesis to
disprove**, not a conclusion — classify each task individually before deciding the fix.

**Preliminary recommendation:** if all are pre-gate FPs, scope the CTL-012-MISSING-DECIDE /
D10 detectors to inceptions created after the decide-gate cutoff (sibling to the R4 grandfather
pattern). The grandfather *cutoff* is a policy call — surface to operator. If any is a genuine
post-gate flip, that's a real governance gap and gets its own fix task.

## Acceptance Criteria

### Agent
- [x] Each of T-1902 / T-2000 / T-1915 / T-1905 / T-1846 classified FP-or-real with evidence (creation date vs decide-gate ship date; presence/absence of a decide record or `## Decision` block)
- [x] If all FP (pre-gate): CTL-012-MISSING-DECIDE + D10 detectors scoped to post-cutoff inceptions (cutoff surfaced to operator as a policy call), OR a TTL'd reviewer-style suppression filed for the named tasks
- [x] If any real: a separate fix task filed for the flip path (one bug = one task)
- [x] RCA filled (post-investigation); reviewer PASS

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bats tests/unit/audit_ctl012_missing_decide_grandfather.bats
bats tests/unit/audit_ctl012_compliance_section.bats
out=$(python3 agents/audit/completed-task-scan.py .tasks .context/episodic docs/reports 2>&1); echo "$out" | python3 -c "import sys,json; ids=[i['id'] for i in json.load(sys.stdin)['unchecked_ac']]; assert 'T-1902' not in ids and 'T-2000' not in ids and 'T-1915' not in ids and 'T-1905' not in ids, ids"

## RCA

**Symptom:** Audit emitted `WARN CTL-012-MISSING-DECIDE` for T-1902/T-2000/T-1915/T-1905 ("flipped without
decide ceremony") and `WARN D10` (decision-without-dialogue) for T-1902/T-1846/T-1915/T-1905. All five
named tasks are historical inceptions completed 2026-05-15 through 2026-05-23.

**Classification (per-task, with evidence):**

| Task | Created | date_finished | Decide record? | Mechanism found | Classification |
|------|---------|----------------|-----------------|------------------|-----------------|
| T-1902 | 2026-05-18 | 2026-05-18T20:15:17Z | No — `## Decision` empty, Agent+Human ACs all unchecked | `git mv` side-effect of unrelated commit `ecce30292` (T-1908) | **FP** — L-390 pattern |
| T-2000 | 2026-05-18 | 2026-05-23T14:32:27+02 | No — same shape | `git mv` side-effect of unrelated commit `a4ecd7add` (T-2002) | **FP** — L-390 pattern |
| T-1915 | 2026-05-18 | 2026-05-19T06:52:17Z | No — same shape | `git mv` side-effect of unrelated commit `4fd5f21f6` (handover S-2026-0519-0851) | **FP** — L-390 pattern |
| T-1905 | 2026-05-18 | 2026-05-18T21:09:38Z | No — same shape | `git mv` side-effect of unrelated commit `ff52e79a6` (T-1909) | **FP** — L-390 pattern |
| T-1846 | 2026-05-15 | 2026-05-15T14:49:04Z | No — `## Decision` empty; Human AC unticked (Agent ACs are ticked, so CTL-012 doesn't flag it — only D10 does, via the Human-AC path) | `git mv` side-effect of unrelated commit `c15b9b819` (T-1847) | **FP** — L-390 pattern; already a named evidence case in L-390 itself |

For all five, `git log --name-status --follow` on the completed/ path shows an `R100` rename from
`.tasks/active/<file>` → `.tasks/completed/<file>` embedded inside a commit whose subject is a
*different, unrelated* task — i.e. the file was moved via a bare `git mv` (or editor drag) alongside
other work, never through `fw task update --status work-completed` or `fw inception decide`. This is
the exact, already-named L-390 pattern ("Tasks moved to .tasks/completed/ via git mv … leave frontmatter
desynced") — T-1846 is literally one of L-390's original 8 evidence cases. T-1062 (2026-05-28) later
patched `status:`/`date_finished:` on T-1902/T-1915/T-1905 directly (cosmetic — cleared a CTL-028 WARN)
but did not — and could not — backfill a decide ceremony that never happened; the Decision section and
AC state were left as-is.

**Root cause:** the hypothesis in this task's Context section ("predate the decide-gate T-1259/T-1260")
is **wrong** — all five tasks were completed in mid/late May 2026, weeks *after* T-1259/T-1260 shipped
(2026-04-15/18). The gate they actually predate is different: **T-2202** (`2c1576193`, 2026-06-13), the
commit that shipped the CTL-012-MISSING-DECIDE sub-classifier itself, and its sibling **T-1870**
(2026-05-15), which shipped CTL-028 (the metadata-desync detector for the same underlying git-mv-bypass
event). T-1259/T-1260 block *agent-invoked* `fw inception decide` under `$CLAUDECODE=1` — none of these
five tasks ever attempted that path; the whole state machine (`update-task.sh`) was bypassed entirely by
a raw filesystem rename, a mechanism T-1259/T-1260 never addressed and were never meant to.

**Why structurally allowed:** `git mv` (or an editor's drag-move) is an ordinary git operation with no
framework hook attached to it — nothing intercepts a rename into `.tasks/completed/` and requires it to
carry the same side effects `update-task.sh` applies (status flip, date_finished stamp, Decision-section
gate, AC auto-tick). L-390 already named this class and CTL-028 already closed the *detection* gap for
*new* occurrences (fires at pre-push since T-1882/T-1883). CTL-012-MISSING-DECIDE (T-2202) is a second,
independent detector for the AC/Decision *consequence* of the same event — but it carried no cutoff, so
every pre-existing instance from before its own ship date surfaces forever with no new information on
each audit run.

**No real/open flip path found.** All five instances are traceable to the single, already-documented,
already-mitigated L-390 mechanism. No separate fix task was filed because there is no distinct bug to
fix — the "flip path" (bare `git mv`) is the L-390 mechanism, and its live-detection leg (CTL-028) has
been in place since 2026-05-15/T-1882.

**Prevention:** added `MISSING_DECIDE_CUTOFF = "2026-06-13"` to
`agents/audit/completed-task-scan.py` (the day CTL-012-MISSING-DECIDE itself shipped). A task is only
classified `missing-decide` when its `date_finished` is on/after the cutoff, or when `date_finished` is
empty/absent (an *undated*, i.e. still-live, desync — deliberately NOT exempted, confirmed against live
production case T-2494). Tasks with `date_finished` before the cutoff are skipped from `unchecked_ac`
entirely — they are confirmed-historical L-390 artifacts the classifier could not have caught live, and
CTL-028 already prevents new unlogged instances at commit time. D10 needed no code change: its existing
30-day time-box (present since inception, T-248) already self-resolved all five — as of 2026-08-12,
every one is >30 days past `date_finished`, confirmed by re-running D10's detection block directly
(see Verification). Pinned by `tests/unit/audit_ctl012_missing_decide_grandfather.bats` (4 cases: grandfathered,
post-cutoff still-flagged, undated still-flagged, and a genuine non-auto-tick unchecked AC still
classified plain `drift` — proving the cutoff does not blanket-suppress CTL-012).

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

### 2026-08-12 — Grandfather cutoff vs. TTL'd per-task suppression

- **Chose:** a date-based cutoff (`MISSING_DECIDE_CUTOFF = "2026-06-13"`) in the classifier itself,
  scoped to `date_finished` on the individual task — not a global time-boxed suppression list.
- **Why:** the cutoff is self-scoping and requires no maintained list. Any *future* task that flips via
  the same bare-`git-mv` mechanism (date_finished on/after the cutoff) is still caught; only instances
  that predate the detector's own existence are exempted. This is the same "grandfather scoped by
  created-after-cutoff" pattern R4 (sibling remediation in the same audit-remediation plan) recommends
  for the C-001 research-artifact backlog — for the same reason: backfilling ceremony for closed,
  weeks-old inceptions has near-zero forward value, and CTL-028 already covers live detection of new
  occurrences.
- **Rejected:** TTL'd reviewer-style suppression per named task (T-1902/T-2000/T-1915/T-1905) — rejected
  because it requires a maintained allowlist for a class that recurs (L-390 is not a one-off; 8+ prior
  evidence cases). A date cutoff generalizes to any other pre-existing instance not yet individually
  spotted, without needing to enumerate them.
- **D10 — no change:** its existing 30-day time-box (T-248, original design) already self-resolves this
  exact case; adding a second cutoff mechanism would be redundant. Confirmed live: as of 2026-08-12 D10
  no longer flags any of the five tasks.
- **Cutoff date policy note (surfaced per this task's own AC wording "policy call"):** 2026-06-13 is the
  ship date of the classifier being scoped (T-2202/`2c1576193`), not an arbitrary round date — it is the
  earliest date a `missing-decide` WARN could have been *actionable* (the check didn't exist before
  then). This is a defensible, non-arbitrary anchor; flagged here for operator visibility rather than as
  a blocking Human AC, since the change is reversible (single constant, unit-tested) and detective-only
  (no gate strengthens or weakens as a result).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-13T23:08:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2385-rca-ctl-012-missing-decide--d10--histori.md
- **Context:** Initial task creation

### 2026-08-12T01:59:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ea4f35dc
- **Timestamp:** 2026-08-12T02:11:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T02:10:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
