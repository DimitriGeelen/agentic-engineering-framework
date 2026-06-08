---
id: T-2268
name: "arc-010 Slice 3 — HM-A demo agent: fresh-session MCP-only task drive (no Bash
  bin/fw)"
description: >
  Materialize T-2209:iw4-headline-mechanic. A fresh Claude Code session, with .mcp.json
  wired to framework-mcp, drives a stub demo task to work-completed using ONLY mcp__fw__*
  tools — zero Bash(bin/fw ...) calls for any wired verb. Captures evidence to docs/reports/arc-010-hm-a-demo-evidence.md
  so arc-010 close gate (G-062) unblocks.

status: captured
workflow_type: build
owner: claude-code
horizon: next
tags: [arc:capability-overlay, mcp, demo, headline-mechanic]
components: []
related_tasks: [T-2209, T-2265, T-2258]
arc_id: capability-overlay
unlocks_inception_decision: [T-2209:iw4-headline-mechanic]
created: 2026-06-08T21:38:44Z
last_update: '2026-06-08T21:45:03Z'
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
  - ts: '2026-06-08T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-08T21:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 3
      F-RECALL: 3
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=3 
      (body:portability-abstraction); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2268: arc-010 Slice 3 — HM-A demo agent: fresh-session MCP-only task drive (no Bash bin/fw)

## Context

Materializes T-2209 `iw4-headline-mechanic` decision: produces the wire-level demo artefact required by arc-010's `headline_mechanic:` (per arc YAML) and the §G-062 arc-closure gate. The arc shipped Slice 1 (T-2258 tool-set artefact, T-2260 OR-2 probe scan) + Slice 2 (T-2265 framework MCP server with 22 tools, 6 gated). What remains is **proof that the surface actually delivers**: an agent in a fresh Claude Code session, with `.mcp.json` wired to `framework-mcp`, drives a stub demo task to `work-completed` using ONLY `mcp__fw__*` tools — and the operator confirms the transcript JSONL has zero `Bash(bin/fw <gated-verb> ...)` lines for the wired verbs.

**Sized M-L** (per [[project_t2265_framework_mcp_shipped]] Optional Next Step): needs `.mcp.json` wiring (operator), demo stub task scaffold, headless `claude -p` worker integration, transcript-JSONL inspection. Best done in a fresh-budget session.

**Dispatch contract:** follow `docs/dispatch-templates/iw-slice-worker.md` — read arc-010 YAML for axioms, read T-2209 + T-2265 + T-2258 for upstream surface, write Agent ACs BEFORE editing source, ship minimally (no scope creep into Slice 4 Watchtower migration).

**Demo evidence path:** `docs/reports/arc-010-hm-a-demo-evidence.md` (sibling pattern to `docs/reports/value-prioritisation-demo/` from T-2136 arc-006 closure).

## Acceptance Criteria

### Agent
- [ ] `.mcp.json` at PROJECT_ROOT includes `framework-mcp` server entry pointing at `agents/mcp/framework_mcp_server.py` (stdio command shape).
- [ ] Demo-target stub task exists at `.tasks/active/T-XXXX-arc-010-hm-a-demo-target.md` (or sibling slug) with workflow_type=build, captured, owner=claude-code. This is the task the demo agent will drive end-to-end.
- [ ] Demo evidence directory `docs/reports/arc-010-hm-a-demo-evidence.md` (or `docs/reports/arc-010-hm-a-demo/README.md` if multi-file) exists with: arc id, headline_mechanic verbatim from arc-010 YAML, traceability table (each headline_mechanic clause → demo artefact path → shipping commit), capture timestamp, capture host.
- [ ] Demo transcript JSONL captured at `docs/reports/arc-010-hm-a-demo/transcript.jsonl` (or referenced from README) — full session of the fresh Claude Code instance driving the demo-target task.
- [ ] Headline-mechanic structural check #1 (positive): `grep -c '"name":"mcp__fw__' <transcript.jsonl>` returns ≥1 for `task_update`, `work_on`, and `context_focus` calls. Demonstrates the wired verbs were exercised.
- [ ] Headline-mechanic structural check #2 (negative — the proof point): `grep -cE 'Bash.*bin/fw (task update|work-on|context focus)' <transcript.jsonl>` returns 0. Demonstrates ZERO shell-fallback for the wired verbs.
- [ ] Demo-target task reaches `status: work-completed` (visible in `.tasks/completed/` OR partial-complete in `active/` with appropriate Recommendation block) at end of demo run.
- [ ] `/review/T-XXXX` (the demo-target task) renders HTTP 200 against running Watchtower — verified via `curl -sf "$(bin/fw watchtower url)/review/T-XXXX"`.
- [ ] Integration test at `tests/integration/test_arc010_hm_a_demo_evidence.bats` asserts: (a) demo evidence README exists at expected path, (b) traceability table contains each headline_mechanic clause, (c) JSONL grep counts match expected shape. Bats green.
- [ ] `bin/fw reviewer T-2268` returns Overall: PASS or CONCERN with findings only in suppressible FP classes (mock-only-integration, AC-verify-mismatch). Override via `bin/fw reviewer override add T-2268 ...` if FP confirmed.
- [ ] arc-010 YAML's `demo_evidence:` field updated to the captured artefact path (e.g. `docs/reports/arc-010-hm-a-demo-evidence.md`). This is the structural unblock for `fw arc close capability-overlay` (G-062 gate). Operator-only.

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
- [ ] [REVIEW] Demo evidence README reads cleanly as a closure artefact for arc-010. **Steps:** Open `docs/reports/arc-010-hm-a-demo-evidence.md` (or referenced README) and walk the traceability table — for each row, jump to the artefact and check it shows what the row claims. **Expected:** Traceability holds; you could hand this to a reviewer who has never seen arc-010 and they would conclude the headline mechanic fired. Tone is factual, no marketing. **If not:** Note which clause is unsubstantiated and which artefact is misleading; the demo session needs a re-run with the gap closed.

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

