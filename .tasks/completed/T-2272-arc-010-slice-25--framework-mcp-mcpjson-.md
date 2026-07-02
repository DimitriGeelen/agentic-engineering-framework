---
id: T-2272
name: "arc-010 Slice 2.5 — framework-mcp .mcp.json fragment helper for operator wiring"
description: >
  arc-010 Slice 2.5 — framework-mcp .mcp.json fragment helper for operator wiring

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-2268, T-2265, T-2258, T-2209]
arc_id: capability-overlay
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T22:16:13Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T22:21:50Z
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
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2272: arc-010 Slice 2.5 — framework-mcp .mcp.json fragment helper for operator wiring

## Context

T-2268 (arc-010 Slice 3 HM-A demo) Agent AC #1 requires the operator to wire a `framework-mcp` entry into `.mcp.json`. Today the operator has to read T-2265's source (`agents/mcp/framework_mcp_server.py`) and synthesize the command shape themselves — friction with one obvious failure mode (wrong path or wrong python invocation).

This slice ships a **stable contract artefact** the operator copy-pastes verbatim:
1. `agents/mcp/framework-mcp.mcp-fragment.json` — static JSON object with the `framework-mcp` server entry shape (command + args + optional env).
2. `bin/fw mcp wire-fragment` — print verb that emits the fragment to stdout for piping (`fw mcp wire-fragment | jq` etc.).

Does NOT touch `.mcp.json` itself — that file mutates the running session's tool surface and stays in operator's hands. Agent ships the contract; operator does the wire.

Agent-internal infrastructure; no rendering surface, no operator-judgment AC needed (T-2143 audience axis: the artefact's consumer is the operator's clipboard, not their visual review).

## Acceptance Criteria

### Agent
- [x] `agents/mcp/framework-mcp.mcp-fragment.json` exists and is valid JSON. Shape: top-level object with key `framework-mcp` and value `{command, args}` (env optional). Validation: `python3 -c "import json; d=json.load(open('agents/mcp/framework-mcp.mcp-fragment.json')); assert 'framework-mcp' in d; assert 'command' in d['framework-mcp']; assert 'args' in d['framework-mcp']"`.
- [x] The fragment's `args` references a path that resolves to `agents/mcp/framework_mcp_server.py` (the actual server entry-point from T-2265). Validation: `python3 -c "import json,os; d=json.load(open('agents/mcp/framework-mcp.mcp-fragment.json')); p=d['framework-mcp']['args'][-1]; assert os.path.isabs(p) or p.endswith('framework_mcp_server.py')"`.
- [x] `bin/fw mcp wire-fragment` subcommand exists and prints the fragment JSON to stdout (exit 0). Validation: `out=$(bin/fw mcp wire-fragment); echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'framework-mcp' in d"`.
- [x] `bin/fw mcp` help block lists `wire-fragment` with one-line description. Validation: `out=$(bin/fw mcp 2>&1); echo "$out" | grep -q "wire-fragment"`.
- [x] bats integration test at `tests/unit/test_mcp_wire_fragment.bats` covers: (a) fragment file valid JSON, (b) `wire-fragment` verb prints valid JSON to stdout, (c) help block lists the verb. Validation: `out=$(bats tests/unit/test_mcp_wire_fragment.bats 2>&1); echo "$out" | grep -qE "^ok " && ! echo "$out" | grep -qE "^not ok"`.
- [x] `bin/fw reviewer T-2272` returns Overall: PASS or CONCERN (no FAIL). FP class overrides allowed (mock-only-integration, AC-verify-mismatch). [R-e3592b1c PASS via OV-60e25441 suppress]
- [x] T-2268 AC #1 references this fragment file as the canonical source (Edit T-2268 AC #1 to add `Copy from agents/mcp/framework-mcp.mcp-fragment.json` hint). Validation: `grep -q "framework-mcp.mcp-fragment.json" .tasks/active/T-2268-*.md`.

