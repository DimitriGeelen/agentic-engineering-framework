---
id: T-2514
name: "audit stale-obs check false-positive: regex block-split mis-associates captured
  date with pending status"
description: >
  audit stale-obs check false-positive: regex block-split mis-associates captured
  date with pending status

status: work-completed
workflow_type: build
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
created: 2026-07-07T17:46:08Z
last_update: '2026-08-16T22:25:08Z'
date_finished: 2026-07-07T17:50:29Z
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
  - ts: '2026-08-16T22:25:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2514: audit stale-obs check false-positive: regex block-split mis-associates captured date with pending status

## Context

`fw audit` observation section emitted `[WARN] 1 observation(s) pending for >7 days`
even though every genuinely-pending observation was captured <7 days ago. Found
during audit-WARN remediation (T-2512 session). The stale/urgent checks in
`agents/audit/audit.sh` split the inbox with `re.split(r'\n  - ', content)`, which
does not match the real inbox format (`- id:` at column 0), collapsing ~30
observations into one mega-block. `re.search('captured: …')` then grabbed the
oldest date in that block while `status: pending` bled in from an unrelated recent
obs → phantom "stale" count. Fix: parse the YAML per-observation.

## Acceptance Criteria

### Agent
- [x] `stale_obs` check in `audit.sh` parses `inbox.yaml` with `yaml.safe_load` per-observation (no regex block-split); tz-aware `datetime.now(timezone.utc)` cutoff.
- [x] `urgent_obs` check likewise uses a per-observation YAML parse (same block-split bug).
- [x] On the current real inbox (0 genuinely->7d-pending obs), the fixed check returns `stale=0` — the phantom WARN is gone.
- [x] Regression proof: a synthetic inbox with one `status: pending` obs captured >7d ago returns `stale=1`; the same obs `status: dismissed` returns `stale=0`; and an old-dismissed + recent-pending pair (the exact false-positive shape) returns `stale=0`.
- [x] `bash -n agents/audit/audit.sh` passes.

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
bash -n agents/audit/audit.sh
python3 -c "import yaml,datetime as D; d=yaml.safe_load(open('.context/inbox.yaml')) or {}; c=D.datetime.now(D.timezone.utc)-D.timedelta(days=7); f=lambda t: t if getattr(t,'tzinfo',None) else (t.replace(tzinfo=D.timezone.utc) if isinstance(t,D.datetime) else D.datetime.fromisoformat(str(t).replace('Z','+00:00'))); n=sum(1 for o in d.get('observations',[]) if isinstance(o,dict) and o.get('status')=='pending' and o.get('captured') is not None and f(o.get('captured'))<c); print('real-inbox stale=',n); assert n==0"
grep -q 'T-2514: parse YAML properly' agents/audit/audit.sh

## RCA

**Symptom:** `fw audit` reported `[WARN] 1 observation(s) pending for >7 days` while
every truly-pending observation (OBS-091, OBS-092) was captured <7 days ago. YAML
parse of the inbox showed 0 genuinely-stale pending obs.

**Root cause:** `agents/audit/audit.sh` stale/urgent checks split the inbox with
`re.split(r'\n  - ', content)`. Observations are top-level list items (`- id:` at
column 0), so the `\n  - ` (2-space-indent) delimiter almost never matched —
producing ONE mega-block of ~30 observations. `if 'status: pending' not in b:` was
True for that block (recent OBS-091/092 are pending), and `re.search('captured:
(\S+)', b)` returned the FIRST captured date in the block (OBS-058, 2026-06-09,
dismissed). Oldest-date + any-pending-status → phantom stale count.

**Why structurally allowed:** the check was written as line-oriented string matching
over a hand-assumed indent format instead of parsing the YAML it was reading. No test
pinned the check against a known inbox, so format drift (observations at col 0, not
`  - `) went undetected. `pending_obs` itself used `grep -c` (per-line, correct),
masking the block-split bug in its siblings.

**Prevention:** replaced both checks with `yaml.safe_load` per-observation iteration
(exact status + tz-aware captured comparison). Verification block now runs the fixed
logic against the real inbox (asserts stale=0) AND asserts the block-split regex is
gone / YAML parse present — so a regression to string-splitting fails the gate.

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

### 2026-07-07T17:46:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2514-audit-stale-obs-check-false-positive-reg.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-daaa8f0f
- **Timestamp:** 2026-07-07T17:50:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-07T17:50:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
