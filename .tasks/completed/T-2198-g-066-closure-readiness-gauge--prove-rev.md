---
id: T-2198
name: "G-066 closure-readiness gauge — prove reviewer auto-tick + dispatch wiring"
description: >
  G-066 closure-readiness gauge — prove reviewer auto-tick + dispatch wiring

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/g066_readiness.bats, tools/g066-readiness.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-04T06:55:01Z
last_update: '2026-08-16T22:24:56Z'
date_finished: 2026-06-04T07:10:31Z
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
  - ts: '2026-06-04T07:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=4 (body:rubric-routable)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=4 (body:rubric-routable); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-04T07:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2198: G-066 closure-readiness gauge — prove reviewer auto-tick + dispatch wiring

## Context

G-066 spec (`.context/project/concerns.yaml`) declares the reviewer-arc T-1442/T-1443 GO scope (auto-tick + `--dispatch` reviewer) "never wired". CLAUDE.md describes both as shipped via T-1985 and T-1951. This task closes the contradiction: a closure-readiness gauge that structurally verifies both wirings are present, plus a `closure_check_command:` field on G-066 so the operator can actuate closure via the T-2185 `/gaps` Close button.

Follows the same shape as `tools/g064-readiness.py` — gauge emits JSON with `verdict: READY|NOT_READY`, parsed by `lib/gaps.py::run_closure_gauge`.

## Acceptance Criteria

### Agent
- [x] `tools/g066-readiness.py` exists and emits JSON `verdict: READY` against the live repo (both T-1985 and T-1951 wirings present).
- [x] Gauge JSON shape: contains `gap_id`, `verdict`, `passing_count`, `total_count`, `checks[]` fields.
- [x] `.context/project/concerns.yaml` G-066 entry has `closure_check_command: "python3 tools/g066-readiness.py --json"`.
- [x] `tests/unit/g066_readiness.bats` covers four conditions: (a) READY against live repo, (b) NOT_READY when auto-tick stub absent, (c) NOT_READY when dispatch routing absent, (d) `--strict` exit 1 on NOT_READY. (Actual: 12/12 PASS, exceeds the four-condition floor.)
- [x] `lib.gaps.gauge_state("G-066")` returns `verdict: READY` and `has_gauge: True` (proves T-2185 surface reads the new gauge).

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

# AC #1 — gauge exists and returns READY against live repo
test -x tools/g066-readiness.py
out=$(python3 tools/g066-readiness.py --json 2>&1); echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d['verdict']=='READY', d"
# AC #2 — gauge JSON shape
out=$(python3 tools/g066-readiness.py --json 2>&1); echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert all(k in d for k in ('gap_id','verdict','passing_count','total_count','checks')), list(d.keys())"
# AC #3 — concerns.yaml has the closure_check_command field on G-066
out=$(python3 -c "import yaml; d=yaml.safe_load(open('.context/project/concerns.yaml')); g=next(x for x in d['concerns'] if x['id']=='G-066'); print(g.get('closure_check_command',''))"); echo "$out" | grep -q "python3 tools/g066-readiness.py --json"
# AC #4 — bats covers four conditions
test -f tests/unit/g066_readiness.bats
bats tests/unit/g066_readiness.bats
# AC #5 — lib.gaps.gauge_state surfaces the gauge to T-2185
out=$(python3 -c "from lib.gaps import gauge_state; import json; print(json.dumps(gauge_state('G-066')))" 2>&1); echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d['has_gauge'] and d['verdict']=='READY', d"

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

### 2026-06-04 — Wiring-presence check, not behaviour-replay
- **Chose:** Structural inspection of the four wiring sites (function definition, field declaration, fw routing branch, dispatch_cli module presence). No end-to-end reviewer run.
- **Why:** Closure readiness is a wiring question. Running the reviewer would couple closure to the live corpus (which is volatile) and to the live TermLink hub (which may not be reachable from cron). Wiring presence is the necessary-and-sufficient signal for "PRONG 1 shipped".
- **Rejected:** (a) Run `fw reviewer T-1442 --dispatch` end-to-end — too slow, network-coupled, and verifies behaviour not wiring; (b) Hash the reviewer source and compare against a baseline — too brittle, refactors trip it; (c) Defer to operator-only override — wastes the T-2185 surface that exists to actuate gauge-confirmed closures.

### 2026-06-04 — Refuse exit on missing project root, not silent fallback
- **Chose:** Exit 2 when `--project-root` (or env/auto-discovery) points at a path with no `.context/`.
- **Why:** Auto-discovery walks up from `__file__`, and a stray `.context/` in a parent directory (e.g. `/tmp/.context/` from prior bats runs) could silently mislabel the project root. Explicit refusal forces the caller to make the root visible.
- **Rejected:** Falling back to CWD silently — same auto-discovery hazard, just relocated.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO — close G-066 via `/gaps` Close button or `fw gaps close G-066`. The closure decision itself is sovereignty-adjacent and stays with the operator.

**Rationale:** Both halves of G-066's PRONG 1 (the "never wired" half) are now in place: T-1985 wired auto-tick into `lib/reviewer/static_scan.py` (the `# Sovereignty: NEVER modifies AC checkboxes` guard documented in G-066's `what_remains` was lifted by the digest-keyed feedback-stream sovereignty rail), and T-1951 wired `fw reviewer --dispatch` → `lib/reviewer/dispatch_cli.py` with `FW_REVIEWER_IN_DISPATCH=1` recursion guard. PRONG 2 (per-task §ACD gate via T-1762) shipped 2026-05-06. The structural gauge `tools/g066-readiness.py` proves all four wiring conditions hold and surfaces VERDICT=READY through `lib/gaps.gauge_state()` — the T-2185 `/gaps` Close button renders enabled, and `fw doctor` now reports `2 gap(s) ≥7 days READY` (G-064 + G-066). No new code paths in the surface itself — this task is pure data: a gauge script + one YAML field. The agent is *not* closing G-066; the gauge is a precondition the operator validates before clicking Close.

**Evidence:**
- Gauge script: `tools/g066-readiness.py` (216 LOC, structural inspection of 4 wiring sites)
- Live gauge output: VERDICT=READY, 4/4 conditions passing
- YAML field: `.context/project/concerns.yaml:2034` `closure_check_command: "python3 tools/g066-readiness.py --json"`
- T-2185 surface integration: `lib.gaps.gauge_state('G-066')` returns `{has_gauge: True, verdict: 'READY'}`
- Watchtower `/gaps`: G-066 renders the enabled Close (READY) button with CSRF token + HTMX swap target
- `fw doctor`: WARNs `Gauge-READY gaps not closed: 2 gap(s) ≥7 days READY` (G-064 30d + G-066 29d)
- Tests: 12/12 bats PASS (`tests/unit/g066_readiness.bats`) — covers live-repo READY, four NOT_READY isolations (one per wiring leg), `--strict` exit semantics, JSON shape contract, human-readable mode, and the `lib.gaps` integration

## Updates

### 2026-06-04T06:55:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2198-g-066-closure-readiness-gauge--prove-rev.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fdb6529e
- **Timestamp:** 2026-06-04T07:10:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-04T07:10:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
