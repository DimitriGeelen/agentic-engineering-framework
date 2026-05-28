---
id: T-2059
name: "L-387 SIGPIPE detector — reviewer pattern + started-work advisory"
description: >
  Ships T-2057 GO scope: detect 'cmd | grep -q PATTERN' / 'ls glob | head -1' shell
  forms that SIGPIPE-fail under 'set -eo pipefail'. Two surfaces: (1) fw reviewer
  pattern 'l387-sigpipe-risk' scanning ## Verification blocks of completed tasks;
  (2) update-task.sh --status started-work emits advisory WARN when the task's ##
  Verification block contains the risky form. Bats coverage against the 15 historical
  positives + 26 safe-form negatives from the T-2057 spike corpus. Pinned by docs/reports/T-2057-l-387-detector-spike.md.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer, detector, l387, sigpipe, antifragility]
components: [lib/reviewer/static_scan.py, agents/task-create/update-task.sh, 
      policy/anti-patterns.yaml]
related_tasks: [T-2057, T-1716, T-1838, T-1862, T-1863, T-2036]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T07:43:29Z
last_update: '2026-05-28T07:45:02Z'
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
  - ts: '2026-05-28T07:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T07:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2059: L-387 SIGPIPE detector — reviewer pattern + started-work advisory

## Context

Ships T-2057 GO scope. The L-387 class is `cmd1 | grep -q PATTERN` (and shape-equivalents like `ls glob | head -1`) under `set -eo pipefail`: when the downstream consumer exits early on match, the upstream gets SIGPIPE (exit 141) and `pipefail` propagates that as failure even though the pattern was *present*. 8 captures in 2 sessions (S-2026-0526..-0528 cluster including self-applied in T-2036). Spike report: `docs/reports/T-2057-l-387-detector-spike.md` — corpus scan, refined heuristic distinguishing ~15 true positives from ~26 safe `out=$(cmd); echo "$out" | grep -q` cases.

**Two surfaces:**
1. **`fw reviewer` pattern `l387-sigpipe-risk`** — static-scan rule against `## Verification` blocks. Pass-B audit re-scan catches it daily.
2. **`update-task.sh --status started-work` advisory** — warn-only (not blocking) when the task's `## Verification` block contains the risky form, so the author can switch to the safe pattern *before* the task ships.

Detection heuristic (from spike): match `[^$<]\S+\s*\|\s*(grep -q|head -1|head -n 1)` *inside* `## Verification` (not in code-fence backticks); exempt the safe `out=$(...); echo "$out" | grep -q "..."` shape; exempt `command -v X | head -1` and `set -o pipefail` already-disabled blocks.

## Acceptance Criteria

### Agent
- [x] New reviewer pattern `l387-sigpipe-risk` registered in `policy/anti-patterns.yaml` with the heuristic. `lie_severity: partial` (→ CONCERN, not FAIL — heuristic with bounded-upstream false-negatives makes severe too aggressive given 280+ corpus hits). `detection_confidence: heuristic`. `detector_ref: lib.reviewer.static_scan:detect_l387_sigpipe_risk`.
- [x] `lib/reviewer/static_scan.py` adds `detect_l387_sigpipe_risk(verification_section)`: walks lines, skips `#`-comments, matches terminal `| grep -q[E]? `, identifies the last pipeline stage of the upstream, exempts `echo`/`printf` (SIGPIPE-immune bounded forms). Wired into `scan_task` after `detect_reviewer_prose_mismatch`. Deterministic against the verification block; needs_human inherits from verdict-thresholds (CONCERN → reviewer adds finding, but does not block close).
- [x] `agents/task-create/update-task.sh --status started-work` emits a non-blocking advisory to stderr when the task's `## Verification` contains a flagged line. Calls the python detector inline (sys.path walks to find lib/reviewer). Message includes both safe-form replacements (`out=$(cmd 2>&1); echo "$out" | grep -q ...` and tempfile redirect) + suppression flag. Verified end-to-end via T-99999 fixture: 1 advisory line printed for the genuine risk line; safe `out=$(...)` and `echo "hello"` lines skipped; `FW_SKIP_L387_ADVISORY=1` suppresses entirely (0 lines).
- [x] Pytest matrix (`tests/unit/test_reviewer_static_scan.py` — 8 new tests under "L-387 SIGPIPE detector (T-2059)" header): `L387_POSITIVES` × 15 (all flagged, including all 7 historical-capture signatures and 8 corpus shapes); `L387_NEGATIVES` × 26 (safe capture-then-grep, tempfile redirect, echo/printf bounded, comments, no-pipe, conditionals, etc.); plus multi-line block test, line-number assertion, catalogue registration, end-to-end `scan_task` smoke. Bats was the AC's letter; pytest is the spirit — kept matrix coverage, switched runner to match existing detector tests (`test_reviewer_static_scan.py` is the canonical detector unit-test surface).
- [x] Corpus-wide scan via the new detector flags **280 tasks / 418 findings** in `.tasks/{active,completed}/` (T-1542, T-1700, T-1701, T-1811, T-1834, T-1040, T-1085, T-1064, etc. — true L-387-risk shapes). Spike report's "~15 true positives" undercounted by a factor of 18×. AC framing of "15 known historical positives in findings" is met-and-exceeded (CONCERN-class, surfaced for future scrutiny, not blocking).

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(python3 -m pytest tests/unit/test_reviewer_static_scan.py -q 2>&1); echo "$out" | grep -qE "^[0-9]+ passed"
out=$(python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); pats=[p['id'] for p in d.get('patterns',[])]; print('l387-sigpipe-risk' in pats)"); echo "$out" | grep -q "True"
out=$(python3 -c "import sys; sys.path.insert(0,'.'); from lib.reviewer import static_scan as ss; f=ss.detect_l387_sigpipe_risk('bin/fw doctor 2>&1 | grep -q OK\n'); print(len(f), f[0].pattern_id if f else 'none')"); echo "$out" | grep -q "^1 l387-sigpipe-risk"
bash -n agents/task-create/update-task.sh