### Human
<!-- No Human AC: this is agent-internal infrastructure with no rendering surface and no
     subjective judgment surface. The fragment file is consumed by operator clipboard
     (not visual review); correctness is binary (valid JSON, correct path, prints to
     stdout). Per T-2143 audience axis: agent-eligible self-eval only.
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

python3 -c "import json; d=json.load(open('agents/mcp/framework-mcp.mcp-fragment.json')); assert 'framework-mcp' in d and 'command' in d['framework-mcp'] and 'args' in d['framework-mcp']"
out=$(bin/fw mcp wire-fragment); echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'framework-mcp' in d"
out=$(bin/fw mcp 2>&1); echo "$out" | grep -q "wire-fragment"
out=$(bats tests/unit/test_mcp_wire_fragment.bats 2>&1); echo "$out" | grep -qE "^ok " && ! echo "$out" | grep -qE "^not ok"
grep -q "framework-mcp.mcp-fragment.json" .tasks/active/T-2268-*.md
out=$(bin/fw reviewer T-2272 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -qE "Overall:.*FAIL"

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

### 2026-06-08 — Audience-axis ruled out [REVIEW] AC at filing
- **What changed:** Initial reflex was to add a `[REVIEW]` Human AC "operator confirms the fragment copy-pastes cleanly into .mcp.json". Applied T-2143 audience-axis test at filing time — the consumer of this artefact is the operator's CLIPBOARD (mechanical copy), not their visual judgment. Binary correctness (valid JSON, correct path, byte-match output) is fully agent-verifiable.
- **Plan impact:** Dropped the [REVIEW] AC. Documented the audience-axis reasoning inline in `### Human` comment so the next agent reading this task sees the explicit routing decision, not silence.
- **Triggered:** No new sub-task. Closes the "easy [REVIEW] reflex" failure mode T-2143 RCA captures.

### 2026-06-08 — Reviewer FP class repeat: mock-only-integration heuristic
- **What changed:** Reviewer fired `mock-only-integration` CONCERN on `out=$(bats ...); ... grep -qE "^ok "` — same heuristic that fires on every "verify via bats" Verification command. The bats here IS the real integration: it shells the actual `bin/fw`, reads the actual JSON file, exits with real status.
- **Plan impact:** Used override (OV-60e25441, 90d TTL) per L-459 recast-vs-override discipline — the AC text genuinely names bats as the verification mechanism, recast would just move the same heuristic-trigger words elsewhere. Override is the right tool when the AC's wording is itself the contract.
- **Triggered:** No new sub-task; this is class-known (memory `feedback_reviewer_markdown_regex` family). Detector tightening filed in T-2179 batch.



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

**Rationale:** Helper artefact ships clean: static JSON fragment with the canonical `framework-mcp` shape + print verb that emits it. Operator copy-paste closes T-2268 AC #1 friction. Agent-internal infrastructure with binary-correctness checks — no rendering surface, no judgment surface, no `[REVIEW]` AC needed (T-2143 audience axis: the artefact's consumer is the operator's clipboard, not their visual review). 7/7 Agent ACs ticked, 6/6 bats green, reviewer PASS after FP suppression.

**Evidence:**
- `agents/mcp/framework-mcp.mcp-fragment.json` — 6 lines, valid JSON, `framework-mcp` key + command + args
- `bin/fw mcp wire-fragment` — dispatch added at `bin/fw:4378`, help block updated at `bin/fw:4439`
- `tests/unit/test_mcp_wire_fragment.bats` — 6/6 PASS (file validity, shape, path resolution, verb output, byte-match, help listing)
- `bin/fw reviewer T-2272` → R-e3592b1c Overall: PASS (OV-60e25441 suppresses heuristic FP, 90d TTL)
- T-2268 AC #1 now contains `framework-mcp.mcp-fragment.json` pointer + `bin/fw mcp wire-fragment` example (verified by Verification command #5)

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

### 2026-06-08T22:16:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2272-arc-010-slice-25--framework-mcp-mcpjson-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-75359cbd
- **Timestamp:** 2026-06-08T22:21:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check

### 2026-06-08T22:21:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
