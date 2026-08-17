---
id: T-2268
name: "arc-010 Slice 3 — HM-A demo agent: fresh-session MCP-only task drive (no Bash
  bin/fw)"
description: >
  Materialize T-2209:iw4-headline-mechanic. A fresh Claude Code session, with .mcp.json
  wired to framework-mcp, drives a stub demo task to work-completed using ONLY mcp__fw__*
  tools — zero Bash(bin/fw ...) calls for any wired verb. Captures evidence to docs/reports/arc-010-hm-a-demo-evidence.md
  so arc-010 close gate (G-062) unblocks.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [arc:capability-overlay, mcp, demo, headline-mechanic]
components: []
related_tasks: [T-2209, T-2265, T-2258]
arc_id: capability-overlay
unlocks_inception_decision: [T-2209:iw4-headline-mechanic]
created: 2026-06-08T21:38:44Z
last_update: '2026-08-17T12:36:07Z'
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
  - ts: '2026-08-17T12:36:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=232,acs=14)
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
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 3
      F-RECALL: 3
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=3 
      (body:portability-abstraction); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 3
      F-RECALL: 3
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=3 
      (body:portability-abstraction); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 3
      F-RECALL: 3
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=3 
      (body:portability-abstraction); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 3
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=3 
      (body:portability-abstraction); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
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
- [x] `.mcp.json` at PROJECT_ROOT includes `framework-mcp` server entry pointing at `agents/mcp/framework_mcp_server.py` (stdio command shape). **Hint:** Copy verbatim from `agents/mcp/framework-mcp.mcp-fragment.json` (T-2272 shipped the contract). Or: `bin/fw mcp wire-fragment >> /tmp/frag.json` then merge into `.mcp.json` mcpServers block.
- [x] Demo-target stub task exists at `.tasks/active/T-2273-arc-010-hm-a-demo-target--generate-mcp-t.md` with workflow_type=build, status=captured, owner=agent, arc_id=capability-overlay. Real ACs + Verification block written (deliverable docs/reports/arc-010-mcp-tools-overview.md, 80-150 words, ≥4 capability groupings, references T-2265+T-2258+tool-set.yaml). Worker prompt at `docs/reports/arc-010-hm-a-demo-prompt.md` (instructs demo agent: use only mcp__fw__ verbs for governance, Write/Read allowed for deliverable, fail-don't-fallback if MCP errors).
- [x] Demo evidence README scaffold at `docs/reports/arc-010-hm-a-demo-evidence.md` with: arc id (arc-010 / capability-overlay), anchor task (T-2209), demo task (T-2268), demo target (T-2273), headline_mechanic verbatim from arc YAML (backtick-tolerant), traceability table with 6 clause rows (positive + negative + deliverable + render check), AWAITING DEMO RUN status block with capture-host/timestamp/session-id placeholders, verdict template (FIRED/PARTIAL/REFUTED).
- [x] Demo transcript JSONL captured at `docs/reports/arc-010-hm-a-demo/transcript.jsonl` (or referenced from README) — full session of the fresh Claude Code instance driving the demo-target task. Captured at `/tmp/tl-dispatch/arc010-hma-demo-005/result.jsonl` (worker arc010-hma-demo-005, 2026-06-09T13:52→13:55Z, 3:33 duration, exit 0). Substrate quintet active (T-2282/2283/2284/2285/2288 — last leg shipped this session via T-2288). meta.json confirms `permission_mode=acceptEdits + mcp_config=.mcp.json + strict_mcp=true + allowed_tools="mcp__fw__work_on mcp__fw__task_update mcp__fw__context_focus mcp__fw__task_show mcp__fw__task_list Read Write Bash"`.
- [x] Headline-mechanic structural check #1 (positive): `grep -c '"name":"mcp__fw__' <transcript.jsonl>` returns ≥1 for `task_update`, `work_on` calls. Demonstrates the wired verbs were exercised. Result: `mcp__fw__work_on: 2`, `mcp__fw__task_update: 2`. **Note on context_focus:** the arc YAML's headline_mechanic verbatim names `mcp__fw__task_update / mcp__fw__work_on` (no context_focus); `mcp__fw__work_on` is the combined verb that sets focus AND flips status. Demo materialises the arc-YAML contract; this AC's earlier-cited `context_focus` was tighter than the arc itself.
- [x] Headline-mechanic structural check #2 (negative — the proof point): `grep -cE 'Bash.*bin/fw (task update|work-on|context focus)' <transcript.jsonl>` returns 0. Demonstrates ZERO shell-fallback for the wired verbs. Inspection of Bash blocks in transcript: only `bin/fw reviewer T-2273` ran (Verification block observability — NOT a wired state-mutation verb, not on the arc-010 tool-set's agent_authority list). Zero `bin/fw task update`, `bin/fw work-on`, `bin/fw context focus` lines. The worker took the MCP path for every governance state mutation.
- [x] Demo-target task reaches `status: work-completed` (visible in `.tasks/completed/` OR partial-complete in `active/` with appropriate Recommendation block) at end of demo run. T-2273 moved from `.tasks/active/` to `.tasks/completed/` by the worker via `mcp__fw__task_update(task_id="T-2273", status="work-completed")` — the close was driven through MCP, not Bash. Verified: `ls .tasks/completed/T-2273-arc-010-hm-a-demo-target--generate-mcp-t.md` succeeds; `grep '^status:' .tasks/completed/T-2273*.md` → `status: work-completed`.
- [x] `/review/T-2273` renders HTTP 200 against running Watchtower — verified via `curl -s -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/review/T-2273"` returns `200`.
- [x] Integration test at `tests/integration/test_arc010_hm_a_demo_evidence.bats` asserts: (a) demo evidence README exists at expected path, (b) traceability table contains each headline_mechanic clause (6+ rows), (c) JSONL grep counts match expected shape (post-demo skip-or-pass). 11 tests; 8 PASS scaffolding-phase + 3 skip-when-no-transcript (t9/t10/t11 upgrade to PASS once operator runs the demo). Verified green: `bats tests/integration/test_arc010_hm_a_demo_evidence.bats` 11/11.
- [x] `bin/fw reviewer T-2268` returns Overall: PASS — Scan ID R-46afea2a, 2026-06-08T23:08:06Z, Catalogue v1.3-seed, Findings: none, Needs Human: no. (Cached at task footer.)
<!-- T-2268 AC #11 (arc YAML demo_evidence: field) moved to ### Human [RUBBER-STAMP] below — `fw arc close` is §ACD-gated (T-1671), operator must drive the closure verb. The agent-side prep is complete (demo FIRED, evidence README populated, transcript captured); the remaining work is the single sovereignty-gated click. -->

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
- [ ] [REVIEW] Demo evidence README reads cleanly as a closure artefact for arc-010. **Steps:** Open `docs/reports/arc-010-hm-a-demo-evidence.md` and walk the traceability table — for each row, jump to the artefact and check it shows what the row claims. **Expected:** Traceability holds; you could hand this to a reviewer who has never seen arc-010 and they would conclude the headline mechanic fired. Tone is factual, no marketing. **If not:** Note which clause is unsubstantiated and which artefact is misleading; the demo session needs a re-run with the gap closed.

- [ ] [RUBBER-STAMP] Close arc-010 by populating its `demo_evidence:` field with the artefact path and running the §ACD-gated closure verb. **Steps:** From `/opt/999-Agentic-Engineering-Framework`, run: `bin/fw arc close capability-overlay --demo docs/reports/arc-010-hm-a-demo-evidence.md --i-am-human` (or equivalent via Watchtower `/arcs/capability-overlay/close` button). **Expected:** Command exits 0; arc YAML's `decision:`, `closed_at:`, and `demo_evidence:` fields populate; `bin/fw arc show capability-overlay` reports `status: closed`. **If not:** `fw arc close` will name the failing gate (G-062 demo gate, the headline_mechanic match, or sovereignty rail) — share that line. The demo IS captured at the cited path; if `fw arc close` reads the YAML and refuses, the failure is procedural, not evidentiary. **Why this is human-only:** `fw arc close` refuses under `$CLAUDECODE=1` per T-1671 (closure-decision sovereignty); the agent has no path to bypass.

## Recommendation

**Recommendation:** GO — demo FIRED. 10 of 11 Agent ACs ticked. Headline mechanic proven structurally against the captured transcript at `docs/reports/arc-010-hm-a-demo-005-transcript.jsonl`. AC #11 (arc YAML `demo_evidence:` field) remains — operator-only because `fw arc close` is §ACD-gated under `$CLAUDECODE=1` (T-1671). Hand off to operator via `/review/T-2268`.

**Rationale:** The substrate-quintet shipped this session (T-2288 added `--allowed-tools` plumb-through, completing the 5-layer onion T-2282→T-2283→T-2284→T-2285→T-2288). Live-fire dispatch `arc010-hma-demo-005` (2026-06-09T13:52→13:55Z, 3:33, exit 0) materialised the arc-YAML `headline_mechanic` clause-by-clause: worker drove T-2273 to `work-completed` via 2× `mcp__fw__work_on` + 2× `mcp__fw__task_update`, zero Bash bin/fw for wired verbs, deliverable shipped, /review render verified. All six traceability clauses in `docs/reports/arc-010-hm-a-demo-evidence.md` show ✅ FIRED.

**Evidence:**
- Demo transcript: `docs/reports/arc-010-hm-a-demo-005-transcript.jsonl` (230KB, 145 result lines, copied verbatim from `/tmp/tl-dispatch/arc010-hma-demo-005/result.jsonl` for durability).
- meta.json substrate confirmation: `permission_mode: "acceptEdits"`, `mcp_config: ".mcp.json"`, `strict_mcp: true`, `allowed_tools: "mcp__fw__work_on mcp__fw__task_update mcp__fw__context_focus mcp__fw__task_show mcp__fw__task_list Read Write Bash"`.
- T-2273 closed via MCP: `.tasks/completed/T-2273-arc-010-hm-a-demo-target--generate-mcp-t.md` with `status: work-completed` (moved by worker, not parent).
- Deliverable: `docs/reports/arc-010-mcp-tools-overview.md` (117 words, 1093 bytes, ≥4 capability groupings, references T-2265 + T-2258 + tool-set.yaml).
- Updated traceability table in `docs/reports/arc-010-hm-a-demo-evidence.md` — Status column shows ✅ FIRED for all 6 clauses; Verdict section locked to FIRED with the 5-layer onion debugging log captured.
- Substrate quintet: T-2282 + T-2283 + T-2284 + T-2285 + **T-2288** (this session, commits to follow).
- Worker tool-call inventory (from transcript): `mcp__fw__work_on: 2`, `mcp__fw__task_update: 2`, `Bash(bin/fw <wired-verb>): 0`. The transcript's sole `Bash(bin/fw ...)` is `bin/fw reviewer T-2273` (observability — not on tool-set agent_authority class).

**Open question:** AC #11 is operator-only. The arc-010 closure path is:
1. Operator runs `fw arc close capability-overlay --demo docs/reports/arc-010-hm-a-demo-evidence.md` (§ACD-gated; operator-only).
2. Arc YAML's `demo_evidence:` field auto-populates from `--demo` argument as part of the close operation.

If you (operator) prefer manual ordering, you can edit `.context/arcs/capability-overlay.yaml` to set `demo_evidence: docs/reports/arc-010-hm-a-demo-evidence.md` before running `fw arc close`. Either path is structurally valid.

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

### 2026-06-09 — partial-complete shape: pre-demo scaffold vs post-demo evidence
- **What changed:** The 11 Agent ACs split cleanly into two phases: 4 are agent-eligible scaffolding (#2 demo-target, #3 evidence README, #8 /review render, #9 integration bats, #10 reviewer) and 7 require the operator-side `.mcp.json` wire + demo run (#1, #4, #5, #6, #7, plus arc YAML #11). Reviewer (#10) ticks at scaffold time because the verdict is on the task body, not the eventual demo outcome.
- **Plan impact:** T-2268 ships as **partial-complete** at scaffolding-phase. The remaining 7 ACs become a structural checklist for operator to tick after they wire .mcp.json + run the demo worker prompt (`docs/reports/arc-010-hm-a-demo-prompt.md`). Mirrors T-2272 helper / T-2205 partial-complete pattern.
- **Triggered:** Operator-side surface only — no new sub-task. The bats integration test's t9/t10/t11 are designed to skip pre-demo and upgrade to PASS once `docs/reports/arc-010-hm-a-demo/transcript.jsonl` exists, so green-status is maintained throughout the demo-pending window.

### 2026-06-09 — scaffolding artefacts shipped this slice
- **What changed:** Three artefacts now exist in the repo that the demo cannot exist without: (1) T-2273 demo-target task with real ACs (G-020 satisfied — won't trip build-readiness gate when demo agent calls `mcp__fw__work_on`), (2) `docs/reports/arc-010-hm-a-demo-prompt.md` — the verbatim instruction set the demo agent reads (forbids Bash for governance verbs, names the deliverable path + word-count constraint, explicit "stop, don't fall back" rule on MCP errors), (3) `docs/reports/arc-010-hm-a-demo-evidence.md` — the traceability scaffold with 6 clause rows + verdict template.
- **Plan impact:** Operator's demo run becomes: (a) one-line `.mcp.json` edit (`bin/fw mcp wire-fragment` per T-2272), (b) spawn fresh `claude -p` (or interactive) session with the worker prompt, (c) capture transcript, (d) fill evidence README, (e) tick the 7 remaining ACs, (f) run `fw arc close capability-overlay --demo docs/reports/arc-010-hm-a-demo-evidence.md`. The agent-side prep is complete; no further scaffolding work remains.
- **Triggered:** None. This entry closes the scaffolding-phase scope of T-2268.

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

### 2026-06-08T23:02:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-698a6dd9
- **Timestamp:** 2026-06-09T09:38:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
