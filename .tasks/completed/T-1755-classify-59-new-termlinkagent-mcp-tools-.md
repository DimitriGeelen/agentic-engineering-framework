---
id: T-1755
name: "Classify 59 new termlink_agent_* MCP tools — orchestrator-mcp-scan baseline
  drift"
description: >
  Classify 59 new termlink_agent_* MCP tools — orchestrator-mcp-scan baseline drift

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-05T22:22:40Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-05T22:26:20Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1755: Classify 59 new termlink_agent_* MCP tools — orchestrator-mcp-scan baseline drift

## Context

`fw audit` raises WARN: "Orchestrator-arc MCP scan: drift detected — NEW: 59 unclassified
tool(s)". All 59 are in the new `termlink_agent_*` family (social/messaging primitives:
post, react, pin, ack, search, history, threads, etc.). T-1646 designed exactly this
scenario — the baseline at `.context/audits/orchestrator-mcp-baseline.yaml` is the
project's source of truth for classification, and the prescribed mitigation is to
update it.

**Path-isolation note:** the source of truth (`/opt/termlink/crates/termlink-mcp/src/tools.rs`)
is outside PROJECT_ROOT and unreadable from here. Classification is by naming convention:
read-suffix nouns (`_history`, `_recent`, `_info`, `_state`, `_summary`, `_stats`,
`_peers`, `_threads`, `_unread`, etc.) → `readonly_exempt`; action verbs
(`_post`, `_react`, `_pin`, `_edit`, `_star`, `_redact`, `_ack`, `_reply`, `_quote`,
`_vote`, `_typing`) → `mutators_ungated`. Human can correct miscategorisations on review.

## Acceptance Criteria

### Agent
- [x] All 59 new tools classified into `mutators_ungated` (13) or `readonly_exempt` (46)
- [x] `baseline_count` updated from 75 → 134 to match current observable count
- [x] `last_verified` updated to 2026-05-06
- [x] `bin/fw audit` no longer raises "Orchestrator-arc MCP scan: drift detected" with NEW unclassified
- [x] Baseline YAML parses; counts match list lengths (4 + 42 + 88 = 134)

## Verification

bash agents/audit/orchestrator-mcp-scan.sh > /tmp/T1755-mcp-scan.out 2>&1; ! grep -q 'unclassified tool' /tmp/T1755-mcp-scan.out
python3 -c "import yaml; yaml.safe_load(open('.context/audits/orchestrator-mcp-baseline.yaml'))"

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

### 2026-05-06 — counts came in 13/46, not 14/45
- **What changed:** Initial mental model assumed 14 mutators (treating `agent_typing` as
  borderline ephemeral). Walking the list more carefully, and applying the existing
  baseline's convention (e.g. `termlink_kv_set` is a mutator even though kv values are
  ephemeral), `typing` lands in mutators while `ack_history` (which I almost grouped with
  `ack`) stays readonly because the suffix `_history` is read-shaped.
- **Plan impact:** None — both classifications result in the same WARN-clearing outcome.
  Naming-convention rule held up under the 59-tool sample.
- **Triggered:** Nothing new. Followup not filed — handler-level verification (gate
  whether each mutator actually has side effects in tools.rs) belongs upstream and
  cannot be done from here.

## Decisions

### 2026-05-06 — naming-convention classification, no upstream read
- **Chose:** Classify by naming convention (action verb → mutator; read-suffix noun → readonly)
- **Why:** `/opt/termlink/crates/termlink-mcp/src/tools.rs` is outside PROJECT_ROOT and unreadable
  per path-isolation hook. The baseline YAML is the project's source of truth; structural
  drift (59 unclassified) is closed and the human can correct any miscategorisation on review.
- **Rejected:**
  - Spawn a TermLink worker to read tools.rs from a path that has access — overkill for
    a 5-minute classification job; would have spent more context on coordination than work.
  - Block on human walking the list — this is mechanical hygiene; human approval belongs
    on the resulting baseline change, not on each line of classification.

### 2026-05-06 — `termlink_agent_typing` → mutator
- **Chose:** Classify `typing` as `mutators_ungated`
- **Why:** It produces an observable side effect on the recipient (typing indicator).
  Ephemeral state is still mutated state — same convention as `termlink_kv_set` on
  ephemeral values.
- **Rejected:** `readonly_exempt` — the tool emits, doesn't read. "Read-only" must mean
  literally returning data without writing.

## Recommendation

**Recommendation:** GO (auto-close)
**Rationale:** Mechanical baseline drift remediation prescribed by T-1646 design. All ACs
pass; MCP scan now PASSES (was WARN). Human review of individual classifications can
ratchet items into `gated` once handler-level governance is wired (out of scope here).
**Evidence:**
- MCP scan before: `[WARN] Orchestrator-arc MCP scan: drift detected — NEW: 59 unclassified tool(s)`
- MCP scan after: `=== orchestrator-mcp-scan (pass) === Tools: 134 (baseline 134)`
- Counts: 4 gated + 42 mutators_ungated + 88 readonly_exempt = 134 ✓
- 13 mutators classified by action-verb convention (post, react, pin, edit, star, ack,
  redact, reply, quote, vote start/end/cast, typing)
- 46 readonly classified by read-suffix convention (history, summary, stats, info, state,
  threads, search, recent, peers, etc.)

## Updates

### 2026-05-05T22:22:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1755-classify-59-new-termlinkagent-mcp-tools-.md
- **Context:** Initial task creation

### 2026-05-05T22:23:53Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c323314a
- **Timestamp:** 2026-06-02T14:59:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T22:26:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
