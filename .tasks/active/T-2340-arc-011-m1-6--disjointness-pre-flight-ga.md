---
id: T-2340
name: "arc-011 M1 §6 — disjointness pre-flight gate (intercept dispatch path)"
description: >
  arc-011 M1 §6 — disjointness pre-flight gate (intercept dispatch path)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
arc_id: parallel-execution-aef
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
created: 2026-06-11T18:04:38Z
last_update: 2026-06-11T18:04:38Z
date_finished: null
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

# T-2340: arc-011 M1 §6 — disjointness pre-flight gate (intercept dispatch path)

## Context

Fourth arc-011 M1 build slice. Pre-dispatch hook that intercepts the dispatch
path: before emitting an envelope for T-X, scans `.context/dispatches.jsonl`
for in-flight dispatches and refuses if any has a write_set that overlaps T-X's.

Direct support for arc-011 headline_mechanic: "absence of governance-plane
corruption (no .tasks/ merge conflicts)". This is the AEF-ADR §3 "conservative
launch policy" made operational — without it, two workers writing the same
file just race; with it, the second never starts.

Composes with T-2337 (write-set validator) + T-2339 (orchestrator-graph) — pre-flight
runs the same disjointness check on the in-flight pool that the graph runs on
the active task pool, just at the dispatch boundary instead of the planning
boundary.

Spec: `docs/reports/arc-011-m1-single-host-sketch.md:277-313` (§6).

## Acceptance Criteria

### Agent
- [x] `agents/orchestrator/orchestrator-graph.py` extended with `pre_flight_check(task_id, dispatches_jsonl_path=None) -> tuple[bool, str]` that returns `(True, "")` when no in-flight overlap exists, or `(False, "write_set overlap with in-flight dispatch <D-ID>: <conflicting path>")` when one does
- [x] Reuses `lib/write_set.py` for the overlap check; reads `.context/dispatches.jsonl` and filters to entries where `outcome` is empty (in-flight) — does NOT re-implement either
- [ ] `bin/fw orchestrator pre-flight T-XXX` CLI verb prints the verdict + exit code (0=allowed, 1=refused, 2=task-not-found) — **PARTIAL: `_main()` extension authored but Edit blocked by budget gate at 97%; next session lands the CLI wire + `bin/fw` dispatch verb + bats**
- [ ] `tests/unit/test_orchestrator_preflight.bats` covers: no in-flight → exit 0; in-flight overlap → exit 1 + stderr reason names dispatch id + path; in-flight non-overlap → exit 0; completed-only history → exit 0; task without write_set → exit 0 with note (conservative undecidable = allowed for pre-flight, since downstream §2 yield-point + §3 declaration both refuse) — all 5 PASS — **PENDING next session**

## Resume Notes (T-2340 pick-up — next session)

**Status:** 2/4 Agent ACs verified. `pre_flight_check()` function is shipped in `agents/orchestrator/orchestrator-graph.py:172-227` (reads `_in_flight_dispatches()`, reuses `lib/write_set.py`). Budget critical at 97% before the `_main()` extension + CLI wire + bats could land.

**Next steps:**
1. **Extend `_main()` in `agents/orchestrator/orchestrator-graph.py`** to dispatch `pre-flight <T-XXX>` subverb (~25 lines). Pattern from existing `next-dispatch` default branch:
   ```python
   if cmd == "pre-flight":
       if len(argv) < 3:
           sys.stderr.write("usage: ... pre-flight <T-XXX>\n")
           return 64
       task_id = argv[2]
       try:
           ok, msg = pre_flight_check(task_id)
       except FileNotFoundError as e:
           sys.stderr.write(f"error: {e}\n")
           return 2
       if ok:
           print(f"allowed{(': ' + msg) if msg else ''}")
           return 0
       sys.stderr.write(f"refused: {msg}\n")
       print("refused")
       return 1
   ```

2. **Add `pre-flight)` branch in `bin/fw` orchestrator dispatch** (near `next-dispatch)` at bin/fw:~3730):
   ```bash
   pre-flight)
       shift
       exec env PROJECT_ROOT="$PROJECT_ROOT" python3 "$FRAMEWORK_ROOT/agents/orchestrator/orchestrator-graph.py" pre-flight "$@"
       ;;
   ```

3. **Author `tests/unit/test_orchestrator_preflight.bats`** with 5 scenarios per AC list. Fixture pattern: write to `$TEST_REPO/.context/dispatches.jsonl` with synthetic in-flight rows like `{"dispatch_id":"D-001","task_id":"T-COL-A","outcome":""}` + create the matching task fixtures under `.tasks/active/`.

4. **Run reviewer + close + push.** Pattern verified across T-2337/T-2338/T-2339 in this session — chain to T-2341 §4 demo (the L-sized headline_mechanic-firing slice).

**Reference files for resume:**
- Spec: `docs/reports/arc-011-m1-single-host-sketch.md:277-313`
- Reused: `lib/write_set.py:resolve_task_path` + `lib/write_set.py:read_write_set` + `lib/write_set.py:expand_globs`
- In-flight format: see `.context/dispatches.jsonl` schema (existing T-1696/T-1697 contracts)

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

### 2026-06-11T18:04:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2340-arc-011-m1-6--disjointness-pre-flight-ga.md
- **Context:** Initial task creation
