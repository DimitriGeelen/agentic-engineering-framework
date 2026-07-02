---
id: T-1946
name: "extract bin/fw:1911 worker-kinds parity heredoc to lib + bats lint enforcing
  zero heredoc-in-cmd-sub"
description: >
  extract bin/fw:1911 worker-kinds parity heredoc to lib + bats lint enforcing zero
  heredoc-in-cmd-sub

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [bin/fw, lib/worker_kinds_parity.py, 
      tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats]
related_tasks: [T-1944, T-1945, T-1735, T-1734, T-1629]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T06:40:25Z
last_update: '2026-06-11T22:24:04Z'
date_finished: 2026-05-20T06:46:49Z
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
  - ts: '2026-05-20T06:45:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-20T06:45:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 3
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1946: extract bin/fw:1911 worker-kinds parity heredoc to lib + bats lint enforcing zero heredoc-in-cmd-sub

## Context

T-1944 extracted the cron-drift heredoc (the noisy one). T-1945 added
the edit-time PreToolUse warning. ONE inline `$(python3 - <<PYEOF
... PYEOF)` block remains in bin/fw at line 1911 — the T-1735
worker-kinds parity check that imports `VALID_WORKER_KINDS` from
`lib/resolver.py` and `lib/workflow_lint.py` and reports drift.

This block is the "stable safe shape" L-408 mentioned (closing `)`
on its own line, no warning emitted at runtime), but it is still
an L-332 violation and grandfathering it would weaken the rule.

Two-part slice:
1. Extract the parity logic to `lib/worker_kinds_parity.py`. bin/fw
   becomes 100% heredoc-in-cmd-sub-free for hot-path code.
2. Add `tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats` — a structural
   lint that greps bin/fw for `\$\(.*<<TAG` patterns and fails if
   count > 0. This is the third layer of L-332/L-408 prevention:
   - Layer 1: the learnings (L-332 / L-408)
   - Layer 2: the PreToolUse edit-time warning (T-1945)
   - Layer 3 (this task): structural lint that bin/fw STAYS clean

The lint is the strongest layer — a future agent who ignores the
WARN cannot ship a violation; the bats fails in CI / pre-push.

Out of scope:
- Extending the lint to `agents/audit/audit.sh` or `lib/*.sh`.
  bin/fw is the canonical self-lockout vector; other scripts can
  parse-error without bricking the agent's tool surface. Future
  task if it ever bites.

## Acceptance Criteria

### Agent
- [x] `lib/worker_kinds_parity.py` exists, executable, takes 1 arg (`FW_LIB_DIR`), prints one line: `OK|<sorted_list>` or `WARN|drift: ...` or `FAIL|<reason>`.
- [x] `bin/fw doctor` invokes the helper as `python3 "$FRAMEWORK_ROOT/lib/worker_kinds_parity.py" "$FW_LIB_DIR"`; the OK/WARN/FAIL surface output is byte-identical to the pre-extraction form.
- [x] bin/fw no longer contains an inline `$(python3 - <<` pattern (grep returns 0 matches).
- [x] `bash -n bin/fw` clean; `bin/fw doctor` first line is the banner (no cosmetic warnings on stdout/stderr).
- [x] `tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats` exists with at least 2 cases — (a) bin/fw has zero `$(...<<TAG)` patterns; (b) introducing a synthetic violation makes the lint fail (proves the lint actually catches violations, not just passes trivially).
- [x] `bats tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats` — all 3 cases pass.
- [x] `bin/fw doctor` worker-kinds-parity check still shows OK/WARN/FAIL line correctly (live smoke).

### Human

(none — pure structural refactor + deterministic bats lint.)

<!-- template kept below for reference
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

bash -n bin/fw
bash -n lib/worker_kinds_parity.py 2>&1 | tail -1 ; test -x lib/worker_kinds_parity.py
bats tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats
out=$(bin/fw doctor 2>&1); echo "$out" | grep -qE "Worker-kinds parity" && echo "$out" | head -1 | grep -q "Framework Health Check"
test "$(grep -cE '\$\([^)]*<<' bin/fw)" -eq 0

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

### 2026-05-20 — Lint had to be comment-aware (own dogfood, second time)

- **What changed:** First lint draft used `grep -cE '\$\([^)]*<<' bin/fw` — which returned 1 because my OWN comment block in bin/fw documenting the extraction said "(last remaining $( python3 - <<TAG ) site in bin/fw)". The lint immediately false-positive'd on the prose describing the rule it was enforcing.
- **Plan impact:** Two-part fix — (a) rewrite the comment to not echo the literal pattern, (b) refine the lint regex to require an uppercase TAG marker AND filter out lines starting with `#` whitespace. Added a third bats case ("lint ignores comment-only references") to pin the behaviour.
- **Triggered:** This is the SECOND time in two consecutive tasks (T-1945 stdin-routing bug, T-1946 comment false-positive) where building the L-332 prevention surfaced its own first-draft violation. Pattern is robust: writing the guard catches the guard's own mistakes. Capture: prevention work tends to be recursive in a healthy way.

## Recommendation

**Recommendation:** GO (work-completed)

**Rationale:** bin/fw is now 100% free of `$(... <<TAG ... TAG)` patterns — the last L-332/L-408 violation extracted to `lib/worker_kinds_parity.py`. Three layers of prevention now stack: learnings → PreToolUse WARN → bats lint. The lint is the strongest because it fails in CI / pre-push regardless of agent attention. Doctor functional behaviour unchanged (live smoke: OK|['Task', 'TermLink', 'ollama-loop', 'pi']).

**Evidence:**
- `grep -cE '\$\([^)]*<<' bin/fw` → 0
- `bash -n bin/fw` — clean
- `bin/fw doctor` first line is the banner; Worker-kinds parity line still appears with full content
- `bats tests/unit/test_bin_fw_no_heredoc_cmd_sub.bats` — 3/3 PASS (positive bin/fw zero-match, synthetic-violation catch, comment-only ignore)
- Live: `python3 lib/worker_kinds_parity.py /opt/.../lib` → `OK|['Task', 'TermLink', 'ollama-loop', 'pi']`
- Fabric cards created for helper + bats

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

### 2026-05-20T06:40:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1946-extract-binfw1911-worker-kinds-parity-he.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9749e604
- **Timestamp:** 2026-06-02T15:00:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — `bin/fw doctor` invokes the helper as `python3 "$FRAMEWORK_ROOT/lib/worker_kinds_parity.py" "$FW_LIB_DIR"`; the OK/WARN/FAIL surface output is byte-identical to the pre-extraction form.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=FRAMEWORK_ROOT/lib/worker_kinds_parity.py in: `bin/fw doctor` invokes the helper as `python3 "$FRAMEWORK_ROOT/lib/worker_kinds_parity.py" "$FW_LIB_DIR"`; the OK/WARN/FAIL surface output is byte-id`
### 2026-05-20T06:46:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