# AC #1: .mcp.json framework-mcp entry present
test -f .mcp.json && grep -q "framework-mcp" .mcp.json && grep -q "framework_mcp_server.py" .mcp.json
# AC #2: demo-target task scaffolded (matches arc-010-hm-a-demo-target slug)
out=$(ls .tasks/active/T-*arc-010-hm-a-demo-target*.md .tasks/completed/T-*arc-010-hm-a-demo-target*.md 2>/dev/null); echo "$out" | grep -q "T-"
# AC #3: demo evidence README at sibling path
test -f docs/reports/arc-010-hm-a-demo-evidence.md -o -f docs/reports/arc-010-hm-a-demo/README.md
# AC #4: transcript JSONL captured
out=$(ls docs/reports/arc-010-hm-a-demo/transcript*.jsonl docs/reports/arc-010-hm-a-demo-transcript*.jsonl 2>/dev/null); echo "$out" | grep -q "jsonl"
# AC #5: positive — mcp__fw__* calls present
out=$(cat docs/reports/arc-010-hm-a-demo/transcript*.jsonl docs/reports/arc-010-hm-a-demo-transcript*.jsonl 2>/dev/null); echo "$out" | grep -qE '"name"\s*:\s*"mcp__fw__(task_update|work_on|context_focus)"'
# AC #6: negative — zero Bash bin/fw <gated-verb> lines (file-based to avoid L-387 SIGPIPE heuristic on assert-absent form)
cat docs/reports/arc-010-hm-a-demo/transcript*.jsonl docs/reports/arc-010-hm-a-demo-transcript*.jsonl > /tmp/t2268-transcript.tmp 2>/dev/null; ! grep -qE 'Bash.*bin/fw (task update|work-on|context focus|task-update)' /tmp/t2268-transcript.tmp
# AC #7: demo-target reached work-completed
out=$(grep -lE "^status:\s*work-completed" .tasks/active/T-*arc-010-hm-a-demo-target*.md .tasks/completed/T-*arc-010-hm-a-demo-target*.md 2>/dev/null); test -n "$out"
# AC #8: /review/<demo-target> renders 200
target_id=$(ls .tasks/active/T-*arc-010-hm-a-demo-target*.md .tasks/completed/T-*arc-010-hm-a-demo-target*.md 2>/dev/null | head -1 | sed -nE 's|.*/(T-[0-9]+)-.*|\1|p'); code=$(curl -s -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/review/${target_id}"); test "$code" = "200"
# AC #9: integration test green
out=$(bats tests/integration/test_arc010_hm_a_demo_evidence.bats 2>&1); echo "$out" | grep -qE "tests, 0 failures|ok [0-9]+"
# AC #10: reviewer PASS or CONCERN-only-with-suppression
out=$(bin/fw reviewer T-2268 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)"
# AC #11: arc-010 demo_evidence wired
out=$(grep -E "^demo_evidence:" .context/arcs/capability-overlay.yaml); echo "$out" | grep -qvE "demo_evidence:\s*(null|~|\"\")?\s*$"

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

### 2026-06-08T21:38:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2268-arc-010-slice-3--hm-a-demo-agent-fresh-s.md
- **Context:** Initial task creation