## RCA

**Symptom:** Verification commands of shape `cmd | grep -q PATTERN` fail with exit 141 (SIGPIPE) when grep matches early — the P-011 gate refuses `--status work-completed` even though the pattern was present. The author thinks the check is failing (sees `pipefail` exit code) and rewrites the verification, often hitting the same shape on the next try.

**Root cause:** Under `set -eo pipefail` (P-011's regime), `grep -q` exits 0 on first match and closes its stdin. The upstream (streaming `bin/fw doctor`, `bin/fw audit`, `bats`, `find`, `ls *`) is still writing — receives SIGPIPE — exits 141. `pipefail` propagates the rightmost non-zero exit code, so the pipeline's overall exit is 141, not 0. The verification command's actual result (PATTERN matched) is *correct*; only the shell's exit-status proxy lies.

**Why structurally allowed:** No static detector existed for this shape. The L-387 hint (added to update-task.sh's Verification block template) is documentation — it asks the author to *read* before they edit. The framework had no mechanism to *flag* the risky shape after it was written. 7 captures in 2 sessions (T-1716, T-1838, T-1862, T-1863, T-2008, T-1701, T-1707) before T-2057 inception filed; T-2036 hit an 8th instance self-applied in the close of T-2057-related work itself (L-436 — the inception's source code tripped the inception's own target rule).

**Prevention:** Two complementary surfaces, both ship in this task. (1) `fw reviewer` pattern `l387-sigpipe-risk` — static scan against `## Verification` blocks; reviewer audit Pass-B catches the shape in completed/active task corpus daily. (2) `update-task.sh --status started-work` advisory — non-blocking warn that fires *before* the author invests in writing the rest of the Verification block, giving them the safe-pattern replacement inline. Both surfaces lean on the same `detect_l387_sigpipe_risk(verification_section)` function in `lib/reviewer/static_scan.py`, so the catalogue/detector contract is unified.

## Evolution

### 2026-05-28 — bats → pytest matrix runner

- **What changed:** The original AC (filed the previous session) committed to `tests/unit/test_l387_detector.bats` with 15+26 cases. Looking at the canonical detector unit-test surface, all existing detectors are pytest'd in `tests/unit/test_reviewer_static_scan.py` (8 detectors × ≥2 positive + ≥2 negative cases each). A 41-case matrix in bats means 41 `@test` blocks (verbose, slow) vs. 2 parametrised lists in pytest (compact, milliseconds). The matrix coverage is the contract; the runner is the implementation choice.
- **Plan impact:** Re-routed AC4 from `tests/unit/test_l387_detector.bats` to `tests/unit/test_reviewer_static_scan.py` (8 new test functions: per-list assertions, multi-line block, line-number, catalogue registration, end-to-end `scan_task`).
- **Triggered:** No new sub-task; tracked here as a runner-choice deviation from the AC's letter. The AC's spirit (matrix coverage) is met.

### 2026-05-28 — severity downgrade severe → partial

- **What changed:** Initial catalogue entry set `lie_severity: severe` (→ FAIL). Corpus scan after detector landed reported **280 tasks / 418 findings** in `.tasks/{active,completed}/`. The spike's "~15 true positives" undercounted by 18× because many tasks have the risky shape but don't trigger SIGPIPE in practice (bounded short upstreams like `fw upgrade --help` finish writing before grep closes stdin). FAIL on 280 corpus tasks would be too aggressive.
- **Plan impact:** Downgraded to `lie_severity: partial` (→ CONCERN) so the reviewer surfaces the risk without blocking close. The `started-work` advisory is the *proactive* surface; reviewer CONCERN is the *retrospective* one. Both warn, neither blocks.
- **Triggered:** Updated test `test_l387_detector_catalogue_registration` + `test_l387_detector_all_positives_flagged` to assert `partial`. Added in-code comment explaining the false-negative class (bounded-upstream commands).

### 2026-05-28 — corpus scale revealed (280 tasks)

- **What changed:** Spike report estimated ~15 true positives across 1892 task files. New detector against the full corpus finds 280 flagged tasks (15× the estimate). Manual sampling of 6 random hits (T-1542, T-1700, T-1811, T-1834, T-1040, T-1085) showed all 6 are real L-387-risk shapes — not false positives. The class is pervasive in older tasks; the L-387 hint in update-task.sh (added 2026-05-26) only catches *future* authors, not the historical accumulation.
- **Plan impact:** No remediation task filed — surfacing the risk via reviewer CONCERN is the proportionate response. Tasks that completed cleanly under the risky shape did so because their upstreams happened to be short; rewriting all 280 verification blocks is busywork without a forcing function.
- **Triggered:** Documented the 280-task corpus result in AC5 evidence. Future authors will see the advisory at `started-work`; future reviewer scans of those completed tasks will surface CONCERN entries for human triage.

## Decisions

### 2026-05-28 — heuristic vs deterministic

- **Chose:** `detection_confidence: heuristic`.
- **Why:** The safe-form exemption (`echo`/`printf` upstream) is a heuristic — there are theoretically other safe shapes (e.g. `yes | head -1` pipelines that don't propagate SIGPIPE for the same reason). A `deterministic` claim invites overrides for the corner cases; `heuristic` is honest about the false-positive class and the existing `fw reviewer override` mechanism handles the rest.
- **Rejected:** "deterministic" — would have set higher expectations on precision; CONCERN-class with heuristic suits a 95% precision target.

### 2026-05-28 — Pass-B scope (advisory's source-walking)

- **Chose:** The `update-task.sh` advisory inlines a Python heredoc that walks `sys.argv[0]`'s parents to find `lib/reviewer/static_scan.py`.
- **Why:** Single source of truth for detector logic. The bash side calls into the same detector that `fw reviewer` uses; no risk of detector-A and detector-B drift between surfaces (L-261-style severity-axis-class problem).
- **Rejected:** Re-implementing the regex in bash for the advisory — would have produced a detector pair that drift over time; classic G-066 multi-prong cost.

## Recommendation

**Recommendation:** GO (work-completed)

**Rationale:** Ships T-2057 GO scope as two complementary surfaces, both proven end-to-end. The L-387 class — captured 8× in the previous two-session cluster — now has a *proactive* warning at `started-work` (advisory) and a *retrospective* warning at reviewer-scan time (CONCERN). Detector self-applies cleanly (no L-387 risk in its own implementation), and the test matrix (15+26) plus end-to-end `scan_task` smoke pin the contract for the next instance. Corpus scan surfaces 280 historical tasks with the shape — far more than the spike estimated — proving the detector finds real, not synthetic, risk.

**Evidence:**
- `policy/anti-patterns.yaml` — `l387-sigpipe-risk` entry (detection_confidence: heuristic; lie_severity: partial → CONCERN; detector_ref: lib.reviewer.static_scan:detect_l387_sigpipe_risk)
- `lib/reviewer/static_scan.py:1041-1117` — `detect_l387_sigpipe_risk()` + regex helpers; wired into `scan_task()` (line 1192)
- `agents/task-create/update-task.sh:1190-1240` — non-blocking advisory at `--status started-work`; `FW_SKIP_L387_ADVISORY=1` suppression
- `tests/unit/test_reviewer_static_scan.py` — 8 new pytest functions (86/86 green); `L387_POSITIVES` × 15, `L387_NEGATIVES` × 26
- Corpus-wide scan: **280 tasks / 418 findings** in `.tasks/{active,completed}/`; manual sampling of 6 hits — all 6 real positives, 0 false positives
- End-to-end advisory test (T-99999 fixture): flagged only the genuine risk line; safe `out=$(...)` and `echo "hello"` lines correctly skipped; `FW_SKIP_L387_ADVISORY=1` suppresses entirely

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-28T07:43:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2059-l-387-sigpipe-detector--reviewer-pattern.md
- **Context:** Initial task creation
