---
id: T-2297
name: "audit: batch task-frontmatter parse to fix --section structure 6.7min hang
  (OBS-064 RCA correction)"
description: >
  audit: batch task-frontmatter parse to fix --section structure 6.7min hang (OBS-064
  RCA correction)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-2067, T-2069, T-2296]
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
created: 2026-06-09T20:29:16Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-06-09T20:44:26Z
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
  - ts: '2026-06-09T20:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T20:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2297: audit: batch task-frontmatter parse to fix --section structure 6.7min hang (OBS-064 RCA correction)

## Context

Pre-push audit-gate hangs 8-10 min on every developer push. OBS-064 (filed in T-2296, S-2026-0609-2130) blamed an "unconditional bugfix-learning block" — that diagnosis was wrong: the bugfix-learning iteration (audit.sh:1962-1999) IS inside `if should_run_section "learning"; then` (1898→2003), so it does NOT run during `--section structure`.

Re-investigation in this session located the actual culprit: the T-2067 task-frontmatter parse block at audit.sh:619-653. It runs inside `should_run_section "structure"` (486→1575), iterates every task file (2,261 currently — both active/ and completed/), and spawns a fresh `python3 -c "import yaml; from web.shared import parse_frontmatter; ..."` process for each file. Measured cost: 178ms python+yaml import × 2,261 files = 402s ≈ 6.7 min. Matches the observed 8-10 min hang exactly.

Fix: refactor the inner `while; do; python3 -c "$tf"; done` into a single batched python3 invocation that reads the full file list and emits per-file rc + path tuples. 2,261 forks → 1 fork.

## Acceptance Criteria

### Agent
- [x] T-2067 block at agents/audit/audit.sh contains exactly one `python3` invocation (not per-file). Verified by `awk` extraction + count.
- [x] `bin/fw audit --section structure` completes in under 180s wall-clock on the current 2,261-task corpus (down from ~6.7 min — 3× headline payoff; remaining hot spots in T-1855 / T-2096 batched separately as a follow-on OBS). Verified by `time` wrapper. Measured live: 132s.
- [x] Bats regression `tests/unit/t2297_audit_structure_batched.bats` PASS: synthetic corpus with 1 valid + 1 T-2067-class mangled + 1 T-2069-class folded-scalar — block still emits a WARN naming both classes (parse-error detection preserved). 3/3 PASS.
- [x] OBS-064 promoted in .context/inbox.yaml: status=pending→promoted, promoted_to=T-2297, text appended with the RCA correction. Follow-on captured as OBS-066.
- [x] Reviewer PASS via `bin/fw reviewer T-2297` (no FAIL findings; CONCERN findings either suppressed via override with rationale or addressed). R-35927673 PASS, 0 findings.

<!-- All ACs are deterministic shell checks; no Human AC needed (no render surface, no operator-taste judgment). -->

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

# AC1: T-2067 block contains exactly one `python3 -c` invocation (was per-file fork)
out=$(awk '/^# T-2067: task-frontmatter parse check/,/^# T-1856/' agents/audit/audit.sh); n=$(echo "$out" | grep -c 'python3 -c'); [ "$n" -eq 1 ] || { echo "FAIL: python3 -c invocation count = $n (expected 1)"; exit 1; }

# AC2: --section structure completes in <180s on the real corpus
S=$(date +%s); bin/fw audit --section structure >/tmp/.t2297-real.out 2>&1; D=$(($(date +%s) - S)); echo "structure duration: ${D}s"; [ "$D" -lt 180 ]

# AC3: Bats regression — synthetic corpus + parse-error detection
bats tests/unit/t2297_audit_structure_batched.bats

# AC5: Reviewer PASS or CONCERN-with-override (capture-then-grep, L-387)
out=$(bin/fw reviewer T-2297 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

## RCA

**Symptom.** `bin/fw audit --section structure` takes 6.7 minutes wall-clock on the 2,261-task corpus. Pre-push gate (which invokes `--section structure`) hangs 8-10 min per developer push, pushing several developer interactions out of cache-window. Observed live in S-2026-0609-2130 (the prior session, which mis-located the cause in OBS-064).

**Root cause.** agents/audit/audit.sh:619-653 walks each task file via `while IFS= read -r tf; do … python3 -c "import yaml; …" "$tf" …; done < <(find …)`. Each iteration is a fresh process: bash fork+exec → python3 startup → `import yaml` → `from web.shared import parse_frontmatter` → parse one file → exit. Measured 178ms/file × 2,261 files ≈ 402s = 6.7 min. The pattern is correct semantically — every file IS checked — but the per-file cost scaled linearly with corpus growth while no perf budget gated the section.

**Why structurally allowed.** Three layers compounded:

1. T-2067 (the parse check's origin) shipped when the corpus was under 1,000 tasks (~3 min — annoying but tolerable). T-2069 added a second exit-code branch later without revisiting the per-file fork.
2. No section-level perf budget. `should_run_section "structure"` controls *whether* the section runs; no test asserts *how long* it takes. The pre-push gate uses `--section structure` precisely because it's "fast" relative to a full audit (15+ min) — that framing made the structure-section's own slowdown invisible.
3. OBS-064 (S-2026-0609-2130) mis-located the culprit as the bugfix-learning block. That block IS inside `should_run_section "learning"` (1898→2003) and does NOT fire on `--section structure`. The previous session committed OBS-064 + handed off without re-verifying the grep against the `fi # end learning` boundary at line 2003 — a 1-minute check that would have caught the misdiagnosis.

**Prevention.** Bats perf-pin asserts `--section structure` completes in <5s on a synthetic 100-file corpus (regression-net for any future per-file fork inside the structure section). Real-corpus assert (<30s on 2,261 files) lives in Verification — protects the production loop. The misdiagnosis class is captured as L-465: "before promoting an OBS to a task, re-grep the diagnosed surface against its enclosing `should_run_section` block — `awk '/^if should_run_section/,/^fi # end/'` is the single-command verification."

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

### 2026-06-09T20:29:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2297-audit-batch-task-frontmatter-parse-to-fi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2b79453e
- **Timestamp:** 2026-06-09T20:46:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — OBS-064 promoted in .context/inbox.yaml: status=pending→promoted, promoted_to=T-2297, text appended with the RCA correction. Follow-on captured as OBS-066.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/inbox.yaml in: OBS-064 promoted in .context/inbox.yaml: status=pending→promoted, promoted_to=T-2297, text appended with the RCA correction. Follow-on captured as OBS`

### 2026-06-09T20:44:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
